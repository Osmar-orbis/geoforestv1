// lib/pages/dashboard_page.dart

import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';

class DashboardPage extends StatefulWidget {
  final int parcelaId;

  const DashboardPage({super.key, required this.parcelaId});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  // --- VARIÁVEIS DE ESTADO ---
  bool _isLoading = true;
  String _errorMessage = '';

  // Dados do Relatório
  Map<String, double> _distribuicaoPorCodigo = {};
  List<double> _valoresCAP = [];

  // KPIs (Key Performance Indicators)
  int _totalArvores = 0;
  double _mediaCAP = 0.0;
  double _minCAP = 0.0;
  double _maxCAP = 0.0;

  // Cores para o gráfico de pizza
  final List<Color> _pieChartColors = [
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.brown,
    Colors.teal,
    Colors.pink,
  ];

  // --- CICLO DE VIDA ---
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  // --- CARREGAMENTO DE DADOS ---
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final dbHelper = DatabaseHelper.instance;

      // Busca os dados em paralelo para maior eficiência
      final results = await Future.wait([
        dbHelper.getDistribuicaoPorCodigo(widget.parcelaId), // <-- CORREÇÃO AQUI
        dbHelper.getValoresCAP(widget.parcelaId),
      ]);

      final codigoData = results[0] as Map<String, double>;
      final capData = results[1] as List<double>;

      if (mounted) {
        setState(() {
          _distribuicaoPorCodigo = codigoData; // <-- CORREÇÃO AQUI
          _valoresCAP = capData;
          _calculateKPIs();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erro ao carregar dados do relatório: $e';
          _isLoading = false;
        });
      }
    }
  }

  /// Calcula os principais indicadores (KPIs) a partir dos dados carregados.
  void _calculateKPIs() {
    if (_valoresCAP.isEmpty) {
      _totalArvores = 0;
      _mediaCAP = 0.0;
      _minCAP = 0.0;
      _maxCAP = 0.0;
      return;
    }
    _totalArvores = _distribuicaoPorCodigo.values.reduce((a, b) => a + b).toInt();
    _mediaCAP = _valoresCAP.reduce((a, b) => a + b) / _valoresCAP.length;
    _minCAP = _valoresCAP.reduce(min);
    _maxCAP = _valoresCAP.reduce(max);
  }

  // --- MÉTODO PRINCIPAL DE BUILD ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Relatório da Parcela ${widget.parcelaId}"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDashboardData,
            tooltip: 'Atualizar Dados',
          )
        ],
      ),
      body: _buildBody(),
    );
  }

  // --- WIDGETS DE BUILD ---

  /// Constrói o corpo da tela com base no estado atual (carregando, erro, dados).
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage.isNotEmpty) {
      return Center(
          child:
              Text(_errorMessage, style: const TextStyle(color: Colors.red)));
    }
    if (_distribuicaoPorCodigo.isEmpty && _valoresCAP.isEmpty) {
      return const Center(
          child: Text("Nenhuma árvore coletada para gerar relatório."));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildKPIs(),
          const SizedBox(height: 24),
          _buildSectionTitle("Distribuição por Código"), // <-- CORREÇÃO AQUI
          SizedBox(height: 250, child: _buildPieChart()),
          const SizedBox(height: 24),
          _buildSectionTitle("Histograma de CAP"),
          SizedBox(height: 300, child: _buildBarChart()),
        ],
      ),
    );
  }

  /// Constrói o título de uma seção do relatório.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Constrói o card com os principais indicadores (KPIs).
  Widget _buildKPIs() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 16.0,
          runSpacing: 16.0,
          children: [
            _kpiCard('Total de Árvores', _totalArvores.toString(), Icons.park),
            _kpiCard(
                'Média CAP', '${_mediaCAP.toStringAsFixed(1)} cm', Icons.straighten),
            _kpiCard(
                'Min CAP', '${_minCAP.toStringAsFixed(1)} cm', Icons.arrow_downward),
            _kpiCard(
                'Max CAP', '${_maxCAP.toStringAsFixed(1)} cm', Icons.arrow_upward),
          ],
        ),
      ),
    );
  }

  /// Constrói um item individual para o card de KPIs.
  Widget _kpiCard(String title, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  /// Constrói o gráfico de pizza para a distribuição de códigos.
  Widget _buildPieChart() {
    if (_distribuicaoPorCodigo.isEmpty) return const SizedBox.shrink();

    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(
          touchCallback: (event, pieTouchResponse) {
            // Interações podem ser adicionadas aqui
          },
        ),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: _distribuicaoPorCodigo.entries.map((entry) {
          final index = _distribuicaoPorCodigo.keys.toList().indexOf(entry.key);
          return PieChartSectionData(
            color: _pieChartColors[index % _pieChartColors.length],
            value: entry.value,
            title: '${entry.key}\n(${entry.value.toInt()})', // Exibe o código e a quantidade
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Constrói o gráfico de barras (histograma) para os valores de CAP.
  Widget _buildBarChart() {
    if (_valoresCAP.isEmpty) return const SizedBox.shrink();

    // Lógica para criar os "bins" (classes) do histograma
    final double minVal = _minCAP;
    final double maxVal = _maxCAP;
    const int numBins = 10;
    // Tamanho de cada classe/barra
    final double binSize = (maxVal - minVal) > 0 ? (maxVal - minVal) / numBins : 1;

    // Inicializa a contagem de cada classe com zero
    List<int> bins = List.filled(numBins, 0);

    // Distribui cada valor de CAP em sua respectiva classe
    for (double val in _valoresCAP) {
      if (binSize == 0) continue;
      int binIndex = ((val - minVal) / binSize).floor();
      
      // Garante que o índice esteja dentro dos limites
      if (binIndex >= numBins) binIndex = numBins - 1;
      if (binIndex < 0) binIndex = 0;
      
      bins[binIndex]++;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (bins.reduce(max).toDouble()) * 1.2, // Espaço extra no topo
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final binStart = minVal + value * binSize;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 4,
                  child: Text(
                    binStart.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: true),
        barGroups: List.generate(numBins, (index) {
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: bins[index].toDouble(),
                color: Theme.of(context).primaryColor,
                width: 15,
                borderRadius: BorderRadius.zero,
              )
            ],
          );
        }),
      ),
    );
  }
}