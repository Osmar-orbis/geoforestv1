// lib/data/datasources/local/database_helper.dart

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
      version: 9, // <<< VERSÃO INCREMENTADA
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
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
        raio REAL
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
        classe TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE cubagens_secoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cubagemArvoreId INTEGER NOT NULL,
        alturaMedicao REAL NOT NULL,
        circunferencia REAL,
        casca1_mm REAL,
        casca2_mm REAL,
        FOREIGN KEY (cubagemArvoreId) REFERENCES cubagens_arvores (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_arvores_parcelaId ON arvores(parcelaId)');
    await db.execute('CREATE INDEX idx_cubagens_secoes_cubagemArvoreId ON cubagens_secoes(cubagemArvoreId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migração para criar a tabela 'arvores' se ela não existir em versões muito antigas
    if (oldVersion < 2) { 
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
            FOREIGN KEY (parcelaId) REFERENCES parcelas (id) ON DELETE CASCADE
          )
        ''');
    }
    if (oldVersion < 4) { try { await db.execute('ALTER TABLE arvores ADD COLUMN status2 TEXT'); } catch (e) { print(e); } }
    if (oldVersion < 5) { await db.execute('DROP TABLE IF EXISTS fustes'); }
    if (oldVersion < 6) { await db.execute('ALTER TABLE parcelas ADD COLUMN exportada INTEGER DEFAULT 0 NOT NULL'); }
    if (oldVersion < 7) { await db.execute('''CREATE TABLE cubagens_arvores(id INTEGER PRIMARY KEY AUTOINCREMENT, identificador TEXT NOT NULL, alturaTotal REAL NOT NULL, tipoMedidaCAP TEXT NOT NULL, valorCAP REAL NOT NULL, alturaBase REAL NOT NULL, classe TEXT)'''); }
    if (oldVersion < 8) {
      await db.execute('DROP TABLE IF EXISTS cubagens_secoes');
      await db.execute('''CREATE TABLE cubagens_secoes(id INTEGER PRIMARY KEY AUTOINCREMENT, cubagemArvoreId INTEGER NOT NULL, alturaMedicao REAL NOT NULL, circunferencia REAL, casca1_mm REAL, casca2_mm REAL, FOREIGN KEY (cubagemArvoreId) REFERENCES cubagens_arvores (id) ON DELETE CASCADE)''');
      await db.execute('CREATE INDEX idx_cubagens_secoes_cubagemArvoreId ON cubagens_secoes(cubagemArvoreId)');
    }
    if (oldVersion < 9) {
      try { await db.execute('ALTER TABLE parcelas ADD COLUMN idFazenda TEXT'); } catch (e) { print(e); }
      try { await db.execute('ALTER TABLE parcelas ADD COLUMN largura REAL'); } catch (e) { print(e); }
      try { await db.execute('ALTER TABLE parcelas ADD COLUMN comprimento REAL'); } catch (e) { print(e); }
      try { await db.execute('ALTER TABLE parcelas ADD COLUMN raio REAL'); } catch (e) { print(e); }
    }
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
    final List<Map<String, dynamic>> maps = await db.query(
      'parcelas',
      where: 'nomeFazenda = ? AND nomeTalhao = ?',
      whereArgs: [nomeFazenda, nomeTalhao],
    );
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

  Future<int> updateParcela(Parcela parcela) async {
    final db = await database;
    return await db.update('parcelas', parcela.toMap(), where: 'id = ?', whereArgs: [parcela.dbId]);
  }

  Future<void> exportarDados(BuildContext context) async {
    final tipoExportacao = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exportar Coletas de Parcela'),
        content: const Text('Quais parcelas você deseja exportar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, 'nao_exportadas'), child: const Text('Apenas Novas')),
          TextButton(onPressed: () => Navigator.pop(context, 'todas'), child: const Text('Exportar Tudo')),
          TextButton(onPressed: () => Navigator.pop(context, 'cancelar'), child: const Text('Cancelar', style: TextStyle(color: Colors.grey))),
        ],
      ),
    );
    if (tipoExportacao == null || tipoExportacao == 'cancelar') return;

    final db = await database;
    final List<Map<String, dynamic>> parcelasMaps = (tipoExportacao == 'nao_exportadas')
      ? await db.query('parcelas', where: 'exportada = 0')
      : await db.query('parcelas');

    if (parcelasMaps.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma parcela para exportar neste critério.'), backgroundColor: Colors.orange));
      }
      return;
    }

    try {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo CSV de parcelas...')));
      
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
            rows.add([ nomeLider, nomesAjudantes, parcelaMap['id'], parcelaMap['idFazenda'], parcelaMap['nomeFazenda'], parcelaMap['nomeTalhao'], parcelaMap['idParcela'], parcelaMap['areaMetrosQuadrados'], parcelaMap['largura'], parcelaMap['comprimento'], parcelaMap['raio'], parcelaMap['espacamento'], parcelaMap['observacao'], easting, northing, parcelaMap['dataColeta'], parcelaMap['status'], arvore.linha, arvore.posicaoNaLinha, fusteCounter[posKey], arvore.status.name, arvore.status2?.name, arvore.cap, arvore.altura, arvore.dominante ? 'Sim' : 'Não' ]);
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

      if (tipoExportacao == 'nao_exportadas') {
         await db.update('parcelas', {'exportada': 1}, where: 'id IN (${idsParaMarcar.map((_) => '?').join(',')})', whereArgs: idsParaMarcar);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(path)], subject: 'Exportação GeoForest');
      }
    } catch (e, s) {
      debugPrint('Erro na exportação de parcelas: $e\n$s');
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na exportação: ${e.toString()}'), backgroundColor: Colors.red));
    }
  }

  Future<int> limparParcelasExportadas() async {
    final db = await database;
    final count = await db.delete('parcelas', where: 'exportada = ?', whereArgs: [1]);
    debugPrint('$count parcelas exportadas foram apagadas.');
    return count;
  }

  // --- MÉTODOS DE CUBAGEM ---
  Future<void> salvarCubagemCompleta(CubagemArvore arvore, List<CubagemSecao> secoes) async {
    final db = await database;
    await db.transaction((txn) async {
      int arvoreId;
      if (arvore.id == null) {
        arvoreId = await txn.insert('cubagens_arvores', arvore.toMap());
        arvore.id = arvoreId;
      } else {
        arvoreId = arvore.id!;
        await txn.update('cubagens_arvores', arvore.toMap(), where: 'id = ?', whereArgs: [arvoreId]);
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
    final List<Map<String, dynamic>> maps = await db.query(
      'cubagens_secoes',
      where: 'cubagemArvoreId = ?',
      whereArgs: [arvoreId],
      orderBy: 'alturaMedicao ASC',
    );
    return List.generate(maps.length, (i) => CubagemSecao.fromMap(maps[i]));
  }

  Future<void> deletarCubagem(int id) async {
    final db = await database;
    await db.delete('cubagens_arvores', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> exportarCubagens(BuildContext context) async {
    final List<CubagemArvore> arvores = await getTodasCubagens();
    if (arvores.isEmpty) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma cubagem para exportar.')));
      return;
    }

    List<List<dynamic>> rows = [];
    rows.add(['id_arvore_db', 'identificador_arvore', 'altura_total_m', 'cap_cm', 'altura_medicao_m', 'circunferencia_cm', 'casca1_mm', 'casca2_mm', 'diametro_cc_cm', 'diametro_sc_cm']);
    for (var arvore in arvores) {
      final secoes = await getSecoesPorArvoreId(arvore.id!);
      if (secoes.isEmpty) {
         rows.add([arvore.id, arvore.identificador, arvore.alturaTotal, arvore.valorCAP, null, null, null, null, null, null]);
      } else {
        for (var secao in secoes) {
          rows.add([ arvore.id, arvore.identificador, arvore.alturaTotal, arvore.valorCAP, secao.alturaMedicao, secao.circunferencia, secao.casca1_mm, secao.casca2_mm, secao.diametroComCasca.toStringAsFixed(2), secao.diametroSemCasca.toStringAsFixed(2) ]);
        }
      }
    }

    try {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gerando arquivo CSV de cubagens...')));
      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final nomePastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDoDia = Directory('${directory.path}/$nomePastaData');
      if (!await pastaDoDia.exists()) await pastaDoDia.create(recursive: true);
      final fileName = 'geoforest_export_cubagens_${DateFormat('HH-mm-ss').format(hoje)}.csv';
      final path = '${pastaDoDia.path}/$fileName';
      final csvData = const ListToCsvConverter().convert(rows);
      await File(path).writeAsString(csvData);
      if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          await Share.shareXFiles([XFile(path)], subject: 'Exportação de Todas as Cubagens');
      }
    } catch (e, s) {
        debugPrint('Erro na exportação de cubagens: $e\n$s');
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Falha na exportação de cubagens: ${e.toString()}'), backgroundColor: Colors.red));
    }
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
    rows.add(['identificador_arvore', 'altura_total_m', 'tipo_medida_cap', 'valor_cap_cm', 'altura_base_m', 'altura_medicao_m', 'circunferencia_cm', 'casca1_mm', 'casca2_mm', 'diametro_cc_cm', 'diametro_sc_cm']);
    if (secoes.isEmpty) {
      rows.add([arvore.identificador, arvore.alturaTotal, arvore.tipoMedidaCAP, arvore.valorCAP, arvore.alturaBase, null, null, null, null, null, null]);
    } else {
      for (var secao in secoes) {
        rows.add([ arvore.identificador, arvore.alturaTotal, arvore.tipoMedidaCAP, arvore.valorCAP, arvore.alturaBase, secao.alturaMedicao, secao.circunferencia, secao.casca1_mm, secao.casca2_mm, secao.diametroComCasca.toStringAsFixed(2), secao.diametroSemCasca.toStringAsFixed(2) ]);
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
}