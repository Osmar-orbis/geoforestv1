// lib/models/arvore_model.dart

enum StatusArvore { 
  normal, 
  falha, 
  morta, 
  quebrada, 
  caida, 
  ataquemacaco, 
  regenaracao, 
  bifurcada,
  multipla // <<< RE-ADICIONADO
}

class Arvore {
  int id;
  double cap;
  double? altura;
  int linha;
  int posicaoNaLinha;
  bool fimDeLinha;
  bool dominante;
  StatusArvore status;
  StatusArvore? status2;
  
  Arvore({
    required this.id,
    required this.cap,
    this.altura,
    required this.linha,
    required this.posicaoNaLinha,
    this.fimDeLinha = false,
    this.dominante = false,
    required this.status,
    this.status2,
  });

  // Verifica se a árvore é considerada "múltipla" para fins de UI
  bool get isConsideradaMultipla {
    return status == StatusArvore.multipla ||
           status == StatusArvore.bifurcada ||
           status2 == StatusArvore.multipla ||
           status2 == StatusArvore.bifurcada;
  }
  factory Arvore.fromMap(Map<String, dynamic> map) {
    return Arvore(
      id: map['id'],
      cap: map['cap'],
      altura: map['altura'],
      linha: map['linha'],
      posicaoNaLinha: map['posicaoNaLinha'],
      fimDeLinha: map['fimDeLinha'] == 1,
      dominante: map['dominante'] == 1,
      status: StatusArvore.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => StatusArvore.normal, // Valor padrão caso não encontre
      ),
      status2: map['status2'] != null
          ? StatusArvore.values.firstWhere(
              (e) => e.name == map['status2'],
              orElse: () => StatusArvore.normal,
            )
          : null,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id == 0 ? null : id,
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
}