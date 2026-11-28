import 'package:material_ui/material_ui.dart';

import '../theme/motion.dart';

/// A number that counts to its new value instead of snapping, e.g. the
/// total volume after a log is added.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final double value;
  final String Function(double value) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: Motion.of(context, Motion.medium),
      curve: Motion.emphasized,
      builder: (context, shown, _) => Text(format(shown), style: style),
    );
  }
}

/// Grows and fades a row in once, when [animate] is set as it first builds.
/// Key it by the row's id so it plays only for a row new to the list.
class RowEntrance extends StatefulWidget {
  const RowEntrance({super.key, required this.animate, required this.child});

  final bool animate;
  final Widget child;

  @override
  State<RowEntrance> createState() => _RowEntranceState();
}

class _RowEntranceState extends State<RowEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Motion.emphasized,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.animate && _controller.value == 1 && !_started) {
      _started = true;
      final duration = Motion.of(context, Motion.medium);
      if (duration > Duration.zero) {
        _controller
          ..duration = duration
          ..forward(from: 0);
      }
    }
  }

  bool _started = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _curve,
      alignment: Alignment.topCenter,
      child: FadeTransition(opacity: _curve, child: widget.child),
    );
  }
}
