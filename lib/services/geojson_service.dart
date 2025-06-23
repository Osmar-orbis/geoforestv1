// lib/services/geojson_service.dart (VERSÃO ATUALIZADA COM PEDIDO DE PERMISSÃO MODERNO)

import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart'; // Import necessário

class GeoJsonService {
  Future<List<Polygon>> importAndParseGeoJson() async {
    // =======================================================================
    // ============ PEDIDO DE PERMISSÃO ATUALIZADO (FORMA MODERNA) =============
    // =======================================================================
    // Esta abordagem é mais compatível com Android 13+
    var photosStatus = await Permission.photos.status;
    var videosStatus = await Permission.videos.status;

    if (!photosStatus.isGranted) {
      photosStatus = await Permission.photos.request();
    }
    if (!videosStatus.isGranted) {
      videosStatus = await Permission.videos.request();
    }

    // Se o usuário negou alguma das permissões de mídia, tentamos o 'storage' como um fallback.
    if (!photosStatus.isGranted && !videosStatus.isGranted) {
      var storageStatus = await Permission.storage.request();
      if (!storageStatus.isGranted) {
        print("ERRO: Permissão de acesso a mídias/arquivos foi negada.");
        return [];
      }
    }
    // =======================================================================

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'json'],
    );

    if (result == null || result.files.single.path == null) {
      print("DEBUG: Nenhum arquivo selecionado.");
      return [];
    }

    try {
      final filePath = result.files.single.path!;
      final file = File(filePath);
      final fileContent = await file.readAsString();

      if (fileContent.isEmpty) {
        print("ERRO: O conteúdo do arquivo está vazio!");
        return [];
      }
      print("DEBUG: Conteúdo do arquivo lido com sucesso. Tamanho: ${fileContent.length} caracteres.");

      final geoJsonData = json.decode(fileContent);

      print("DEBUG: JSON decodificado com sucesso!");
      if (geoJsonData['features'] == null) {
        print("ERRO: O JSON não contém a chave 'features'.");
        return [];
      }
      print("DEBUG: Encontradas ${geoJsonData['features'].length} features.");

      final List<Polygon> polygons = [];

      for (var feature in geoJsonData['features']) {
        final geometry = feature['geometry'];
        if (geometry != null) {
          if (geometry['type'] == 'Polygon') {
            final List<LatLng> points = [];
            for (var point in geometry['coordinates'][0]) {
              points.add(LatLng(point[1].toDouble(), point[0].toDouble()));
            }
            polygons.add(_createPolygon(points));
          } else if (geometry['type'] == 'MultiPolygon') {
            for (var polygonCoords in geometry['coordinates']) {
              final List<LatLng> points = [];
              for (var point in polygonCoords[0]) {
                points.add(LatLng(point[1].toDouble(), point[0].toDouble()));
              }
              polygons.add(_createPolygon(points));
            }
          }
        }
      }

      print("DEBUG: Processamento concluído. ${polygons.length} polígonos criados.");
      return polygons;

    } catch (e, s) {
      debugPrint("ERRO CRÍTICO: $e");
      debugPrint("Stacktrace: $s");
      return [];
    }
  }

  Polygon _createPolygon(List<LatLng> points) {
    return Polygon(
      points: points,
      color: const Color(0xFF617359).withAlpha(128),
      borderColor: const Color(0xFF1D4433),
      borderStrokeWidth: 2,
    );
  }
}