// lib/pages/projetos/detalhes_projeto_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';

// Imports para as páginas de navegação
import 'package:geoforestcoletor/pages/atividades/form_atividade_page.dart';
import 'package:geoforestcoletor/pages/atividades/detalhes_atividade_page.dart';

class DetalhesProjetoPage extends StatefulWidget {
  final Projeto projeto;
  const DetalhesProjetoPage({super.key, required this.projeto});

  @override
  State<DetalhesProjetoPage> createState() => _DetalhesProjetoPageState();
}

class _DetalhesProjetoPageState extends State<DetalhesProjetoPage> {
  late Future<List<Atividade>> _atividadesFuture;
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _carregarAtividades();
  }

  void _carregarAtividades() {
    setState(() {
      _atividadesFuture = dbHelper.getAtividadesDoProjeto(widget.projeto.id!);
    });
  }

  void _navegarParaNovaAtividade() async {
    final bool? atividadeCriada = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FormAtividadePage(projetoId: widget.projeto.id!),
      ),
    );
    if (atividadeCriada == true && mounted) {
      _carregarAtividades(); // Recarrega a lista para mostrar a nova atividade
    }
  }

  void _navegarParaDetalhesAtividade(Atividade atividade) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesAtividadePage(atividade: atividade)),
    ).then((_) {
      // Recarrega as atividades caso algo mude (ex: uma atividade foi editada)
      _carregarAtividades();
    });
  }

  Future<void> _deletarAtividade(Atividade atividade) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja apagar a atividade "${atividade.tipo}" e todos os seus dados (fazendas, talhões, etc)?'),
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
      await dbHelper.deleteAtividade(atividade.id!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Atividade "${atividade.tipo}" apagada.'),
          backgroundColor: Colors.green));
      _carregarAtividades();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.projeto.nome),
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
                   Text('Detalhes do Projeto', style: Theme.of(context).textTheme.titleLarge),
                    const Divider(height: 20),
                  Text("Empresa: ${widget.projeto.empresa}",
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                  Text("Responsável: ${widget.projeto.responsavel}",
                      style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 8),
                   Text('Data de Criação: ${DateFormat('dd/MM/yyyy').format(widget.projeto.dataCriacao)}',
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
            child: Text(
              "Atividades do Projeto",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Atividade>>(
              future: _atividadesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Erro ao carregar atividades: ${snapshot.error}'));
                }

                final atividades = snapshot.data ?? [];

                if (atividades.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhuma atividade encontrada.\nClique no botão "+" para adicionar a primeira.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: atividades.length,
                  itemBuilder: (context, index) {
                    final atividade = atividades[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(_getIconForAtividade(atividade.tipo)),
                        ),
                        title: Text(atividade.tipo,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(atividade.descricao.isNotEmpty ? atividade.descricao : 'Sem descrição'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deletarAtividade(atividade),
                        ),
                        onTap: () => _navegarParaDetalhesAtividade(atividade),
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
        onPressed: _navegarParaNovaAtividade,
        tooltip: 'Nova Atividade',
        icon: const Icon(Icons.add_task),
        label: const Text('Nova Atividade'),
      ),
    );
  }

  IconData _getIconForAtividade(String tipo) {
    if (tipo.toLowerCase().contains('inventário')) return Icons.forest;
    if (tipo.toLowerCase().contains('cubagem')) return Icons.architecture;
    if (tipo.toLowerCase().contains('manutenção')) return Icons.build;
    return Icons.assignment;
  }
}