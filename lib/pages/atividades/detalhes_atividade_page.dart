// lib/pages/atividades/detalhes_atividade_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:geoforestcoletor/pages/fazenda/form_fazenda_page.dart';
import 'package:geoforestcoletor/pages/fazenda/detalhes_fazenda_page.dart';
import 'package:geoforestcoletor/pages/menu/home_page.dart'; // <<< 1. IMPORTA A HOMEPAGE

class DetalhesAtividadePage extends StatefulWidget {
  final Atividade atividade;
  const DetalhesAtividadePage({super.key, required this.atividade});

  @override
  State<DetalhesAtividadePage> createState() => _DetalhesAtividadePageState();
}

class _DetalhesAtividadePageState extends State<DetalhesAtividadePage> {
  late Future<List<Fazenda>> _fazendasFuture;
  final dbHelper = DatabaseHelper.instance;

  // >>> 2. ESTADO PARA CONTROLAR O MODO DE SELEÇÃO <<<
  bool _isSelectionMode = false;
  final Set<String> _selectedFazendas = {}; // O ID da fazenda é uma String

  @override
  void initState() {
    super.initState();
    _carregarFazendas();
  }

  void _carregarFazendas() {
    if(mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedFazendas.clear();
        _fazendasFuture = dbHelper.getFazendasDaAtividade(widget.atividade.id!);
      });
    }
  }

  // --- MÉTODOS DE SELEÇÃO E EXCLUSÃO ---
  void _toggleSelectionMode(String? fazendaId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedFazendas.clear();
      if (_isSelectionMode && fazendaId != null) {
        _selectedFazendas.add(fazendaId);
      }
    });
  }

  void _onItemSelected(String fazendaId) {
    setState(() {
      if (_selectedFazendas.contains(fazendaId)) {
        _selectedFazendas.remove(fazendaId);
        if (_selectedFazendas.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedFazendas.add(fazendaId);
      }
    });
  }

  Future<void> _deleteSelectedFazendas() async {
    if (_selectedFazendas.isEmpty) return;
    
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar as ${_selectedFazendas.length} fazendas selecionadas e todos os seus dados? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      for (final id in _selectedFazendas) {
        await dbHelper.deleteFazenda(id, widget.atividade.id!);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_selectedFazendas.length} fazendas apagadas.'),
          backgroundColor: Colors.green));
      _carregarFazendas();
    }
  }

  // --- MÉTODOS DE NAVEGAÇÃO ---
  void _navegarParaNovaFazenda() async {
    final bool? fazendaCriada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormFazendaPage(atividadeId: widget.atividade.id!),
      ),
    );
    if (fazendaCriada == true && mounted) {
      _carregarFazendas();
    }
  }

  void _navegarParaDetalhesFazenda(Fazenda fazenda) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesFazendaPage(fazenda: fazenda)),
    ).then((_) => _carregarFazendas());
  }

  // --- WIDGETS DE CONSTRUÇÃO DA UI ---
  AppBar _buildSelectionAppBar() {
    return AppBar(
      title: Text('${_selectedFazendas.length} selecionada(s)'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _toggleSelectionMode(null),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Apagar selecionadas',
          onPressed: _deleteSelectedFazendas,
        ),
      ],
    );
  }
  
  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text(widget.atividade.tipo),
      actions: [
        IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Voltar para o Início',
          onPressed: () => Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const HomePage(title: 'Geo Forest Analytics')),
            (Route<dynamic> route) => false,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            margin: const EdgeInsets.all(12.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Detalhes da Atividade', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text("Descrição: ${widget.atividade.descricao.isNotEmpty ? widget.atividade.descricao : 'N/A'}",
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text('Data de Criação: ${DateFormat('dd/MM/yyyy').format(widget.atividade.dataCriacao)}',
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              "Fazendas da Atividade",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Fazenda>>(
              future: _fazendasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar fazendas: ${snapshot.error}'));
                }

                final fazendas = snapshot.data ?? [];

                if (fazendas.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhuma fazenda encontrada.\nClique no botão "+" para adicionar a primeira.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: fazendas.length,
                  itemBuilder: (context, index) {
                    final fazenda = fazendas[index];
                    final isSelected = _selectedFazendas.contains(fazenda.id);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
                      child: ListTile(
                        onTap: () {
                          if (_isSelectionMode) {
                            _onItemSelected(fazenda.id);
                          } else {
                            _navegarParaDetalhesFazenda(fazenda);
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode(fazenda.id);
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : null,
                          child: Icon(isSelected ? Icons.check : Icons.agriculture_outlined),
                        ),
                        title: Text(fazenda.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('ID: ${fazenda.id}\n${fazenda.municipio} - ${fazenda.estado}'),
                        trailing: _isSelectionMode ? null : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            _toggleSelectionMode(fazenda.id);
                            await _deleteSelectedFazendas();
                          },
                        ),
                        selected: isSelected,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: _navegarParaNovaFazenda,
        tooltip: 'Nova Fazenda',
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Nova Fazenda'),
      ),
    );
  }
}