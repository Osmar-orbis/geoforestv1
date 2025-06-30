// lib/pages/talhoes/detalhes_talhao_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/pages/menu/map_import_page.dart';
import 'package:geoforestcoletor/pages/menu/home_page.dart';
import 'package:geoforestcoletor/pages/amostra/form_parcela_page.dart';
import 'package:geoforestcoletor/pages/amostra/inventario_page.dart';
// >>> 1. IMPORTA A SUA PÁGINA DE DASHBOARD CORRETA <<<
import 'package:geoforestcoletor/pages/dashboard/talhao_dashboard_page.dart'; 

class DetalhesTalhaoPage extends StatefulWidget {
  final Talhao talhao;
  const DetalhesTalhaoPage({super.key, required this.talhao});

  @override
  State<DetalhesTalhaoPage> createState() => _DetalhesTalhaoPageState();
}

class _DetalhesTalhaoPageState extends State<DetalhesTalhaoPage> {
  late Future<List<Parcela>> _parcelasFuture;
  final dbHelper = DatabaseHelper.instance;

  bool _isSelectionMode = false;
  final Set<int> _selectedParcelas = {};

  @override
  void initState() {
    super.initState();
    _carregarParcelas();
  }

  void _carregarParcelas() {
    // Garante que o modo de seleção seja desativado ao recarregar
    if(mounted) {
      setState(() {
        _isSelectionMode = false;
        _selectedParcelas.clear();
        _parcelasFuture = dbHelper.getParcelasDoTalhao(widget.talhao.id!);
      });
    }
  }

  // --- MÉTODOS DE SELEÇÃO E EXCLUSÃO ---
  void _toggleSelectionMode(int? parcelaDbId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedParcelas.clear();
      if (_isSelectionMode && parcelaDbId != null) {
        _selectedParcelas.add(parcelaDbId);
      }
    });
  }
  
  void _onItemSelected(int parcelaDbId) {
    setState(() {
      if (_selectedParcelas.contains(parcelaDbId)) {
        _selectedParcelas.remove(parcelaDbId);
        if (_selectedParcelas.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedParcelas.add(parcelaDbId);
      }
    });
  }

  Future<void> _deleteSelectedParcelas() async {
    if (_selectedParcelas.isEmpty) return;
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar as ${_selectedParcelas.length} parcelas selecionadas? Esta ação não pode ser desfeita.'),
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
      await dbHelper.deletarMultiplasParcelas(_selectedParcelas.toList());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_selectedParcelas.length} parcelas apagadas.'),
          backgroundColor: Colors.green));
      _carregarParcelas(); // Recarrega a lista e sai do modo de seleção
    }
  }
  
  Future<void> _deleteSingleParcela(int parcelaId) async {
     _selectedParcelas.clear();
     _selectedParcelas.add(parcelaId);
     await _deleteSelectedParcelas();
  }

  // --- MÉTODOS DE NAVEGAÇÃO ---
  void _navegarParaMapa() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => MapImportPage(talhao: widget.talhao)));
  }

  Future<void> _navegarParaNovaParcela() async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => FormParcelaPage(talhao: widget.talhao)));
    if (mounted) _carregarParcelas();
  }

  void _navegarParaCubagem() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Navegação para Cubagem a ser implementada.')));
  }

  Future<void> _navegarParaDetalhesParcela(Parcela parcela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => InventarioPage(parcela: parcela)));
    if (mounted) _carregarParcelas();
  }

  // --- WIDGETS DE CONSTRUÇÃO DA UI ---
  AppBar _buildSelectionAppBar() {
    return AppBar(
      title: Text('${_selectedParcelas.length} selecionada(s)'),
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => _toggleSelectionMode(null),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Apagar selecionadas',
          onPressed: _deleteSelectedParcelas,
        ),
      ],
    );
  }
  
  AppBar _buildNormalAppBar() {
    return AppBar(
      title: Text('Talhão: ${widget.talhao.nome}'),
      actions: [
        // >>> 2. BOTÃO QUE CHAMA O DASHBOARD CORRETO <<<
        IconButton(
          icon: const Icon(Icons.analytics_outlined),
          tooltip: 'Ver Análise do Talhão',
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TalhaoDashboardPage(talhao: widget.talhao),
              ),
            );
          },
        ),
        IconButton(icon: const Icon(Icons.straighten_outlined), tooltip: 'Cubagem', onPressed: _navegarParaCubagem),
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
                  Text('Detalhes do Talhão', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text("Fazenda: ${widget.talhao.fazendaNome ?? 'Não informada'}", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text("Espécie: ${widget.talhao.especie ?? 'Não informada'}", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text("Área: ${widget.talhao.areaHa?.toStringAsFixed(2) ?? 'N/A'} ha", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text("Idade: ${widget.talhao.idadeAnos?.toStringAsFixed(1) ?? 'N/A'} anos", style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: ElevatedButton.icon(onPressed: _navegarParaMapa, icon: const Icon(Icons.map_outlined), label: const Text('Abrir Talhão no Mapa'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text("Coletas de Parcela", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ),
          Expanded(
            child: FutureBuilder<List<Parcela>>(
              future: _parcelasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar parcelas: ${snapshot.error}'));
                }
                final parcelas = snapshot.data ?? [];
                if (parcelas.isEmpty) {
                  return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Nenhuma parcela coletada neste talhão.\nClique no botão "+" para iniciar a primeira coleta.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey))));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: parcelas.length,
                  itemBuilder: (context, index) {
                    final parcela = parcelas[index];
                    final isSelected = _selectedParcelas.contains(parcela.dbId!);
                    final dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(parcela.dataColeta!);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: isSelected ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5) : null,
                      child: ListTile(
                        onTap: () {
                          if (_isSelectionMode) {
                            _onItemSelected(parcela.dbId!);
                          } else {
                            _navegarParaDetalhesParcela(parcela);
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode(parcela.dbId!);
                          }
                        },
                        leading: CircleAvatar(
                          backgroundColor: isSelected ? Theme.of(context).colorScheme.primary : parcela.status.cor,
                          child: Icon(isSelected ? Icons.check : parcela.status.icone, color: Colors.white),
                        ),
                        title: Text('Parcela ID: ${parcela.idParcela}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Coletado em: $dataFormatada'),
                        trailing: _isSelectionMode ? null : IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deleteSingleParcela(parcela.dbId!),
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
        onPressed: _navegarParaNovaParcela,
        tooltip: 'Nova Coleta de Parcela',
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nova Parcela'),
      ),
    );
  }
}