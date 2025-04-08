import 'package:latlong2/latlong.dart';

class JobArea {
  final int jobId;
  final List<LatLng> polygonPoints;

  JobArea({
    required this.jobId,
    required this.polygonPoints,
  });
}