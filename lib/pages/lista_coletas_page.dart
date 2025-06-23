// lib/pages/lista_coletas_page.dart (ou lista_atividades_page.dart)

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:geoforestcoletor/helpers/database_helper.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/pages/coleta_dados_page.dart';
import 'package:geoforestcoletor/pages/cubagem_dados_page.dart';
import 'package:geoforestcoletor/pages/inventario_page.dart';
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

  @override
  void initState() {
    super.initState();
    _carregarTodasAtividades();
  }

  Future<void> _carregarTodasAtividades() async {
    setState(() {
      _atividadesFuture = _fetchData();
    });
  }

  Future<Map<String, List<dynamic>>> _fetchData() async {
    final parcelas = await dbHelper.getTodasParcelas();
    final cubagens = await dbHelper.getTodasCubagens();
    return {
      'parcelas': parcelas,
      'cubagens': cubagens,
    };
  }

  // --- MÉTODOS DE NAVEGAÇÃO E AÇÃO ---

  void _navegarParaInventario(Parcela parcela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => InventarioPage(parcela: parcela)));
    _carregarTodasAtividades();
  }

  void _navegarParaEdicaoParcela(Parcela parcela) async {
    await Navigator.push(context, MaterialPageRoute(builder: (context) => ColetaDadosPage(parcelaParaEditar: parcela)));
    _carregarTodasAtividades();
  }

  void _deletarParcela(Parcela parcela) async {
    // Adicione uma lógica de confirmação se desejar
    await dbHelper.deleteParcela(parcela.dbId!);
    _carregarTodasAtividades();
  }

  void _editarCubagem(CubagemArvore arvore) async {
    // A tela de edição vai usar o método 'Relativas' como padrão, por exemplo.
    // Você pode adaptar essa lógica se precisar distinguir
    await Navigator.push(context, MaterialPageRoute(builder: (context) => CubagemDadosPage(metodo: 'Relativas', arvoreParaEditar: arvore)));
    _carregarTodasAtividades();
  }

  void _deletarCubagem(CubagemArvore cubagem) async {
    // Adicione um diálogo de confirmação aqui se desejar
    final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar Exclusão'),
          content: Text('Tem certeza que deseja apagar a cubagem "${cubagem.identificador}"? Essa ação não pode ser desfeita.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Apagar'), style: FilledButton.styleFrom(backgroundColor: Colors.red)),
          ],
        )
    ) ?? false;

    if (confirmar) {
      await dbHelper.deletarCubagem(cubagem.id!);
      _carregarTodasAtividades();
    }
  }

  // --- WIDGET BUILDERS PARA CADA TIPO DE ITEM ---

  Widget _buildParcelaCard(Parcela parcela) {
    final isConcluida = parcela.status == StatusParcela.concluida;
    return Slidable(
      key: ValueKey('parcela_${parcela.dbId}'),
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _navegarParaEdicaoParcela(parcela),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            icon: Icons.edit_note,
            label: 'Editar',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (context) => _deletarParcela(parcela),
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Excluir',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ListTile(
          leading: Icon(isConcluida ? Icons.check_circle_outline : Icons.timelapse_outlined, color: isConcluida ? Colors.green : Colors.orange),
          title: Text('${parcela.nomeFazenda} - Talhão ${parcela.nomeTalhao}', style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Parcela ${parcela.idParcela} | ${DateFormat('dd/MM/yy HH:mm').format(parcela.dataColeta!)}'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
          onTap: () => _navegarParaInventario(parcela),
        ),
      ),
    );
  }

  // <<< CARD DE CUBAGEM ATUALIZADO AQUI
  Widget _buildCubagemCard(CubagemArvore cubagem) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.straighten, color: Colors.brown),
            title: Text(cubagem.identificador, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Altura: ${cubagem.alturaTotal}m, CAP/DAP: ${cubagem.valorCAP}cm'),
            onTap: () => _editarCubagem(cubagem),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton.icon(icon: const Icon(Icons.edit, size: 18), label: const Text('Editar'), onPressed: () => _editarCubagem(cubagem)),
                // O BOTÃO DE EXPORTAR INDIVIDUAL FOI REMOVIDO DAQUI
                TextButton.icon(icon: const Icon(Icons.delete, size: 18), label: const Text('Apagar'), style: TextButton.styleFrom(foregroundColor: Colors.red), onPressed: () => _deletarCubagem(cubagem)),
              ],
            ),
          )
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: RefreshIndicator(
        onRefresh: _carregarTodasAtividades,
        child: FutureBuilder<Map<String, List<dynamic>>>(
          future: _atividadesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erro ao carregar dados: ${snapshot.error}'));
            }

            final parcelas = snapshot.data?['parcelas'] as List<Parcela>? ?? [];
            final cubagens = snapshot.data?['cubagens'] as List<CubagemArvore>? ?? [];

            if (parcelas.isEmpty && cubagens.isEmpty) {
              return const Center(child: Text('Nenhuma atividade encontrada.'));
            }

            return CustomScrollView(
              slivers: [
                if (parcelas.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text('Coletas de Parcela', style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildParcelaCard(parcelas[index]),
                      childCount: parcelas.length,
                    ),
                  ),
                ],
                if (cubagens.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                      child: Text('Cubagens Rigorosas', style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _buildCubagemCard(cubagens[index]),
                      childCount: cubagens.length,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
      // <<< SPEED DIAL ATUALIZADO AQUI
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        children: [
          SpeedDialChild(
            child: const Icon(Icons.straighten),
            label: 'Nova Cubagem',
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Escolha o Método'),
                  content: const Text('Como as seções serão medidas?'),
                  actions: [
                    TextButton(child: const Text('SEÇÕES FIXAS'), onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CubagemDadosPage(metodo: 'Fixas'))).then((_) => _carregarTodasAtividades());
                    }),
                    TextButton(child: const Text('SEÇÕES RELATIVAS'), onPressed: () {
                      Navigator.of(ctx).pop();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CubagemDadosPage(metodo: 'Relativas'))).then((_) => _carregarTodasAtividades());
                    }),
                  ],
                ),
              );
            },
          ),
          SpeedDialChild(
            child: const Icon(Icons.forest),
            label: 'Nova Coleta de Parcela',
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ColetaDadosPage())).then((_) => _carregarTodasAtividades());
            },
          ),
        ],
      ),
    );
  }
}