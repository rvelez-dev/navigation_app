import 'package:latlong2/latlong.dart' as ll2;

/// Calculates a human-readable walking-time estimate for a route.
///
/// Pure math — no Flutter, no async, no state.
class WalkingTimeCalculator {
  /// Average walking speed in meters per second (~5 km/h).
  static const double walkingSpeedMps = 1.4;

  /// Returns a string like "~4 min walk • 320 m" for the given route.
  /// Returns an empty string if the route has fewer than 2 points.
  static String estimate(List<ll2.LatLng> route) {
    if (route.length < 2) return '';

    const ll2.Distance distCalc = ll2.Distance();
    double totalMeters = 0;
    for (int i = 0; i < route.length - 1; i++) {
      totalMeters +=
          distCalc.as(ll2.LengthUnit.Meter, route[i], route[i + 1]);
    }

    final int seconds = (totalMeters / walkingSpeedMps).round();
    final int minutes = (seconds / 60).ceil();

    if (minutes < 1) return '< 1 min walk';
    return '~$minutes min walk • ${totalMeters.round()} m';
  }
}
