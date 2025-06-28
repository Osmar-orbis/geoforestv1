// lib/pages/amostra/inventario_page.dart (VERSÃO FINAL E CORRIGIDA)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/services/validation_service.dart';
import 'package:geoforestcoletor/widgets/arvore_dialog.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class InventarioPage extends StatefulWidget {
  final Parcela parcela;
  const InventarioPage({super.key, required this.parcela});

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  final _validationService = ValidationService();

  List<Arvore> _arvoresColetadas = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _mostrandoApenasDominantes = false;
  bool _listaInvertida = false;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    if (widget.parcela.dbId != null) {
      final arvoresDoBanco = await DatabaseHelper().getArvoresDaParcela(widget.parcela.dbId!);
      if (mounted) setState(() => _arvoresColetadas = arvoresDoBanco);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _deletarArvore(BuildContext context, Arvore arvore) async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Exclusão'),
        content: Text('Tem certeza que deseja apagar a árvore da linha ${arvore.linha}, posição ${arvore.posicaoNaLinha}?'),
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
      setState(() {
        _arvoresColetadas.remove(arvore);
      });
      await _salvarEstadoAtual(showSnackbar: false);
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Árvore removida com sucesso.'),
          backgroundColor: Colors.green,
        ));
    }
  }

  Future<void> _processarResultadoDialogo(DialogResult result, {int? indexOriginal}) async {
    final validationResult = _validationService.validateSingleTree(result.arvore);
    if (!validationResult.isValid) {
      final querSalvarMesmoAssim = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Dados Incomuns Detectados"),
          content: Text(validationResult.warnings.join('\n\n')),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text("Corrigir")),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text("Salvar Mesmo Assim", style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      );
      if (querSalvarMesmoAssim != true) {
        if (indexOriginal != null) {
           _abrirFormularioParaEditar(result.arvore);
        } else {
          _adicionarNovaArvore(arvoreInicial: result.arvore);
        }
        return;
      }
    }

    setState(() {
      if (indexOriginal != null) {
        _arvoresColetadas[indexOriginal] = result.arvore;
      } else {
        _arvoresColetadas.add(result.arvore);
      }
    });

    await _salvarEstadoAtual(showSnackbar: !(result.atualizarEProximo || result.irParaProxima));

    if (result.irParaProxima) {
      Future.delayed(const Duration(milliseconds: 50), () => _adicionarNovaArvore());
    } else if (result.continuarNaMesmaPosicao) {
      Future.delayed(const Duration(milliseconds: 50), () => _adicionarNovaArvore(isFusteAdicional: true));
    } else if (result.atualizarEProximo && indexOriginal != null) {
      _arvoresColetadas.sort((a, b) {
        int compLinha = a.linha.compareTo(b.linha);
        if (compLinha != 0) return compLinha;
        int compPos = a.posicaoNaLinha.compareTo(b.posicaoNaLinha);
        if (compPos != 0) return compPos;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
      final int novoIndex = _arvoresColetadas.indexOf(result.arvore);
      if (novoIndex + 1 < _arvoresColetadas.length) {
        Future.delayed(const Duration(milliseconds: 100), () => _abrirFormularioParaEditar(_arvoresColetadas[novoIndex + 1]));
      }
    }
  }

  Future<void> _adicionarNovaArvore({Arvore? arvoreInicial, bool isFusteAdicional = false}) async {
    _arvoresColetadas.sort((a, b) {
      int compLinha = a.linha.compareTo(b.linha);
      if (compLinha != 0) return compLinha;
      return a.posicaoNaLinha.compareTo(b.posicaoNaLinha);
    });

    int proximaLinha = 1;
    int proximaPosicao = 1;

    if (!isFusteAdicional && _arvoresColetadas.isNotEmpty) {
      final ultimaArvore = _arvoresColetadas.last;
      proximaLinha = ultimaArvore.fimDeLinha ? ultimaArvore.linha + 1 : ultimaArvore.linha;
      proximaPosicao = ultimaArvore.fimDeLinha ? 1 : ultimaArvore.posicaoNaLinha + 1;
    } else if (isFusteAdicional && _arvoresColetadas.isNotEmpty) {
      final ultimaArvore = _arvoresColetadas.last;
      proximaLinha = ultimaArvore.linha;
      proximaPosicao = ultimaArvore.posicaoNaLinha;
    }

    final result = await showDialog<DialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ArvoreDialog(
        arvoreParaEditar: arvoreInicial,
        linhaAtual: arvoreInicial?.linha ?? proximaLinha,
        posicaoNaLinhaAtual: arvoreInicial?.posicaoNaLinha ?? proximaPosicao,
        isAdicionandoFuste: isFusteAdicional,
      ),
    );

    if (result != null) {
      await _processarResultadoDialogo(result);
    }
  }

  Future<void> _abrirFormularioParaEditar(Arvore arvore) async {
    final int indexOriginal = _arvoresColetadas.indexOf(arvore);
    if (indexOriginal == -1) return;

    final result = await showDialog<DialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ArvoreDialog(
        arvoreParaEditar: arvore,
        linhaAtual: arvore.linha,
        posicaoNaLinhaAtual: arvore.posicaoNaLinha,
      ),
    );

    if (result != null) {
      await _processarResultadoDialogo(result, indexOriginal: indexOriginal);
    }
  }
  
  Future<void> _salvarEstadoAtual({bool showSnackbar = true, bool concluir = false}) async {
    if (_isSaving) return;
    if (mounted) setState(() => _isSaving = true);
    try {
      if (concluir) {
        widget.parcela.status = StatusParcela.concluida;
        _identificarArvoresDominantes();
      }
      _arvoresColetadas.sort((a, b) {
        int compLinha = a.linha.compareTo(b.linha);
        if (compLinha != 0) return compLinha;
        int compPos = a.posicaoNaLinha.compareTo(b.posicaoNaLinha);
        if (compPos != 0) return compPos;
        return (a.id ?? 0).compareTo(b.id ?? 0);
      });
      await DatabaseHelper().saveFullColeta(widget.parcela, _arvoresColetadas);
      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Progresso salvo!'), duration: Duration(seconds: 2), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _identificarArvoresDominantes() {
    for (var arvore in _arvoresColetadas) {
      arvore.dominante = false;
    }
    final int numeroDeDominantes = (widget.parcela.areaMetrosQuadrados / 100).floor();
    final arvoresCandidatas = _arvoresColetadas.where((a) => a.codigo == Codigo.normal).toList();
    if (arvoresCandidatas.length <= numeroDeDominantes) {
      for (var arvore in arvoresCandidatas) {
        arvore.dominante = true;
      }
    } else {
      arvoresCandidatas.sort((a, b) => b.cap.compareTo(a.cap));
      for (int i = 0; i < numeroDeDominantes; i++) {
        arvoresCandidatas[i].dominante = true;
      }
    }
  }

  Future<void> _concluirColeta() async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Concluir Coleta'), content: const Text('Tem certeza que deseja marcar esta parcela como concluída? As árvores dominantes serão selecionadas automaticamente.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')), ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Concluir'))])) ?? false;
    if (!confirm) return;
    await _salvarEstadoAtual(concluir: true, showSnackbar: false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parcela concluída com sucesso!'), backgroundColor: Colors.blue));
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _analisarParcelaInteira() async {
    if (_arvoresColetadas.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A análise estatística requer pelo menos 10 árvores.'), backgroundColor: Colors.orange));
      return;
    }
    final validationResult = _validationService.validateParcela(_arvoresColetadas);
    await showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text("Relatório de Análise Estatística"), content: validationResult.isValid ? const Text("Nenhuma anomalia estatística significativa foi encontrada nos dados de CAP.") : SingleChildScrollView(child: Text(validationResult.warnings.join('\n\n'))), actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text("OK"))]));
  }
  
  Widget _buildSummaryCard() {
    final int totalArvores = _arvoresColetadas.length;
    final int contagemAlturaNormal = _arvoresColetadas.where((a) => a.codigo == Codigo.normal && a.altura != null && a.altura! > 0).length;
    final int contagemAlturaDominante = _arvoresColetadas.where((a) => a.dominante && a.altura != null && a.altura! > 0).length;

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Talhão: ${widget.parcela.nomeTalhao} / Parcela: ${widget.parcela.idParcela}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(height: 20),
            _buildStatRow('Árvores Coletadas:', '$totalArvores'),
            _buildStatRow('Alturas Medidas (Normais):', '$contagemAlturaNormal'),
            _buildStatRow('Alturas Medidas (Dominantes):', '$contagemAlturaDominante'),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    final theme = Theme.of(context);
    final headerStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.bold,
      color: theme.colorScheme.onSurface.withOpacity(0.6),
      letterSpacing: 0.5,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(bottom: BorderSide(color: theme.dividerColor, width: 1.5)),
      ),
      child: Row(
        children: [
          _HeaderCell('LINHA', flex: 15, style: headerStyle),
          _HeaderCell('ÁRVORE', flex: 15, style: headerStyle),
          _HeaderCell('CAP', flex: 20, style: headerStyle),
          _HeaderCell('ALTURA', flex: 20, style: headerStyle),
          _HeaderCell('CÓDIGOS', flex: 30, style: headerStyle),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listaFiltrada = _mostrandoApenasDominantes ? _arvoresColetadas.where((a) => a.dominante).toList() : _arvoresColetadas;
    
    final listaOrdenada = List<Arvore>.from(listaFiltrada);
    listaOrdenada.sort((a, b) {
      int compLinha = a.linha.compareTo(b.linha);
      if (compLinha != 0) return compLinha;
      int compPos = a.posicaoNaLinha.compareTo(b.posicaoNaLinha);
      if (compPos != 0) return compPos;
      return (a.id ?? 0).compareTo(b.id ?? 0);
    });

    final listaExibida = _listaInvertida ? listaOrdenada.reversed.toList() : listaOrdenada;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coleta da Parcela'),
        actions: [
          if (_isSaving)
            const Padding(padding: EdgeInsets.only(right: 16.0), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))))
          else ...[
            IconButton(icon: const Icon(Icons.swap_vert), tooltip: 'Inverter Ordem da Lista', onPressed: () => setState(() => _listaInvertida = !_listaInvertida)),
            IconButton(icon: const Icon(Icons.analytics_outlined), tooltip: 'Analisar Parcela', onPressed: _arvoresColetadas.isEmpty ? null : _analisarParcelaInteira),
            IconButton(icon: const Icon(Icons.save_outlined), tooltip: 'Salvar Progresso', onPressed: () => _salvarEstadoAtual()),
            IconButton(icon: const Icon(Icons.check_circle_outline), tooltip: 'Concluir e Salvar Parcela', onPressed: _concluirColeta),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 8.0),
                  child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {if (!_mostrandoApenasDominantes) _identificarArvoresDominantes(); setState(() => _mostrandoApenasDominantes = !_mostrandoApenasDominantes);}, icon: Icon(_mostrandoApenasDominantes ? Icons.filter_list_off : Icons.filter_list), label: Text(_mostrandoApenasDominantes ? 'Mostrar Todas' : 'Encontrar Dominantes'))),
                ),
                
                _buildHeaderRow(),

                Expanded(
                  child: _arvoresColetadas.isEmpty
                      ? const Center(child: Text('Clique no botão "+" para adicionar a primeira árvore.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                      : SlidableAutoCloseBehavior(
                        child: ListView.builder(
                            padding: EdgeInsets.zero,
                            itemCount: listaExibida.length,
                            itemBuilder: (context, index) {
                              final arvore = listaExibida[index];
                              
                              return Slidable(
                                key: ValueKey(arvore.id ?? arvore.hashCode),
                                endActionPane: ActionPane(
                                  motion: const StretchMotion(),
                                  extentRatio: 0.25,
                                  children: [
                                    SlidableAction(
                                      onPressed: (ctx) => _deletarArvore(ctx, arvore),
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      icon: Icons.delete_outline,
                                      label: 'Excluir',
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () => _abrirFormularioParaEditar(arvore),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                                    decoration: BoxDecoration(
                                      color: arvore.dominante ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4) : (index.isOdd ? Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3) : Colors.transparent),
                                      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor, width: 0.8)),
                                    ),
                                    child: Row(
                                      children: [
                                        _DataCell(arvore.linha.toString(), flex: 15),
                                        _DataCell(arvore.posicaoNaLinha.toString(), flex: 15),
                                        _DataCell(arvore.cap > 0 ? arvore.cap.toStringAsFixed(1) : '-', flex: 20),
                                        _DataCell(arvore.altura?.toStringAsFixed(1) ?? '-', flex: 20),
                                        _DataCell(
                                          '${arvore.codigo.name[0].toUpperCase()}${arvore.codigo2 != null ? ", ${arvore.codigo2!.name[0].toUpperCase()}" : ""}', 
                                          flex: 30, 
                                          isBold: true
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                      ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _adicionarNovaArvore(),
        tooltip: 'Adicionar Árvore',
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final int flex;
  final TextStyle? style;
  const _HeaderCell(this.text, {required this.flex, this.style});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(text, style: style, textAlign: TextAlign.center),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isBold;
  const _DataCell(this.text, {required this.flex, this.isBold = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 16,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}