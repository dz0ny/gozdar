import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/parcel.dart';
import '../models/map_location.dart';
import '../models/secnja_share.dart';
import 'database_service.dart';

/// The result of an upload: the link to send and when it expires.
class ShareResult {
  final Uri link;
  final DateTime expiresAt;

  const ShareResult(this.link, this.expiresAt);
}

/// The share could not reach the server or the server refused it.
class ShareException implements Exception {
  final String message;

  const ShareException(this.message);

  @override
  String toString() => 'ShareException: $message';
}

enum ReceiveOutcome { imported, expired, offline, invalid }

/// What [SecnjaShareService.receive] did. On import it has the payload and
/// the id of the parcel that now holds the trees.
typedef ReceiveResult = ({
  ReceiveOutcome outcome,
  SecnjaSharePayload? payload,
  int? parcelId,
});

const ReceiveResult _offline = (outcome: ReceiveOutcome.offline, payload: null, parcelId: null);

/// Uploads sečnja shares to the worker and downloads shares from others.
class SecnjaShareService {
  static const _timeout = Duration(seconds: 15);

  static SecnjaShareService _instance = SecnjaShareService();
  static SecnjaShareService get instance => _instance;

  @visibleForTesting
  static set instance(SecnjaShareService value) => _instance = value;

  final http.Client _client;
  final DatabaseService _db;
  final Uri base;

  SecnjaShareService({http.Client? client, DatabaseService? db, Uri? base})
      : _client = client ?? http.Client(),
        _db = db ?? DatabaseService(),
        base = base ?? Uri.parse('https://gozdar.dz0ny.dev');

  Uri linkFor(String shareId) => base.replace(path: '/s/$shareId');

  Uri _api([String? id]) => base.replace(path: id == null ? '/api/s' : '/api/s/$id');

  Map<String, String> _headers([String? token]) => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(_timeout);
    } on TimeoutException {
      throw const ShareException('timeout');
    } on ShareException {
      rethrow;
    } catch (e) {
      throw ShareException(e.toString());
    }
  }

  /// Uploads [payload] for [parcel]. The first upload makes a new link.
  /// Later uploads update the same link and restart its 30 days.
  Future<ShareResult> share(Parcel parcel, SecnjaSharePayload payload) async {
    final body = jsonEncode(payload.toJson());
    var id = parcel.shareId;
    var token = parcel.shareEditToken;
    String? expires;

    if (id != null && token != null) {
      final res = await _send(_client.put(_api(id), headers: _headers(token), body: body));
      if (res.statusCode == 200) {
        expires = (jsonDecode(res.body) as Map)['expiresAt'] as String;
      } else if (res.statusCode != 404 && res.statusCode != 403) {
        throw ShareException('HTTP ${res.statusCode}');
      }
      // On 404 or 403 the old link is gone. Make a new one.
    }

    if (expires == null) {
      final res = await _send(_client.post(_api(), headers: _headers(), body: body));
      if (res.statusCode != 201) throw ShareException('HTTP ${res.statusCode}');
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      id = json['id'] as String;
      token = json['editToken'] as String;
      expires = json['expiresAt'] as String;
    }

    final expiresAt = DateTime.parse(expires);
    await _db.saveParcelShare(
      parcel.id,
      shareId: id!,
      editToken: token!,
      hash: payload.contentHash,
      sharedAt: DateTime.now(),
      expiresAt: expiresAt,
    );
    return ShareResult(linkFor(id), expiresAt);
  }

  /// Deletes the link of [parcel] on the server and forgets it locally.
  Future<void> revoke(Parcel parcel) async {
    final id = parcel.shareId;
    final token = parcel.shareEditToken;
    if (id != null && token != null) {
      final res = await _send(_client.delete(_api(id), headers: _headers(token)));
      if (res.statusCode != 204 && res.statusCode != 404) {
        throw ShareException('HTTP ${res.statusCode}');
      }
    }
    await _db.clearParcelShare(parcel.id);
  }

  /// Deletes the link of a parcel that the owner deletes. The parcel goes
  /// away anyway, so a failure only leaves the link to expire by itself.
  Future<void> revokeQuietly(Parcel parcel) async {
    if (!parcel.isShared) return;
    try {
      await revoke(parcel);
    } catch (e) {
      debugPrint('Revoking share of parcel ${parcel.id} failed: $e');
    }
  }

  /// Downloads the share [shareId] and imports it: the parcel joins Moj gozd
  /// (or the matching saved parcel is used) and its trees become sečnja marks.
  /// The logger can then share the parcel on, like any own parcel.
  Future<ReceiveResult> receive(String shareId) async {
    final http.Response res;
    try {
      res = await _send(_client.get(_api(shareId)));
    } on ShareException {
      return _offline;
    }
    if (res.statusCode == 404 || res.statusCode == 410) {
      return (outcome: ReceiveOutcome.expired, payload: null, parcelId: null);
    }
    if (res.statusCode != 200) return _offline;

    final SecnjaSharePayload payload;
    try {
      payload = SecnjaSharePayload.fromJson(
        jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
      );
    } catch (_) {
      // A login page of a public Wi-Fi, or a share from a newer app.
      return (outcome: ReceiveOutcome.invalid, payload: null, parcelId: null);
    }
    final parcelId = await _import(shareId, payload);
    return (outcome: ReceiveOutcome.imported, payload: payload, parcelId: parcelId);
  }

  /// Stores [payload] and returns the id of its parcel.
  Future<int> _import(String shareId, SecnjaSharePayload payload) async {
    final existing = payload.koNumber != null
        ? await _db.findParcelByKoAndNumber(payload.koNumber, payload.parcelNumber)
        : await _db.findParcelByName(payload.parcelNumber);
    // The owner opened their own link: the marks are already here.
    if (existing != null && existing.shareId == shareId) return existing.id;

    final parcelId = existing?.id ??
        await _db.insertParcel(Parcel(
          name: payload.koName != null
              ? '${payload.koName} - ${payload.parcelNumber}'
              : payload.parcelNumber,
          polygon: payload.polygon,
          cadastralMunicipality: payload.koNumber,
          parcelNumber: payload.koNumber != null ? payload.parcelNumber : null,
          owner: payload.owner,
        ));

    // An updated link replaces the trees it brought before.
    await _db.deleteSecnjaFromShare(shareId);
    final have = await _db.getSecnjaByParcel(parcelId);
    for (final p in payload.points) {
      // A forwarded link can bring trees this phone already has.
      final known = have.any((m) =>
          (m.latitude - p.lat).abs() < 1e-6 && (m.longitude - p.lng).abs() < 1e-6);
      if (known) continue;
      await _db.insertLocation(MapLocation(
        name: p.name,
        latitude: p.lat,
        longitude: p.lng,
        type: LocationType.secnja,
        parcelId: parcelId,
        sourceShareId: shareId,
      ));
    }
    return parcelId;
  }
}
