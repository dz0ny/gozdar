import 'dart:convert';

import 'secnja_share.dart';

/// Sečnja that another owner shared with this phone through a link.
class ReceivedShare {
  int id;
  String shareId;
  String payloadJson;
  DateTime fetchedAt;
  DateTime expiresAt;
  bool visible;

  ReceivedShare({
    this.id = 0,
    required this.shareId,
    required this.payloadJson,
    required this.fetchedAt,
    required this.expiresAt,
    this.visible = true,
  });

  SecnjaSharePayload get payload => SecnjaSharePayload.fromJson(
        jsonDecode(payloadJson) as Map<String, dynamic>,
      );

  /// Whole days until the link expires, never below zero.
  int get daysLeft {
    final left = expiresAt.difference(DateTime.now());
    return left.isNegative ? 0 : (left.inHours / 24).ceil();
  }
}
