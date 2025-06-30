// lib/pages/amostra/lista_projetos_page.dart (CORRIGIDO)

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/pages/amostra/coleta_dados_page.dart';
import 'package:geoforestcoletor/pages/amostra/inventario_page.dart';
import 'package:geoforestcoletor/pages/cubagem/cubagem_dados_page.dart';
import 'package:intl/intl.dart';

class ListaColetasPage extends StatefulWidget {
  const ListaColetasPage({super.key, required this.title});
  final String title;

  @override
  State<ListaColetasPage> createState() => _ListaColetasPageState();
}

class _ListaColetasPageState extends State<ListaColetasPage> {
  final dbHelper = DatabaseHelper();
  late Future<Map<String, List<dynamic>>> _atividadesFuture;

  bool _isSelectionMode = false;
  final Set<int> _selectedParcelaIds = {};
  final Set<int> _selectedCubagemIds = {};

  @override
  void initState() {
    super.initState();
    _atividadesFuture = _fetchData();
  }

  Future<void> _refreshData() async {
    setState(() {
      _selectedParcelaIds.clear();
      _selectedCubagemIds.clear();
      _isSelectionMode = false;
      _atividadesFuture = _fetchData();
    });
  }

  Future<Map<String, List<dynamic>>> _fetchData() async {
    final parcelas = await dbHelper.getTodasParcelas();
    final cubagens = await dbHelper.getTodasCubagens();
    return {'parcelas': parcelas, 'cubagens': cubagens};
  }

  void _toggleSelection(bool isParcela, int id) {
    setState(() {
      final selectedSet = isParcela ? _selectedParcelaIds : _selectedCubagemIds;
      if (selectedSet.contains(id)) {
        selectedSet.remove(id);
      } else {
        selectedSet.add(id);
      }
      _isSelectionMode = _selectedParcelaIds.isNotEmpty || _selectedCubagemIds.isNotEmpty;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedParcelaIds.clear();
      _selectedCubagemIds.clear();
      _isSelectionMode = false;
    });
  }

  Future<void> _deleteSelectedItems() async {
    final totalSelected = _selectedParcelaIds.length + _selectedCubagemIds.length;
    if (totalSelected == 0) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar os $totalSelected itens selecionados?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Apagar')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await dbHelper.deletarMultiplasParcelas(_selectedParcelaIds.toList());
      await dbHelper.deletarMultiplasCubagens(_selectedCubagemIds.toList());
      _refreshData();
    }
  }

  Future<void> _navegarParaInventario(Parcela parcela) async {
    if (parcela.status == StatusParcela.pendente) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Primeiro inicie a coleta deslizando o card.')));
      return;
    }
    final bool? foiAtualizado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => InventarioPage(parcela: parcela)));
    if (foiAtualizado == true && mounted) await _refreshData();
  }

  Future<void> _navegarParaEdicaoParcela(Parcela parcela) async {
    final foiAtualizado = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => ColetaDadosPage(parcelaParaEditar: parcela)));
    if (foiAtualizado == true && mounted) await _refreshData();
  }

  Future<void> _deletarParcela(Parcela parcela) async {
    final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirmar Exclusão'), content: Text('Tem certeza que deseja apagar a parcela "${parcela.idParcela}" e todas as suas árvores? Essa ação não pode ser desfeita.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Apagar'))]));
    if (confirmar == true && mounted) {
      await dbHelper.deleteParcela(parcela.dbId!);
      await _refreshData();
    }
  }

  Future<void> _editarCubagem(CubagemArvore arvore) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => CubagemDadosPage(metodo: arvore.tipoMedidaCAP, arvoreParaEditar: arvore)));
    await _refreshData();
  }

  Future<void> _deletarCubagem(CubagemArvore cubagem) async {
    final confirmar = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Confirmar Exclusão'), content: Text('Tem certeza que deseja apagar a cubagem "${cubagem.identificador}"? Essa ação não pode ser desfeita.'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.of(ctx).pop(true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Apagar'))]));
    if (confirmar == true && mounted) {
      await dbHelper.deletarCubagem(cubagem.id!);
      await _refreshData();
    }
  }

  Widget _buildParcelaCard(Parcela parcela) {
    final isSelected = _selectedParcelaIds.contains(parcela.dbId!);
    final bool isClickable = parcela.status != StatusParcela.pendente;

    late final Color statusColor;
    late final IconData statusIcon;
    if (parcela.status == StatusParcela.concluida && parcela.exportada) {
      statusColor = Colors.blue;
      statusIcon = Icons.cloud_done_outlined;
    } else {
      statusColor = parcela.status.cor;
      statusIcon = parcela.status.icone;
    }

    return Card(
      color: isSelected ? Colors.lightBlue.shade100 : null,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Slidable(
        key: ValueKey('parcela_${parcela.dbId}'),
        enabled: !_isSelectionMode,
        startActionPane: ActionPane(
          motion: const StretchMotion(),
          children: [SlidableAction(onPressed: (_) => _navegarParaEdicaoParcela(parcela), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, icon: Icons.edit_note, label: isClickable ? 'Editar' : 'Iniciar')],
        ),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          children: [SlidableAction(onPressed: (_) => _deletarParcela(parcela), backgroundColor: Colors.redAccent, foregroundColor: Colors.white, icon: Icons.delete_outline, label: 'Excluir')],
        ),
        child: ListTile(
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(true, parcela.dbId!);
            } else {
              _navegarParaInventario(parcela);
            }
          },
          onLongPress: () {
            _toggleSelection(true, parcela.dbId!);
          },
          leading: _isSelectionMode
              ? Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked_outlined, color: Theme.of(context).primaryColor)
              : Icon(statusIcon, color: statusColor),
          title: Text('${parcela.nomeFazenda ?? 'Fazenda avulsa'} - ${parcela.nomeTalhao ?? 'Talhão avulso'}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Parcela ${parcela.idParcela} | ${DateFormat('dd/MM/yy HH:mm').format(parcela.dataColeta!)}'),
          trailing: _isSelectionMode ? null : (isClickable ? const Icon(Icons.arrow_forward_ios, size: 14) : null),
        ),
      ),
    );
  }

  Widget _buildCubagemCard(CubagemArvore cubagem) {
    final isSelected = _selectedCubagemIds.contains(cubagem.id!);

    return Card(
      color: isSelected ? Colors.lightBlue.shade100 : null,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Slidable(
        key: ValueKey('cubagem_${cubagem.id}'),
        enabled: !_isSelectionMode,
        startActionPane: ActionPane(
          motion: const StretchMotion(),
          children: [SlidableAction(onPressed: (_) => _editarCubagem(cubagem), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, icon: Icons.edit_note, label: 'Editar')],
        ),
        endActionPane: ActionPane(
          motion: const StretchMotion(),
          children: [SlidableAction(onPressed: (_) => _deletarCubagem(cubagem), backgroundColor: Colors.redAccent, foregroundColor: Colors.white, icon: Icons.delete_outline, label: 'Excluir')],
        ),
        child: ListTile(
          onTap: () {
            if (_isSelectionMode) {
              _toggleSelection(false, cubagem.id!);
            } else {
              _editarCubagem(cubagem);
            }
          },
          onLongPress: () {
            _toggleSelection(false, cubagem.id!);
          },
          leading: _isSelectionMode
              ? Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked_outlined, color: Theme.of(context).primaryColor)
              : Builder(builder: (_) {
                  final Color statusColor = cubagem.exportada ? Colors.blue : Colors.brown;
                  final IconData statusIcon = cubagem.exportada ? Icons.cloud_done_outlined : Icons.straighten;
                  return Icon(statusIcon, color: statusColor);
                }),
          title: Text(cubagem.identificador, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Altura: ${cubagem.alturaTotal}m, CAP/DAP: ${cubagem.valorCAP}cm'),
          trailing: _isSelectionMode ? null : const Icon(Icons.arrow_forward_ios, size: 14),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(icon: const Icon(Icons.close), onPressed: _clearSelection, tooltip: 'Sair do modo de seleção'),
              title: Text('${_selectedParcelaIds.length + _selectedCubagemIds.length} selecionados'),
              actions: [IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteSelectedItems, tooltip: 'Apagar Selecionados')],
            )
          : AppBar(title: Text(widget.title)),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: FutureBuilder<Map<String, List<dynamic>>>(
          future: _atividadesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snapshot.hasError) return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));

            final parcelas = snapshot.data?['parcelas'] as List<Parcela>? ?? [];
            final cubagens = snapshot.data?['cubagens'] as List<CubagemArvore>? ?? [];
            if (parcelas.isEmpty && cubagens.isEmpty) {
              return const Center(child: Text('Nenhuma atividade encontrada.\nUse o botão + para adicionar.', textAlign: TextAlign.center));
            }

            return CustomScrollView(
              slivers: [
                if (parcelas.isNotEmpty) ...[
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text('Coletas de Parcela', style: Theme.of(context).textTheme.titleLarge))),
                  SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildParcelaCard(parcelas[index]), childCount: parcelas.length)),
                ],
                if (cubagens.isNotEmpty) ...[
                  SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16, 24, 16, 8), child: Text('Cubagens Rigorosas', style: Theme.of(context).textTheme.titleLarge))),
                  SliverList(delegate: SliverChildBuilderDelegate((context, index) => _buildCubagemCard(cubagens[index]), childCount: cubagens.length)),
                ],
              ],
            );
          },
        ),
      ),
      floatingActionButton: _isSelectionMode
          ? null
          : SpeedDial(
              icon: Icons.add,
              activeIcon: Icons.close,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              children: [
                SpeedDialChild(
                  child: const Icon(Icons.straighten),
                  label: 'Nova Cubagem',
                  onTap: () async {
                    final String? metodoEscolhido = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(title: const Text('Escolha o Método'), content: const Text('Como as seções serão medidas?'), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop('Fixas'), child: const Text('SEÇÕES FIXAS')), TextButton(onPressed: () => Navigator.of(ctx).pop('Relativas'), child: const Text('SEÇÕES RELATIVAS'))]));
                    if (metodoEscolhido != null && mounted) {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => CubagemDadosPage(metodo: metodoEscolhido)));
                      await _refreshData();
                    }
                  },
                ),
                SpeedDialChild(
                  child: const Icon(Icons.forest),
                  label: 'Nova Coleta de Parcela',
                  onTap: () {
                    // <<< CORREÇÃO APLICADA AQUI >>>
                    final novaParcelaAvulsa = Parcela(
                      talhaoId: null, // Indica que é uma coleta avulsa, não ligada a um talhão
                      idParcela: '', 
                      areaMetrosQuadrados: 0, 
                      dataColeta: DateTime.now(),
                      // O status já tem o valor padrão de 'pendente' no modelo
                    );
                    Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => ColetaDadosPage(parcelaParaEditar: novaParcelaAvulsa))).then((foiAtualizado) {
                      if (foiAtualizado == true) _refreshData();
                    });
                  },
                ),
              ],
            ),
    );
  }
}