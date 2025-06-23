// lib/widgets/arvore_dialog.dart (VERSÃO COM LINHA E POSIÇÃO EDITÁVEIS SEMPRE)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';

// A classe de resultado agora informa qual ação foi tomada
class DialogResult {
  final Arvore arvore;
  final bool continuarNaMesmaPosicao; // Para fustes múltiplos
  final bool irParaProxima; // <<-- NOVA FLAG

  DialogResult({
    required this.arvore,
    this.continuarNaMesmaPosicao = false,
    this.irParaProxima = false, // <<-- VALOR PADRÃO
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

  @override
  State<ArvoreDialog> createState() => _ArvoreDialogState();
}

class _ArvoreDialogState extends State<ArvoreDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _linhaController;
  late TextEditingController _posicaoController;
  final _capController = TextEditingController();
  final _alturaController = TextEditingController();
  
  late StatusArvore _status;
  StatusArvore? _status2;
  late bool _isDominante;
  late bool _isFimDeLinha;

  bool get isEditing => widget.arvoreParaEditar != null;
  
  @override
  void initState() {
    super.initState();
    final arvore = widget.arvoreParaEditar;

    _linhaController = TextEditingController(text: (arvore?.linha ?? widget.linhaAtual).toString());
    _posicaoController = TextEditingController(text: (arvore?.posicaoNaLinha ?? widget.posicaoNaLinhaAtual).toString());
    _capController.text = arvore?.cap.toStringAsFixed(1) ?? '';
    _alturaController.text = arvore?.altura?.toStringAsFixed(1) ?? '';

    if (widget.isAdicionandoFuste) {
      _status = StatusArvore.multipla;
    } else {
      _status = arvore?.status ?? StatusArvore.normal;
    }

    _status2 = arvore?.status2;
    _isDominante = arvore?.dominante ?? false;
    _isFimDeLinha = arvore?.fimDeLinha ?? false;
  }

  @override
  void dispose() {
    _capController.dispose();
    _alturaController.dispose();
    _linhaController.dispose();
    _posicaoController.dispose();
    super.dispose();
  }

  String getStatusDisplayName(StatusArvore status) {
    return status.name[0].toUpperCase() + status.name.substring(1);
  }

  // Função _salvar agora aceita um parâmetro para 'irParaProxima'
  void _salvar({required bool continuarFuste, required bool irParaProxima}) {
    if (_formKey.currentState!.validate()) {
      final arvore = Arvore(
        id: widget.arvoreParaEditar?.id ?? 0,
        linha: int.tryParse(_linhaController.text) ?? widget.linhaAtual,
        posicaoNaLinha: int.tryParse(_posicaoController.text) ?? widget.posicaoNaLinhaAtual,
        cap: double.tryParse(_capController.text.replaceAll(',', '.')) ?? 0,
        altura: _alturaController.text.isNotEmpty ? double.tryParse(_alturaController.text.replaceAll(',', '.')) : null,
        status: _status,
        status2: _status2,
        dominante: _isDominante,
        fimDeLinha: !continuarFuste ? _isFimDeLinha : false, // Fim de linha só é relevante se não for adicionar fuste
      );
      
      // Retorna o resultado com a nova flag
      Navigator.of(context).pop(DialogResult(
        arvore: arvore,
        continuarNaMesmaPosicao: continuarFuste,
        irParaProxima: irParaProxima,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool podeAdicionarFuste = _status == StatusArvore.multipla || _status2 == StatusArvore.multipla;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Árvore' : 'Adicionar Árvore'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Campos de Linha e Posição editáveis
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _linhaController, enabled: true, decoration: const InputDecoration(labelText: 'Linha', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                  const SizedBox(width: 16),
                  Expanded(child: TextFormField(controller: _posicaoController, enabled: true, decoration: const InputDecoration(labelText: 'Posição', border: OutlineInputBorder()), keyboardType: TextInputType.number, validator: (v) => v!.isEmpty ? 'Obrigatório' : null)),
                ],
              ),
              const SizedBox(height: 16),
              
              // Restante do formulário
              DropdownButtonFormField<StatusArvore>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status Principal', border: OutlineInputBorder()),
                items: StatusArvore.values.map((s) => DropdownMenuItem(value: s, child: Text(getStatusDisplayName(s)))).toList(),
                onChanged: (val) { if (val != null) setState(() { _status = val; if (_status2 == _status) _status2 = null; }); },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<StatusArvore?>(
                value: _status2,
                decoration: const InputDecoration(labelText: 'Status Secundário (Opcional)', border: const OutlineInputBorder()),
                items: [
                  const DropdownMenuItem(value: null, child: Text('-- Nenhum --')),
                  ...StatusArvore.values.where((s) => s != _status).map((s) => DropdownMenuItem(value: s, child: Text(getStatusDisplayName(s)))),
                ],
                onChanged: (val) => setState(() => _status2 = val),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capController,
                enabled: _status != StatusArvore.falha,
                decoration: InputDecoration(labelText: 'CAP (cm)', border: const OutlineInputBorder(), filled: _status == StatusArvore.falha, fillColor: Colors.grey[200]),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) => (_status != StatusArvore.falha) && (v == null || v.isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _alturaController,
                enabled: _status != StatusArvore.falha,
                decoration: InputDecoration(labelText: 'Altura (m)', border: const OutlineInputBorder(), filled: _status == StatusArvore.falha, fillColor: Colors.grey[200]),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),

              // =============================================================
              // =========== CHECKBOXES RESTAURADOS E FUNCIONAIS =============
              // =============================================================
              CheckboxListTile(
                title: const Text('Árvore Dominante'),
                value: _isDominante,
                onChanged: (val) => setState(() => _isDominante = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
              CheckboxListTile(
                title: const Text('Fim da linha'),
                subtitle: const Text('(Marque no último fuste desta posição)'),
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
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        
        // =============================================================
        // ============== BOTÕES DE AÇÃO ATUALIZADOS ===================
        // =============================================================
        
        // Botão "Salvar" (que apenas fecha o diálogo)
        OutlinedButton(
          onPressed: () => _salvar(continuarFuste: false, irParaProxima: false),
          child: Text(isEditing ? 'Atualizar' : 'Salvar'),
        ),

        // Botão "Salvar e Próxima" (o botão principal)
        // Só aparece se não estiver editando e não for adicionar fuste
        if (!isEditing && !podeAdicionarFuste)
          ElevatedButton(
            onPressed: () => _salvar(continuarFuste: false, irParaProxima: true),
            child: const Text('Salvar e Próxima'),
          ),

        // O botão de fuste
        if (!isEditing && podeAdicionarFuste)
          ElevatedButton(
            onPressed: () => _salvar(continuarFuste: true, irParaProxima: false), // Fuste não avança para a próxima posição
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]),
            child: const Text('Adic. Fuste'),
          ),
      ],
    );
  }
}
