// lib/pages/dashboard/dashboard_page.dart (VERSÃO FINAL E SEM VOLUME)

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';

class DashboardPage extends StatefulWidget {
  final int parcelaId;
  const DashboardPage({Key? key, required this.parcelaId}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  Map<String, double> _distribuicaoPorStatus = {};
  List<double> _valoresCAP = [];
  String _errorMessage = '';

  int _totalArvores = 0;
  double _mediaCAP = 0.0;
  double _minCAP = 0.0;
  double _maxCAP = 0.0;

  final List<Color> _pieChartColors = [
    Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.brown, Colors.teal,
  ];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final dbHelper = DatabaseHelper();

      final statusDataFuture = dbHelper.getDistribuicaoPorStatus(widget.parcelaId);
      final capDataFuture = dbHelper.getValoresCAP(widget.parcelaId);

      final results = await Future.wait([statusDataFuture, capDataFuture]);

      final statusData = results[0] as Map<String, double>;
      final capData = results[1] as List<double>;

      if (mounted) {
        setState(() {
          _distribuicaoPorStatus = statusData;
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

  void _calculateKPIs() {
    if (_valoresCAP.isEmpty) {
      _totalArvores = 0;
      _mediaCAP = 0.0;
      _minCAP = 0.0;
      _maxCAP = 0.0;
      return;
    }
    _totalArvores = _valoresCAP.length;
    _mediaCAP = _valoresCAP.reduce((a, b) => a + b) / _totalArvores;
    _minCAP = _valoresCAP.reduce(min);
    _maxCAP = _valoresCAP.reduce(max);
  }

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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
              : _distribuicaoPorStatus.isEmpty && _valoresCAP.isEmpty
                  ? const Center(child: Text("Nenhuma árvore coletada para gerar relatório."))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildKPIs(),
                          const SizedBox(height: 24),
                          _buildSectionTitle("Distribuição por Status"),
                          SizedBox(height: 250, child: _buildPieChart()),
                          const SizedBox(height: 24),
                          _buildSectionTitle("Histograma de CAP"),
                          SizedBox(height: 300, child: _buildBarChart()),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

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
            _kpiCard('Média CAP', '${_mediaCAP.toStringAsFixed(1)} cm', Icons.straighten),
            _kpiCard('Min CAP', '${_minCAP.toStringAsFixed(1)} cm', Icons.arrow_downward),
            _kpiCard('Max CAP', '${_maxCAP.toStringAsFixed(1)} cm', Icons.arrow_upward),
          ],
        ),
      ),
    );
  }

  Widget _kpiCard(String title, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Theme.of(context).primaryColor, size: 28),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        Text(title, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        pieTouchData: PieTouchData(touchCallback: (event, pieTouchResponse) {}),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
        sections: _distribuicaoPorStatus.entries.map((entry) {
          final index = _distribuicaoPorStatus.keys.toList().indexOf(entry.key);
          return PieChartSectionData(
            color: _pieChartColors[index % _pieChartColors.length],
            value: entry.value,
            title: '${entry.value.toInt()}',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [Shadow(color: Colors.black, blurRadius: 2)],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBarChart() {
    if (_valoresCAP.isEmpty) return const SizedBox.shrink();

    final double minVal = _valoresCAP.reduce(min);
    final double maxVal = _valoresCAP.reduce(max);
    const int numBins = 10;
    final double binSize = (maxVal - minVal) > 0 ? (maxVal - minVal) / numBins : 1;

    List<int> bins = List.filled(numBins, 0);
    for (double val in _valoresCAP) {
      if (binSize == 0) continue;
      int binIndex = ((val - minVal) / binSize).floor();
      if (binIndex >= numBins) binIndex = numBins - 1;
      if (binIndex < 0) binIndex = 0;
      bins[binIndex]++;
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (bins.reduce(max).toDouble()) * 1.2,
        barTouchData: BarTouchData(enabled: true),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final binStart = minVal + value * binSize;
                return SideTitleWidget(
                  meta: meta,
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
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
