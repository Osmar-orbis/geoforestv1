import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/pages/inventario_page.dart';
import 'package:geoforestcoletor/helpers/database_helper.dart';
import 'package:provider/provider.dart';
import 'package:geoforestcoletor/providers/map_provider.dart';
import 'package:geoforestcoletor/models/sample_point.dart';

enum FormaParcela { retangular, circular }

class ColetaDadosPage extends StatefulWidget {
  final Parcela? parcelaParaEditar;
  final String? nomeFazendaInicial;
  final String? nomeTalhaoInicial;
  final int? idParcelaInicial;

  const ColetaDadosPage({
    super.key,
    this.parcelaParaEditar,
    this.nomeFazendaInicial,
    this.nomeTalhaoInicial,
    this.idParcelaInicial,
  });

  @override
  State<ColetaDadosPage> createState() => _ColetaDadosPageState();
}

class _ColetaDadosPageState extends State<ColetaDadosPage> {
  final _formKey = GlobalKey<FormState>();

  final _nomeFazendaController = TextEditingController();
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

    // Pré-preenche os campos se estiver editando
    if (widget.parcelaParaEditar != null) {
      final p = widget.parcelaParaEditar!;
      _nomeFazendaController.text = p.nomeFazenda;
      _talhaoParcelaController.text = p.nomeTalhao;
      _idParcelaController.text = p.idParcela;
      _espacamentoController.text = p.espacamento ?? '';
      _observacaoController.text = p.observacao ?? '';
      _areaCalculada = p.areaMetrosQuadrados;

      if (p.latitude != null && p.longitude != null) {
        _posicaoAtual = Position(
          latitude: p.latitude!,
          longitude: p.longitude!,
          timestamp: DateTime.now(),
          accuracy: 0.0,
          altitude: 0.0,
          altitudeAccuracy: 0.0,
          heading: 0.0,
          headingAccuracy: 0.0,
          speed: 0.0,
          speedAccuracy: 0.0,
        );
      }
    } else {
      // Pré-preenche novos
      _nomeFazendaController.text = widget.nomeFazendaInicial ?? '';
      _talhaoParcelaController.text = widget.nomeTalhaoInicial ?? '';
      _idParcelaController.text = widget.idParcelaInicial?.toString() ?? '';
    }

    _larguraController.addListener(_calcularArea);
    _comprimentoController.addListener(_calcularArea);
    _raioController.addListener(_calcularArea);
  }

  @override
  void dispose() {
    _nomeFazendaController.dispose();
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

  Future<void> _salvarEIniciarColeta() async {
    if (!_formKey.currentState!.validate()) return;
    if (_areaCalculada <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A área da parcela deve ser maior que zero'), backgroundColor: Colors.orange),
      );
      return;
    }
    setState(() => _salvando = true);

    try {
      final dbHelper = DatabaseHelper();
      final novaParcela = Parcela(
        nomeFazenda: _nomeFazendaController.text.trim(),
        nomeTalhao: _talhaoParcelaController.text.trim(),
        idParcela: _idParcelaController.text.trim(),
        areaMetrosQuadrados: _areaCalculada,
        espacamento: _espacamentoController.text.trim().isNotEmpty ? _espacamentoController.text.trim() : null,
        observacao: _observacaoController.text.trim().isNotEmpty ? _observacaoController.text.trim() : null,
        latitude: _posicaoAtual?.latitude,
        longitude: _posicaoAtual?.longitude,
        dataColeta: DateTime.now(),
        status: StatusParcela.emAndamento,
      );

      final parcelaSalva = await dbHelper.saveFullColeta(novaParcela, []);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => InventarioPage(parcela: parcelaSalva)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _salvando = false);
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
      final parcela = Parcela(
        nomeFazenda: _nomeFazendaController.text.trim(),
        nomeTalhao: _talhaoParcelaController.text.trim(),
        idParcela: _idParcelaController.text.trim(),
        areaMetrosQuadrados: _areaCalculada,
        espacamento: _espacamentoController.text.trim().isNotEmpty ? _espacamentoController.text.trim() : null,
        observacao: _observacaoController.text.trim().isNotEmpty ? _observacaoController.text.trim() : null,
        latitude: _posicaoAtual?.latitude,
        longitude: _posicaoAtual?.longitude,
        dataColeta: DateTime.now(),
        status: StatusParcela.concluida,
      );

      await dbHelper.saveFullColeta(parcela, []);

      if (widget.idParcelaInicial != null) {
        context.read<MapProvider>().updateSampleStatus(
          widget.idParcelaInicial!,
          SampleStatus.completed,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parcela finalizada com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(true); // volta para o mapa
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao finalizar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _salvando = false);
    }
  }

  Future<void> _atualizarDadosEditados() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final dbHelper = DatabaseHelper();
      final parcelaEditada = Parcela(
        dbId: widget.parcelaParaEditar!.dbId,
        nomeFazenda: _nomeFazendaController.text.trim(),
        nomeTalhao: _talhaoParcelaController.text.trim(),
        idParcela: _idParcelaController.text.trim(),
        areaMetrosQuadrados: _areaCalculada > 0 ? _areaCalculada : widget.parcelaParaEditar!.areaMetrosQuadrados,
        espacamento: _espacamentoController.text.trim().isNotEmpty ? _espacamentoController.text.trim() : null,
        observacao: _observacaoController.text.trim().isNotEmpty ? _observacaoController.text.trim() : null,
        latitude: _posicaoAtual?.latitude ?? widget.parcelaParaEditar!.latitude,
        longitude: _posicaoAtual?.longitude ?? widget.parcelaParaEditar!.longitude,
        dataColeta: widget.parcelaParaEditar!.dataColeta,
        status: widget.parcelaParaEditar!.status,
      );

      await dbHelper.updateParcela(parcelaEditada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parcela atualizada com sucesso!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _salvando = false);
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

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20),
      );

      setState(() => _posicaoAtual = position);
    } catch (e) {
      setState(() => _erroLocalizacao = e.toString());
    } finally {
      setState(() => _buscandoLocalizacao = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.parcelaParaEditar != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Editar Parcela' : 'Nova Coleta'),
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
              TextFormField(
                controller: _nomeFazendaController,
                decoration: const InputDecoration(labelText: 'Nome da Fazenda', border: OutlineInputBorder(), prefixIcon: Icon(Icons.business)),
                validator: (v) => v == null || v.trim().length < 2 ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _talhaoParcelaController,
                decoration: const InputDecoration(labelText: 'Talhão', border: OutlineInputBorder(), prefixIcon: Icon(Icons.grid_on)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idParcelaController,
                decoration: const InputDecoration(labelText: 'ID da parcela', border: OutlineInputBorder(), prefixIcon: Icon(Icons.tag)),
                validator: (v) => v == null || v.trim().isEmpty ? 'Campo obrigatório' : null,
              ),
              const SizedBox(height: 16),
              _buildCalculadoraArea(),
              const SizedBox(height: 16),
              _buildColetorCoordenadas(),
              const SizedBox(height: 16),
              TextFormField(
                controller: _espacamentoController,
                decoration: const InputDecoration(labelText: 'Espaçamento', border: OutlineInputBorder(), prefixIcon: Icon(Icons.space_bar), helperText: 'Opcional'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _observacaoController,
                decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder(), prefixIcon: Icon(Icons.comment), helperText: 'Opcional'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              _buildActionButtons(isEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(bool isEditing) {
    if (isEditing) {
      return SizedBox(
        height: 50,
        child: ElevatedButton(
          onPressed: _salvando ? null : _atualizarDadosEditados,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4433), foregroundColor: Colors.white),
          child: _salvando
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
              : const Text('Salvar Alterações', style: TextStyle(fontSize: 18)),
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: _salvando ? null : _finalizarParcelaVazia,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF1D4433)),
                  foregroundColor: const Color(0xFF1D4433),
                ),
                child: const Text('Finalizar'),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _salvando ? null : _salvarEIniciarColeta,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D4433), foregroundColor: Colors.white),
                child: _salvando
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white))
                    : const Text('Iniciar Coleta', style: TextStyle(fontSize: 18)),
              ),
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
          onSelectionChanged: (newSelection) => setState(() {
            _formaDaParcela = newSelection.first;
            _calcularArea();
          }),
        ),
        const SizedBox(height: 16),
        if (_formaDaParcela == FormaParcela.retangular)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _larguraController,
                  decoration: const InputDecoration(labelText: 'Largura (m)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                ),
              ),
              const SizedBox(width: 8),
              const Text('x', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _comprimentoController,
                  decoration: const InputDecoration(labelText: 'Comprimento (m)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                ),
              ),
            ],
          )
        else
          TextFormField(
            controller: _raioController,
            decoration: const InputDecoration(labelText: 'Raio (m)', border: OutlineInputBorder()),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _areaCalculada > 0 ? Colors.green[50] : Colors.grey[200],
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _areaCalculada > 0 ? Colors.green : Colors.grey),
          ),
          child: Column(
            children: [
              const Text('Área Calculada:'),
              Text('${_areaCalculada.toStringAsFixed(2)} m²',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _areaCalculada > 0 ? Colors.green[800] : Colors.black))
            ],
          ),
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
          child: Row(
            children: [
              Expanded(
                child: _buscandoLocalizacao
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [CircularProgressIndicator(), SizedBox(width: 16), Text('Buscando...')],
                      )
                    : _erroLocalizacao != null
                        ? Text('Erro: $_erroLocalizacao', style: const TextStyle(color: Colors.red))
                        : _posicaoAtual == null
                            ? const Text('Nenhuma localização obtida.')
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Lat: ${_posicaoAtual!.latitude.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Lon: ${_posicaoAtual!.longitude.toStringAsFixed(6)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  Text('Precisão: ±${_posicaoAtual!.accuracy.toStringAsFixed(1)}m', style: TextStyle(color: Colors.grey[700])),
                                ],
                              ),
              ),
              IconButton(
                icon: const Icon(Icons.my_location, color: Color(0xFF1D4433)),
                onPressed: _buscandoLocalizacao ? null : _obterLocalizacaoAtual,
                tooltip: 'Obter localização',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
