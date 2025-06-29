// lib/models/talhao_model.dart

class Talhao {
  final int? id; // O talhão continua com ID automático
  
  // Chave estrangeira composta para ligar à Fazenda
  final String fazendaId; 
  final int fazendaAtividadeId;
  
  final String nome;
  final double? areaHa;
  final double? idadeAnos;
  final String? especie;

  Talhao({
    this.id,
    required this.fazendaId,
    required this.fazendaAtividadeId,
    required this.nome,
    this.areaHa,
    this.idadeAnos,
    this.especie,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fazendaId': fazendaId,
      'fazendaAtividadeId': fazendaAtividadeId,
      'nome': nome,
      'areaHa': areaHa,
      'idadeAnos': idadeAnos,
      'especie': especie,
    };
  }

  factory Talhao.fromMap(Map<String, dynamic> map) {
    return Talhao(
      id: map['id'],
      fazendaId: map['fazendaId'],
      fazendaAtividadeId: map['fazendaAtividadeId'],
      nome: map['nome'],
      areaHa: map['areaHa'],
      idadeAnos: map['idadeAnos'],
      especie: map['especie'],
    );
  }
}