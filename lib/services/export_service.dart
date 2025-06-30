// lib/services/export_service.dart

import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
// import 'package:geoforestcoletor/models/projeto_model.dart'; // <<< REMOVIDO
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {

  Future<void> exportarProjetosCompletos({
    required BuildContext context,
    required List<int> projetoIds,
  }) async {
    if (projetoIds.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preparando dados para exportação...')));

    try {
      final dbHelper = DatabaseHelper.instance;
      final List<Map<String, dynamic>> features = [];

      for (final projetoId in projetoIds) {
        final projeto = await dbHelper.getProjetoById(projetoId);
        if (projeto == null) continue;

        final atividades = await dbHelper.getAtividadesDoProjeto(projetoId);
        for (final atividade in atividades) {
          final fazendas =
              await dbHelper.getFazendasDaAtividade(atividade.id!);
          for (final fazenda in fazendas) {
            final talhoes = await dbHelper.getTalhoesDaFazenda(
                fazenda.id, fazenda.atividadeId);
            for (final talhao in talhoes) {
              final parcelas = await dbHelper.getParcelasDoTalhao(talhao.id!);
              for (final parcela in parcelas) {
                features.add({
                  'type': 'Feature',
                  'geometry': parcela.latitude != null
                      ? {
                          'type': 'Point',
                          'coordinates': [parcela.longitude, parcela.latitude],
                        }
                      : null,
                  'properties': {
                    'tipo_feature': 'parcela_planejada',
                    'projeto_nome': projeto.nome,
                    'projeto_empresa': projeto.empresa,
                    'projeto_responsavel': projeto.responsavel,
                    'atividade_tipo': atividade.tipo,
                    'atividade_descricao': atividade.descricao,
                    'fazenda_id': fazenda.id,
                    'fazenda_nome': fazenda.nome,
                    'fazenda_municipio': fazenda.municipio,
                    'fazenda_estado': fazenda.estado,
                    'talhao_nome': talhao.nome,
                    'talhao_especie': talhao.especie,
                    'talhao_area_ha': talhao.areaHa,
                    'talhao_idade_anos': talhao.idadeAnos,
                    'parcela_id_plano': parcela.idParcela,
                    'parcela_area_m2': parcela.areaMetrosQuadrados,
                    'parcela_espacamento': parcela.espacamento,
                    'parcela_status_inicial': parcela.status.name,
                  }
                });
              }
            }
          }
        }
      }

      if (features.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Nenhuma parcela encontrada nos projetos selecionados para exportar.'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }

      final Map<String, dynamic> geoJson = {
        'type': 'FeatureCollection',
        'features': features,
      };

      const jsonEncoder = JsonEncoder.withIndent('  ');
      final geoJsonString = jsonEncoder.convert(geoJson);

      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final fName =
          'Exportacao_Projetos_GeoForest_${DateFormat('yyyyMMdd_HHmm').format(hoje)}.geojson';
      final path = '${directory.path}/$fName';

      await File(path).writeAsString(geoJsonString);

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Carga de Projeto GeoForest',
        );
      }
    } catch (e, s) {
      debugPrint('Erro na exportação de projeto: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha na exportação: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> exportProjectAsGeoJson({
    required BuildContext context,
    required List<Polygon> areaPolygons,
    required List<SamplePoint> samplePoints,
    required String farmName,
    required String blockName,
  }) async {
    final List<SamplePoint> pontosConcluidos = samplePoints
        .where((ponto) => ponto.status == SampleStatus.completed)
        .toList();

    if (areaPolygons.isEmpty && pontosConcluidos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhuma área ou amostra concluída para exportar.'),
          backgroundColor: Colors.orange,
        ));
      }
      return;
    }

    if (areaPolygons.isNotEmpty && pontosConcluidos.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Aviso: Nenhuma amostra concluída foi encontrada. Exportando apenas a área do projeto.'),
          backgroundColor: Colors.orange,
        ));
      }
    }

    try {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gerando arquivo GeoJSON...')));
      }

      final Map<String, dynamic> geoJson = {
        'type': 'FeatureCollection',
        'features': <Map<String, dynamic>>[],
      };

      for (final polygon in areaPolygons) {
        final coordinates =
            polygon.points.map((p) => [p.longitude, p.latitude]).toList();
        geoJson['features'].add({
          'type': 'Feature',
          'geometry': {'type': 'Polygon', 'coordinates': [coordinates]},
          'properties': {
            'type': 'area',
            'farmName': farmName,
            'blockName': blockName
          },
        });
      }

      for (final point in pontosConcluidos) {
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

      const jsonEncoder = JsonEncoder.withIndent('  ');
      final geoJsonString = jsonEncoder.convert(geoJson);

      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final nomePastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDoDia = Directory('${directory.path}/$nomePastaData');
      if (!await pastaDoDia.exists()) await pastaDoDia.create(recursive: true);

      final fileName =
          'Projeto_${farmName.replaceAll(' ', '_')}_${blockName.replaceAll(' ', '_')}.geojson';
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha na exportação: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> exportarAnaliseTalhaoCsv({
    required BuildContext context,
    required Talhao talhao,
    required TalhaoAnalysisResult analise,
  }) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gerando arquivo CSV...')));

      List<List<dynamic>> rows = [];

      // ... (toda a lógica para adicionar linhas está correta) ...

      rows.add(['Resumo do Talhão']);
      rows.add(['Métrica', 'Valor']);
      rows.add(['Fazenda', talhao.fazendaNome ?? 'N/A']);
      rows.add(['Talhão', talhao.nome]);
      rows.add(['Nº de Parcelas Amostradas', analise.totalParcelasAmostradas]);
      rows.add(['Nº de Árvores Medidas', analise.totalArvoresAmostradas]);
      rows.add([
        'Área Total Amostrada (ha)',
        analise.areaTotalAmostradaHa.toStringAsFixed(4)
      ]);
      rows.add(['']);
      rows.add(['Resultados por Hectare']);
      rows.add(['Métrica', 'Valor']);
      rows.add(['Árvores / ha', analise.arvoresPorHectare]);
      rows.add([
        'Área Basal (G) m²/ha',
        analise.areaBasalPorHectare.toStringAsFixed(2)
      ]);
      rows.add([
        'Volume Estimado m³/ha',
        analise.volumePorHectare.toStringAsFixed(2)
      ]);
      rows.add(['']);
      rows.add(['Estatísticas da Amostra']);
      rows.add(['Métrica', 'Valor']);
      rows.add(['CAP Médio (cm)', analise.mediaCap.toStringAsFixed(1)]);
      rows.add(['Altura Média (m)', analise.mediaAltura.toStringAsFixed(1)]);
      rows.add(['']);

      rows.add(['Distribuição Diamétrica (CAP)']);
      rows.add(['Classe (cm)', 'Nº de Árvores', '%']);

      final totalArvoresVivas =
          analise.distribuicaoDiametrica.values.fold(0, (a, b) => a + b);

      analise.distribuicaoDiametrica.forEach((pontoMedio, contagem) {
        final inicioClasse = pontoMedio - 2.5;
        final fimClasse = pontoMedio + 2.5 - 0.1;
        final porcentagem =
            totalArvoresVivas > 0 ? (contagem / totalArvoresVivas) * 100 : 0;
        rows.add([
          '${inicioClasse.toStringAsFixed(1)} - ${fimClasse.toStringAsFixed(1)}',
          contagem,
          '${porcentagem.toStringAsFixed(1)}%',
        ]);
      });

      final dir = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final fName =
          'analise_talhao_${talhao.nome}_${DateFormat('yyyy-MM-dd_HH-mm').format(hoje)}.csv';
      final path = '${dir.path}/$fName';

      final csvData = const ListToCsvConverter().convert(rows);
      await File(path).writeAsString(csvData, encoding: utf8); // <<< PONTO E VÍRGULA EXTRA REMOVIDO

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(path)],
            subject: 'Análise do Talhão ${talhao.nome}');
      }
    } catch (e, s) {
      debugPrint('Erro ao exportar análise CSV: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha na exportação: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }
}