// lib/widgets/cubagem_secao_dialog.dart (VERSÃO CORRIGIDA)

import 'package:flutter/material.dart';
import '../models/cubagem_secao_model.dart';

class CubagemSecaoDialog extends StatefulWidget {
  final CubagemSecao secaoParaEditar;

  const CubagemSecaoDialog({
    super.key,
    required this.secaoParaEditar,
  });

  @override
  State<CubagemSecaoDialog> createState() => _CubagemSecaoDialogState();
}

class _CubagemSecaoDialogState extends State<CubagemSecaoDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _circunferenciaController;
  late TextEditingController _casca1Controller;
  late TextEditingController _casca2Controller;

  @override
  void initState() {
    super.initState();
    // ##### CORREÇÃO DOS AVISOS #####
    // Acessa diretamente widget.secaoParaEditar, pois é garantido que não é nulo.
    _circunferenciaController = TextEditingController(text: widget.secaoParaEditar.circunferencia > 0 ? widget.secaoParaEditar.circunferencia.toString() : '');
    _casca1Controller = TextEditingController(text: widget.secaoParaEditar.casca1_mm > 0 ? widget.secaoParaEditar.casca1_mm.toString() : '');
    _casca2Controller = TextEditingController(text: widget.secaoParaEditar.casca2_mm > 0 ? widget.secaoParaEditar.casca2_mm.toString() : '');
  }

  @override
  void dispose() {
    _circunferenciaController.dispose();
    _casca1Controller.dispose();
    _casca2Controller.dispose();
    super.dispose();
  }

  void _salvar() {
    if (_formKey.currentState!.validate()) {
      final secaoAtualizada = CubagemSecao(
        id: widget.secaoParaEditar.id,
        cubagemArvoreId: widget.secaoParaEditar.cubagemArvoreId,
        alturaMedicao: widget.secaoParaEditar.alturaMedicao,
        circunferencia: double.tryParse(_circunferenciaController.text.replaceAll(',', '.')) ?? 0,
        casca1_mm: double.tryParse(_casca1Controller.text.replaceAll(',', '.')) ?? 0,
        casca2_mm: double.tryParse(_casca2Controller.text.replaceAll(',', '.')) ?? 0,
      );
      Navigator.of(context).pop(secaoAtualizada);
    }
  }
  
  // Função para validar campos de forma segura
  String? _validadorObrigatorio(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Obrigatório';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Medição em ${widget.secaoParaEditar.alturaMedicao.toStringAsFixed(2)}m'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ##### CORREÇÃO DOS AVISOS #####
              TextFormField(
                controller: _circunferenciaController,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Circunferência (cm)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validadorObrigatorio,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _casca1Controller,
                decoration: const InputDecoration(labelText: 'Espessura Casca 1 (mm)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validadorObrigatorio,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _casca2Controller,
                decoration: const InputDecoration(labelText: 'Espessura Casca 2 (mm)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: _validadorObrigatorio,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _salvar, child: const Text('Confirmar')),
      ],
    );
  }
}