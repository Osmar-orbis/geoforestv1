// lib/pages/talhoes/detalhes_talhao_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/pages/menu/map_import_page.dart';
import 'package:geoforestcoletor/pages/menu/home_page.dart'; // <<< 1. IMPORTA A HOMEPAGE
import 'package:geoforestcoletor/pages/amostra/form_parcela_page.dart';

class DetalhesTalhaoPage extends StatefulWidget {
  final Talhao talhao;

  const DetalhesTalhaoPage({super.key, required this.talhao});

  @override
  State<DetalhesTalhaoPage> createState() => _DetalhesTalhaoPageState();
}

class _DetalhesTalhaoPageState extends State<DetalhesTalhaoPage> {
  late Future<List<Parcela>> _parcelasFuture;
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _carregarParcelas();
  }

  void _carregarParcelas() {
    setState(() {
      _parcelasFuture = dbHelper.getParcelasDoTalhao(widget.talhao.id!);
    });
  }

  void _navegarParaMapa() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapImportPage(talhao: widget.talhao),
      ),
    );
  }

  void _navegarParaNovaParcela() async {
  final foiAtualizado = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (context) => FormParcelaPage(talhao: widget.talhao),
    ),
  );
  if (foiAtualizado == true && mounted) {
    _carregarParcelas();
  }
}

  void _navegarParaCubagem() {
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Navegação para Cubagem a ser implementada.')));
  }
  
  Future<void> _deletarParcela(Parcela parcela) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar a Parcela ID "${parcela.idParcela}"? Todos os dados de árvores associados a ela serão perdidos.'),
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
      await dbHelper.deleteParcela(parcela.dbId!);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Parcela ID "${parcela.idParcela}" apagada.'),
          backgroundColor: Colors.green));
      _carregarParcelas();
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Talhão: ${widget.talhao.nome}'),
        actions: [
            IconButton(
                icon: const Icon(Icons.straighten_outlined),
                tooltip: 'Cubagem',
                onPressed: _navegarParaCubagem,
            ),
            // <<< 2. ADICIONA O BOTÃO NA APPBAR >>>
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Voltar para o Início',
              onPressed: () {
                // Navega para a HomePage e remove todas as telas anteriores da pilha.
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const HomePage(title: 'Geo Forest Analytics')),
                  (Route<dynamic> route) => false,
                );
              },
            ),
        ],
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
                  Text('Detalhes do Talhão', style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
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
            child: ElevatedButton.icon(
              onPressed: _navegarParaMapa,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Abrir Talhão no Mapa'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
            child: Text(
              "Coletas de Parcela",
              style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Nenhuma parcela coletada neste talhão.\nClique no botão "+" para iniciar a primeira coleta.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: parcelas.length,
                  itemBuilder: (context, index) {
                    final parcela = parcelas[index];
                    final dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(parcela.dataColeta!);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: parcela.status.cor,
                          child: Icon(parcela.status.icone, color: Colors.white),
                        ),
                        title: Text('Parcela ID: ${parcela.idParcela}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Coletado em: $dataFormatada'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => _deletarParcela(parcela),
                        ),
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
        onPressed: _navegarParaNovaParcela,
        tooltip: 'Nova Coleta de Parcela',
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Nova Parcela'),
      ),
    );
  }
}