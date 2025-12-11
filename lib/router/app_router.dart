import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/log_batch.dart';
import '../models/log_entry.dart';
import '../models/parcel.dart';
import '../screens/about_screen.dart';
import '../screens/batch_detail_screen.dart';
import '../screens/forest_tab.dart';
import '../screens/intro_wizard_screen.dart';
import '../screens/logs_tab.dart';
import '../screens/map_tab.dart';
import '../screens/parcel_detail_screen.dart';
import '../screens/parcel_editor.dart';
import '../widgets/log_entry_form.dart';
import '../widgets/main_scaffold.dart';
import 'route_names.dart';

/// Navigator keys for StatefulShellRoute branches
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellNavigatorMapKey = GlobalKey<NavigatorState>(debugLabel: 'map');
final _shellNavigatorForestKey = GlobalKey<NavigatorState>(debugLabel: 'forest');
final _shellNavigatorLogsKey = GlobalKey<NavigatorState>(debugLabel: 'logs');

/// Global key to access MapTabState for operations like setNavigationTarget
final mapTabKey = GlobalKey<MapTabState>();

/// Global key to access ForestTabState for refresh operations
final forestTabKey = GlobalKey<ForestTabState>();

/// Parameters for ParcelEditor with optional callback
class ParcelEditorParams {
  final Parcel? parcel;
  final void Function(Parcel)? onSave;

  const ParcelEditorParams({this.parcel, this.onSave});
}

/// Parameters for LogEntryForm with optional callback
class LogEntryFormParams {
  final LogEntry? logEntry;
  final void Function(LogEntry)? onSave;

  const LogEntryFormParams({this.logEntry, this.onSave});
}

/// Create the GoRouter configuration
GoRouter createRouter({required bool showOnboarding}) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: showOnboarding ? AppRoutes.onboarding : AppRoutes.forest,
    debugLogDiagnostics: false,
    routes: [
      // Onboarding (outside shell, shown before main app)
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const IntroWizardScreen(),
      ),

      // About screen (full screen, outside shell)
      GoRoute(
        path: AppRoutes.about,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => const AboutScreen(),
      ),

      // Main shell with tabs
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Map tab (index 0)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorMapKey,
            routes: [
              GoRoute(
                path: AppRoutes.map,
                builder: (context, state) => MapTab(key: mapTabKey),
              ),
            ],
          ),

          // Forest tab (index 1, default)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorForestKey,
            routes: [
              GoRoute(
                path: AppRoutes.forest,
                builder: (context, state) => ForestTab(key: forestTabKey),
                routes: [
                  // Parcel detail nested under forest
                  GoRoute(
                    path: 'parcel/:id',
                    builder: (context, state) {
                      final parcel = state.extra as Parcel;
                      return ParcelDetailScreen(parcel: parcel);
                    },
                  ),
                ],
              ),
            ],
          ),

          // Logs tab (index 2)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorLogsKey,
            routes: [
              GoRoute(
                path: AppRoutes.logs,
                builder: (context, state) => const LogsTab(),
                routes: [
                  // Batch detail nested under logs
                  GoRoute(
                    path: 'batch/:id',
                    builder: (context, state) {
                      final batch = state.extra as LogBatch;
                      return BatchDetailScreen(batch: batch);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Full screen routes (outside tabs, use root navigator)
      GoRoute(
        path: AppRoutes.parcelNew,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final params = state.extra as ParcelEditorParams?;
          return MaterialPage(
            fullscreenDialog: true,
            child: ParcelEditor(
              parcel: params?.parcel,
              onSave: params?.onSave,
            ),
          );
        },
      ),

      // Parcel edit (full screen, uses parcel ID from path)
      GoRoute(
        path: '/forest/parcel/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final params = state.extra as ParcelEditorParams;
          return MaterialPage(
            fullscreenDialog: true,
            child: ParcelEditor(
              parcel: params.parcel,
              onSave: params.onSave,
            ),
          );
        },
      ),

      // Log entry form (full screen)
      GoRoute(
        path: AppRoutes.logNew,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final params = state.extra as LogEntryFormParams?;
          return MaterialPage(
            fullscreenDialog: true,
            child: LogEntryForm(
              logEntry: params?.logEntry,
              onSave: params?.onSave,
            ),
          );
        },
      ),

      // Log edit (full screen)
      GoRoute(
        path: '/logs/log/:id/edit',
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) {
          final params = state.extra as LogEntryFormParams;
          return MaterialPage(
            fullscreenDialog: true,
            child: LogEntryForm(
              logEntry: params.logEntry,
              onSave: params.onSave,
            ),
          );
        },
      ),
    ],
  );
}
