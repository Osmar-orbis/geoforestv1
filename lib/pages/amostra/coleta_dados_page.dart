// lib/pages/amostra/coleta_dados_page.dart

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/pages/amostra/inventario_page.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';

enum FormaParcela { retangular, circular }

class ColetaDadosPage extends StatefulWidget {
  final Parcela parcelaParaEditar;
  const ColetaDadosPage({super.key, required this.parcelaParaEditar});

  @override
  State<ColetaDadosPage> createState() => _ColetaDadosPageState();
}

class _ColetaDadosPageState extends State<ColetaDadosPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeFazendaController = TextEditingController();
  final _idFazendaController = TextEditingController();
  final _talhaoParcelaController = TextEditingController();
  final _idParcelaController = TextEditingController();
  final _espacamentoController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _larguraController = TextEditingController();
  final _comprimentoController = TextEditingController();
  final _raioController = TextEditingController();

  Position? _posicaoAtual;
  bool _buscandoLocalizacao = false;
  String? _erroLocalizacao;
  bool _salvando = false;
  FormaParcela _formaDaParcela = FormaParcela.retangular;
  double _areaCalculada = 0.0;

  @override
  void initState() {
    super.initState();
    _preencherDadosIniciais();
    _larguraController.addListener(_calcularArea);
    _comprimentoController.addListener(_calcularArea);
    _raioController.addListener(_calcularArea);
  }
  
  void _preencherDadosIniciais() {
    final p = widget.parcelaParaEditar;
    _nomeFazendaController.text = p.nomeFazenda;
    _idFazendaController.text = p.idFazenda ?? '';
    _talhaoParcelaController.text = p.nomeTalhao;
    _idParcelaController.text = p.idParcela;
    _espacamentoController.text = p.espacamento ?? '';
    _observacaoController.text = p.observacao ?? '';
    _areaCalculada = p.areaMetrosQuadrados;

    if (p.largura != null) _larguraController.text = p.largura.toString().replaceAll('.', ',');
    if (p.comprimento != null) _comprimentoController.text = p.comprimento.toString().replaceAll('.', ',');
    if (p.raio != null) {
      _raioController.text = p.raio.toString().replaceAll('.', ',');
      setState(() => _formaDaParcela = FormaParcela.circular);
    }
    
    if (p.latitude != null && p.longitude != null) {
      _posicaoAtual = Position(latitude: p.latitude!, longitude: p.longitude!, timestamp: DateTime.now(), accuracy: 0.0, altitude: 0.0, altitudeAccuracy: 0.0, heading: 0.0, headingAccuracy: 0.0, speed: 0.0, speedAccuracy: 0.0);
    }
  }

  @override
  void dispose() {
    _nomeFazendaController.dispose();
    _idFazendaController.dispose();
    _talhaoParcelaController.dispose();
    _idParcelaController.dispose();
    _espacamentoController.dispose();
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

  Parcela _construirObjetoParcela() {
    return widget.parcelaParaEditar.copyWith(
      nomeFazenda: _nomeFazendaController.text.trim(),
      idFazenda: _idFazendaController.text.trim().isNotEmpty ? _idFazendaController.text.trim() : null,
      nomeTalhao: _talhaoParcelaController.text.trim(),
      idParcela: _idParcelaController.text.trim(),
      areaMetrosQuadrados: _areaCalculada,
      espacamento: _espacamentoController.text.trim().isNotEmpty ? _espacamentoController.text.trim() : null,
      observacao: _observacaoController.text.trim().isNotEmpty ? _observacaoController.text.trim() : null,
      latitude: _posicaoAtual?.latitude,
      longitude: _posicaoAtual?.longitude,
      dataColeta: DateTime.now(),
      largura: double.tryParse(_larguraController.text.replaceAll(',', '.')),
      comprimento: double.tryParse(_comprimentoController.text.replaceAll(',', '.')),
      raio: double.tryParse(_raioController.text.replaceAll(',', '.')),
    );
  }

  Future<void> _salvarEIniciarColeta() async {
    if (!_formKey.currentState!.validate()) return;
    if (_areaCalculada <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A área da parcela deve ser maior que zero'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _salvando = true);
    
    try {
      final dbHelper = DatabaseHelper();
      final parcelaAtualizada = _construirObjetoParcela().copyWith(status: StatusParcela.emAndamento);
      final parcelaSalva = await dbHelper.saveFullColeta(parcelaAtualizada, []);
      
      if (mounted) {
        final inventarioConcluido = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => InventarioPage(parcela: parcelaSalva)),
        );
        if (inventarioConcluido == true) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _finalizarParcelaVazia() async {
    if (!_formKey.currentState!.validate()) return;
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Parcela?'),
        content: const Text('Você vai marcar a parcela como concluída sem árvores. Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
        ],
      ),
    );

    if (confirmar != true) return;
    setState(() => _salvando = true);
    
    try {
      final dbHelper = DatabaseHelper();
      final parcelaFinalizada = _construirObjetoParcela().copyWith(status: StatusParcela.concluida);
      await dbHelper.saveFullColeta(parcelaFinalizada, []);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parcela finalizada com sucesso!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao finalizar: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final dbHelper = DatabaseHelper();
      final parcelaEditada = _construirObjetoParcela();
      await dbHelper.updateParcela(parcelaEditada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alterações salvas com sucesso!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _navegarParaInventario() async {
    await _salvarAlteracoes();
    if (!mounted) return;

    final foiAtualizado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => InventarioPage(parcela: widget.parcelaParaEditar),
      ),
    );
    if (foiAtualizado == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _obterLocalizacaoAtual() async {
    setState(() { _buscandoLocalizacao = true; _erroLocalizacao = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw 'Serviço de GPS desabilitado.';
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) throw 'Permissão negada.';
      }
      if (permission == LocationPermission.deniedForever) throw 'Permissão negada permanentemente.';

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 20));
      setState(() => _posicaoAtual = position);
    } catch (e) {
      setState(() => _erroLocalizacao = e.toString());
    } finally {
      if(mounted) setState(() => _buscandoLocalizacao = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNovaColeta = widget.parcelaParaEditar.status == StatusParcela.pendente;

    return Scaffold(
      appBar: AppBar(
        title: Text(isNovaColeta ? 'Nova Coleta de Parcela' : 'Editar Dados da Parcela'),
        backgroundColor: const Color(0xFF617359),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _nomeFazendaController, decoration: const InputDecoration(labelText: 'Nome da Fazenda', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)), validator: (v) => v == null || v.trim().length < 2 ? 'Campo obrigatório' : null),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idFazendaController,
                decoration: const InputDecoration(labelText: 'Código da Fazenda (Opcional)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.pin_outlined)),
              ),
              const SizedBox(height: 16),
              TextFormField(controller: _talhaoParcelaController, decoration: const InputDecoration(labelText: 'Talhão', border: OutlineInputBorder(), prefixIcon: Icon(Icons.grid_on)), validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null),
              const SizedBox(height: 16),
              TextFormField(controller: _idParcelaController, decoration: const InputDecoration(labelText: 'ID da parcela', border: OutlineInputBorder(), prefixIcon: Icon(Icons.tag)), validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null),
              const SizedBox(height: 16),
              _buildCalculadoraArea(),
              const SizedBox(height: 16),
              _buildColetorCoordenadas(),
              const SizedBox(height: 16),
              TextFormField(controller: _espacamentoController, decoration: const InputDecoration(labelText: 'Espaçamento', border: OutlineInputBorder(), prefixIcon: Icon(Icons.space_bar), helperText: 'Opcional')),
              const SizedBox(height: 16),
              TextFormField(controller: _observacaoController, decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder(), prefixIcon: Icon(Icons.comment), helperText: 'Opcional'), maxLines: 3),
              const SizedBox(height: 24),
              _buildActionButtons(isNovaColeta),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isNovaColeta) {
    if (isNovaColeta) {
      return Row(
        children: [
          Expanded(child: SizedBox(height: 50, child: OutlinedButton(onPressed: _salvando ? null : _finalizarParcelaVazia, style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF1D4433)), foregroundColor: const Color(0xFF1D4433)), child: const Text('Finalizar Vazia')))),
          const SizedBox(width: 16),
          Expanded(child: SizedBox(height: 50, child: ElevatedButton(onPressed: _salvando ? null : _salvarEIniciarColeta, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4433), foregroundColor: Colors.white), child: _salvando ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Text('Iniciar Coleta', style: TextStyle(fontSize: 18))))),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _salvando ? null : _salvarAlteracoes,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white),
              child: _salvando ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : const Text('Salvar Dados da Parcela', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _salvando ? null : _navegarParaInventario,
              icon: const Icon(Icons.park_outlined),
              label: const Text('Ver/Editar Inventário', style: TextStyle(fontSize: 18)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4433), foregroundColor: Colors.white),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildCalculadoraArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Área da Parcela', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<FormaParcela>(
          segments: const [
            ButtonSegment(value: FormaParcela.retangular, label: Text('Retangular'), icon: Icon(Icons.crop_square)),
            ButtonSegment(value: FormaParcela.circular, label: Text('Circular'), icon: Icon(Icons.circle_outlined)),
          ],
          selected: {_formaDaParcela},
          onSelectionChanged: (newSelection) => setState(() { _formaDaParcela = newSelection.first; _calcularArea(); }),
        ),
        const SizedBox(height: 16),
        if (_formaDaParcela == FormaParcela.retangular)
          Row(children: [
            Expanded(child: TextFormField(controller: _larguraController, decoration: const InputDecoration(labelText: 'Largura (m)', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null)),
            const SizedBox(width: 8), const Text('x', style: TextStyle(fontSize: 20)), const SizedBox(width: 8),
            Expanded(child: TextFormField(controller: _comprimentoController, decoration: const InputDecoration(labelText: 'Comprimento (m)', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null)),
          ])
        else
          TextFormField(controller: _raioController, decoration: const InputDecoration(labelText: 'Raio (m)', border: OutlineInputBorder()), keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null),
        const SizedBox(height: 16),
        Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: _areaCalculada > 0 ? Colors.green[50] : Colors.grey[200], borderRadius: BorderRadius.circular(4), border: Border.all(color: _areaCalculada > 0 ? Colors.green : Colors.grey)),
          child: Column(children: [ const Text('Área Calculada:'), Text('${_areaCalculada.toStringAsFixed(2)} m²', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _areaCalculada > 0 ? Colors.green[800] : Colors.black)) ]),
        ),
      ],
    );
  }

  Widget _buildColetorCoordenadas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Coordenadas da Parcela', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            Expanded(child: _buscandoLocalizacao ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Buscando...')])
                : _erroLocalizacao != null ? Text('Erro: $_erroLocalizacao', style: const TextStyle(color: Colors.red))
                : _posicaoAtual == null ? const Text('Nenhuma localização obtida.')
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Lat: ${_posicaoAtual!.latitude.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Lon: ${_posicaoAtual!.longitude.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Precisão: ±${_posicaoAtual!.accuracy.toStringAsFixed(1)}m', style: TextStyle(color: Colors.grey[700])),
                  ])),
            IconButton(icon: const Icon(Icons.my_location, color: Color(0xFF1D4433)), onPressed: _buscandoLocalizacao ? null : _obterLocalizacaoAtual, tooltip: 'Obter localização'),
          ]),
        ),
      ],
    );
  }
}