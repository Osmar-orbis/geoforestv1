// lib/services/export_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  
  Future<void> exportProjectAsGeoJson({
    required BuildContext context,
    required List<Polygon> areaPolygons,
    required List<SamplePoint> samplePoints,
    required String farmName,
    required String blockName,
  }) async {
    if (areaPolygons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma área de projeto para exportar.')));
      return;
    }

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo de projeto GeoJSON...')));
      }

      // 1. Criar a estrutura base do GeoJSON (FeatureCollection)
      final Map<String, dynamic> geoJson = {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      // 2. Adicionar os polígonos da área como Features
      for (final polygon in areaPolygons) {
        final coordinates = polygon.points.map((p) => [p.longitude, p.latitude]).toList();
        
        geoJson['features'].add({
          'type': 'Feature',
          'geometry': {
            'type': 'Polygon',
            'coordinates': [coordinates], // GeoJSON Polygon precisa de um array de anéis
          },
          'properties': {
            'type': 'area',
            'farmName': farmName,
            'blockName': blockName,
          },
        });
      }

      // 3. Adicionar os pontos de amostragem como Features
      for (final point in samplePoints) {
        geoJson['features'].add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [point.position.longitude, point.position.latitude],
          },
          'properties': {
            'type': 'plot',
            'id': point.id,
            'status': point.status.name,
          },
        });
      }

      // 4. Converter o mapa Dart para uma string JSON formatada
      const jsonEncoder = JsonEncoder.withIndent('  ');
      final geoJsonString = jsonEncoder.convert(geoJson);

      // 5. Salvar e compartilhar o arquivo
      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final nomePastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDoDia = Directory('${directory.path}/$nomePastaData');
      if (!await pastaDoDia.exists()) await pastaDoDia.create(recursive: true);
      
      final fileName = 'Projeto_${farmName.replaceAll(' ', '_')}_${blockName.replaceAll(' ', '_')}.geojson';
      final path = '${pastaDoDia.path}/$fileName';

      await File(path).writeAsString(geoJsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Projeto de Amostragem GeoForest: $farmName - $blockName',
        );
      }

    } catch (e, s) {
      debugPrint('Erro na exportação para GeoJSON: $e\n$s');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na exportação: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }
}