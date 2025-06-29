// lib/pages/fazendas/detalhes_fazenda_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';

// Futuramente, importaremos o formulário e a página de detalhes do talhão
import 'package:geoforestcoletor/pages/talhoes/form_talhao_page.dart';
import 'package:geoforestcoletor/pages/talhoes/detalhes_talhao_page.dart';

class DetalhesFazendaPage extends StatefulWidget {
  final Fazenda fazenda;

  const DetalhesFazendaPage({super.key, required this.fazenda});

  @override
  State<DetalhesFazendaPage> createState() => _DetalhesFazendaPageState();
}

class _DetalhesFazendaPageState extends State<DetalhesFazendaPage> {
  late Future<List<Talhao>> _talhoesFuture;
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _carregarTalhoes();
  }

  void _carregarTalhoes() {
    setState(() {
      _talhoesFuture = dbHelper.getTalhoesDaFazenda(widget.fazenda.id, widget.fazenda.atividadeId);
    });
  }

  void _navegarParaNovoTalhao() async {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Funcionalidade "Novo Talhão" a ser implementada.')));

      final bool? talhaoCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormTalhaoPage(
          fazendaId: widget.fazenda.id,
          fazendaAtividadeId: widget.fazenda.atividadeId,
        ),
      ),
    );
    if (talhaoCriado == true && mounted) {
      _carregarTalhoes();
    }
    
  }
  
  void _navegarParaDetalhesTalhao(Talhao talhao) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navegando para os detalhes do talhão: ${talhao.nome}')));

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesTalhaoPage(talhao: talhao)),
    ).then((_) => _carregarTalhoes());
    
  }

  Future<void> _deletarTalhao(Talhao talhao) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja apagar o talhão "${talhao.nome}" e todas as suas coletas de parcela e cubagem?'),
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
      await dbHelper.deleteTalhao(talhao.id!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Talhão "${talhao.nome}" apagado.'),
          backgroundColor: Colors.green));
      _carregarTalhoes();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fazenda.nome),
      ),
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
                  Text('Detalhes da Fazenda', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  Text("ID: ${widget.fazenda.id}", style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text("Local: ${widget.fazenda.municipio} - ${widget.fazenda.estado.toUpperCase()}", style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              "Talhões da Fazenda",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Talhao>>(
              future: _talhoesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erro ao carregar talhões: ${snapshot.error}'));
                }

                final talhoes = snapshot.data ?? [];

                if (talhoes.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhum talhão encontrado.\nClique no botão "+" para adicionar o primeiro.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: talhoes.length,
                  itemBuilder: (context, index) {
                    final talhao = talhoes[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.park_outlined),
                        ),
                        title: Text(talhao.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Área: ${talhao.areaHa ?? 'N/A'} ha - Espécie: ${talhao.especie ?? 'N/A'}'),
                         trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deletarTalhao(talhao),
                        ),
                        onTap: () => _navegarParaDetalhesTalhao(talhao),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navegarParaNovoTalhao,
        tooltip: 'Novo Talhão',
        icon: const Icon(Icons.add_chart),
        label: const Text('Novo Talhão'),
      ),
    );
  }
}