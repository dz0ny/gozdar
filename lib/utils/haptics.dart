import 'dart:async';

import 'package:flutter/services.dart';

/// The app's haptic vocabulary: one weight per kind of action, so the same
/// action always feels the same. Each call fires and forgets.
abstract final class Haptics {
  /// Picking something: a layer, a species, a map vertex.
  static void select() => unawaited(HapticFeedback.selectionClick());

  /// Something placed or saved: a log, a location, a mark.
  static void confirm() => unawaited(HapticFeedback.mediumImpact());

  /// Something removed.
  static void remove() => unawaited(HapticFeedback.heavyImpact());
}
