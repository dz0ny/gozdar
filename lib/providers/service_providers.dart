import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/cadastral_service.dart';
import '../services/database_service.dart';
import '../services/log_input_prefs_service.dart';
import '../services/map_preferences_service.dart';

/// Collaborators the notifiers read, so tests can swap them with overrides.
final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

final mapPreferencesServiceProvider = Provider<MapPreferencesService>(
  (ref) => MapPreferencesService(),
);

final cadastralServiceProvider = Provider<CadastralService>(
  (ref) => CadastralService(),
);

final logInputPrefsServiceProvider = Provider<LogInputPrefsService>(
  (ref) => LogInputPrefsService(),
);
