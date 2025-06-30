// lib\pages\dashboard\relatorio_comparativo_page.dart
import 'package:flutter/material.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/pages/dashboard/talhao_dashboard_page.dart'; // <<< REUTILIZAREMOS ESTA PÁGINA

class RelatorioComparativoPage extends StatefulWidget {
  final List<Talhao> talhoesSelecionados;

  const RelatorioComparativoPage({super.key, required this.talhoesSelecionados});

  @override
  State<RelatorioComparativoPage> createState() => _RelatorioComparativoPageState();
}

class _RelatorioComparativoPageState extends State<RelatorioComparativoPage> {
  // Agrupa os talhões por fazenda para a UI
  final Map<String, List<Talhao>> _talhoesPorFazenda = {};

  @override
  void initState() {
    super.initState();
    _agruparTalhoes();
  }

  void _agruparTalhoes() {
    for (var talhao in widget.talhoesSelecionados) {
      // Usa o fazendaNome que já vem do banco de dados
      final fazendaNome = talhao.fazendaNome ?? 'Fazenda Desconhecida';
      if (!_talhoesPorFazenda.containsKey(fazendaNome)) {
        _talhoesPorFazenda[fazendaNome] = [];
      }
      _talhoesPorFazenda[fazendaNome]!.add(talhao);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório Comparativo'),
      ),
      body: ListView.builder(
        itemCount: _talhoesPorFazenda.keys.length,
        itemBuilder: (context, index) {
          final fazendaNome = _talhoesPorFazenda.keys.elementAt(index);
          final talhoesDaFazenda = _talhoesPorFazenda[fazendaNome]!;

          // Cada Fazenda é um ExpansionTile
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ExpansionTile(
              title: Text(
                fazendaNome,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              initiallyExpanded: true,
              children: talhoesDaFazenda.map((talhao) {
                // Cada Talhão dentro da fazenda também é um ExpansionTile
                return Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Theme.of(context).dividerColor)
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ExpansionTile(
                      title: Text(
                        'Talhão: ${talhao.nome}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      children: [
                        // O conteúdo do ExpansionTile é a nossa TalhaoDashboardPage!
                        // No entanto, como não podemos colocar uma página inteira aqui,
                        // teremos que transformá-la em um widget reutilizável.
                        // Por enquanto, colocamos um placeholder.
                        TalhaoDashboardContent(talhao: talhao),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

