// lib/widgets/arvore_dialog.dart (COM LINHA E POSIÇÃO EDITÁVEIS)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';

class DialogResult {
  final Arvore arvore;
  final bool irParaProxima;
  final bool continuarNaMesmaPosicao;
  final bool atualizarEProximo;
  final bool atualizarEAnterior;

  DialogResult({
    required this.arvore,
    this.irParaProxima = false,
    this.continuarNaMesmaPosicao = false,
    this.atualizarEProximo = false,
    this.atualizarEAnterior = false,
  });
}

class ArvoreDialog extends StatefulWidget {
  final Arvore? arvoreParaEditar;
  final int linhaAtual;
  final int posicaoNaLinhaAtual;
  final bool isAdicionandoFuste;

  const ArvoreDialog({
    super.key,
    this.arvoreParaEditar,
    required this.linhaAtual,
    required this.posicaoNaLinhaAtual,
    this.isAdicionandoFuste = false,
  });

  bool get isEditing => arvoreParaEditar != null;

  @override
  State<ArvoreDialog> createState() => _ArvoreDialogState();
}

class _ArvoreDialogState extends State<ArvoreDialog> {
  final _formKey = GlobalKey<FormState>();
  final _capController = TextEditingController();
  final _alturaController = TextEditingController();
  // 1. ADICIONE CONTROLLERS PARA LINHA E POSIÇÃO
  final _linhaController = TextEditingController();
  final _posicaoController = TextEditingController();

  late StatusArvore _status;
  StatusArvore2? _status2;
  bool _fimDeLinha = false;
  bool _camposHabilitados = true;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      final arvore = widget.arvoreParaEditar!;
      _capController.text = arvore.cap.toString().replaceAll('.', ',');
      _alturaController.text = arvore.altura?.toString().replaceAll('.', ',') ?? '';
      _status = arvore.status;
      _status2 = arvore.status2;
      _fimDeLinha = arvore.fimDeLinha;
      // 2. PREENCHA OS NOVOS CONTROLLERS COM OS DADOS DA ÁRVORE SENDO EDITADA
      _linhaController.text = arvore.linha.toString();
      _posicaoController.text = arvore.posicaoNaLinha.toString();
      
    } else {
      _status = StatusArvore.normal;
      // No modo de adição, preenchemos com os valores automáticos
      _linhaController.text = widget.linhaAtual.toString();
      _posicaoController.text = widget.posicaoNaLinhaAtual.toString();
    }
    _atualizarEstadoCampos();
  }

  void _atualizarEstadoCampos() {
    setState(() {
      if (_status == StatusArvore.falha || _status == StatusArvore.caida) {
        _camposHabilitados = false;
        _capController.text = '0';
        _alturaController.clear();
      } else {
        _camposHabilitados = true;
        if (_capController.text == '0') {
          _capController.clear();
        }
      }
    });
  }

  @override
  void dispose() {
    _capController.dispose();
    _alturaController.dispose();
    // 3. FAÇA O DISPOSE DOS NOVOS CONTROLLERS
    _linhaController.dispose();
    _posicaoController.dispose();
    super.dispose();
  }

  void _submit({bool proxima = false, bool mesmoFuste = false, bool atualizarEProximo = false, bool atualizarEAnterior = false}) {
    if (_formKey.currentState!.validate()) {
      final double cap = double.tryParse(_capController.text.replaceAll(',', '.')) ?? 0.0;
      final double? altura = _alturaController.text.isNotEmpty ? double.tryParse(_alturaController.text.replaceAll(',', '.')) : null;
      // 4. PEGUE OS VALORES DOS NOVOS CONTROLLERS
      final int linha = int.tryParse(_linhaController.text) ?? widget.linhaAtual;
      final int posicao = int.tryParse(_posicaoController.text) ?? widget.posicaoNaLinhaAtual;

      final arvore = Arvore(
        id: widget.arvoreParaEditar?.id,
        cap: cap,
        altura: altura,
        // 5. USE OS NOVOS VALORES DE LINHA E POSIÇÃO AO CRIAR O OBJETO
        linha: linha,
        posicaoNaLinha: posicao,
        status: _status,
        status2: _status2,
        fimDeLinha: _fimDeLinha,
        dominante: widget.arvoreParaEditar?.dominante ?? false,
      );

      Navigator.of(context).pop(DialogResult(
        arvore: arvore,
        irParaProxima: proxima,
        continuarNaMesmaPosicao: mesmoFuste,
        atualizarEProximo: atualizarEProximo,
        atualizarEAnterior: atualizarEAnterior,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    bool hasStatus2 = widget.arvoreParaEditar?.status2 != null || _status2 != null;

    return AlertDialog(
      title: Text(widget.isEditing
          ? 'Editar Árvore' // Título simplificado para edição
          : widget.isAdicionandoFuste
              ? 'Adicionar Fuste L${widget.linhaAtual}/P${widget.posicaoNaLinhaAtual}'
              : 'Adicionar Árvore L${widget.linhaAtual}/P${widget.posicaoNaLinhaAtual}'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // =======================================================
              // 6. ADICIONE OS CAMPOS DE TEXTO PARA LINHA E POSIÇÃO
              //    ELES SERÃO HABILITADOS APENAS NO MODO DE EDIÇÃO
              // =======================================================
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _linhaController,
                        enabled: widget.isEditing, // HABILITADO APENAS PARA EDIÇÃO
                        decoration: const InputDecoration(labelText: 'Linha'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? 'Inválido' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _posicaoController,
                        enabled: widget.isEditing, // HABILITADO APENAS PARA EDIÇÃO
                        decoration: const InputDecoration(labelText: 'Posição'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.isEmpty || int.tryParse(v) == null) ? 'Inválido' : null,
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButtonFormField<StatusArvore>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status Principal'),
                items: StatusArvore.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _status = value);
                    _atualizarEstadoCampos();
                  }
                },
              ),
              if (hasStatus2) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<StatusArvore2?>(
                  value: _status2,
                  decoration: const InputDecoration(labelText: 'Status Secundário (Opcional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Nenhum')),
                    ...StatusArvore2.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name))),
                  ],
                  onChanged: (value) => setState(() => _status2 = value),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _capController,
                enabled: _camposHabilitados,
                decoration: const InputDecoration(labelText: 'CAP (cm)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (_camposHabilitados && (value == null || value.isEmpty)) {
                    return 'Campo obrigatório';
                  }
                  if (value != null && value.isNotEmpty && double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Número inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alturaController,
                enabled: _camposHabilitados,
                decoration: const InputDecoration(labelText: 'Altura (m) - Opcional'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              if (!widget.isEditing)
                SwitchListTile(
                  title: const Text('Fim da linha de plantio?'),
                  value: _fimDeLinha,
                  onChanged: (value) => setState(() => _fimDeLinha = value),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8.0,
          children: widget.isEditing
              ? [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  TextButton(onPressed: () => _submit(atualizarEAnterior: true), child: const Text('Atualizar Ant.')),
                  ElevatedButton(onPressed: () => _submit(), child: const Text('Atualizar')),
                  ElevatedButton(
                    onPressed: () => _submit(atualizarEProximo: true),
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                    child: const Text('Atualizar Próx.'),
                  ),
                ]
              : [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
                  ElevatedButton(onPressed: () => _submit(mesmoFuste: true), child: const Text('Adic. Fuste')),
                  ElevatedButton(
                    onPressed: () => _submit(proxima: true),
                    style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
                    child: const Text('Salvar e Próximo'),
                  ),
                ],
        )
      ],
    );
  }
}