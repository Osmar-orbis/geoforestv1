import 'package:flutter/material.dart';
import 'package:geoforestcoletor/helpers/database_helper.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/widgets/arvore_dialog.dart';

class InventarioPage extends StatefulWidget {
  final Parcela parcela;
  const InventarioPage({super.key, required this.parcela});

  @override
  State<InventarioPage> createState() => _InventarioPageState();
}

class _InventarioPageState extends State<InventarioPage> {
  List<Arvore> _arvoresColetadas = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _mostrandoApenasDominantes = false;

  int _linhaAtual = 1;
  int _posicaoNaLinhaAtual = 1;

  @override
  void initState() {
    super.initState();
    _carregarDadosIniciais();
  }

  Future<void> _carregarDadosIniciais() async {
    setState(() => _isLoading = true);
    if (widget.parcela.dbId != null) {
      final arvoresDoBanco =
          await DatabaseHelper().getArvoresDaParcela(widget.parcela.dbId!);
      setState(() => _arvoresColetadas = arvoresDoBanco);
    }
    _atualizarContadoresLinhaPosicao();
    setState(() => _isLoading = false);
  }

  void _atualizarContadoresLinhaPosicao() {
    if (_arvoresColetadas.isEmpty) {
      _linhaAtual = 1;
      _posicaoNaLinhaAtual = 1;
      return;
    }
    int maxLinha =
        _arvoresColetadas.map((a) => a.linha).reduce((a, b) => a > b ? a : b);
    final arvoresNaMaxLinha =
        _arvoresColetadas.where((a) => a.linha == maxLinha).toList();
    int maxPosicaoNaMaxLinha = arvoresNaMaxLinha
        .map((a) => a.posicaoNaLinha)
        .reduce((a, b) => a > b ? a : b);

    final ultimaArvore = _arvoresColetadas.lastWhere(
      (a) => a.linha == maxLinha && a.posicaoNaLinha == maxPosicaoNaMaxLinha,
      orElse: () => _arvoresColetadas.last,
    );

    if (ultimaArvore.fimDeLinha) {
      _linhaAtual = maxLinha + 1;
      _posicaoNaLinhaAtual = 1;
    } else {
      _linhaAtual = maxLinha;
      _posicaoNaLinhaAtual = maxPosicaoNaMaxLinha + 1;
    }
  }

  Future<void> _abrirFormularioParaAdicionar() async {
    bool continuarAdicionando = true;
    while (continuarAdicionando) {
      _atualizarContadoresLinhaPosicao();

      bool continuarNaMesmaPosicaoFuste = false;
      bool primeiroFuste = true;

      do {
        continuarNaMesmaPosicaoFuste = false;

        final result = await showDialog<DialogResult>(
          context: context,
          barrierDismissible: false,
          builder: (context) => ArvoreDialog(
            linhaAtual: _linhaAtual,
            posicaoNaLinhaAtual: _posicaoNaLinhaAtual,
            isAdicionandoFuste: !primeiroFuste,
          ),
        );

        if (result == null) {
          continuarAdicionando = false;
          break;
        }

        setState(() => _arvoresColetadas.add(result.arvore));
        await _salvarEstadoAtual(showSnackbar: false);

        continuarNaMesmaPosicaoFuste = result.continuarNaMesmaPosicao;
        if (continuarNaMesmaPosicaoFuste) primeiroFuste = false;

        if (!result.irParaProxima && !continuarNaMesmaPosicaoFuste) {
          continuarAdicionando = false;
        }
      } while (continuarNaMesmaPosicaoFuste);
    }

    setState(_atualizarContadoresLinhaPosicao);
  }

  // =======================================================================
  // ====================== MÉTODO COM A CORREÇÃO APLICADA =================
  // =======================================================================
  Future<void> _abrirFormularioParaEditar(Arvore arvore) async {
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
      // Encontra o item a ser substituído usando o ID da árvore original.
      // Isso é crucial para que o _salvarEstadoAtual tenha a lista correta.
      final index = _arvoresColetadas.indexWhere((a) => a.id == arvore.id);

      if (index != -1) {
        // 1. Atualiza o item na lista local APENAS para preparar para o salvamento.
        _arvoresColetadas[index] = result.arvore;

        // 2. Salva a lista inteira e atualizada no banco.
        // O método saveFullColeta vai apagar os registros antigos e inserir a lista atualizada.
        await _salvarEstadoAtual();

        // 3. === A CORREÇÃO PRINCIPAL (FONTE DA VERDADE) ===
        // Em vez de manipular a lista localmente (sort, setState, etc.),
        // o que causava o bug da "lambança", nós recarregamos TUDO do banco.
        // Isso garante que a ordem e os dados estejam 100% corretos e
        // sincronizados com o que foi salvo.
        await _carregarDadosIniciais();
      }
    }
  }

  Future<void> _salvarEstadoAtual(
      {bool showSnackbar = true, bool concluir = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      if (concluir) {
        widget.parcela.status = StatusParcela.concluida;
        _identificarArvoresDominantes();
      }

      // Garante que a lista esteja ordenada ANTES de salvar, para consistência.
      _arvoresColetadas.sort((a, b) {
        int compLinha = a.linha.compareTo(b.linha);
        if (compLinha != 0) return compLinha;
        return a.posicaoNaLinha.compareTo(b.posicaoNaLinha);
      });

      await DatabaseHelper().saveFullColeta(widget.parcela, _arvoresColetadas);
      
      if (mounted && showSnackbar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Progresso salvo!'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _concluirColeta() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Concluir Coleta'),
            content: const Text(
                'Tem certeza que deseja marcar esta parcela como concluída?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Concluir'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      await _salvarEstadoAtual(concluir: true, showSnackbar: false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parcela concluída com sucesso!'),
            backgroundColor: Colors.blue,
          ),
        );
        Navigator.of(context).pop(true); // Retorna true para a tela anterior
      }
    }
  }

  void _identificarArvoresDominantes() {
    for (var arvore in _arvoresColetadas) {
      arvore.dominante = false;
    }
    final int numeroDeDominantes =
        (widget.parcela.areaMetrosQuadrados / 100).floor();
    final arvoresCandidatas = _arvoresColetadas
        .where((a) =>
            a.status != StatusArvore.falha && a.status != StatusArvore.morta)
        .toList();

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

  String _getArvoreSubtitle(Arvore arvore) {
    String statusPrincipal =
        arvore.status.name[0].toUpperCase() + arvore.status.name.substring(1);
    String statusSecundario = arvore.status2 != null
        ? ' / ${arvore.status2!.name[0].toUpperCase() + arvore.status2!.name.substring(1)}'
        : '';
    String altura = arvore.altura != null
        ? ' | Altura: ${arvore.altura!.toStringAsFixed(1)}m'
        : '';
    return '$statusPrincipal$statusSecundario$altura';
  }

  @override
  Widget build(BuildContext context) {
    final listaExibida = _mostrandoApenasDominantes
        ? _arvoresColetadas.where((a) => a.dominante).toList()
        : _arvoresColetadas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coleta da Parcela'),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Salvar Progresso',
              onPressed: () => _salvarEstadoAtual(),
            ),
            IconButton(
              icon: const Icon(Icons.check_circle_outline),
              tooltip: 'Concluir e Salvar Parcela',
              onPressed: _concluirColeta,
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    elevation: 2,
                    child: ListTile(
                      leading: Icon(Icons.info_outline,
                          color: Theme.of(context).primaryColor),
                      title: Text(
                        'Talhão: ${widget.parcela.nomeTalhao} / Parcela: ${widget.parcela.idParcela}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle:
                          Text('Árvores Coletadas: ${_arvoresColetadas.length}'),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => setState(() {
                        if (!_mostrandoApenasDominantes) {
                          _identificarArvoresDominantes();
                        }
                        _mostrandoApenasDominantes =
                            !_mostrandoApenasDominantes;
                      }),
                      icon: Icon(
                        _mostrandoApenasDominantes
                            ? Icons.filter_list_off
                            : Icons.filter_list,
                      ),
                      label: Text(
                        _mostrandoApenasDominantes
                            ? 'Mostrar Todas'
                            : 'Encontrar Dominantes',
                      ),
                    ),
                  ),
                ),
                const Divider(height: 16),
                Expanded(
                  child: _arvoresColetadas.isEmpty
                      ? const Center(
                          child: Text(
                            'Clique no botão "+" para adicionar a primeira árvore.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: listaExibida.length,
                          itemBuilder: (context, index) {
                            final arvore = listaExibida[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              color: arvore.dominante
                                  ? Colors.green.withAlpha(51)
                                  : null,
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: arvore.dominante
                                      ? Colors.amber[700]
                                      : Theme.of(context).primaryColor,
                                  child: arvore.dominante
                                      ? const Icon(Icons.star,
                                          color: Colors.white, size: 20)
                                      : Text(
                                          '${arvore.posicaoNaLinha}',
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                ),
                                title: Text(
                                    'L: ${arvore.linha} | CAP: ${arvore.cap.toStringAsFixed(1)} cm'),
                                subtitle: Text(_getArvoreSubtitle(arvore)),
                                trailing: const Icon(Icons.edit_outlined,
                                    color: Colors.grey),
                                onTap: () => _abrirFormularioParaEditar(arvore),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _abrirFormularioParaAdicionar,
        tooltip: 'Adicionar Árvore',
        child: const Icon(Icons.add),
      ),
    );
  }
}