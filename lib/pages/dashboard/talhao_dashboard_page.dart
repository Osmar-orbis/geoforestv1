// lib/pages/dashboard/talhao_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';

class TalhaoDashboardPage extends StatefulWidget {
  final String nomeFazenda;
  final String nomeTalhao;

  const TalhaoDashboardPage({
    super.key,
    required this.nomeFazenda,
    required this.nomeTalhao,
  });

  @override
  State<TalhaoDashboardPage> createState() => _TalhaoDashboardPageState();
}

class _TalhaoDashboardPageState extends State<TalhaoDashboardPage> {
  final _dbHelper = DatabaseHelper.instance;
  final _analysisService = AnalysisService();

  late Future<TalhaoAnalysisResult> _analysisResultFuture;

  @override
  void initState() {
    super.initState();
    _analysisResultFuture = _analisarTalhao();
  }

  Future<TalhaoAnalysisResult> _analisarTalhao() async {
    // Carrega todas as parcelas e suas árvores para o talhão selecionado
    final List<Parcela> parcelas = await _dbHelper.getParcelasComArvores(
      widget.nomeFazenda,
      widget.nomeTalhao,
    );
    // Roda o serviço de análise
    return _analysisService.getTalhaoInsights(parcelas);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Análise: ${widget.nomeTalhao}'),
      ),
      body: FutureBuilder<TalhaoAnalysisResult>(
        future: _analysisResultFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao analisar talhão: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.totalArvoresAmostradas == 0) {
            return const Center(child: Text('Não há dados suficientes para a análise.'));
          }

          final result = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildResumoCard(result),
                const SizedBox(height: 16),
                _buildInsightsCard("⚠️ Alertas", result.warnings, Colors.red.shade100),
                const SizedBox(height: 12),
                _buildInsightsCard("💡 Insights", result.insights, Colors.blue.shade100),
                const SizedBox(height: 12),
                _buildInsightsCard("🛠️ Recomendações", result.recommendations, Colors.orange.shade100),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navegar para a página de simulação de desbaste
                  },
                  icon: const Icon(Icons.content_cut_outlined),
                  label: const Text('Simular Desbaste'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Navegar para a página de análise de rendimento
                  },
                  icon: const Icon(Icons.bar_chart_outlined),
                  label: const Text('Analisar Rendimento Comercial'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildResumoCard(TalhaoAnalysisResult result) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Resumo do Talhão', style: Theme.of(context).textTheme.titleLarge),
            const Divider(height: 20),
            _buildStatRow('Árvores/ha:', result.arvoresPorHectare.toString()),
            _buildStatRow('CAP Médio:', '${result.mediaCap.toStringAsFixed(1)} cm'),
            _buildStatRow('Altura Média:', '${result.mediaAltura.toStringAsFixed(1)} m'),
            _buildStatRow('Área Basal (G):', '${result.areaBasalPorHectare.toStringAsFixed(2)} m²/ha'),
            _buildStatRow('Volume Estimado:', '${result.volumePorHectare.toStringAsFixed(2)} m³/ha'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInsightsCard(String title, List<String> items, Color color) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Card(
      color: color,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text('- $item'),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}