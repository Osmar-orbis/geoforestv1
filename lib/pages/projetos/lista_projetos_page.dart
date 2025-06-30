// lib/pages/projetos/lista_projetos_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/pages/atividades/atividades_page.dart';
import 'package:geoforestcoletor/services/export_service.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';

// 1. IMPORT ADICIONADO PARA A PÁGINA DO FORMULÁRIO
import 'form_projeto_page.dart'; 

class ListaProjetosPage extends StatefulWidget {
  const ListaProjetosPage({super.key, required this.title});
  final String title;

  @override
  State<ListaProjetosPage> createState() => _ListaProjetosPageState();
}

class _ListaProjetosPageState extends State<ListaProjetosPage> {
  final dbHelper = DatabaseHelper.instance;
  final exportService = ExportService();
  List<Projeto> projetos = [];
  bool _isLoading = true;

  bool _isSelectionMode = false;
  final Set<int> _selectedProjetos = {};

  @override
  void initState() {
    super.initState();
    _carregarProjetos();
  }

  Future<void> _carregarProjetos() async {
    setState(() => _isLoading = true);
    final data = await dbHelper.getTodosProjetos();
    setState(() {
      projetos = data;
      _isLoading = false;
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProjetos.clear();
      _isSelectionMode = false;
    });
  }

  void _toggleSelection(int projetoId) {
    setState(() {
      if (_selectedProjetos.contains(projetoId)) {
        _selectedProjetos.remove(projetoId);
      } else {
        _selectedProjetos.add(projetoId);
      }
      _isSelectionMode = _selectedProjetos.isNotEmpty;
    });
  }

  Future<void> _importarProjeto() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['geojson', 'json'],
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      final fileContent = await file.readAsString();

      final String message = await dbHelper.importarProjetoCompleto(fileContent);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 5),
        ));
        _carregarProjetos();
      }
    } else {
      // Usuário cancelou a seleção
    }
  }

  Future<void> _exportarProjetosSelecionados() async {
    if (_selectedProjetos.isEmpty) return;

    await exportService.exportarProjetosCompletos(
      context: context,
      projetoIds: _selectedProjetos.toList(),
    );

    _clearSelection();
  }

  Future<void> _deletarProjetosSelecionados() async {
    if (_selectedProjetos.isEmpty) return;

    final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Confirmar Exclusão'),
              content: Text(
                  'Tem certeza que deseja apagar os ${_selectedProjetos.length} projetos selecionados? Todas as atividades, fazendas, talhões e coletas associadas serão perdidas permanentemente.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancelar')),
                FilledButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style:
                        FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Apagar')),
              ],
            ));
    if (confirmar == true && mounted) {
      for (final id in _selectedProjetos) {
        await dbHelper.deleteProjeto(id);
      }
      _clearSelection();
      await _carregarProjetos();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _clearSelection,
              ),
              title: Text('${_selectedProjetos.length} selecionados'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  onPressed: _exportarProjetosSelecionados,
                  tooltip: 'Exportar Selecionados',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _deletarProjetosSelecionados,
                  tooltip: 'Apagar Selecionados',
                ),
              ],
            )
          : AppBar(
              title: Text(widget.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.upload_file_outlined),
                  onPressed: _importarProjeto,
                  tooltip: 'Importar Projeto',
                ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : projetos.isEmpty
              ? const Center(
                  child: Text(
                      'Nenhum projeto encontrado.\nUse o botão + para adicionar um novo.',
                      textAlign: TextAlign.center))
              : ListView.builder(
                  itemCount: projetos.length,
                  itemBuilder: (context, index) {
                    final projeto = projetos[index];
                    final isSelected = _selectedProjetos.contains(projeto.id!);

                    return Card(
                        color: isSelected ? Colors.lightBlue.shade100 : null,
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child:
                           ListTile(
                            onTap: () {
                              if (_isSelectionMode) {
                                _toggleSelection(projeto.id!);
                              } else {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => AtividadesPage(projeto: projeto)));
                              }
                            },
                            onLongPress: () {
                              _toggleSelection(projeto.id!);
                            },
                            leading: Icon(
                                isSelected ? Icons.check_circle : Icons.folder_outlined,
                                color: Theme.of(context).primaryColor,
                            ),
                            title: Text(projeto.nome, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Responsável: ${projeto.responsavel}'),
                            trailing: Text(DateFormat('dd/MM/yy').format(projeto.dataCriacao)),
                          ),
                        );
                  },
                ),
      // 2. LÓGICA DE NAVEGAÇÃO IMPLEMENTADA AQUI
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navega para a página de formulário para criar um novo projeto
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FormProjetoPage()),
          ).then((_) {
            // Após voltar da tela de criação, atualiza a lista de projetos
            _carregarProjetos();
          });
        },
        tooltip: 'Adicionar Projeto',
        child: const Icon(Icons.add),
      ),
    );
  }
}