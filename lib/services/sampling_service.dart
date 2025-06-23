// lib/services/sampling_service.dart (VERSÃO FINAL, SEM NOVAS DEPENDÊNCIAS)

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class SamplingService {
  List<LatLng> generateSamplePoints({
    required Polygon polygon,
    required double hectaresPerSample,
  }) {
    if (hectaresPerSample <= 0 || polygon.points.isEmpty) return [];

    // 1. CALCULAR A ÁREA DO POLÍGONO
    // Usamos o algoritmo "Surveyor's formula" para calcular a área em um plano 2D.
    // Para áreas pequenas/médias, a distorção é aceitável.
    final areaInSqMeters = _calculatePolygonArea(polygon.points);
    final areaInHectares = areaInSqMeters / 10000;

    // 2. CALCULAR O NÚMERO DE PONTOS
    final int numberOfPoints = (areaInHectares / hectaresPerSample).floor();
    if (numberOfPoints <= 0) return [];

    // 3. ENCONTRAR O BOUNDING BOX
    num minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0;
    for (final point in polygon.points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLon = min(minLon, point.longitude);
      maxLon = max(maxLon, point.longitude);
    }

    final List<LatLng> validSamplePoints = [];
    final Random random = Random();
    int attempts = 0;
    final int maxAttempts = numberOfPoints * 200; // Aumentamos um pouco as tentativas

    // 4. GERAR PONTOS E TESTAR
    while (validSamplePoints.length < numberOfPoints && attempts < maxAttempts) {
      final randLat = minLat + random.nextDouble() * (maxLat - minLat);
      final randLon = minLon + random.nextDouble() * (maxLon - minLon);
      final randomPoint = LatLng(randLat, randLon);

      // 5. VERIFICAR SE O PONTO ESTÁ DENTRO DO POLÍGONO
      // Usamos o algoritmo "Ray-casting" para a verificação.
      if (_isPointInPolygon(randomPoint, polygon.points)) {
        validSamplePoints.add(randomPoint);
      }
      attempts++;
    }

    if (validSamplePoints.length < numberOfPoints) {
      debugPrint("Aviso: Gerados ${validSamplePoints.length} de $numberOfPoints pontos.");
    }
    
    return validSamplePoints;
  }

  // --- ALGORITMOS MATEMÁTICOS IMPLEMENTADOS MANUALMENTE ---

  /// Calcula a área de um polígono usando a fórmula de Shoelace/Surveyor.
  /// Assume um plano cartesiano, o que é uma aproximação.
  /// Converte graus para metros para uma estimativa da área.
  double _calculatePolygonArea(List<LatLng> points) {
    if (points.length < 3) return 0.0;

    double area = 0.0;
    // Conversão aproximada de graus para metros no equador
    const double degToMet = 111320.0; 

    for (int i = 0; i < points.length; i++) {
      LatLng p1 = points[i];
      LatLng p2 = points[(i + 1) % points.length]; // Próximo ponto, voltando ao início no final

      // Converte coordenadas para um sistema de metros aproximado
      double p1x = p1.longitude * degToMet * cos(p1.latitude * pi / 180);
      double p1y = p1.latitude * degToMet;
      double p2x = p2.longitude * degToMet * cos(p2.latitude * pi / 180);
      double p2y = p2.latitude * degToMet;

      area += (p1x * p2y - p2x * p1y);
    }

    return (area.abs() / 2.0);
  }

  /// Verifica se um ponto está dentro de um polígono usando o algoritmo Ray-casting.
  bool _isPointInPolygon(LatLng point, List<LatLng> polygon) {
    int intersections = 0;
    for (int i = 0; i < polygon.length; i++) {
      LatLng p1 = polygon[i];
      LatLng p2 = polygon[(i + 1) % polygon.length];

      if (p1.latitude > point.latitude != p2.latitude > point.latitude) {
        double atX = (p2.longitude - p1.longitude) * (point.latitude - p1.latitude) / (p2.latitude - p1.latitude) + p1.longitude;
        if (point.longitude < atX) {
          intersections++;
        }
      }
    }
    return intersections % 2 == 1;
  }
}