// lib/pages/dashboard/talhao_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/services/analysis_service.dart';
import 'package:geoforestcoletor/services/pdf_service.dart';
import 'package:geoforestcoletor/widgets/grafico_distribuicao_widget.dart';
import 'package:geoforestcoletor/pages/analises/simulacao_desbaste_page.dart';
import 'package:geoforestcoletor/pages/analises/rendimento_dap_page.dart';

class TalhaoDashboardPage extends StatefulWidget {
  // A página agora recebe o objeto Talhao completo.
  final Talhao talhao;

  const TalhaoDashboardPage({
    super.key,
    required this.talhao,
  });

  @override
  State<TalhaoDashboardPage> createState() => _TalhaoDashboardPageState();
}

class _TalhaoDashboardPageState extends State<TalhaoDashboardPage> {
  final _dbHelper = DatabaseHelper.instance;
  final _analysisService = AnalysisService();
  final _pdfService = PdfService();

  List<Parcela> _parcelasDoTalhao = [];
  List<Arvore> _arvoresDoTalhao = [];
  late Future<void> _dataLoadingFuture;
  TalhaoAnalysisResult? _analysisResult;

  @override
  void initState() {
    super.initState();
    _dataLoadingFuture = _carregarEAnalisarTalhao();
  }

  Future<void> _carregarEAnalisarTalhao() async {
    // Chama o novo método do DatabaseHelper usando o ID do talhão.
    final dadosAgregados = await _dbHelper.getDadosAgregadosDoTalhao(widget.talhao.id!);
    
    _parcelasDoTalhao = dadosAgregados['parcelas'] as List<Parcela>;
    _arvoresDoTalhao = dadosAgregados['arvores'] as List<Arvore>;

    if (_parcelasDoTalhao.isEmpty || _arvoresDoTalhao.isEmpty) return;

    final resultado = _analysisService.getTalhaoInsights(_parcelasDoTalhao, _arvoresDoTalhao);
    if (mounted) {
      setState(() => _analysisResult = resultado);
    }
  }

  void _navegarParaSimulacao() {
    if (_analysisResult == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SimulacaoDesbastePage(
          parcelas: _parcelasDoTalhao,
          arvores: _arvoresDoTalhao,
          analiseInicial: _analysisResult!,
        ),
      ),
    );
  }

  void _analisarRendimento() {
    if (_analysisResult == null) return;

    final resultadoRendimento = _analysisService.analisarRendimentoPorDAP(_parcelasDoTalhao, _arvoresDoTalhao);

    if (resultadoRendimento.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há dados suficientes para a análise de rendimento.'), backgroundColor: Colors.orange),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RendimentoDapPage(
          // Usa as informações do objeto talhao.
          nomeFazenda: widget.talhao.fazendaId, // Usando o ID da fazenda
          nomeTalhao: widget.talhao.nome,
          dadosRendimento: resultadoRendimento,
          analiseGeral: _analysisResult!,
        ),
      ),
    );
  }

  void _gerarPlanoDeCubagemPdf() async {
    if (_analysisResult == null || _analysisResult!.totalArvoresAmostradas == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Dados de análise insuficientes para gerar o plano.")),
      );
      return;
    }

    final String? totalParaCubarStr = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        final List<int> valoresSugeridos = [10, 20, 30, 50, 100];
        final totalAmostradas = _analysisResult!.totalArvoresAmostradas;

        return AlertDialog(
          title: const Text('Definir Plano de Cubagem'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total de árvores medidas: $totalAmostradas',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                const Text('Sugestões:'),
                Wrap(
                  spacing: 8.0,
                  children: valoresSugeridos
                      .where((valor) => valor < totalAmostradas)
                      .map((valor) => OutlinedButton(
                            child: Text(valor.toString()),
                            onPressed: () {
                              controller.text = valor.toString();
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nº de árvores para cubar',
                    hintText: 'Ou digite um valor',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Gerar PDF'),
            ),
          ],
        );
      },
    );

    final int? totalParaCubar = int.tryParse(totalParaCubarStr ?? '');
    if (totalParaCubar == null || totalParaCubar <= 0) return;

    final plano = _analysisService.gerarPlanoDeCubagem(
      _analysisResult!.distribuicaoDiametrica,
      _analysisResult!.totalArvoresAmostradas,
      totalParaCubar,
    );

    // Garante que o BuildContext não seja usado em um gap assíncrono
    if (!mounted) return;

    await _pdfService.gerarPlanoCubagemPdf(
      context: context,
      nomeFazenda: widget.talhao.fazendaId,
      nomeTalhao: widget.talhao.nome,
      planoDeCubagem: plano,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Análise: ${widget.talhao.nome}')),
      body: FutureBuilder<void>(
        future: _dataLoadingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao analisar talhão: ${snapshot.error}'));
          }
          if (_analysisResult == null || _analysisResult!.totalArvoresAmostradas == 0) {
            return const Center(child: Text('Não há dados de parcelas concluídas para a análise.'));
          }

          final result = _analysisResult!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildResumoCard(result),
                const SizedBox(height: 16),
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Distribuição Diamétrica (CAP)', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 24),
                        GraficoDistribuicaoWidget(dadosDistribuicao: result.distribuicaoDiametrica),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildInsightsCard("⚠️ Alertas", result.warnings, Colors.red.shade100),
                const SizedBox(height: 12),
                _buildInsightsCard("💡 Insights", result.insights, Colors.blue.shade100),
                const SizedBox(height: 12),
                _buildInsightsCard("🛠️ Recomendações", result.recommendations, Colors.orange.shade100),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _navegarParaSimulacao,
                  icon: const Icon(Icons.content_cut_outlined),
                  label: const Text('Simular Desbaste'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _analisarRendimento,
                  icon: const Icon(Icons.bar_chart_outlined),
                  label: const Text('Analisar Rendimento Comercial'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _gerarPlanoDeCubagemPdf,
                  icon: const Icon(Icons.picture_as_pdf_outlined, color: Colors.white),
                  label: const Text('Gerar Plano de Cubagem (PDF)'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
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
            const Divider(height: 20, thickness: 0.5, indent: 20, endIndent: 20),
            _buildStatRow('Nº de Parcelas Amostradas:', result.totalParcelasAmostradas.toString()),
            _buildStatRow('Nº de Árvores Medidas:', result.totalArvoresAmostradas.toString()),
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
            ...items.map((item) => Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Text('- $item'))),
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