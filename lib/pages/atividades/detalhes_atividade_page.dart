// lib/pages/atividades/detalhes_atividade_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';

// Importe o formulário de fazenda (o caminho pode variar)
import 'package:geoforestcoletor/pages/fazenda/form_fazenda_page.dart';
// Futuramente, importaremos a página de detalhes da fazenda
import 'package:geoforestcoletor/pages/fazenda/detalhes_fazenda_page.dart';

class DetalhesAtividadePage extends StatefulWidget {
  final Atividade atividade;

  const DetalhesAtividadePage({super.key, required this.atividade});

  @override
  State<DetalhesAtividadePage> createState() => _DetalhesAtividadePageState();
}

class _DetalhesAtividadePageState extends State<DetalhesAtividadePage> {
  late Future<List<Fazenda>> _fazendasFuture;
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _carregarFazendas();
  }

  void _carregarFazendas() {
    setState(() {
      _fazendasFuture = dbHelper.getFazendasDaAtividade(widget.atividade.id!);
    });
  }

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
    // AINDA NÃO IMPLEMENTADO
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Navegando para os detalhes da fazenda: ${fazenda.nome}')));
    
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesFazendaPage(fazenda: fazenda)),
    ).then((_) => _carregarFazendas());
    
  }

  Future<void> _deletarFazenda(Fazenda fazenda) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text(
            'Tem certeza que deseja apagar a fazenda "${fazenda.nome}" (ID: ${fazenda.id}) e todos os seus talhões e coletas?'),
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
      // <<< ALTERADO: Passando os dois parâmetros para o delete
      await dbHelper.deleteFazenda(fazenda.id, fazenda.atividadeId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Fazenda "${fazenda.nome}" apagada.'),
          backgroundColor: Colors.green));
      _carregarFazendas();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.atividade.tipo),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Card com informações da Atividade
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

          // Lista de Fazendas
          Expanded(
            child: FutureBuilder<List<Fazenda>>(
              future: _fazendasFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Erro ao carregar fazendas: ${snapshot.error}'));
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
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.agriculture_outlined),
                        ),
                        // <<< ALTERADO: Mostrando o ID da fazenda no subtítulo
                        title: Text(fazenda.nome,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('ID: ${fazenda.id}\n${fazenda.municipio} - ${fazenda.estado}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deletarFazenda(fazenda),
                        ),
                        onTap: () => _navegarParaDetalhesFazenda(fazenda),
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
        onPressed: _navegarParaNovaFazenda,
        tooltip: 'Nova Fazenda',
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Nova Fazenda'),
      ),
    );
  }
}