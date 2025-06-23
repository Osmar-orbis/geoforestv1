class CubagemArvore {
  int? id;
  String identificador; // Ex: "Talhão 1 - Árvore 1" ou um ID único
  double alturaTotal;
  String tipoMedidaCAP; // 'suta' ou 'fita'
  double valorCAP; // O valor do CAP ou DAP medido
  double alturaBase; // Onde o tronco foi cortado
  String? classe; // Ex: "60-70"

  CubagemArvore({
    this.id,
    required this.identificador,
    required this.alturaTotal,
    required this.tipoMedidaCAP,
    required this.valorCAP,
    required this.alturaBase,
    this.classe,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'identificador': identificador,
      'alturaTotal': alturaTotal,
      'tipoMedidaCAP': tipoMedidaCAP,
      'valorCAP': valorCAP,
      'alturaBase': alturaBase,
      'classe': classe,
    };
  }

  factory CubagemArvore.fromMap(Map<String, dynamic> map) {
    return CubagemArvore(
      id: map['id'],
      identificador: map['identificador'],
      alturaTotal: map['alturaTotal'],
      tipoMedidaCAP: map['tipoMedidaCAP'],
      valorCAP: map['valorCAP'],
      alturaBase: map['alturaBase'],
      classe: map['classe'],
    );
  }
}