// lib/pages/amostra/inventario_page.dart (NOVA ABORDAGEM SIMPLIFICADA)

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
  // Não precisamos mais dos contadores de linha/posição como estado da classe

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

  Future<void> _deletarArvore(Arvore arvore) async {
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
  
  // =========================================================================
  // NOVA ABORDAGEM: Função única e recursiva para adicionar árvores
  // =========================================================================
  Future<void> _adicionarNovaArvore({Arvore? arvoreParaCorrecao, bool isFusteAdicional = false}) async {
    // 1. Calcula a próxima linha/posição disponível
    int proximaLinha = 1;
    int proximaPosicao = 1;

    if (!isFusteAdicional && _arvoresColetadas.isNotEmpty) {
      final ultimaArvore = _arvoresColetadas.last;
      if (ultimaArvore.fimDeLinha) {
        proximaLinha = ultimaArvore.linha + 1;
        proximaPosicao = 1;
      } else {
        proximaLinha = ultimaArvore.linha;
        proximaPosicao = ultimaArvore.posicaoNaLinha + 1;
      }
    } else if (isFusteAdicional && _arvoresColetadas.isNotEmpty) {
       final ultimaArvore = _arvoresColetadas.last;
       proximaLinha = ultimaArvore.linha;
       proximaPosicao = ultimaArvore.posicaoNaLinha;
    }

    // Abre o diálogo. Se `arvoreParaCorrecao` não for nula, o diálogo será pré-preenchido.
    final result = await showDialog<DialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ArvoreDialog(
        arvoreParaEditar: arvoreParaCorrecao,
        linhaAtual: arvoreParaCorrecao?.linha ?? proximaLinha,
        posicaoNaLinhaAtual: arvoreParaCorrecao?.posicaoNaLinha ?? proximaPosicao,
        isAdicionandoFuste: isFusteAdicional,
      ),
    );

    // Se o usuário cancelar, sai da função
    if (result == null) return;

    // Valida o resultado do diálogo
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
      
      // Se clicar em "Corrigir", chama a função novamente passando a árvore com problema
      if (querSalvarMesmoAssim != true) {
        // Atraso mínimo para garantir que o diálogo feche antes de abrir o próximo
        Future.delayed(const Duration(milliseconds: 50), () {
          _adicionarNovaArvore(arvoreParaCorrecao: result.arvore, isFusteAdicional: isFusteAdicional);
        });
        return; // Sai da execução atual
      }
    }
    
    // Se a validação passou ou foi forçada, salva a árvore.
    if (mounted) {
      setState(() => _arvoresColetadas.add(result.arvore));
      await _salvarEstadoAtual(showSnackbar: false);
    }
    
    // Verifica se precisa continuar adicionando
    if (result.continuarNaMesmaPosicao) {
      // Adicionar outro fuste na mesma posição
       Future.delayed(const Duration(milliseconds: 50), () {
          _adicionarNovaArvore(isFusteAdicional: true);
        });
    } else if (result.irParaProxima) {
      // Ir para a próxima árvore
       Future.delayed(const Duration(milliseconds: 50), () {
          _adicionarNovaArvore();
        });
    }
  }

  Future<void> _abrirFormularioParaEditar(Arvore arvore) async {
    final int indexOriginal = _arvoresColetadas.indexOf(arvore);
    if (indexOriginal == -1) return;

    final result = await showDialog<DialogResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ArvoreDialog(arvoreParaEditar: arvore, linhaAtual: arvore.linha, posicaoNaLinhaAtual: arvore.posicaoNaLinha),
    );

    if (result == null) return;

    setState(() => _arvoresColetadas[indexOriginal] = result.arvore);

    final showSnackbar = !(result.atualizarEProximo);
    await _salvarEstadoAtual(showSnackbar: showSnackbar);

    if (result.atualizarEProximo) {
      final int proximoIndex = indexOriginal + 1;
      if (proximoIndex < _arvoresColetadas.length) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            _abrirFormularioParaEditar(_arvoresColetadas[proximoIndex]);
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fim da lista!'), backgroundColor: Colors.blue),
        );
      }
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
    final arvoresCandidatas = _arvoresColetadas.where((a) => a.status == StatusArvore.normal).toList();
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

  String _getArvoreSubtitle(Arvore arvore) {
    String statusPrincipal = arvore.status.name[0].toUpperCase() + arvore.status.name.substring(1);
    String statusSecundario = arvore.status2 != null ? ' / ${arvore.status2!.name[0].toUpperCase() + arvore.status2!.name.substring(1)}' : '';
    String altura = arvore.altura != null ? ' | Altura: ${arvore.altura!.toStringAsFixed(1)}m' : '';
    return '$statusPrincipal$statusSecundario$altura';
  }

  @override
  Widget build(BuildContext context) {
    final listaFiltrada = _mostrandoApenasDominantes ? _arvoresColetadas.where((a) => a.dominante).toList() : _arvoresColetadas;
    final listaExibida = _listaInvertida ? listaFiltrada.reversed.toList() : listaFiltrada;

    final int totalArvores = _arvoresColetadas.length;
    final int contagemAlturaNormal = _arvoresColetadas.where((a) => a.status == StatusArvore.normal && a.altura != null && a.altura! > 0).length;
    final int contagemAlturaDominante = _arvoresColetadas.where((a) => a.dominante && a.altura != null && a.altura! > 0).length;

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
                Card(
                  margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Talhão: ${widget.parcela.nomeTalhao} / Parcela: ${widget.parcela.idParcela}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const Divider(height: 16),
                        _buildStatRow('Árvores Coletadas:', '$totalArvores'),
                        _buildStatRow('Alturas Medidas (Normais):', '$contagemAlturaNormal'),
                        _buildStatRow('Alturas Medidas (Dominantes):', '$contagemAlturaDominante'),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 0),
                  child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () {if (!_mostrandoApenasDominantes) _identificarArvoresDominantes(); setState(() => _mostrandoApenasDominantes = !_mostrandoApenasDominantes);}, icon: Icon(_mostrandoApenasDominantes ? Icons.filter_list_off : Icons.filter_list), label: Text(_mostrandoApenasDominantes ? 'Mostrar Todas' : 'Encontrar Dominantes'))),
                ),
                const Divider(height: 16),
                Expanded(
                  child: _arvoresColetadas.isEmpty
                      ? const Center(child: Text('Clique no botão "+" para adicionar a primeira árvore.', style: TextStyle(color: Colors.grey, fontSize: 16)))
                      : SlidableAutoCloseBehavior(
                        child: ListView.builder(
                            itemCount: listaExibida.length,
                            itemBuilder: (context, index) {
                              final arvore = listaExibida[index];
                              return Slidable(
                                key: ValueKey(arvore.id ?? arvore.hashCode),
                                endActionPane: ActionPane(
                                  motion: const StretchMotion(),
                                  children: [
                                    SlidableAction(
                                      onPressed: (_) => _deletarArvore(arvore),
                                      backgroundColor: Colors.redAccent,
                                      foregroundColor: Colors.white,
                                      icon: Icons.delete_outline,
                                      label: 'Excluir',
                                    ),
                                  ],
                                ),
                                child: Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  color: arvore.dominante ? Colors.green.withAlpha(51) : null,
                                  child: ListTile(
                                    leading: CircleAvatar(backgroundColor: arvore.dominante ? Colors.amber[700] : Theme.of(context).primaryColor, child: arvore.dominante ? const Icon(Icons.star, color: Colors.white, size: 20) : Text('${arvore.posicaoNaLinha}', style: const TextStyle(color: Colors.white))),
                                    title: Text('L: ${arvore.linha} | CAP: ${arvore.cap.toStringAsFixed(1)} cm'),
                                    subtitle: Text(_getArvoreSubtitle(arvore)),
                                    trailing: const Icon(Icons.edit_outlined, color: Colors.grey),
                                    onTap: () => _abrirFormularioParaEditar(arvore),
                                  ),
                                ),
                              );
                            },
                          ),
                      ),
                ),
              ],
            ),
      // O FloatingActionButton agora chama a nova função simplificada
      floatingActionButton: FloatingActionButton(
        onPressed: () => _adicionarNovaArvore(),
        tooltip: 'Adicionar Árvore',
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