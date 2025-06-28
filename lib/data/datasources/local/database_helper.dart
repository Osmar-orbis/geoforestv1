// lib/data/datasources/local/database_helper.dart (VERSÃO 17 - COMPLETA)

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_secao_model.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:shared_preferences/shared_preferences.dart';

const Map<String, int> zonasUtmSirgas2000 = {
  'SIRGAS 2000 / UTM Zona 18S': 31978, 'SIRGAS 2000 / UTM Zona 19S': 31979,
  'SIRGAS 2000 / UTM Zona 20S': 31980, 'SIRGAS 2000 / UTM Zona 21S': 31981,
  'SIRGAS 2000 / UTM Zona 22S': 31982, 'SIRGAS 2000 / UTM Zona 23S': 31983,
  'SIRGAS 2000 / UTM Zona 24S': 31984, 'SIRGAS 2000 / UTM Zona 25S': 31985,
};

final Map<int, String> proj4Definitions = {
  31978: '+proj=utm +zone=18 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs', 31979: '+proj=utm +zone=19 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31980: '+proj=utm +zone=20 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs', 31981: '+proj=utm +zone=21 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31982: '+proj=utm +zone=22 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs', 31983: '+proj=utm +zone=23 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31984: '+proj=utm +zone=24 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs', 31985: '+proj=utm +zone=25 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
};

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  static DatabaseHelper get instance => _instance;

  DatabaseHelper._privateConstructor();
  factory DatabaseHelper() => _instance;

  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    proj4.Projection.add('EPSG:4326', '+proj=longlat +datum=WGS84 +no_defs');
    proj4Definitions.forEach((epsg, def) {
      proj4.Projection.add('EPSG:$epsg', def);
    });
    return await openDatabase(
      join(await getDatabasesPath(), 'geoforestcoletor.db'),
      // <<< MUDANÇA: VERSÃO INCREMENTADA >>>
      version: 17,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // <<< MUDANÇA: ADICIONANDO NOVAS COLUNAS NA CRIAÇÃO >>>
    await db.execute('''
      CREATE TABLE parcelas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomeFazenda TEXT NOT NULL,
        nomeTalhao TEXT NOT NULL,
        idParcela TEXT NOT NULL,
        areaMetrosQuadrados REAL NOT NULL,
        espacamento TEXT,
        observacao TEXT,
        latitude REAL,
        longitude REAL,
        dataColeta TEXT NOT NULL,
        status TEXT NOT NULL,
        exportada INTEGER DEFAULT 0 NOT NULL,
        idFazenda TEXT,
        largura REAL,
        comprimento REAL,
        raio REAL,
        isSynced INTEGER DEFAULT 0 NOT NULL,
        idadeFloresta REAL,
        areaTalhao REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE arvores (
        id INTEGER PRIMARY KEY AUTOINCREMENT, 
        parcelaId INTEGER NOT NULL, 
        cap REAL NOT NULL, 
        altura REAL, 
        linha INTEGER NOT NULL, 
        posicaoNaLinha INTEGER NOT NULL, 
        fimDeLinha INTEGER NOT NULL, 
        dominante INTEGER NOT NULL, 
        status TEXT NOT NULL, 
        status2 TEXT,
        observacao TEXT,
        capAuditoria REAL,
        alturaAuditoria REAL,
        FOREIGN KEY (parcelaId) REFERENCES parcelas (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE cubagens_arvores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        identificador TEXT NOT NULL,
        alturaTotal REAL NOT NULL,
        tipoMedidaCAP TEXT NOT NULL,
        valorCAP REAL NOT NULL,
        alturaBase REAL NOT NULL,
        classe TEXT,
        id_fazenda TEXT,
        nome_fazenda TEXT,
        nome_talhao TEXT,
        exportada INTEGER DEFAULT 0 NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE cubagens_secoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT, cubagemArvoreId INTEGER NOT NULL, alturaMedicao REAL NOT NULL, circunferencia REAL, casca1_mm REAL, casca2_mm REAL, FOREIGN KEY (cubagemArvoreId) REFERENCES cubagens_arvores (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE talhoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        idFazenda TEXT,
        nomeFazenda TEXT NOT NULL,
        nomeTalhao TEXT NOT NULL,
        areaHa REAL,
        idadeAnos REAL,
        UNIQUE(nomeFazenda, nomeTalhao)
      )
    ''');

    await db.execute('CREATE INDEX idx_arvores_parcelaId ON arvores(parcelaId)');
    await db.execute('CREATE INDEX idx_cubagens_secoes_cubagemArvoreId ON cubagens_secoes(cubagemArvoreId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) { 
        await db.execute('''CREATE TABLE arvores (id INTEGER PRIMARY KEY AUTOINCREMENT, parcelaId INTEGER NOT NULL, cap REAL NOT NULL, altura REAL, linha INTEGER NOT NULL, posicaoNaLinha INTEGER NOT NULL, fimDeLinha INTEGER NOT NULL, dominante INTEGER NOT NULL, status TEXT NOT NULL, FOREIGN KEY (parcelaId) REFERENCES parcelas (id) ON DELETE CASCADE)''');
    }
    if (oldVersion < 4) { try { await db.execute('ALTER TABLE arvores ADD COLUMN status2 TEXT'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); } }
    if (oldVersion < 5) { await db.execute('DROP TABLE IF EXISTS fustes'); }
    if (oldVersion < 6) { try { await db.execute('ALTER TABLE parcelas ADD COLUMN exportada INTEGER DEFAULT 0 NOT NULL'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); } }
    if (oldVersion < 7) { try { await db.execute('''CREATE TABLE cubagens_arvores(id INTEGER PRIMARY KEY AUTOINCREMENT, identificador TEXT NOT NULL, alturaTotal REAL NOT NULL, tipoMedidaCAP TEXT NOT NULL, valorCAP REAL NOT NULL, alturaBase REAL NOT NULL, classe TEXT)'''); } catch(e) { debugPrint("Migration Error (ignorable): $e"); } }
    if (oldVersion < 8) {
      await db.execute('DROP TABLE IF EXISTS cubagens_secoes');
      await db.execute('''CREATE TABLE cubagens_secoes(id INTEGER PRIMARY KEY AUTOINCREMENT, cubagemArvoreId INTEGER NOT NULL, alturaMedicao REAL NOT NULL, circunferencia REAL, casca1_mm REAL, casca2_mm REAL, FOREIGN KEY (cubagemArvoreId) REFERENCES cubagens_arvores (id) ON DELETE CASCADE)''');
      await db.execute('CREATE INDEX idx_cubagens_secoes_cubagemArvoreId ON cubagens_secoes(cubagemArvoreId)');
    }
    if (oldVersion < 9) {
      try { await db.execute('ALTER TABLE parcelas ADD COLUMN idFazenda TEXT'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); }
      try { await db.execute('ALTER TABLE parcelas ADD COLUMN largura REAL'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); }
      try { await db.execute('ALTER TABLE parcelas ADD COLUMN comprimento REAL'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); }
      try { await db.execute('ALTER TABLE parcelas ADD COLUMN raio REAL'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); }
    }
    if (oldVersion < 10) {
      try { await db.execute('ALTER TABLE cubagens_arvores ADD COLUMN id_fazenda TEXT'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); }
      try { await db.execute('ALTER TABLE cubagens_arvores ADD COLUMN nome_fazenda TEXT'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); }
      try { await db.execute('ALTER TABLE cubagens_arvores ADD COLUMN nome_talhao TEXT'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); }
    }
    if (oldVersion < 12) {
      try { await db.execute('ALTER TABLE cubagens_arvores ADD COLUMN exportada INTEGER DEFAULT 0 NOT NULL;'); } catch (e) { debugPrint("Migration Error (ignorable): $e"); }
    }
    if (oldVersion < 13) {
      try {
        await db.execute('ALTER TABLE parcelas ADD COLUMN isSynced INTEGER DEFAULT 0 NOT NULL;');
        debugPrint('Coluna "isSynced" adicionada à tabela "parcelas" com sucesso.');
      } catch (e) {
        debugPrint('Erro ao adicionar coluna isSynced (pode já existir): $e');
      }
    }
    if (oldVersion < 14) {
      try {
        await db.execute('''
          CREATE TABLE talhoes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            idFazenda TEXT,
            nomeFazenda TEXT NOT NULL,
            nomeTalhao TEXT NOT NULL,
            areaHa REAL,
            idadeAnos REAL,
            UNIQUE(nomeFazenda, nomeTalhao)
          )
        ''');
        debugPrint('Tabela "talhoes" criada com sucesso na migração.');
      } catch (e) {
        debugPrint('Erro ao criar a tabela "talhoes" (pode já existir): $e');
      }
    }
    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE arvores ADD COLUMN observacao TEXT;');
        debugPrint('Coluna "observacao" adicionada à tabela "arvores" com sucesso.');
      } catch (e) {
        debugPrint('Erro ao adicionar coluna observacao (pode já existir): $e');
      }
    }
    if (oldVersion < 16) {
      try {
        await db.execute('ALTER TABLE arvores ADD COLUMN capAuditoria REAL;');
        await db.execute('ALTER TABLE arvores ADD COLUMN alturaAuditoria REAL;');
        debugPrint('Colunas de auditoria adicionadas à tabela "arvores" com sucesso.');
      } catch (e) {
        debugPrint('Erro ao adicionar colunas de auditoria (podem já existir): $e');
      }
    }
    // <<< MUDANÇA: ADICIONANDO A NOVA MIGRAÇÃO >>>
    if (oldVersion < 17) {
      try {
        await db.execute('ALTER TABLE parcelas ADD COLUMN idadeFloresta REAL;');
        await db.execute('ALTER TABLE parcelas ADD COLUMN areaTalhao REAL;');
        debugPrint('Colunas idadeFloresta e areaTalhao adicionadas à tabela "parcelas".');
      } catch (e) {
        debugPrint('Erro ao adicionar colunas de info adicionais (podem já existir): $e');
      }
    }
  }

  Future<List<Parcela>> getUnsyncedParcelas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parcelas',
      where: 'isSynced = ?',
      whereArgs: [0],
    );
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<void> markParcelaAsSynced(int id) async {
    final db = await database;
    await db.update(
      'parcelas',
      {'isSynced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    debugPrint('Parcela ID: $id marcada como sincronizada (isSynced=1).');
  }

  Future<void> limparTodasAsParcelas() async {
    final db = await database;
    await db.delete('parcelas');
    debugPrint('Tabela de parcelas e árvores limpa.');
  }

  Future<void> saveBatchParcelas(List<Parcela> parcelas) async {
    final db = await database;
    final batch = db.batch();
    for (final parcela in parcelas) {
      batch.insert('parcelas', parcela.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Parcela>> getParcelasByProject(String nomeFazenda, String nomeTalhao) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('parcelas', where: 'nomeFazenda = ? AND nomeTalhao = ?', whereArgs: [nomeFazenda, nomeTalhao]);
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<Parcela?> getParcelaById(int id) async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      return Parcela.fromMap(maps.first);
    }
    return null;
  }

  Future<Parcela> saveFullColeta(Parcela parcela, List<Arvore> arvores) async {
    final db = await database;
    await db.transaction((txn) async {
      int parcelaId;
      parcela.isSynced = false; 
      final parcelaMap = parcela.toMap();
      final dataColetaAtual = parcela.dataColeta ?? DateTime.now();
      parcelaMap['dataColeta'] = dataColetaAtual.toIso8601String();

      if (parcela.dbId == null) {
        parcelaMap.remove('id');
        parcelaId = await txn.insert('parcelas', parcelaMap);
        parcela.dbId = parcelaId;
        parcela.dataColeta = dataColetaAtual;
      } else {
        parcelaId = parcela.dbId!;
        await txn.update('parcelas', parcelaMap, where: 'id = ?', whereArgs: [parcelaId]);
      }
      await txn.delete('arvores', where: 'parcelaId = ?', whereArgs: [parcelaId]);
      for (final arvore in arvores) {
        final arvoreMap = arvore.toMap();
        arvoreMap['parcelaId'] = parcelaId;
        await txn.insert('arvores', arvoreMap);
      }
    });
    return parcela;
  }

  Future<List<Arvore>> getArvoresDaParcela(int parcelaId) async {
    final db = await database;
    final List<Map<String, dynamic>> arvoresMaps = await db.query('arvores', where: 'parcelaId = ?', whereArgs: [parcelaId], orderBy: 'linha, posicaoNaLinha, id');
    return List.generate(arvoresMaps.length, (i) => Arvore.fromMap(arvoresMaps[i]));
  }

  Future<List<Parcela>> getTodasParcelas() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('parcelas', orderBy: 'dataColeta DESC');
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<int> deleteParcela(int id) async {
    final db = await database;
    return await db.delete('parcelas', where: 'id = ?', whereArgs: [id]);
  }
  
  Future<void> deletarMultiplasParcelas(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.delete(
      'parcelas',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<int> updateParcela(Parcela parcela) async {
    final db = await database;
    return await db.update('parcelas', parcela.toMap(), where: 'id = ?', whereArgs: [parcela.dbId]);
  }
  
  Future<int> limparParcelasExportadas() async {
    final db = await database;
    final count = await db.delete('parcelas', where: 'exportada = ?', whereArgs: [1]);
    debugPrint('$count parcelas exportadas foram apagadas.');
    return count;
  }

  Future<Map<String, List<String>>> getProjetosDisponiveis() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'parcelas',
      columns: ['nomeFazenda', 'nomeTalhao'],
      where: 'status = ?',
      whereArgs: [StatusParcela.concluida.name], 
      distinct: true, 
      orderBy: 'nomeFazenda, nomeTalhao',
    );

    final Map<String, List<String>> projetos = {};
    for (final map in maps) {
      final nomeFazenda = map['nomeFazenda'] as String;
      final nomeTalhao = map['nomeTalhao'] as String;
      if (!projetos.containsKey(nomeFazenda)) {
        projetos[nomeFazenda] = [];
      }
      projetos[nomeFazenda]!.add(nomeTalhao);
    }
    return projetos;
  }

  Future<List<Parcela>> getParcelasComArvores(String nomeFazenda, String nomeTalhao) async {
    final db = await database;
    final List<Map<String, dynamic>> parcelasMaps = await db.query(
      'parcelas',
      where: 'nomeFazenda = ? AND nomeTalhao = ?',
      whereArgs: [nomeFazenda, nomeTalhao],
    );

    if (parcelasMaps.isEmpty) {
      return [];
    }
    
    List<Parcela> parcelas = parcelasMaps.map((map) => Parcela.fromMap(map)).toList();

    for (var parcela in parcelas) {
      if (parcela.dbId != null) {
        final List<Arvore> arvores = await getArvoresDaParcela(parcela.dbId!);
        parcela.arvores = arvores;
      }
    }
    
    return parcelas;
  }

  Future<Map<String, dynamic>> getDadosAgregadosDoTalhao(String nomeFazenda, String nomeTalhao) async {
    final List<Parcela> parcelas = await getParcelasByProject(nomeFazenda, nomeTalhao);
    final List<Parcela> parcelasConcluidas = parcelas.where((p) => p.status == StatusParcela.concluida).toList();

    final List<Arvore> todasAsArvores = [];
    for (final parcela in parcelasConcluidas) {
      if (parcela.dbId != null) {
        final arvoresDaParcela = await getArvoresDaParcela(parcela.dbId!);
        todasAsArvores.addAll(arvoresDaParcela);
      }
    }

    return {
      'parcelas': parcelasConcluidas,
      'arvores': todasAsArvores,
    };
  }

  Future<void> limparTodasAsCubagens() async {
    final db = await database;
    await db.delete('cubagens_arvores');
    debugPrint('Tabela de cubagens e seções limpa.');
  }

  Future<void> salvarCubagemCompleta(CubagemArvore arvore, List<CubagemSecao> secoes) async {
    final db = await database;
    await db.transaction((txn) async {
      int arvoreId;
      final dbMap = arvore.toMap();
      if (arvore.id == null) {
        arvoreId = await txn.insert('cubagens_arvores', dbMap);
        arvore.id = arvoreId;
      } else {
        arvoreId = arvore.id!;
        await txn.update('cubagens_arvores', dbMap, where: 'id = ?', whereArgs: [arvoreId]);
      }
      await txn.delete('cubagens_secoes', where: 'cubagemArvoreId = ?', whereArgs: [arvoreId]);
      for (var secao in secoes) {
        secao.cubagemArvoreId = arvoreId;
        await txn.insert('cubagens_secoes', secao.toMap());
      }
    });
  }

  Future<List<CubagemArvore>> getTodasCubagens() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cubagens_arvores', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => CubagemArvore.fromMap(maps[i]));
  }

  Future<List<CubagemSecao>> getSecoesPorArvoreId(int arvoreId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('cubagens_secoes', where: 'cubagemArvoreId = ?', whereArgs: [arvoreId], orderBy: 'alturaMedicao ASC');
    return List.generate(maps.length, (i) => CubagemSecao.fromMap(maps[i]));
  }

  Future<void> deletarCubagem(int id) async {
    final db = await database;
    await db.delete('cubagens_arvores', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletarMultiplasCubagens(List<int> ids) async {
    if (ids.isEmpty) return;
    final db = await database;
    await db.delete(
      'cubagens_arvores',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<void> exportarUmaCubagem(BuildContext context, int arvoreId) async {
    final db = await database;
    final List<Map<String, dynamic>> arvoreMaps = await db.query('cubagens_arvores', where: 'id = ?', whereArgs: [arvoreId]);

    if (arvoreMaps.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Árvore não encontrada.')));
      return;
    }
    
    final arvore = CubagemArvore.fromMap(arvoreMaps.first);
    final secoes = await getSecoesPorArvoreId(arvore.id!);

    List<List<dynamic>> rows = [];
    rows.add(['id_fazenda', 'fazenda', 'talhao', 'identificador_arvore', 'altura_total_m', 'tipo_medida_cap', 'valor_cap_cm', 'altura_base_m', 'altura_medicao_m', 'circunferencia_cm', 'casca1_mm', 'casca2_mm', 'diametro_cc_cm', 'diametro_sc_cm']);
    
    if (secoes.isEmpty) {
      rows.add([arvore.idFazenda, arvore.nomeFazenda, arvore.nomeTalhao, arvore.identificador, arvore.alturaTotal, arvore.tipoMedidaCAP, arvore.valorCAP, arvore.alturaBase, null, null, null, null, null, null]);
    } else {
      for (var secao in secoes) {
        rows.add([ arvore.idFazenda, arvore.nomeFazenda, arvore.nomeTalhao, arvore.identificador, arvore.alturaTotal, arvore.tipoMedidaCAP, arvore.valorCAP, arvore.alturaBase, secao.alturaMedicao, secao.circunferencia, secao.casca1_mm, secao.casca2_mm, secao.diametroComCasca.toStringAsFixed(2), secao.diametroSemCasca.toStringAsFixed(2) ]);
      }
    }

    final csvData = const ListToCsvConverter().convert(rows);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final nomePastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDoDia = Directory('${directory.path}/$nomePastaData');
      if (!await pastaDoDia.exists()) await pastaDoDia.create(recursive: true);
      final sanitizedId = arvore.identificador.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_');
      final fileName = 'Cubagem_${sanitizedId}_${DateFormat('HH-mm-ss').format(hoje)}.csv';
      final path = '${pastaDoDia.path}/$fileName';
      await File(path).writeAsString(csvData);
      if (context.mounted) {
        await Share.shareXFiles([XFile(path)], subject: 'Exportação de Cubagem: ${arvore.identificador}');
      }
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
    }
  }

  Future<Map<String, double>> getDistribuicaoPorStatus(int parcelaId) async {
    final db = await database;
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT status, COUNT(*) as total
      FROM arvores
      WHERE parcelaId = ?
      GROUP BY status
    ''', [parcelaId]);

    if (result.isEmpty) return {};
    return { for (var row in result) row['status']: (row['total'] as int).toDouble() };
  }

  Future<List<double>> getValoresCAP(int parcelaId) async {
      final db = await database;
      final List<Map<String, dynamic>> result = await db.rawQuery(
          'SELECT cap FROM arvores WHERE parcelaId = ?', [parcelaId]
      );
      if (result.isEmpty) return [];
      return result.map((row) => row['cap'] as double).toList();
  }

  Future<void> exportarDados(BuildContext context) async {
    final tipoExportacao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Coletas de Parcela'),
        content: const Text('Selecione o tipo de exportação:'),
        actions: [
          TextButton(
            child: const Text('Novas Concluídas'),
            onPressed: () => Navigator.pop(context, 'novas_concluidas'),
          ),
          TextButton(
            child: const Text('Re-exportar Todas Concluídas'),
            onPressed: () => Navigator.pop(context, 'todas_concluidas'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancelar'),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (tipoExportacao == null || tipoExportacao == 'cancelar' || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando dados para exportação...')));

    try {
      final db = await database;
      final List<Map<String, dynamic>> parcelasMaps;

      if (tipoExportacao == 'novas_concluidas') {
        parcelasMaps = await db.query(
          'parcelas',
          where: 'status = ? AND exportada = ?',
          whereArgs: [StatusParcela.concluida.name, 0],
        );
      } else {
        parcelasMaps = await db.query(
          'parcelas',
          where: 'status = ?',
          whereArgs: [StatusParcela.concluida.name],
        );
      }

      if (parcelasMaps.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Nenhuma parcela encontrada para este critério.'),
            backgroundColor: Colors.orange,
          ));
        }
        return;
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo CSV...')));
      }

      final prefs = await SharedPreferences.getInstance();
      final nomeLider = prefs.getString('nome_lider') ?? 'N/A';
      final nomesAjudantes = prefs.getString('nomes_ajudantes') ?? 'N/A';
      final nomeZona = prefs.getString('zona_utm_selecionada') ?? 'SIRGAS 2000 / UTM Zona 22S';
      final codigoEpsg = zonasUtmSirgas2000[nomeZona]!;
      final projWGS84 = proj4.Projection.get('EPSG:4326')!;
      final projUTM = proj4.Projection.get('EPSG:$codigoEpsg')!;

      List<List<dynamic>> rows = [];
      rows.add([ 'Lider_Equipe', 'Ajudantes', 'ID_Db_Parcela', 'Codigo_Fazenda', 'Fazenda', 'Talhao', 'ID_Coleta_Parcela', 'Area_m2', 'Largura_m', 'Comprimento_m', 'Raio_m', 'Espacamento', 'Observacao_Parcela', 'Easting', 'Northing', 'Data_Coleta', 'Status_Parcela', 'Linha', 'Posicao_na_Linha', 'Fuste_Num', 'Status_Arvore', 'Status_Arvore_2', 'CAP_cm', 'Altura_m', 'Dominante' ]);

      List<int> idsParaMarcar = [];
      for (var parcelaMap in parcelasMaps) {
        idsParaMarcar.add(parcelaMap['id'] as int);
        String easting = '', northing = '';
        if (parcelaMap['latitude'] != null && parcelaMap['longitude'] != null) {
          var pontoUtm = projWGS84.transform(projUTM, proj4.Point(x: parcelaMap['longitude'] as double, y: parcelaMap['latitude'] as double));
          easting = pontoUtm.x.toStringAsFixed(2);
          northing = pontoUtm.y.toStringAsFixed(2);
        }
        final List<Arvore> arvores = await getArvoresDaParcela(parcelaMap['id'] as int);
        if (arvores.isEmpty) {
          rows.add([ nomeLider, nomesAjudantes, parcelaMap['id'], parcelaMap['idFazenda'], parcelaMap['nomeFazenda'], parcelaMap['nomeTalhao'], parcelaMap['idParcela'], parcelaMap['areaMetrosQuadrados'], parcelaMap['largura'], parcelaMap['comprimento'], parcelaMap['raio'], parcelaMap['espacamento'], parcelaMap['observacao'], easting, northing, parcelaMap['dataColeta'], parcelaMap['status'], null, null, null, null, null, null, null, null ]);
        } else {
          Map<String, int> fusteCounter = {};
          for (final arvore in arvores) {
            String posKey = '${arvore.linha}-${arvore.posicaoNaLinha}';
            fusteCounter[posKey] = (fusteCounter[posKey] ?? 0) + 1;
            rows.add([ nomeLider, nomesAjudantes, parcelaMap['id'], parcelaMap['idFazenda'], parcelaMap['nomeFazenda'], parcelaMap['nomeTalhao'], parcelaMap['idParcela'], parcelaMap['areaMetrosQuadrados'], parcelaMap['largura'], parcelaMap['comprimento'], parcelaMap['raio'], parcelaMap['espacamento'], parcelaMap['observacao'], easting, northing, parcelaMap['dataColeta'], parcelaMap['status'], arvore.linha, arvore.posicaoNaLinha, fusteCounter[posKey], arvore.codigo.name, arvore.codigo2?.name, arvore.cap, arvore.altura, arvore.dominante ? 'Sim' : 'Não' ]);
          }
        }
      }

      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final nomePastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDoDia = Directory('${directory.path}/$nomePastaData');
      if (!await pastaDoDia.exists()) await pastaDoDia.create(recursive: true);

      final fileName = 'geoforest_export_parcelas_${DateFormat('HH-mm-ss').format(hoje)}.csv';
      final path = '${pastaDoDia.path}/$fileName';
      await File(path).writeAsString(const ListToCsvConverter().convert(rows));

      await db.update('parcelas', {'exportada': 1}, where: 'id IN (${idsParaMarcar.map((_) => '?').join(',')})', whereArgs: idsParaMarcar);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(path)], subject: 'Exportação GeoForest');
      }

    } catch (e, s) {
      debugPrint('Erro na exportação de parcelas: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na exportação: ${e.toString()}'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> exportarCubagens(BuildContext context) async {
    final tipoExportacao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Cubagens'),
        content: const Text('Selecione o tipo de exportação:'),
        actions: [
          TextButton(
            child: const Text('Exportar Novas'),
            onPressed: () => Navigator.pop(context, 'novas'),
          ),
          TextButton(
            child: const Text('Re-exportar Todas'),
            onPressed: () => Navigator.pop(context, 'todas'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancelar'),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
    if (tipoExportacao == null || tipoExportacao == 'cancelar' || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buscando dados de cubagem...')));
    
    try {
      final db = await database;
      final List<Map<String, dynamic>> arvoresMaps;

      if (tipoExportacao == 'novas') {
        arvoresMaps = await db.query('cubagens_arvores', where: 'exportada = ?', whereArgs: [0]);
      } else {
        arvoresMaps = await db.query('cubagens_arvores');
      }
      
      if (arvoresMaps.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma cubagem para exportar neste critério.'), backgroundColor: Colors.orange));
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo CSV de cubagens...')));
      }
      
      List<CubagemArvore> arvores = arvoresMaps.map((map) => CubagemArvore.fromMap(map)).toList();
      List<int> idsParaMarcar = [];

      List<List<dynamic>> rows = [];
      rows.add(['id_arvore_db', 'id_fazenda', 'fazenda', 'talhao', 'identificador_arvore', 'altura_total_m', 'cap_cm', 'altura_medicao_m', 'circunferencia_cm', 'casca1_mm', 'casca2_mm', 'diametro_cc_cm', 'diametro_sc_cm']);
      
      for (var arvore in arvores) {
        idsParaMarcar.add(arvore.id!);
        final secoes = await getSecoesPorArvoreId(arvore.id!);
        if (secoes.isEmpty) {
          rows.add([arvore.id, arvore.idFazenda, arvore.nomeFazenda, arvore.nomeTalhao, arvore.identificador, arvore.alturaTotal, arvore.valorCAP, null, null, null, null, null, null]);
        } else {
          for (var secao in secoes) {
            rows.add([ arvore.id, arvore.idFazenda, arvore.nomeFazenda, arvore.nomeTalhao, arvore.identificador, arvore.alturaTotal, arvore.valorCAP, secao.alturaMedicao, secao.circunferencia, secao.casca1_mm, secao.casca2_mm, secao.diametroComCasca.toStringAsFixed(2), secao.diametroSemCasca.toStringAsFixed(2) ]);
          }
        }
      }
      
      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final nomePastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDoDia = Directory('${directory.path}/$nomePastaData');
      if (!await pastaDoDia.exists()) await pastaDoDia.create(recursive: true);
      final fileName = 'geoforest_export_cubagens_${DateFormat('HH-mm-ss').format(hoje)}.csv';
      final path = '${pastaDoDia.path}/$fileName';
      final csvData = const ListToCsvConverter().convert(rows);
      await File(path).writeAsString(csvData);

      await db.update('cubagens_arvores', {'exportada': 1}, where: 'id IN (${idsParaMarcar.map((_) => '?').join(',')})', whereArgs: idsParaMarcar);

      if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          await Share.shareXFiles([XFile(path)], subject: 'Exportação de Cubagens');
      }
    } catch (e, s) {
        debugPrint('Erro na exportação de cubagens: $e\n$s');
        if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na exportação de cubagens: ${e.toString()}'), backgroundColor: Colors.red));
        }
    }
  }
}