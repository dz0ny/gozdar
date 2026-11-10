import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/services/file_hash.dart';
import 'package:gozdar/services/kataster_sharing_service.dart';

/// A phone that shares one file, like the server in the app.
class _Peer {
  _Peer(this.fileName, this.file);

  final String fileName;
  final File file;
  var downloads = 0;
  late final HttpServer _server;

  KatasterPeer get peer =>
      KatasterPeer(host: _server.address.host, port: _server.port);

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      if (request.uri.path == '/kataster/files') {
        request.response
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode([
              {'fileName': fileName, 'bytes': file.lengthSync()},
            ]),
          );
        await request.response.close();
        return;
      }
      if (request.method == 'GET') downloads++;
      await KatasterSharingService.serveFile(request, file);
    });
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  final service = KatasterSharingService.instance;
  const name = 'addresses.sqlite';
  final good = Uint8List.fromList(List.generate(70000, (i) => i % 251));
  final goodHash = sha256.convert(good).toString();
  late Directory dir;
  late File target;
  final peers = <_Peer>[];

  Future<_Peer> share(String label, List<int> bytes) async {
    final file = File('${dir.path}/$label')..writeAsBytesSync(bytes);
    final peer = _Peer(name, file);
    await peer.start();
    peers.add(peer);
    service.addPeerForTesting(peer.peer);
    return peer;
  }

  setUp(() {
    dir = Directory.systemTemp.createTempSync('peer_verify');
    target = File('${dir.path}/$name.part');
    service.trustedHash = (_) async => goodHash;
  });

  tearDown(() async {
    service.clearPeersForTesting();
    for (final peer in peers) {
      await peer.stop();
    }
    peers.clear();
    dir.deleteSync(recursive: true);
  });

  test('sha256OfFile gives the known hash of "abc"', () async {
    final file = File('${dir.path}/abc')..writeAsStringSync('abc');
    expect(
      await sha256OfFile(file.path),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  test('a copy with the manifest hash is accepted', () async {
    await share('good', good);
    // A part of an earlier internet download must not survive.
    target.writeAsBytesSync([1, 2, 3]);
    File('${target.path}.validator').writeAsStringSync('"old"');

    final ok = await service.downloadFileTo(name, target, discover: false);

    expect(ok, isTrue);
    expect(target.readAsBytesSync(), good);
    expect(File('${target.path}.validator').existsSync(), isFalse);
    expect(File('${target.path}.peer').existsSync(), isFalse);
  });

  test('a changed copy is dropped and the target stays untouched', () async {
    final bad = Uint8List.fromList(good)..[100] ^= 1;
    final peer = await share('bad', bad);
    target.writeAsBytesSync([1, 2, 3]);

    final ok = await service.downloadFileTo(name, target, discover: false);

    expect(ok, isFalse);
    expect(peer.downloads, 1);
    expect(target.readAsBytesSync(), [1, 2, 3]);
    expect(File('${target.path}.peer').existsSync(), isFalse);
  });

  test('the next phone is asked after a changed copy', () async {
    await share('bad', Uint8List.fromList(good)..[0] ^= 1);
    await share('good', good);

    final ok = await service.downloadFileTo(name, target, discover: false);

    expect(ok, isTrue);
    expect(target.readAsBytesSync(), good);
  });

  test('without a known hash nothing is downloaded from a phone', () async {
    final peer = await share('good', good);
    service.trustedHash = (_) async => null;

    final ok = await service.downloadFileTo(name, target, discover: false);

    expect(ok, isFalse);
    expect(peer.downloads, 0);
    expect(target.existsSync(), isFalse);
  });
}
