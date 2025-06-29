// lib/pages/amostra/form_parcela_page.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';
import 'package:geoforestcoletor/pages/amostra/inventario_page.dart';

enum FormaParcela { retangular, circular }

class FormParcelaPage extends StatefulWidget {
  final Talhao talhao;

  const FormParcelaPage({super.key, required this.talhao});

  @override
  State<FormParcelaPage> createState() => _FormParcelaPageState();
}

class _FormParcelaPageState extends State<FormParcelaPage> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper.instance;

  final _idParcelaController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _larguraController = TextEditingController();
  final _comprimentoController = TextEditingController();
  final _raioController = TextEditingController();

  bool _isSaving = false;
  FormaParcela _formaDaParcela = FormaParcela.retangular;
  double _areaCalculada = 0.0;

  @override
  void initState() {
    super.initState();
    _larguraController.addListener(_calcularArea);
    _comprimentoController.addListener(_calcularArea);
    _raioController.addListener(_calcularArea);
  }

  @override
  void dispose() {
    _idParcelaController.dispose();
    _observacaoController.dispose();
    _larguraController.dispose();
    _comprimentoController.dispose();
    _raioController.dispose();
    super.dispose();
  }

  void _calcularArea() {
    double area = 0.0;
    if (_formaDaParcela == FormaParcela.retangular) {
      final largura = double.tryParse(_larguraController.text.replaceAll(',', '.')) ?? 0;
      final comprimento = double.tryParse(_comprimentoController.text.replaceAll(',', '.')) ?? 0;
      area = largura * comprimento;
    } else {
      final raio = double.tryParse(_raioController.text.replaceAll(',', '.')) ?? 0;
      area = math.pi * raio * raio;
    }
    setState(() => _areaCalculada = area);
  }

  Future<void> _salvarEIniciarColeta() async {
    if (!_formKey.currentState!.validate()) return;
    if (_areaCalculada <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A área da parcela deve ser maior que zero.'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _isSaving = true);

    final novaParcela = Parcela(
      talhaoId: widget.talhao.id,
      idParcela: _idParcelaController.text.trim(),
      areaMetrosQuadrados: _areaCalculada,
      observacao: _observacaoController.text.trim(),
      dataColeta: DateTime.now(),
      status: StatusParcela.emAndamento,
      largura: _formaDaParcela == FormaParcela.retangular ? double.tryParse(_larguraController.text.replaceAll(',', '.')) : null,
      comprimento: _formaDaParcela == FormaParcela.retangular ? double.tryParse(_comprimentoController.text.replaceAll(',', '.')) : null,
      raio: _formaDaParcela == FormaParcela.circular ? double.tryParse(_raioController.text.replaceAll(',', '.')) : null,
      // Passando dados do talhão para a parcela
      nomeFazenda: widget.talhao.fazendaId,
      nomeTalhao: widget.talhao.nome,
    );

    try {
      // Salva a parcela e obtém o objeto salvo com o dbId
      final parcelaSalva = await dbHelper.saveFullColeta(novaParcela, []);

      if (mounted) {
        // Navega para a tela de inventário, substituindo o formulário
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => InventarioPage(parcela: parcelaSalva)),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova Parcela'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _idParcelaController,
                decoration: const InputDecoration(labelText: 'ID da Parcela', border: OutlineInputBorder(), prefixIcon: Icon(Icons.tag)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              _buildCalculadoraArea(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacaoController,
                decoration: const InputDecoration(labelText: 'Observações (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.comment)),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _salvarEIniciarColeta,
                icon: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.arrow_forward),
                label: const Text('Salvar e Iniciar Inventário'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculadoraArea() {
    // A mesma UI de cálculo de área da ColetaDadosPage
    return Column( /* ... */ );
  }
}