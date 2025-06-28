// lib/models/parcela_model.dart (VERSÃO COM NOVOS CAMPOS)

import 'package:flutter/material.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';

enum StatusParcela {
  pendente(Icons.pending_outlined, Colors.grey),
  emAndamento(Icons.edit_note_outlined, Colors.orange),
  concluida(Icons.check_circle_outline, Colors.green);

  final IconData icone;
  final Color cor;
  
  const StatusParcela(this.icone, this.cor);
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
  bool isSynced;
  final double? largura;
  final double? comprimento;
  final double? raio;

  // <<< NOVOS CAMPOS ADICIONADOS AQUI >>>
  final double? idadeFloresta;
  final double? areaTalhao;

  List<Arvore> arvores;

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
    this.isSynced = false,
    this.largura,
    this.comprimento,
    this.raio,
    this.idadeFloresta, // <<< NOVO
    this.areaTalhao,    // <<< NOVO
    this.arvores = const [],
  });

  Parcela copyWith({
    int? dbId,
    String? idFazenda,
    String? nomeFazenda,
    String? nomeTalhao,
    String? idParcela,
    double? areaMetrosQuadrados,
    String? espacamento,
    String? observacao,
    double? latitude,
    double? longitude,
    DateTime? dataColeta,
    StatusParcela? status,
    bool? exportada,
    bool? isSynced,
    double? largura,
    double? comprimento,
    double? raio,
    double? idadeFloresta, // <<< NOVO
    double? areaTalhao,    // <<< NOVO
    List<Arvore>? arvores,
  }) {
    return Parcela(
      dbId: dbId ?? this.dbId,
      idFazenda: idFazenda ?? this.idFazenda,
      nomeFazenda: nomeFazenda ?? this.nomeFazenda,
      nomeTalhao: nomeTalhao ?? this.nomeTalhao,
      idParcela: idParcela ?? this.idParcela,
      areaMetrosQuadrados: areaMetrosQuadrados ?? this.areaMetrosQuadrados,
      espacamento: espacamento ?? this.espacamento,
      observacao: observacao ?? this.observacao,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      dataColeta: dataColeta ?? this.dataColeta,
      status: status ?? this.status,
      exportada: exportada ?? this.exportada,
      isSynced: isSynced ?? this.isSynced,
      largura: largura ?? this.largura,
      comprimento: comprimento ?? this.comprimento,
      raio: raio ?? this.raio,
      idadeFloresta: idadeFloresta ?? this.idadeFloresta, // <<< NOVO
      areaTalhao: areaTalhao ?? this.areaTalhao,          // <<< NOVO
      arvores: arvores ?? this.arvores,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': dbId,
      'idFazenda': idFazenda,
      'nomeFazenda': nomeFazenda,
      'nomeTalhao': nomeTalhao,
      'idParcela': idParcela,
      'areaMetrosQuadrados': areaMetrosQuadrados,
      'espacamento': espacamento,
      'observacao': observacao,
      'latitude': latitude,
      'longitude': longitude,
      'dataColeta': dataColeta?.toIso8601String(),
      'status': status.name,
      'exportada': exportada ? 1 : 0,
      'isSynced': isSynced ? 1 : 0,
      'largura': largura,
      'comprimento': comprimento,
      'raio': raio,
      'idadeFloresta': idadeFloresta, // <<< NOVO
      'areaTalhao': areaTalhao,       // <<< NOVO
    };
  }

  factory Parcela.fromMap(Map<String, dynamic> map) {
    return Parcela(
      dbId: map['id'],
      idFazenda: map['idFazenda'],
      nomeFazenda: map['nomeFazenda'],
      nomeTalhao: map['nomeTalhao'],
      idParcela: map['idParcela'],
      areaMetrosQuadrados: map['areaMetrosQuadrados'],
      espacamento: map['espacamento'],
      observacao: map['observacao'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      dataColeta: map['dataColeta'] != null ? DateTime.parse(map['dataColeta']) : null,
      status: StatusParcela.values.firstWhere(
            (e) => e.name == map['status'],
        orElse: () => StatusParcela.pendente,
      ),
      exportada: map['exportada'] == 1,
      isSynced: map['isSynced'] == 1,
      largura: map['largura'],
      comprimento: map['comprimento'],
      raio: map['raio'],
      idadeFloresta: map['idadeFloresta'], // <<< NOVO
      areaTalhao: map['areaTalhao'],       // <<< NOVO
    );
  }
}