// lib/models/arvore_model.dart (VERSÃO SEM VOLUME)

enum StatusArvore {
  normal,
  falha,
  bifurcada,
  multipla,
  quebrada,
  morta,
  caida,
  ataquemacaco,
  regenaracao,
  inclinada,
  fogo,
  formiga,
  outro
}

enum StatusArvore2 {
  bifurcada,
  multipla,
  quebrada,
  morta,
  caida,
  ataquemacaco,
  regenaracao,
  inclinada,
  fogo,
  formiga,
  outro
}

class Arvore {
  int? id;
  final double cap;
  final double? altura;
  final int linha;
  final int posicaoNaLinha;
  final bool fimDeLinha;
  bool dominante;
  final StatusArvore status;
  final StatusArvore2? status2;

  Arvore({
    this.id,
    required this.cap,
    this.altura,
    required this.linha,
    required this.posicaoNaLinha,
    this.fimDeLinha = false,
    this.dominante = false,
    required this.status,
    this.status2,
  });

  Arvore copyWith({
    int? id,
    double? cap,
    double? altura,
    int? linha,
    int? posicaoNaLinha,
    bool? fimDeLinha,
    bool? dominante,
    StatusArvore? status,
    StatusArvore2? status2,
  }) {
    return Arvore(
      id: id ?? this.id,
      cap: cap ?? this.cap,
      altura: altura ?? this.altura,
      linha: linha ?? this.linha,
      posicaoNaLinha: posicaoNaLinha ?? this.posicaoNaLinha,
      fimDeLinha: fimDeLinha ?? this.fimDeLinha,
      dominante: dominante ?? this.dominante,
      status: status ?? this.status,
      status2: status2 ?? this.status2,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cap': cap,
      'altura': altura,
      'linha': linha,
      'posicaoNaLinha': posicaoNaLinha,
      'fimDeLinha': fimDeLinha ? 1 : 0,
      'dominante': dominante ? 1 : 0,
      'status': status.name,
      'status2': status2?.name,
    };
  }

  factory Arvore.fromMap(Map<String, dynamic> map) {
    return Arvore(
      id: map['id'],
      cap: map['cap']?.toDouble() ?? 0.0,
      altura: map['altura']?.toDouble(),
      linha: map['linha'] ?? 0,
      posicaoNaLinha: map['posicaoNaLinha'] ?? 0,
      fimDeLinha: map['fimDeLinha'] == 1,
      dominante: map['dominante'] == 1,
      status: StatusArvore.values.firstWhere((e) => e.name == map['status'], orElse: () => StatusArvore.normal),
      status2: map['status2'] != null ? StatusArvore2.values.firstWhere((e) => e.name == map['status2']) : null,
    );
  }
}