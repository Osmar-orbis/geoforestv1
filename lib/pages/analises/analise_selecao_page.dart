// lib/pages/analise/analise_selecao_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/pages/dashboard/talhao_dashboard_page.dart';


class AnaliseSelecaoPage extends StatefulWidget {
  const AnaliseSelecaoPage({super.key});

  @override
  State<AnaliseSelecaoPage> createState() => _AnaliseSelecaoPageState();
}

class _AnaliseSelecaoPageState extends State<AnaliseSelecaoPage> {
  final dbHelper = DatabaseHelper.instance;
  Map<String, List<String>> _projetos = {}; // Mapa: { 'Nome Fazenda': ['Talhao1', 'Talhao2'] }
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarProjetos();
  }

  Future<void> _carregarProjetos() async {
    setState(() => _isLoading = true);
    final projetosDoBanco = await dbHelper.getProjetosDisponiveis();
    setState(() {
      _projetos = projetosDoBanco;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fazendas = _projetos.keys.toList();

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
                    final nomeFazenda = fazendas[index];
                    final talhoes = _projetos[nomeFazenda]!;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        leading: const Icon(Icons.business_outlined),
                        title: Text(nomeFazenda, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${talhoes.length} talhão(ões) disponíveis'),
                        children: talhoes.map((nomeTalhao) {
                          return ListTile(
                            leading: const Icon(Icons.forest_outlined, color: Colors.green),
                            title: Text('Talhão: $nomeTalhao'),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TalhaoDashboardPage(
                                    nomeFazenda: nomeFazenda,
                                    nomeTalhao: nomeTalhao,
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