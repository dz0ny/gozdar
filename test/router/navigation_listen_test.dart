import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gozdar/models/navigation_target.dart';
import 'package:gozdar/router/navigation_notifier.dart';
import 'package:latlong2/latlong.dart';

/// The shell listens for navigation commands. A command sent from a screen
/// pushed over it must still reach it.
class _Shell extends ConsumerStatefulWidget {
  const _Shell(this.onCommand);
  final VoidCallback onCommand;

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> {
  @override
  Widget build(BuildContext context) {
    ref.listen(navigationNotifierProvider, (_, next) {
      if (next.pendingNavigationTarget != null) widget.onCommand();
    });
    return TextButton(
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () {
                ref
                    .read(navigationNotifierProvider.notifier)
                    .navigateToMapWithTarget(
                      NavigationTarget(
                        location: const LatLng(46, 14),
                        name: 'Smreka',
                      ),
                    );
                Navigator.of(context).pop();
              },
              child: const Text('SEND'),
            ),
          ),
        ),
      ),
      child: const Text('OPEN'),
    );
  }
}

void main() {
  testWidgets('a command from a pushed screen reaches the shell', (
    tester,
  ) async {
    var commands = 0;
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: _Shell(() => commands++))),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SEND'));
    await tester.pumpAndSettle();
    expect(commands, 1);
  });
}
