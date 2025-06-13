import 'package:geolocator/geolocator.dart';

class GeofenceService {
  Future<bool> isWithinGeofence(double userLat, double userLng, double officeLat, double officeLng, {double radiusInMeters = 100}) async {
    final distance = Geolocator.distanceBetween(userLat, userLng, officeLat, officeLng);
    return distance <= radiusInMeters;
  }
}
