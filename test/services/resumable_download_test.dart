import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/kataster_sharing_service.dart';
import 'package:gozdar/services/resumable_download.dart';

/// Serves [body] with ETag, `Range: bytes=N-` and `If-Range`, like R2 and
/// the phone-to-phone server. With [cutAfter] the first full response drops
/// the connection after that many bytes.
class _Server {
  _Server(this.body, this.etag, {this.cutAfter, this.honourIfRange = true});

  Uint8List body;
  String etag;
  int? cutAfter;

  /// R2 sends the requested tail even when If-Range names another version.
  final bool honourIfRange;
  final ranges = <String?>[];
  late final HttpServer _server;

  String get url => 'http://${_server.address.host}:${_server.port}/file';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen(_handle);
  }

  Future<void> stop() => _server.close(force: true);

  Future<void> _handle(HttpRequest request) async {
    final range = request.headers.value(HttpHeaders.rangeHeader);
    ranges.add(range);
    final response = request.response
      ..headers.set(HttpHeaders.etagHeader, etag);
    if (request.method == 'HEAD') {
      response.contentLength = body.length;
      await response.close();
      return;
    }
    final start = range == null
        ? null
        : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)!.group(1)!);
    final ifRange = request.headers.value(HttpHeaders.ifRangeHeader);
    if (start != null && (ifRange == etag || !honourIfRange)) {
      if (start >= body.length) {
        response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
        await response.close();
        return;
      }
      response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(HttpHeaders.contentRangeHeader,
            'bytes $start-${body.length - 1}/${body.length}')
        ..contentLength = body.length - start
        ..add(body.sublist(start));
      await response.close();
      return;
    }
    response.contentLength = body.length;
    final cut = cutAfter;
    if (cut != null) {
      cutAfter = null;
      final socket = await response.detachSocket(); // writes the headers
      socket.add(body.sublist(0, cut));
      await socket.flush();
      socket.destroy();
      return;
    }
    response.add(body);
    await response.close();
  }
}

Uint8List _bytes(int n, int seed) =>
    Uint8List.fromList(List.generate(n, (i) => (i * 31 + seed) & 0xff));

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('resumable'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('continues after the connection drops mid-file', () async {
    final body = _bytes(300000, 1);
    final server = _Server(body, '"v1"', cutAfter: 100000);
    await server.start();
    addTearDown(server.stop);
    final part = File('${dir.path}/f.part');

    final result = await ResumableDownload.fetch(server.url, part);

    expect(result.isComplete, isTrue);
    expect(await part.readAsBytes(), body);
    expect(server.ranges.last, startsWith('bytes='));
    expect(int.parse(server.ranges.last!.substring(6, server.ranges.last!.length - 1)),
        greaterThan(0));
  });

  test('continues a part left by an earlier run', () async {
    final body = _bytes(200000, 2);
    final server = _Server(body, '"v1"');
    await server.start();
    addTearDown(server.stop);
    final part = File('${dir.path}/f.part')
      ..writeAsBytesSync(body.sublist(0, 50000));
    File('${part.path}.validator').writeAsStringSync('"v1"');

    final result = await ResumableDownload.fetch(server.url, part);

    expect(result.isComplete, isTrue);
    expect(await part.readAsBytes(), body);
    expect(server.ranges, ['bytes=50000-']);
  });

  test('starts over when the file changed since the part began', () async {
    final body = _bytes(120000, 3);
    final server = _Server(body, '"v2"');
    await server.start();
    addTearDown(server.stop);
    final part = File('${dir.path}/f.part')
      ..writeAsBytesSync(_bytes(40000, 9)); // from the old file
    File('${part.path}.validator').writeAsStringSync('"v1"');

    final result = await ResumableDownload.fetch(server.url, part);

    expect(result.isComplete, isTrue);
    expect(await part.readAsBytes(), body);
  });

  test('starts over when the server ignores If-Range for a changed file',
      () async {
    final body = _bytes(120000, 6);
    final server = _Server(body, '"v2"', honourIfRange: false);
    await server.start();
    addTearDown(server.stop);
    final part = File('${dir.path}/f.part')
      ..writeAsBytesSync(_bytes(40000, 9)); // from the old file
    File('${part.path}.validator').writeAsStringSync('"v1"');

    final result = await ResumableDownload.fetch(server.url, part);

    expect(result.isComplete, isTrue);
    expect(await part.readAsBytes(), body);
    expect(server.ranges, ['bytes=40000-', null]);
  });

  test('a finished part that was kept is confirmed without a new download',
      () async {
    final body = _bytes(80000, 4);
    final server = _Server(body, '"v1"');
    await server.start();
    addTearDown(server.stop);
    final part = File('${dir.path}/f.part');
    await ResumableDownload.fetch(server.url, part);

    final again = await ResumableDownload.fetch(server.url, part);

    expect(again.isComplete, isTrue);
    expect(server.ranges.sublist(1), ['bytes=80000-', null]); // GET, HEAD
    expect(await part.readAsBytes(), body);
  });

  test('reports a refused request', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((r) {
      r.response.statusCode = HttpStatus.notFound;
      r.response.close();
    });

    final result = await ResumableDownload.fetch(
      'http://127.0.0.1:${server.port}/x',
      File('${dir.path}/x.part'),
    );

    expect(result.outcome, DownloadOutcome.failed);
    expect(result.statusCode, 404);
  });

  test('a nearby phone serves the rest of a file it was cut off from',
      () async {
    final body = _bytes(150000, 5);
    final source = File('${dir.path}/parcels-x.sqlite')..writeAsBytesSync(body);
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final ranges = <String?>[];
    server.listen((r) {
      ranges.add(r.headers.value(HttpHeaders.rangeHeader));
      KatasterSharingService.serveFile(r, source);
    });
    final url = 'http://127.0.0.1:${server.port}/kataster/files/parcels-x.sqlite';
    final part = File('${dir.path}/got.part');
    await ResumableDownload.fetch(url, part); // learns the ETag
    await part.writeAsBytes(body.sublist(0, 60000)); // as if cut off here

    final result = await ResumableDownload.fetch(url, part);

    expect(result.isComplete, isTrue);
    expect(ranges.last, 'bytes=60000-');
    expect(await part.readAsBytes(), body);
  });
}
