/// Route path constants for go_router navigation
class AppRoutes {
  AppRoutes._();

  // Root routes
  static const onboarding = '/onboarding';
  static const about = '/about';

  // Tab routes (StatefulShellRoute branches)
  static const map = '/map';
  static const forest = '/forest';
  static const logs = '/logs';

  // Parcel routes
  static const parcelNew = '/parcel/new';
  static String parcelDetail(int id) => '/forest/parcel/$id';
  static String parcelEdit(int id) => '/forest/parcel/$id/edit';

  // Log routes
  static const logNew = '/log/new';
  static String logEdit(int id) => '/logs/log/$id/edit';

  // Batch routes
  static String batchDetail(int id) => '/logs/batch/$id';
}
