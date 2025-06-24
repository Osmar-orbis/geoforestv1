// lib/models/sample_point.dart

import 'package:latlong2/latlong.dart';

class SamplePoint {
  final int id; // Número da parcela (ex: 1, 2, 3...)
  final LatLng position; // Coordenadas do ponto

  SamplePoint({
    required this.id,
    required this.position,
  });
}