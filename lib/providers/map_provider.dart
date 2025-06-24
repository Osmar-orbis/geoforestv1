// lib/providers/map_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/services/geojson_service.dart';
import 'package:geoforestcoletor/services/sampling_service.dart';

// Enum para gerenciar os tipos de mapa de fundo de forma segura.
enum MapLayerType { ruas, satelite, sateliteMapbox }

class MapProvider with ChangeNotifier {
  final _geoJsonService = GeoJsonService();

  // ESTADO INTERNO DO PROVIDER
  List<Polygon> _polygons = [];
  List<SamplePoint> _samplePoints = [];
  bool _isLoading = false;
  String _farmName = '';
  String _blockName = '';
  MapLayerType _currentLayer = MapLayerType.ruas;

  // URLs para os diferentes "paineis" de mapa.
  final Map<MapLayerType, String> _tileUrls = {
    MapLayerType.ruas: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapLayerType.satelite: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapLayerType.sateliteMapbox: 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
  };

  // <<< COLE SUA CHAVE DE ACESSO PÚBLICA DO MAPBOX AQUI >>>
  // Se não tiver uma, a opção de mapa Mapbox não funcionará.
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
      if (_mapboxAccessToken.contains('SUA_CHAVE')) {
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

  void clearMapData() {
    _polygons = [];
    _samplePoints = [];
    _farmName = '';
    _blockName = '';
    notifyListeners();
  }

  Future<int> importAndClear() async {
    _setLoading(true);
    _polygons = await _geoJsonService.importAndParseGeoJson();
    _samplePoints = []; 
    _farmName = '';
    _blockName = '';
    _setLoading(false);
    return _polygons.length;
  }

  Future<int> generateSamples({
    required double hectaresPerSample,
    required String farmName,
    required String blockName,
  }) async {
    if (_polygons.isEmpty) return 0;
    
    _setLoading(true);

    _farmName = farmName;
    _blockName = blockName;
    
    _samplePoints = await compute(_generatePointsInBackground, {
      'polygons': _polygons,
      'hectaresPerSample': hectaresPerSample,
    });
    
    _setLoading(false);
    return _samplePoints.length;
  }
  
  static List<SamplePoint> _generatePointsInBackground(Map<String, dynamic> params) {
    final samplingService = SamplingService();
    final List<Polygon> polygons = params['polygons'];
    final double hectaresPerSample = params['hectaresPerSample'];
    
    return samplingService.generateGridSamplePoints(
      polygons: polygons,
      hectaresPerSample: hectaresPerSample,
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}