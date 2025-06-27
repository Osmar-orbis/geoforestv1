class CubagemArvore {
  // Atributos do Banco de Dados e Identificação
  int? id;
  String? idFazenda;
  String nomeFazenda;
  String nomeTalhao;
  String identificador;
  String? classe;
  bool exportada;

  // Atributos de Medição
  double alturaTotal;
  String tipoMedidaCAP;
  double valorCAP;
  double alturaBase;

  CubagemArvore({
    // Identificação
    this.id,
    this.idFazenda,
    required this.nomeFazenda,
    required this.nomeTalhao,
    required this.identificador,
    this.classe,
    this.exportada = false,
    
    // Medição
    required this.alturaTotal,
    required this.tipoMedidaCAP,
    required this.valorCAP,
    required this.alturaBase,
  });

  /// Converte o objeto Dart em um Map para ser salvo no banco de dados.
  /// As chaves do Map devem corresponder exatamente aos nomes das colunas na tabela 'cubagens_arvores'.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_fazenda': idFazenda,
      'nome_fazenda': nomeFazenda,
      'nome_talhao': nomeTalhao,
      'identificador': identificador,
      'classe': classe,
      'alturaTotal': alturaTotal,
      'tipoMedidaCAP': tipoMedidaCAP,
      'valorCAP': valorCAP,
      'alturaBase': alturaBase,
      'exportada': exportada ? 1 : 0,
    };
  }

  /// Cria um objeto CubagemArvore a partir de um Map vindo do banco de dados.
  /// É crucial lidar com campos que podem ser nulos, especialmente em registros antigos.
  factory CubagemArvore.fromMap(Map<String, dynamic> map) {
    return CubagemArvore(
      // Identificação
      id: map['id'],
      idFazenda: map['id_fazenda'],
      nomeFazenda: map['nome_fazenda'] ?? '', // Garante retrocompatibilidade com dados antigos
      nomeTalhao: map['nome_talhao'] ?? '',   // Garante retrocompatibilidade com dados antigos
      identificador: map['identificador'],
      classe: map['classe'],
      exportada: map['exportada'] == 1,
      
      // Medição
      alturaTotal: map['alturaTotal'],
      tipoMedidaCAP: map['tipoMedidaCAP'],
      valorCAP: map['valorCAP'],
      alturaBase: map['alturaBase'],
    );
  }
}