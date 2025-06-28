// lib/pages/amostra/coleta_dados_page.dart (VERSÃO FINAL COM DIÁLOGO)

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/pages/amostra/inventario_page.dart';
import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
// <<< MUDANÇA: IMPORTANDO O NOVO DIÁLOGO >>>
import 'package:geoforestcoletor/widgets/informacoes_adicionais_dialog.dart';

enum FormaParcela { retangular, circular }

class ColetaDadosPage extends StatefulWidget {
  final Parcela parcelaParaEditar;
  const ColetaDadosPage({super.key, required this.parcelaParaEditar});

  @override
  State<ColetaDadosPage> createState() => _ColetaDadosPageState();
}

class _ColetaDadosPageState extends State<ColetaDadosPage> {
  final _formKey = GlobalKey<FormState>();
  final dbHelper = DatabaseHelper();
  late Parcela _parcelaAtual;

  final _nomeFazendaController = TextEditingController();
  final _idFazendaController = TextEditingController();
  final _talhaoParcelaController = TextEditingController();
  final _idParcelaController = TextEditingController();
  final _observacaoController = TextEditingController();
  final _larguraController = TextEditingController();
  final _comprimentoController = TextEditingController();
  final _raioController = TextEditingController();
  // <<< MUDANÇA: REMOÇÃO DO _espacamentoController >>>

  Position? _posicaoAtual;
  bool _buscandoLocalizacao = false;
  String? _erroLocalizacao;
  bool _salvando = false;
  FormaParcela _formaDaParcela = FormaParcela.retangular;
  double _areaCalculada = 0.0;
  bool _temArvoresColetadas = false;

  @override
  void initState() {
    super.initState();
    _parcelaAtual = widget.parcelaParaEditar;
    _carregarDadosDaParcela();
    _larguraController.addListener(_calcularArea);
    _comprimentoController.addListener(_calcularArea);
    _raioController.addListener(_calcularArea);
  }

  Future<void> _carregarDadosDaParcela() async {
    if (_parcelaAtual.dbId != null) {
      final parcelaDoBanco = await dbHelper.getParcelaById(_parcelaAtual.dbId!);
      final arvores = await dbHelper.getArvoresDaParcela(_parcelaAtual.dbId!);

      if (parcelaDoBanco != null && mounted) {
        setState(() {
          _parcelaAtual = parcelaDoBanco;
          _temArvoresColetadas = arvores.isNotEmpty;
        });
      }
    }
    _preencherDadosIniciais();
  }

  void _preencherDadosIniciais() {
    final p = _parcelaAtual;
    _nomeFazendaController.text = p.nomeFazenda;
    _idFazendaController.text = p.idFazenda ?? '';
    _talhaoParcelaController.text = p.nomeTalhao;
    _idParcelaController.text = p.idParcela;
    // <<< MUDANÇA: O _espacamentoController não é mais preenchido aqui >>>
    _observacaoController.text = p.observacao ?? '';
    _areaCalculada = p.areaMetrosQuadrados;

    if (p.largura != null) _larguraController.text = p.largura.toString().replaceAll('.', ',');
    if (p.comprimento != null) _comprimentoController.text = p.comprimento.toString().replaceAll('.', ',');
    if (p.raio != null) {
      _raioController.text = p.raio.toString().replaceAll('.', ',');
      _formaDaParcela = FormaParcela.circular;
    } else {
      _formaDaParcela = FormaParcela.retangular;
    }

    if (p.latitude != null && p.longitude != null) {
      _posicaoAtual = Position(latitude: p.latitude!, longitude: p.longitude!, timestamp: DateTime.now(), accuracy: 0.0, altitude: 0.0, altitudeAccuracy: 0.0, heading: 0.0, headingAccuracy: 0.0, speed: 0.0, speedAccuracy: 0.0);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nomeFazendaController.dispose();
    _idFazendaController.dispose();
    _talhaoParcelaController.dispose();
    _idParcelaController.dispose();
    // <<< MUDANÇA: O _espacamentoController não é mais removido daqui >>>
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
    // <<< MUDANÇA: O espaçamento já está em _parcelaAtual, não precisa ser pego de um controller >>>
    return _parcelaAtual.copyWith(
      nomeFazenda: _nomeFazendaController.text.trim(),
      idFazenda: _idFazendaController.text.trim().isNotEmpty ? _idFazendaController.text.trim() : null,
      nomeTalhao: _talhaoParcelaController.text.trim(),
      idParcela: _idParcelaController.text.trim(),
      areaMetrosQuadrados: _areaCalculada,
      observacao: _observacaoController.text.trim().isNotEmpty ? _observacaoController.text.trim() : null,
      latitude: _posicaoAtual?.latitude,
      longitude: _posicaoAtual?.longitude,
      dataColeta: _parcelaAtual.dataColeta ?? DateTime.now(),
      largura: _formaDaParcela == FormaParcela.retangular ? double.tryParse(_larguraController.text.replaceAll(',', '.')) : null,
      comprimento: _formaDaParcela == FormaParcela.retangular ? double.tryParse(_comprimentoController.text.replaceAll(',', '.')) : null,
      raio: _formaDaParcela == FormaParcela.circular ? double.tryParse(_raioController.text.replaceAll(',', '.')) : null,
    );
  }
  
  // <<< MUDANÇA: NOVA FUNÇÃO PARA ABRIR O DIÁLOGO >>>
  Future<void> _abrirDialogoInfoAdicionais() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => InformacoesAdicionaisDialog(
        espacamentoInicial: _parcelaAtual.espacamento,
        idadeInicial: _parcelaAtual.idadeFloresta,
        areaTalhaoInicial: _parcelaAtual.areaTalhao,
      ),
    );

    if (result != null) {
      setState(() {
        _parcelaAtual = _parcelaAtual.copyWith(
          espacamento: result['espacamento'],
          idadeFloresta: result['idade'],
          areaTalhao: result['areaTalhao'],
        );
      });
    }
  }

  Future<void> _salvarEIniciarColeta() async {
    if (!_formKey.currentState!.validate()) return;
    if (_areaCalculada <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A área da parcela deve ser maior que zero'), backgroundColor: Colors.orange));
      return;
    }
    setState(() => _salvando = true);

    try {
      final parcelaAtualizada = _construirObjetoParcela().copyWith(status: StatusParcela.emAndamento);
      final parcelaSalva = await dbHelper.saveFullColeta(parcelaAtualizada, []);

      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => InventarioPage(parcela: parcelaSalva)),
        );
        await _carregarDadosDaParcela();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
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
      final parcelaFinalizada = _construirObjetoParcela().copyWith(status: StatusParcela.concluida);
      await dbHelper.saveFullColeta(parcelaFinalizada, []);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parcela finalizada com sucesso!'), backgroundColor: Colors.green));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao finalizar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _salvarAlteracoes() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _salvando = true);
    try {
      final parcelaEditada = _construirObjetoParcela();
      await dbHelper.updateParcela(parcelaEditada);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alterações salvas com sucesso!'), backgroundColor: Colors.green));
        await _carregarDadosDaParcela();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  Future<void> _navegarParaInventario() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => InventarioPage(parcela: _parcelaAtual),
      ),
    );
    await _carregarDadosDaParcela();
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
      if (mounted) setState(() => _buscandoLocalizacao = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isModoNovo = _parcelaAtual.status == StatusParcela.pendente && !_temArvoresColetadas;

    return Scaffold(
      appBar: AppBar(
        title: Text(isModoNovo ? 'Nova Coleta de Parcela' : 'Editar Dados da Parcela'),
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
              const SizedBox(height: 24),
              
              // <<< MUDANÇA: BOTÃO PARA ABRIR O DIÁLOGO >>>
              SizedBox(
                height: 50,
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _abrirDialogoInfoAdicionais,
                  icon: const Icon(Icons.library_books_outlined),
                  label: const Text('Informações Adicionais do Talhão'),
                  style: OutlinedButton.styleFrom(
                     foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                     side: BorderSide(color: Colors.grey.shade400),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              TextFormField(controller: _observacaoController, decoration: const InputDecoration(labelText: 'Observações da Parcela', border: OutlineInputBorder(), prefixIcon: Icon(Icons.comment), helperText: 'Opcional'), maxLines: 3),
              const SizedBox(height: 24),
              _buildActionButtons(isModoNovo),
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