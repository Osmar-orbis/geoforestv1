// lib/widgets/arvore_dialog.dart (VERSÃO FINAL COMPLETA)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';

class DialogResult {
  final Arvore arvore;
  final bool continuarNaMesmaPosicao;
  DialogResult({required this.arvore, required this.continuarNaMesmaPosicao});
}

class ArvoreDialog extends StatefulWidget {
  final Arvore? arvoreParaEditar;
  final int linhaAtual;
  final int posicaoNaLinhaAtual;

  const ArvoreDialog({
    super.key,
    this.arvoreParaEditar,
    required this.linhaAtual,
    required this.posicaoNaLinhaAtual,
  });

  @override
  State<ArvoreDialog> createState() => _ArvoreDialogState();
}

class _ArvoreDialogState extends State<ArvoreDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _linhaController;
  late TextEditingController _posicaoController;
  late TextEditingController _capController;
  late TextEditingController _alturaController;

  late StatusArvore _status;
  StatusArvore? _status2;
  late bool _isDominante;
  late bool _isFimDeLinha;

  bool get isEditing => widget.arvoreParaEditar != null;

  @override
  void initState() {
    super.initState();
    final arvore = widget.arvoreParaEditar;

    _linhaController = TextEditingController(
      text: (arvore?.linha ?? widget.linhaAtual).toString(),
    );
    _posicaoController = TextEditingController(
      text: (arvore?.posicaoNaLinha ?? widget.posicaoNaLinhaAtual).toString(),
    );
    _capController = TextEditingController(
      text: arvore?.cap.toStringAsFixed(1) ?? '',
    );
    _alturaController = TextEditingController(
      text: arvore?.altura?.toStringAsFixed(1) ?? '',
    );

    _status = arvore?.status ?? StatusArvore.normal;
    _status2 = arvore?.status2;
    _isDominante = arvore?.dominante ?? false;
    _isFimDeLinha = arvore?.fimDeLinha ?? false;
  }

  @override
  void dispose() {
    _linhaController.dispose();
    _posicaoController.dispose();
    _capController.dispose();
    _alturaController.dispose();
    super.dispose();
  }

  String getStatusDisplayName(StatusArvore? status) {
    if (status == null) return '-- Nenhum --';
    final name = status.name;
    return name[0].toUpperCase() +
        name
            .substring(1)
            .replaceAllMapped(RegExp(r'[A-Z]'), (m) => ' ${m.group(0)}')
            .trimLeft();
  }

  void _salvar({required bool continuar}) {
    if (_formKey.currentState!.validate()) {
      final arvore = Arvore(
        id: widget.arvoreParaEditar?.id ?? 0,
        linha: int.parse(_linhaController.text),
        posicaoNaLinha: int.parse(_posicaoController.text),
        cap: double.tryParse(_capController.text) ?? 0.0,
        altura: _alturaController.text.isNotEmpty
            ? double.tryParse(_alturaController.text)
            : null,
        status: _status,
        status2: _status2,
        dominante: _isDominante,
        fimDeLinha: !continuar ? _isFimDeLinha : false,
      );

      Navigator.of(context)
          .pop(DialogResult(arvore: arvore, continuarNaMesmaPosicao: continuar));
    }
  }

  @override
  Widget build(BuildContext context) {
    final podeSerMultipla = _status == StatusArvore.multipla ||
        _status == StatusArvore.bifurcada ||
        _status2 == StatusArvore.multipla ||
        _status2 == StatusArvore.bifurcada;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Árvore' : 'Adicionar Árvore'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _linhaController,
                        decoration: const InputDecoration(
                          labelText: 'Linha',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _posicaoController,
                        decoration: const InputDecoration(
                          labelText: 'Posição',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text(
                  'L: ${widget.linhaAtual}, P: ${widget.posicaoNaLinhaAtual}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.grey[800]),
                  textAlign: TextAlign.center,
                ),
                const Divider(),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<StatusArvore>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Status Principal',
                  border: OutlineInputBorder(),
                ),
                items: StatusArvore.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(getStatusDisplayName(s)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _status = val;
                      if (_status2 == _status) _status2 = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<StatusArvore?>(
                value: _status2,
                decoration: const InputDecoration(
                  labelText: 'Status Secundário (Opcional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('-- Nenhum --'),
                  ),
                  ...StatusArvore.values
                      .where((s) => s != _status)
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child: Text(getStatusDisplayName(s)),
                          )),
                ],
                onChanged: (val) => setState(() => _status2 = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capController,
                enabled: _status != StatusArvore.falha,
                decoration: InputDecoration(
                  labelText: 'CAP (cm)',
                  border: const OutlineInputBorder(),
                  filled: _status == StatusArvore.falha,
                  fillColor: Colors.grey[200],
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) =>
                    (_status != StatusArvore.falha) && (v == null || v.isEmpty)
                        ? 'Campo obrigatório'
                        : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alturaController,
                enabled: _status != StatusArvore.falha,
                decoration: InputDecoration(
                  labelText: 'Altura (m)',
                  border: const OutlineInputBorder(),
                  filled: _status == StatusArvore.falha,
                  fillColor: Colors.grey[200],
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: const Text('Árvore Dominante'),
                value: _isDominante,
                onChanged: (val) => setState(() => _isDominante = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              if (!isEditing)
                CheckboxListTile(
                  title: const Text('Fim da linha'),
                  subtitle: const Text('(Marque no último fuste da linha)'),
                  value: _isFimDeLinha,
                  onChanged: (val) => setState(() => _isFimDeLinha = val ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.end,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (!isEditing && podeSerMultipla)
          ElevatedButton(
            onPressed: () => _salvar(continuar: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[800],
            ),
            child: const Text('Salvar e Adicionar Fuste'),
          ),
        ElevatedButton(
          onPressed: () => _salvar(continuar: false),
          child: Text(isEditing ? 'Atualizar' : 'Salvar e Próxima'),
        ),
      ],
    );
  }
}
