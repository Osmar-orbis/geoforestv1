// lib/providers/map_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/models/sample_point.dart'; // <<< 1. IMPORT NECESSÁRIO
import 'package:geoforestcoletor/services/geojson_service.dart';
import 'package:geoforestcoletor/services/sampling_service.dart';

// Enum para gerenciar os tipos de mapa de fundo de forma segura.
enum MapLayerType { ruas, satelite, sateliteMapbox }

class MapProvider with ChangeNotifier {
  final _geoJsonService = GeoJsonService();

  // ESTADO INTERNO DO PROVIDER
  List<Polygon> _polygons = [];
  List<SamplePoint> _samplePoints = []; // O tipo de dado foi atualizado para SamplePoint
  bool _isLoading = false;
  String _farmName = '';
  String _blockName = '';
  MapLayerType _currentLayer = MapLayerType.satelite; // Mudei o padrão para satélite

  // URLs para os diferentes "paineis" de mapa.
  final Map<MapLayerType, String> _tileUrls = {
    MapLayerType.ruas: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapLayerType.satelite: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapLayerType.sateliteMapbox: 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
  };

  final String _mapboxAccessToken = 'pk.eyJ1IjoiZ2VvZm9yZXN0YXBwIiwiYSI6ImNtY2FyczBwdDAxZmYybHB1OWZlbG1pdW0ifQ.5HeYC0moMJ8dzZzVXKTPrg';

  // GETTERS PÚBLICOS (A forma como a UI lê o estado)
  List<Polygon> get polygons => _polygons;
  List<SamplePoint> get samplePoints => _samplePoints;
  bool get isLoading => _isLoading;
  String get farmName => _farmName;
  String get blockName => _blockName;
  MapLayerType get currentLayer => _currentLayer;

  String get currentTileUrl {
    String url = _tileUrls[_currentLayer]!;
    if (url.contains('{accessToken}')) {
      if (_mapboxAccessToken.contains('SUA_CHAVE_AQUI')) {
        // Fallback para o satélite padrão se a chave não for inserida
        return _tileUrls[MapLayerType.satelite]!;
      }
      return url.replaceAll('{accessToken}', _mapboxAccessToken);
    }
    return url;
  }
  
  // MÉTODOS PÚBLICOS (A forma como a UI modifica o estado)

  /// Cicla para a próxima camada de mapa disponível.
  void switchMapLayer() {
    final layers = MapLayerType.values;
    final nextIndex = (_currentLayer.index + 1) % layers.length;
    _currentLayer = layers[nextIndex];
    notifyListeners();
  }

  /// Limpa todos os dados do mapa, exceto o tipo de camada.
  void clearMapData() {
    _polygons = [];
    _samplePoints = [];
    _farmName = '';
    _blockName = '';
    notifyListeners();
  }

  /// Importa um novo GeoJSON, limpando todos os dados anteriores.
  Future<int> importAndClear() async {
    _setLoading(true);
    // Limpa tudo antes de começar a importar o novo arquivo
    clearMapData();
    _polygons = await _geoJsonService.importAndParseGeoJson();
    _setLoading(false);
    return _polygons.length;
  }

  /// Gera os pontos de amostragem com base nos polígonos carregados.
  Future<int> generateSamples({
    required double hectaresPerSample,
    required String farmName,
    required String blockName,
  }) async {
    if (_polygons.isEmpty) return 0;
    
    _setLoading(true);

    _farmName = farmName;
    _blockName = blockName;
    
    // O método 'compute' é ótimo para performance, mantemos ele.
    _samplePoints = await compute(_generatePointsInBackground, {
      'polygons': _polygons,
      'hectaresPerSample': hectaresPerSample,
    });
    
    _setLoading(false);
    return _samplePoints.length;
  }

  /// Função estática auxiliar que roda em uma thread separada via 'compute'.
  static List<SamplePoint> _generatePointsInBackground(Map<String, dynamic> params) {
    // Esta função não pode acessar 'this', então instanciamos o serviço aqui.
    final samplingService = SamplingService();
    final List<Polygon> polygons = params['polygons'];
    final double hectaresPerSample = params['hectaresPerSample'];
    
    return samplingService.generateGridSamplePoints(
      polygons: polygons,
      hectaresPerSample: hectaresPerSample,
    );
  }

  // =========================================================================
  // ============ FUNCIONALIDADE NOVA: GERENCIAMENTO DE STATUS ===============
  // =========================================================================

  /// Atualiza o status de uma parcela específica e notifica a UI para reconstruir.
  void updateSampleStatus(int pointId, SampleStatus newStatus) {
    // 'indexWhere' é a forma mais performática de encontrar um item em uma lista.
    final index = _samplePoints.indexWhere((p) => p.id == pointId);

    // Verificamos se o ponto foi encontrado para evitar erros.
    if (index != -1) {
      // Usamos o método 'copyWith' que criamos no modelo para gerar uma nova instância
      // do ponto com o status atualizado. Isso segue os princípios de imutabilidade.
      _samplePoints[index] = _samplePoints[index].copyWith(status: newStatus);

      // O comando mais importante: notifica todos os widgets que estão 'escutando'
      // (usando context.watch) que este provider mudou, fazendo com que eles
      // se reconstruam e mostrem a nova cor.
      notifyListeners();
    }
  }

  // =========================================================================

  /// Método privado para controlar o estado de loading de forma centralizada.
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}