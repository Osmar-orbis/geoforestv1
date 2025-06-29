// lib/pages/projetos/lista_projetos_page.dart

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:intl/intl.dart';

// Vamos importar as páginas que vamos usar a seguir.
// Se elas ainda não existem, o editor pode sublinhar em vermelho, mas isso é esperado.
import 'package:geoforestcoletor/pages/projetos/form_projeto_page.dart';
import 'package:geoforestcoletor/pages/projetos/detalhes_projeto_page.dart';

class ListaProjetosPage extends StatefulWidget {
  const ListaProjetosPage({super.key});

  @override
  State<ListaProjetosPage> createState() => _ListaProjetosPageState();
}

class _ListaProjetosPageState extends State<ListaProjetosPage> {
  late Future<List<Projeto>> _projetosFuture;
  final dbHelper = DatabaseHelper.instance;

  @override
  void initState() {
    super.initState();
    _carregarProjetos();
  }

  // Busca os projetos do banco de dados e atualiza o estado da tela
  void _carregarProjetos() {
    setState(() {
      _projetosFuture = dbHelper.getTodosProjetos();
    });
  }

  // Navega para a tela de formulário para criar um novo projeto
  void _navegarParaNovoProjeto() async {
    // Aguarda o resultado da página de formulário
    final bool? projetoCriado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const FormProjetoPage()),
    );
    // Se a página de formulário retornar 'true', recarrega a lista de projetos
    if (projetoCriado == true && mounted) {
      _carregarProjetos();
    }
  }

// Em _ListaProjetosPageState

  void _navegarParaDetalhesProjeto(Projeto projeto) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => DetalhesProjetoPage(projeto: projeto)),
    ).then((_) {
    // Opcional: Recarregar a lista de projetos caso algo mude na tela de detalhes.
    // _carregarProjetos(); 
  });
}

  // Deleta um projeto e todas as suas dependências (em cascata)
  Future<void> _deletarProjeto(Projeto projeto) async {
     final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar o projeto "${projeto.nome}" e TODAS as suas fazendas, talhões e coletas? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Apagar Tudo'),
          ),
        ],
      ),
    );

    if(confirmar == true && mounted) {
      await dbHelper.deleteProjeto(projeto.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Projeto "${projeto.nome}" apagado.'), backgroundColor: Colors.green)
      );
      _carregarProjetos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus Projetos'),
      ),
      body: FutureBuilder<List<Projeto>>(
        future: _projetosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erro ao carregar projetos: ${snapshot.error}'));
          }
          
          final projetos = snapshot.data ?? [];

          if (projetos.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'Nenhum projeto encontrado.\nClique no botão "+" para criar o primeiro.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _carregarProjetos(),
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: projetos.length,
              itemBuilder: (context, index) {
                final projeto = projetos[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.folder_copy_outlined),
                    ),
                    title: Text(projeto.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Empresa: ${projeto.empresa}\nCriado em: ${DateFormat('dd/MM/yyyy').format(projeto.dataCriacao)}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _deletarProjeto(projeto),
                      tooltip: 'Excluir Projeto',
                    ),
                    onTap: () => _navegarParaDetalhesProjeto(projeto),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navegarParaNovoProjeto,
        tooltip: 'Novo Projeto',
        child: const Icon(Icons.add),
      ),
    );
  }
}