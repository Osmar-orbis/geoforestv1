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
    required List<SamplePoint> samplePoints, // Recebe todos os pontos
    required String farmName,
    required String blockName,
  }) async {

    // =========================================================================
    // ---> INÍCIO DA MUDANÇA: FILTRAGEM DOS PONTOS <---
    // =========================================================================

    // 1. FILTRAR A LISTA: Criamos uma nova lista contendo apenas os pontos
    // cujo status é 'completed'.
    final List<SamplePoint> pontosConcluidos = samplePoints
        .where((ponto) => ponto.status == SampleStatus.completed)
        .toList();

    // 2. VERIFICAR: Se não houver polígonos da área E nenhum ponto concluído,
    // não há nada para exportar. Avisamos o usuário e paramos a função.
    if (areaPolygons.isEmpty && pontosConcluidos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhuma área ou amostra concluída para exportar.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }
    
    // Opcional: Avisar se apenas a área será exportada, pois não há pontos concluídos.
    if (areaPolygons.isNotEmpty && pontosConcluidos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Aviso: Nenhuma amostra concluída foi encontrada. Exportando apenas a área do projeto.'),
          backgroundColor: Colors.orange,
        ));
      }
    }

    // =========================================================================
    // ---> FIM DA MUDANÇA <---
    // =========================================================================

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo GeoJSON...')));
      }

      final Map<String, dynamic> geoJson = {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      // Adicionar os polígonos da área (sem alterações nesta parte)
      for (final polygon in areaPolygons) {
        final coordinates = polygon.points.map((p) => [p.longitude, p.latitude]).toList();
        geoJson['features'].add({
          'type': 'Feature',
          'geometry': {'type': 'Polygon', 'coordinates': [coordinates]},
          'properties': {'type': 'area', 'farmName': farmName, 'blockName': blockName},
        });
      }

      // ---> MUDANÇA AQUI: Agora iteramos sobre a LISTA FILTRADA <---
      // Adicionar APENAS os pontos de amostragem CONCLUÍDOS como Features
      for (final point in pontosConcluidos) { // Usando a lista 'pontosConcluidos'
        geoJson['features'].add({
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [point.position.longitude, point.position.latitude],
          },
          'properties': {
            'type': 'plot',
            'id': point.id,
            'status': point.status.name, // Vai salvar como 'completed'
            // Você pode adicionar mais dados do DB aqui se precisar
          },
        });
      }

      // O resto do código permanece o mesmo...
      const jsonEncoder = JsonEncoder.withIndent('  ');
      final geoJsonString = jsonEncoder.convert(geoJson);

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