import 'package:flutter/widgets.dart';

/// Durations and curves for the app's motion, so moves feel alike.
///
/// Read [of] instead of a raw duration: it drops to zero when the user asked
/// the system to reduce motion.
abstract final class Motion {
  /// Small state changes: a highlight, a fade.
  static const short = Duration(milliseconds: 150);

  /// Rows coming and going, counters.
  static const medium = Duration(milliseconds: 300);

  /// Camera moves on the map.
  static const long = Duration(milliseconds: 450);

  /// Moves that start and end at rest (the map camera).
  static const Curve standard = Curves.easeInOutCubic;

  /// Things arriving on screen: fast in, gentle stop.
  static const Curve emphasized = Curves.easeOutCubic;

  /// Whether the user asked the system to reduce motion.
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [duration], or zero under reduced motion.
  static Duration of(BuildContext context, Duration duration) =>
      reduced(context) ? Duration.zero : duration;
}
