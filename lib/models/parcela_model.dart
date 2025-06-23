// lib/models/parcela_model.dart (VERSÃO ATUALIZADA)

// ignore_for_file: non_constant_identifier_names

enum StatusParcela { iniciada, concluida, emAndamento }

class Parcela {
  int? dbId;
  DateTime? dataColeta;
  
  final String nomeFazenda;
  final String nomeTalhao;
  final String idParcela;
  final double areaMetrosQuadrados;
  final String? espacamento;
  final String? observacao;
  final double? latitude;
  final double? longitude;
  StatusParcela status;

  // =============================================================
  // ================ 1. NOVA PROPRIEDADE ADICIONADA ===============
  // =============================================================
  bool exportada;

  Parcela({
    this.dbId,
    required this.nomeFazenda,
    required this.nomeTalhao,
    required this.idParcela,
    required this.areaMetrosQuadrados,
    this.espacamento,
    this.observacao,
    this.latitude,
    this.longitude,
    this.dataColeta,
    this.status = StatusParcela.iniciada,
    // =============================================================
    // ============ 2. VALOR PADRÃO NO CONSTRUTOR ============
    // =============================================================
    this.exportada = false, 
  });

  Map<String, dynamic> toMap() {
    return {
      'id': dbId,
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
      // =============================================================
      // ======== 3. ADICIONADO AO MÉTODO toMap PARA SALVAR ========
      // =============================================================
      'exportada': exportada ? 1 : 0, // Salva como 1 (true) ou 0 (false)
    };
  }

  factory Parcela.fromMap(Map<String, dynamic> map) {
    return Parcela(
      dbId: map['id'],
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
        orElse: () => StatusParcela.iniciada,
      ),
      // =============================================================
      // ===== 4. ADICIONADO AO MÉTODO fromMap PARA LER DO BANCO =====
      // =============================================================
      exportada: map['exportada'] == 1, // Lê 1 como true, qualquer outra coisa como false
    );
  }
}