import 'package:geolocator/geolocator.dart';

class GozdarLocationSettings {
  GozdarLocationSettings._();

  static const currentPosition = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    timeLimit: Duration(seconds: 20),
  );

  static const stream = LocationSettings(
    accuracy: LocationAccuracy.bestForNavigation,
    distanceFilter: 0,
  );
}
