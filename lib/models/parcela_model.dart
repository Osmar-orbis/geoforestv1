// lib/models/parcela_model.dart (VERSÃO CORRETA E FINAL)

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum StatusParcela {
  pendente(cor: Colors.orange, icone: Icons.hourglass_top_outlined),
  emAndamento(cor: Colors.blue, icone: Icons.directions_walk),
  concluida(cor: Colors.green, icone: Icons.check_circle_outline);

  const StatusParcela({
    required this.cor,
    required this.icone,
  });

  final Color cor;
  final IconData icone;
}

class Parcela {
  int? dbId;
  DateTime? dataColeta;
  final String? idFazenda;
  final String nomeFazenda;
  final String nomeTalhao;
  final String idParcela;
  final double areaMetrosQuadrados;
  final String? espacamento;
  final String? observacao;
  final double? latitude;
  final double? longitude;
  StatusParcela status;
  bool exportada;
  final double? largura;
  final double? comprimento;
  final double? raio;
  bool isSynced;
  final String? nomeLider;
  final String? nomesAjudantes;

  Parcela({
    this.dbId,
    this.idFazenda,
    required this.nomeFazenda,
    required this.nomeTalhao,
    required this.idParcela,
    required this.areaMetrosQuadrados,
    this.espacamento,
    this.observacao,
    this.latitude,
    this.longitude,
    this.dataColeta,
    required this.status,
    this.exportada = false,
    this.largura,
    this.comprimento,
    this.raio,
    this.isSynced = false,
    // =======================================================
    // ESTA É A PARTE QUE FALTAVA NO SEU ARQUIVO
    // =======================================================
    this.nomeLider,
    this.nomesAjudantes,
  });

  // Todos os outros métodos (copyWith, toMap, fromMap, toMapForFirestore)
  // devem estar como na versão que te passei anteriormente, incluindo
  // os campos nomeLider e nomesAjudantes.
  // Se precisar, eu colo o arquivo inteiro de novo.
  // ... (vou omitir por brevidade, mas eles precisam estar aqui e corretos)
    Parcela copyWith({int? dbId, String? idFazenda, String? nomeFazenda, String? nomeTalhao, String? idParcela, double? areaMetrosQuadrados, String? espacamento, String? observacao, double? latitude, double? longitude, DateTime? dataColeta, StatusParcela? status, bool? exportada, double? largura, double? comprimento, double? raio, bool? isSynced, String? nomeLider, String? nomesAjudantes}) {
    return Parcela(dbId: dbId ?? this.dbId, idFazenda: idFazenda ?? this.idFazenda, nomeFazenda: nomeFazenda ?? this.nomeFazenda, nomeTalhao: nomeTalhao ?? this.nomeTalhao, idParcela: idParcela ?? this.idParcela, areaMetrosQuadrados: areaMetrosQuadrados ?? this.areaMetrosQuadrados, espacamento: espacamento ?? this.espacamento, observacao: observacao ?? this.observacao, latitude: latitude ?? this.latitude, longitude: longitude ?? this.longitude, dataColeta: dataColeta ?? this.dataColeta, status: status ?? this.status, exportada: exportada ?? this.exportada, largura: largura ?? this.largura, comprimento: comprimento ?? this.comprimento, raio: raio ?? this.raio, isSynced: isSynced ?? this.isSynced, nomeLider: nomeLider ?? this.nomeLider, nomesAjudantes: nomesAjudantes ?? this.nomesAjudantes);
  }
  Map<String, dynamic> toMap() {
    return {'id': dbId, 'idFazenda': idFazenda, 'nomeFazenda': nomeFazenda, 'nomeTalhao': nomeTalhao, 'idParcela': idParcela, 'areaMetrosQuadrados': areaMetrosQuadrados, 'espacamento': espacamento, 'observacao': observacao, 'latitude': latitude, 'longitude': longitude, 'dataColeta': dataColeta?.toIso8601String(), 'status': status.name, 'exportada': exportada ? 1 : 0, 'largura': largura, 'comprimento': comprimento, 'raio': raio, 'isSynced': isSynced ? 1 : 0, 'nomeLider': nomeLider, 'nomesAjudantes': nomesAjudantes};
  }
  factory Parcela.fromMap(Map<String, dynamic> map) {
    return Parcela(dbId: map['id'], idFazenda: map['idFazenda'], nomeFazenda: map['nomeFazenda'], nomeTalhao: map['nomeTalhao'], idParcela: map['idParcela'], areaMetrosQuadrados: map['areaMetrosQuadrados'], espacamento: map['espacamento'], observacao: map['observacao'], latitude: map['latitude'], longitude: map['longitude'], dataColeta: map['dataColeta'] != null ? DateTime.parse(map['dataColeta']) : null, status: StatusParcela.values.firstWhere((e) => e.name == map['status'], orElse: () => StatusParcela.pendente), exportada: map['exportada'] == 1, largura: map['largura'], comprimento: map['comprimento'], raio: map['raio'], isSynced: map['isSynced'] == 1, nomeLider: map['nomeLider'], nomesAjudantes: map['nomesAjudantes']);
  }
  Map<String, dynamic> toMapForFirestore() {
    return {'idFazenda': idFazenda, 'nomeFazenda': nomeFazenda, 'nomeTalhao': nomeTalhao, 'idParcela': idParcela, 'areaMetrosQuadrados': areaMetrosQuadrados, 'espacamento': espacamento, 'observacao': observacao, 'localizacao': (latitude != null && longitude != null) ? GeoPoint(latitude!, longitude!) : null, 'dataColeta': dataColeta, 'status': status.name, 'exportada': exportada, 'largura': largura, 'comprimento': comprimento, 'raio': raio, 'sincronizadoEm': FieldValue.serverTimestamp(), 'nomeLider': nomeLider, 'nomesAjudantes': nomesAjudantes};
  }
}