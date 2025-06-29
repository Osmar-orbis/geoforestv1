// lib/pages/analises/analise_selecao_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/pages/dashboard/talhao_dashboard_page.dart';
import 'package:collection/collection.dart'; // Import para groupBy

class AnaliseSelecaoPage extends StatefulWidget {
  const AnaliseSelecaoPage({super.key});

  @override
  State<AnaliseSelecaoPage> createState() => _AnaliseSelecaoPageState();
}

class _AnaliseSelecaoPageState extends State<AnaliseSelecaoPage> {
  final dbHelper = DatabaseHelper.instance;
  // Agora a lista é de objetos Talhao.
  Map<String, List<Talhao>> _talhoesPorFazenda = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarTalhoes();
  }

  Future<void> _carregarTalhoes() async {
    setState(() => _isLoading = true);
    // Busca todos os talhões que têm parcelas concluídas.
    final talhoesCompletos = await dbHelper.getTalhoesComParcelasConcluidas();

    // Agrupa os talhões pelo ID da fazenda.
    final groupedData = groupBy(talhoesCompletos, (Talhao talhao) => talhao.fazendaId);
    
    setState(() {
      _talhoesPorFazenda = groupedData;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fazendas = _talhoesPorFazenda.keys.toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orbis Analista - Seleção'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : fazendas.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Nenhum talhão com coletas concluídas foi encontrado para análise.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: fazendas.length,
                  itemBuilder: (context, index) {
                    final idFazenda = fazendas[index];
                    final talhoes = _talhoesPorFazenda[idFazenda]!;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        leading: const Icon(Icons.business_outlined),
                        title: Text('Fazenda ID: $idFazenda', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${talhoes.length} talhão(ões) disponíveis'),
                        children: talhoes.map((talhao) {
                          return ListTile(
                            leading: const Icon(Icons.forest_outlined, color: Colors.green),
                            title: Text('Talhão: ${talhao.nome}'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  // Passa o objeto Talhao completo para a página de dashboard.
                                  builder: (context) => TalhaoDashboardPage(
                                    talhao: talhao,
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
    );
  }
}