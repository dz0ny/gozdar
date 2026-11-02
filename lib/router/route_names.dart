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
  static String parcelDetail(int id) => '/forest/parcel/$id';
  static String parcelEdit(int id) => '/forest/parcel/$id/edit';

  // Log routes
  static const logNew = '/log/new';
  static String logEdit(int id) => '/logs/log/$id/edit';

  // Sečnja share link (https://gozdar.dz0ny.dev/o/<id>)
  static String share(String id) => '/o/$id';

  // Batch routes
  static String batchDetail(int id) => '/logs/batch/$id';
}
