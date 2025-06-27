// lib/providers/map_provider.dart (Versão Final e Verificada)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
// A importação correta não é necessária aqui, pois as classes são usadas na UI

import 'package:geoforestcoletor/data/datasources/local/database_helper.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/sample_point.dart';
import 'package:geoforestcoletor/services/geojson_service.dart';
import 'package:geoforestcoletor/services/sampling_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum MapLayerType { ruas, satelite, sateliteMapbox }

class MapProvider with ChangeNotifier {
  final _geoJsonService = GeoJsonService();
  final _dbHelper = DatabaseHelper.instance;

  List<Polygon> _polygons = [];
  List<SamplePoint> _samplePoints = [];
  bool _isLoading = false;
  
  String _farmName = '';
  String _blockName = '';
  String? _idFazenda;

  MapLayerType _currentLayer = MapLayerType.satelite;
  
  Position? _currentUserPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isFollowingUser = false;
  
  // Estado de desenho
  bool _isDrawing = false;
  final List<LatLng> _drawnPoints = [];

  // Getters
  bool get isDrawing => _isDrawing;
  List<LatLng> get drawnPoints => _drawnPoints;
  List<Polygon> get polygons => _polygons;
  List<SamplePoint> get samplePoints => _samplePoints;
  bool get isLoading => _isLoading;
  String get farmName => _farmName;
  String get blockName => _blockName;
  String? get idFazenda => _idFazenda;
  MapLayerType get currentLayer => _currentLayer;
  Position? get currentUserPosition => _currentUserPosition;
  bool get isFollowingUser => _isFollowingUser;

  // Métodos de desenho
  void startDrawing() {
    clearMapData();
    _isDrawing = true;
    _drawnPoints.clear();
    notifyListeners();
  }

  void cancelDrawing() {
    _isDrawing = false;
    _drawnPoints.clear();
    notifyListeners();
  }

  void addDrawnPoint(LatLng point) {
    if (!_isDrawing) return;
    _drawnPoints.add(point);
    notifyListeners();
  }

  void undoLastDrawnPoint() {
    if (_drawnPoints.isNotEmpty) {
      _drawnPoints.removeLast();
      notifyListeners();
    }
  }

  void saveDrawnPolygon() {
    if (_drawnPoints.length < 3) {
      cancelDrawing();
      return;
    }
    _polygons.add(Polygon(points: List.from(_drawnPoints), color: const Color(0xFF617359).withAlpha(128), borderColor: const Color(0xFF1D4433), borderStrokeWidth: 2, isFilled: true));
    _isDrawing = false;
    _drawnPoints.clear();
    notifyListeners();
  }

  // O resto do seu código (importação, geração de amostras, etc.)
  // ... (Cole aqui o resto do seu MapProvider, a partir do updateProjectInfo)
  final Map<MapLayerType, String> _tileUrls = {
    MapLayerType.ruas: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapLayerType.satelite: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapLayerType.sateliteMapbox: 'https://api.mapbox.com/styles/v1/mapbox/satellite-v9/tiles/256/{z}/{x}/{y}@2x?access_token={accessToken}',
  };
  final String _mapboxAccessToken = 'pk.eyJ1IjoiZ2VvZm9yZXN0YXBwIiwiYSI6ImNtY2FyczBwdDAxZmYybHB1OWZlbG1pdW0ifQ.5HeYC0moMJ8dzZzVXKTPrg';

  String get currentTileUrl {
    String url = _tileUrls[_currentLayer]!;
    if (url.contains('{accessToken}')) {
      if (_mapboxAccessToken.contains('SUA_CHAVE_AQUI') || _mapboxAccessToken.isEmpty) {
        return _tileUrls[MapLayerType.satelite]!;
      }
      return url.replaceAll('{accessToken}', _mapboxAccessToken);
    }
    return url;
  }
  
  void switchMapLayer() {
    final layers = MapLayerType.values;
    final nextIndex = (_currentLayer.index + 1) % layers.length;
    _currentLayer = layers[nextIndex];
    notifyListeners();
  }
  

  Future<void> updateProjectInfo({required String farmName, required String blockName, String? idFazenda}) async {
    _farmName = farmName;
    _blockName = blockName;
    _idFazenda = idFazenda;
    await _saveCurrentProject(farmName, blockName, idFazenda);
    notifyListeners();
  }
  
  void clearMapData() {
    _polygons = [];
    _samplePoints = [];
    _farmName = '';
    _blockName = '';
    _idFazenda = null;
    _clearLastProject();
    if (_isFollowingUser) {
      toggleFollowingUser();
    }
    if (_isDrawing) {
      cancelDrawing();
    }
    notifyListeners();
  }

  Future<void> _clearLastProject() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_farm_name');
    await prefs.remove('last_block_name');
    await prefs.remove('last_farm_id');
  }

  Future<bool> importAndClear() async {
    _setLoading(true);
    clearMapData(); 
    final importedData = await _geoJsonService.importAndParseGeoJson();
    _polygons = importedData['polygons'] as List<Polygon>;
    _samplePoints = importedData['points'] as List<SamplePoint>;
    _setLoading(false);
    return _polygons.isNotEmpty || _samplePoints.isNotEmpty;
  }

  Future<void> saveImportedProject({required String farmName, required String blockName, String? idFazenda}) async {
    if (_samplePoints.isEmpty) return;
    _setLoading(true);
    await updateProjectInfo(farmName: farmName, blockName: blockName, idFazenda: idFazenda); // Usa o novo método
    final List<Parcela> novasParcelas = _samplePoints.map((point) => Parcela(nomeFazenda: farmName, nomeTalhao: blockName, idFazenda: idFazenda, idParcela: point.id.toString(), latitude: point.position.latitude, longitude: point.position.longitude, status: StatusParcela.pendente, dataColeta: DateTime.now(), areaMetrosQuadrados: 0, exportada: false)).toList();
    await _dbHelper.saveBatchParcelas(novasParcelas);
    await loadSamplesFromDb(farmName: farmName, blockName: blockName);
    _setLoading(false);
  }
  
  Future<int> generateSamples({required double hectaresPerSample, required String farmName, required String blockName, String? idFazenda}) async {
    if (_polygons.isEmpty) return 0;
    _setLoading(true);
    await updateProjectInfo(farmName: farmName, blockName: blockName, idFazenda: idFazenda); // Usa o novo método
    final points = await compute(_generatePointsInBackground, {'polygons': _polygons, 'hectaresPerSample': hectaresPerSample});
    final List<Parcela> novasParcelas = points.map((point) => Parcela(nomeFazenda: farmName, idFazenda: idFazenda, nomeTalhao: blockName, idParcela: point.id.toString(), latitude: point.position.latitude, longitude: point.position.longitude, status: StatusParcela.pendente, dataColeta: DateTime.now(), areaMetrosQuadrados: 0, exportada: false)).toList();
    await _dbHelper.saveBatchParcelas(novasParcelas);
    await loadSamplesFromDb(farmName: farmName, blockName: blockName);
    _setLoading(false);
    return _samplePoints.length;
  }
  
  static List<SamplePoint> _generatePointsInBackground(Map<String, dynamic> params) {
    final samplingService = SamplingService();
    final List<Polygon> polygons = params['polygons'];
    final double hectaresPerSample = params['hectaresPerSample'];
    return samplingService.generateGridSamplePoints(polygons: polygons, hectaresPerSample: hectaresPerSample);
  }
  
  Future<void> loadSamplesFromDb({required String farmName, required String blockName}) async {
    _setLoading(true);
    _farmName = farmName;
    _blockName = blockName;
    // Carrega o idFazenda também, se existir
    final prefs = await SharedPreferences.getInstance();
    _idFazenda = prefs.getString('last_farm_id');

    final parcelasDoBanco = await _dbHelper.getParcelasByProject(farmName, blockName);
    _samplePoints = parcelasDoBanco.map((parcela) {
      SampleStatus status;
      switch (parcela.status) {
        case StatusParcela.concluida: status = SampleStatus.completed; break;
        case StatusParcela.emAndamento: status = SampleStatus.open; break;
        case StatusParcela.pendente: status = SampleStatus.untouched;
      }
      if (parcela.exportada) { status = SampleStatus.exported; }
      return SamplePoint(id: int.tryParse(parcela.idParcela) ?? 0, position: LatLng(parcela.latitude ?? 0, parcela.longitude ?? 0), status: status, data: {'dbId': parcela.dbId});
    }).toList();
    _setLoading(false);
  }

  Future<void> loadLastProject() async {
    _setLoading(true);
    final prefs = await SharedPreferences.getInstance();
    final lastFarm = prefs.getString('last_farm_name');
    final lastBlock = prefs.getString('last_block_name');
    if (lastFarm != null && lastBlock != null && lastFarm.isNotEmpty && lastBlock.isNotEmpty) {
      await loadSamplesFromDb(farmName: lastFarm, blockName: lastBlock);
    }
    _setLoading(false);
  }

  Future<void> _saveCurrentProject(String farmName, String blockName, String? idFazenda) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_farm_name', farmName);
    await prefs.setString('last_block_name', blockName);
    if(idFazenda != null) {
      await prefs.setString('last_farm_id', idFazenda);
    }
  }

  void toggleFollowingUser() { if (_isFollowingUser) { _positionStreamSubscription?.cancel(); _isFollowingUser = false; } else { const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 1); _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) { _currentUserPosition = position; notifyListeners(); }); _isFollowingUser = true; } notifyListeners(); }
  void updateUserPosition(Position position) { _currentUserPosition = position; notifyListeners(); }
  @override
  void dispose() { 
    _positionStreamSubscription?.cancel(); 
    super.dispose(); 
  }
  void _setLoading(bool value) { _isLoading = value; notifyListeners(); }
}