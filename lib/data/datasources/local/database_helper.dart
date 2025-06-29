// lib/data/datasources/local/database_helper.dart

import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// Imports para a nova hierarquia
import 'package:geoforestcoletor/models/projeto_model.dart';
import 'package:geoforestcoletor/models/atividade_model.dart';
import 'package:geoforestcoletor/models/fazenda_model.dart';
import 'package:geoforestcoletor/models/talhao_model.dart';

// Imports de coleta
import 'package:geoforestcoletor/models/parcela_model.dart';
import 'package:geoforestcoletor/models/arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_arvore_model.dart';
import 'package:geoforestcoletor/models/cubagem_secao_model.dart';

// --- CONSTANTES DE PROJEÇÃO GEOGRÁFICA ---

const Map<String, int> zonasUtmSirgas2000 = {
  'SIRGAS 2000 / UTM Zona 18S': 31978,
  'SIRGAS 2000 / UTM Zona 19S': 31979,
  'SIRGAS 2000 / UTM Zona 20S': 31980,
  'SIRGAS 2000 / UTM Zona 21S': 31981,
  'SIRGAS 2000 / UTM Zona 22S': 31982,
  'SIRGAS 2000 / UTM Zona 23S': 31983,
  'SIRGAS 2000 / UTM Zona 24S': 31984,
  'SIRGAS 2000 / UTM Zona 25S': 31985,
};

final Map<int, String> proj4Definitions = {
  31978:
      '+proj=utm +zone=18 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31979:
      '+proj=utm +zone=19 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31980:
      '+proj=utm +zone=20 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31981:
      '+proj=utm +zone=21 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31982:
      '+proj=utm +zone=22 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31983:
      '+proj=utm +zone=23 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31984:
      '+proj=utm +zone=24 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
  31985:
      '+proj=utm +zone=25 +south +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs',
};

// --- CLASSE PRINCIPAL DO BANCO DE DADOS ---

class DatabaseHelper {
  // --- SINGLETON ---
  static final DatabaseHelper _instance = DatabaseHelper._privateConstructor();
  static Database? _database;

  DatabaseHelper._privateConstructor();
  factory DatabaseHelper() => _instance;
  static DatabaseHelper get instance => _instance;

  Future<Database> get database async => _database ??= await _initDatabase();

  // --- INICIALIZAÇÃO E CICLO DE VIDA DO BANCO ---

  Future<Database> _initDatabase() async {
    proj4.Projection.add('EPSG:4326', '+proj=longlat +datum=WGS84 +no_defs');
    proj4Definitions.forEach((epsg, def) {
      proj4.Projection.add('EPSG:$epsg', def);
    });

    return await openDatabase(
      join(await getDatabasesPath(), 'geoforestcoletor.db'),
      version: 20,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // Criação da estrutura de tabelas FINAL (v20) em novas instalações
    await db.execute('''
      CREATE TABLE projetos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        empresa TEXT NOT NULL,
        responsavel TEXT NOT NULL,
        dataCriacao TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE atividades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projetoId INTEGER NOT NULL,
        tipo TEXT NOT NULL,
        descricao TEXT NOT NULL,
        dataCriacao TEXT NOT NULL,
        FOREIGN KEY (projetoId) REFERENCES projetos (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE fazendas (
        id TEXT NOT NULL,
        atividadeId INTEGER NOT NULL,
        nome TEXT NOT NULL,
        municipio TEXT NOT NULL,
        estado TEXT NOT NULL,
        PRIMARY KEY (id, atividadeId),
        FOREIGN KEY (atividadeId) REFERENCES atividades (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE talhoes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fazendaId TEXT NOT NULL,
        fazendaAtividadeId INTEGER NOT NULL,
        nome TEXT NOT NULL,
        areaHa REAL,
        idadeAnos REAL,
        especie TEXT,
        FOREIGN KEY (fazendaId, fazendaAtividadeId) REFERENCES fazendas (id, atividadeId) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE parcelas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        talhaoId INTEGER,
        nomeFazenda TEXT,
        nomeTalhao TEXT,
        idParcela TEXT NOT NULL,
        areaMetrosQuadrados REAL NOT NULL,
        espacamento TEXT,
        observacao TEXT,
        latitude REAL,
        longitude REAL,
        dataColeta TEXT NOT NULL,
        status TEXT NOT NULL,
        exportada INTEGER DEFAULT 0 NOT NULL,
        isSynced INTEGER DEFAULT 0 NOT NULL,
        idFazenda TEXT,
        largura REAL,
        comprimento REAL,
        raio REAL,
        idadeFloresta REAL,
        areaTalhao REAL,
        FOREIGN KEY (talhaoId) REFERENCES talhoes (id) ON DELETE CASCADE
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
        codigo TEXT NOT NULL,
        codigo2 TEXT,
        observacao TEXT,
        capAuditoria REAL,
        alturaAuditoria REAL,
        FOREIGN KEY (parcelaId) REFERENCES parcelas (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE cubagens_arvores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        talhaoId INTEGER,
        id_fazenda TEXT,
        nome_fazenda TEXT,
        nome_talhao TEXT,
        identificador TEXT NOT NULL,
        alturaTotal REAL NOT NULL,
        tipoMedidaCAP TEXT NOT NULL,
        valorCAP REAL NOT NULL,
        alturaBase REAL NOT NULL,
        classe TEXT,
        exportada INTEGER DEFAULT 0 NOT NULL,
        FOREIGN KEY (talhaoId) REFERENCES talhoes (id) ON DELETE CASCADE
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
    await db.execute(
        'CREATE INDEX idx_cubagens_secoes_cubagemArvoreId ON cubagens_secoes(cubagemArvoreId)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var v = oldVersion + 1; v <= newVersion; v++) {
      debugPrint("Executando migração de banco de dados para a versão $v...");
      // A lógica de migração permanece a mesma, pois já estava correta.
      // O importante é que ela seja executada sequencialmente.
       switch (v) {
        case 18:
          await db.execute(
              '''CREATE TABLE IF NOT EXISTS projetos (id INTEGER PRIMARY KEY AUTOINCREMENT, nome TEXT NOT NULL, empresa TEXT NOT NULL, responsavel TEXT NOT NULL, dataCriacao TEXT NOT NULL)''');
          try {
            await db.execute(
                '''CREATE TABLE fazendas (id INTEGER PRIMARY KEY AUTOINCREMENT, projetoId INTEGER NOT NULL, nome TEXT NOT NULL, municipio TEXT NOT NULL, estado TEXT NOT NULL, FOREIGN KEY (projetoId) REFERENCES projetos (id) ON DELETE CASCADE)''');
          } catch (e) { /* Ignorável */ }
          break;
        case 19:
          await db.execute(
              '''CREATE TABLE atividades (id INTEGER PRIMARY KEY AUTOINCREMENT, projetoId INTEGER NOT NULL, tipo TEXT NOT NULL, descricao TEXT NOT NULL, dataCriacao TEXT NOT NULL, FOREIGN KEY (projetoId) REFERENCES projetos (id) ON DELETE CASCADE)''');
          await db.execute('DROP TABLE IF EXISTS fazendas');
          await db.execute('''
            CREATE TABLE fazendas (id INTEGER PRIMARY KEY AUTOINCREMENT, atividadeId INTEGER NOT NULL, nome TEXT NOT NULL, municipio TEXT NOT NULL, estado TEXT NOT NULL, FOREIGN KEY (atividadeId) REFERENCES atividades (id) ON DELETE CASCADE)
          ''');
          break;
        case 20:
          await db.execute('DROP TABLE IF EXISTS fazendas');
          await db.execute('''
            CREATE TABLE fazendas (
              id TEXT NOT NULL,
              atividadeId INTEGER NOT NULL,
              nome TEXT NOT NULL,
              municipio TEXT NOT NULL,
              estado TEXT NOT NULL,
              PRIMARY KEY (id, atividadeId),
              FOREIGN KEY (atividadeId) REFERENCES atividades (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('DROP TABLE IF EXISTS talhoes');
          await db.execute('''
            CREATE TABLE talhoes (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              fazendaId TEXT NOT NULL,
              fazendaAtividadeId INTEGER NOT NULL,
              nome TEXT NOT NULL,
              areaHa REAL,
              idadeAnos REAL,
              especie TEXT,
              FOREIGN KEY (fazendaId, fazendaAtividadeId) REFERENCES fazendas (id, atividadeId) ON DELETE CASCADE
            )
          ''');
          await db.execute('DROP TABLE IF EXISTS parcelas');
          await db.execute('''
            CREATE TABLE parcelas (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              talhaoId INTEGER,
              nomeFazenda TEXT,
              nomeTalhao TEXT,
              idParcela TEXT NOT NULL,
              areaMetrosQuadrados REAL NOT NULL,
              espacamento TEXT,
              observacao TEXT,
              latitude REAL,
              longitude REAL,
              dataColeta TEXT NOT NULL,
              status TEXT NOT NULL,
              exportada INTEGER DEFAULT 0 NOT NULL,
              isSynced INTEGER DEFAULT 0 NOT NULL,
              idFazenda TEXT,
              largura REAL,
              comprimento REAL,
              raio REAL,
              idadeFloresta REAL,
              areaTalhao REAL,
              FOREIGN KEY (talhaoId) REFERENCES talhoes (id) ON DELETE CASCADE
            )
          ''');
          await db.execute('DROP TABLE IF EXISTS cubagens_arvores');
          await db.execute('''
            CREATE TABLE cubagens_arvores (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              talhaoId INTEGER,
              id_fazenda TEXT,
              nome_fazenda TEXT,
              nome_talhao TEXT,
              identificador TEXT NOT NULL,
              alturaTotal REAL NOT NULL,
              tipoMedidaCAP TEXT NOT NULL,
              valorCAP REAL NOT NULL,
              alturaBase REAL NOT NULL,
              classe TEXT,
              exportada INTEGER DEFAULT 0 NOT NULL,
              FOREIGN KEY (talhaoId) REFERENCES talhoes (id) ON DELETE CASCADE
            )
          ''');
          break;
      }
    }
  }

  // --- MÉTODOS CRUD: HIERARQUIA ---

  Future<int> insertProjeto(Projeto p) async => await (await database).insert('projetos', p.toMap());
  Future<List<Projeto>> getTodosProjetos() async {
    final maps = await (await database).query('projetos', orderBy: 'dataCriacao DESC');
    return List.generate(maps.length, (i) => Projeto.fromMap(maps[i]));
  }
  Future<void> deleteProjeto(int id) async => await (await database).delete('projetos', where: 'id = ?', whereArgs: [id]);

  Future<int> insertAtividade(Atividade a) async => await (await database).insert('atividades', a.toMap());
  Future<List<Atividade>> getAtividadesDoProjeto(int projetoId) async {
    final maps = await (await database).query('atividades', where: 'projetoId = ?', whereArgs: [projetoId], orderBy: 'dataCriacao DESC');
    return List.generate(maps.length, (i) => Atividade.fromMap(maps[i]));
  }
  Future<void> deleteAtividade(int id) async => await (await database).delete('atividades', where: 'id = ?', whereArgs: [id]);

  Future<void> insertFazenda(Fazenda f) async {
    await (await database).insert('fazendas', f.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
  }
  Future<List<Fazenda>> getFazendasDaAtividade(int atividadeId) async {
    final maps = await (await database).query('fazendas', where: 'atividadeId = ?', whereArgs: [atividadeId], orderBy: 'nome');
    return List.generate(maps.length, (i) => Fazenda.fromMap(maps[i]));
  }
  Future<void> deleteFazenda(String id, int atividadeId) async {
    await (await database).delete('fazendas', where: 'id = ? AND atividadeId = ?', whereArgs: [id, atividadeId]);
  }

  Future<int> insertTalhao(Talhao t) async => await (await database).insert('talhoes', t.toMap());
  Future<List<Talhao>> getTalhoesDaFazenda(String fazendaId, int fazendaAtividadeId) async {
    final maps = await (await database).query('talhoes', where: 'fazendaId = ? AND fazendaAtividadeId = ?', whereArgs: [fazendaId, fazendaAtividadeId], orderBy: 'nome');
    return List.generate(maps.length, (i) => Talhao.fromMap(maps[i]));
  }
  Future<void> deleteTalhao(int id) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('cubagens_arvores', where: 'talhaoId = ?', whereArgs: [id]);
      await txn.delete('parcelas', where: 'talhaoId = ?', whereArgs: [id]);
      await txn.delete('talhoes', where: 'id = ?', whereArgs: [id]);
    });
  }

  Future<double> getAreaTotalTalhoesDaFazenda(String fazendaId, int fazendaAtividadeId) async {
    final result = await (await database).rawQuery('SELECT SUM(areaHa) as total FROM talhoes WHERE fazendaId = ? AND fazendaAtividadeId = ?', [fazendaId, fazendaAtividadeId]);
    if (result.isNotEmpty && result.first['total'] != null) {
      return (result.first['total'] as num).toDouble();
    }
    return 0.0;
  }

   Future<List<Talhao>> getTalhoesComParcelasConcluidas() async {
    final db = await database;
    // Seleciona distintos talhaoId da tabela de parcelas onde o status é concluído
    final maps = await db.rawQuery('''
      SELECT T.* FROM talhoes T
      INNER JOIN parcelas P ON T.id = P.talhaoId
      WHERE P.status = ?
      GROUP BY T.id
    ''', [StatusParcela.concluida.name]);
    
    return List.generate(maps.length, (i) => Talhao.fromMap(maps[i]));
  }

  // --- MÉTODOS CRUD: COLETA DE PARCELA E ÁRVORES ---

  Future<List<Parcela>> getParcelasDoTalhao(int talhaoId) async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'talhaoId = ?', whereArgs: [talhaoId], orderBy: 'dataColeta DESC');
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<List<Parcela>> getUnsyncedParcelas() async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'isSynced = ?', whereArgs: [0]);
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<void> markParcelaAsSynced(int id) async {
    final db = await database;
    await db.update('parcelas', {'isSynced': 1}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> limparTodasAsParcelas() async {
    await (await database).delete('parcelas');
    debugPrint('Tabela de parcelas e árvores limpa.');
  }

  Future<void> saveBatchParcelas(List<Parcela> parcelas) async {
    final db = await database;
    final batch = db.batch();
    for (final p in parcelas) {
      batch.insert('parcelas', p.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<Parcela> saveFullColeta(Parcela p, List<Arvore> arvores) async {
    final db = await database;
    await db.transaction((txn) async {
      int pId;
      p.isSynced = false;
      final pMap = p.toMap();
      final d = p.dataColeta ?? DateTime.now();
      pMap['dataColeta'] = d.toIso8601String();

      if (p.dbId == null) {
        pMap.remove('id');
        pId = await txn.insert('parcelas', pMap);
        p.dbId = pId;
        p.dataColeta = d;
      } else {
        pId = p.dbId!;
        await txn.update('parcelas', pMap, where: 'id = ?', whereArgs: [pId]);
      }

      await txn.delete('arvores', where: 'parcelaId = ?', whereArgs: [pId]);
      for (final a in arvores) {
        final aMap = a.toMap();
        aMap['parcelaId'] = pId;
        await txn.insert('arvores', aMap);
      }
    });
    return p;
  }
  
  Future<Parcela?> getParcelaById(int id) async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) return Parcela.fromMap(maps.first);
    return null;
  }

  Future<List<Arvore>> getArvoresDaParcela(int parcelaId) async {
    final db = await database;
    final maps = await db.query('arvores',
        where: 'parcelaId = ?', whereArgs: [parcelaId], orderBy: 'linha, posicaoNaLinha, id');
    return List.generate(maps.length, (i) => Arvore.fromMap(maps[i]));
  }

  Future<List<Parcela>> getTodasParcelas() async {
    final db = await database;
    final maps = await db.query('parcelas', orderBy: 'dataColeta DESC');
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  Future<int> deleteParcela(int id) async =>
      await (await database).delete('parcelas', where: 'id = ?', whereArgs: [id]);

  Future<void> deletarMultiplasParcelas(List<int> ids) async {
    if (ids.isEmpty) return;
    await (await database).delete(
      'parcelas',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  Future<int> updateParcela(Parcela p) async =>
      await (await database).update('parcelas', p.toMap(), where: 'id = ?', whereArgs: [p.dbId]);

  Future<int> limparParcelasExportadas() async {
    final count =
        await (await database).delete('parcelas', where: 'exportada = ?', whereArgs: [1]);
    debugPrint('$count parcelas exportadas foram apagadas.');
    return count;
  }

  Future<Map<String, List<String>>> getProjetosDisponiveis() async {
    final db = await database;
    final maps = await db.query(
      'parcelas',
      columns: ['nomeFazenda', 'nomeTalhao'],
      where: 'status = ?',
      whereArgs: [StatusParcela.concluida.name],
      distinct: true,
      orderBy: 'nomeFazenda, nomeTalhao',
    );
    final projetos = <String, List<String>>{};
    for (final map in maps) {
      final fazenda = map['nomeFazenda'] as String;
      final talhao = map['nomeTalhao'] as String;
      if (!projetos.containsKey(fazenda)) {
        projetos[fazenda] = [];
      }
      projetos[fazenda]!.add(talhao);
    }
    return projetos;
  }
  
  // --- MÉTODOS CRUD: CUBAGEM ---

  Future<void> limparTodasAsCubagens() async {
    await (await database).delete('cubagens_arvores');
    debugPrint('Tabela de cubagens e seções limpa.');
  }

  Future<void> salvarCubagemCompleta(CubagemArvore arvore, List<CubagemSecao> secoes) async {
    final db = await database;
    await db.transaction((txn) async {
      int id;
      final map = arvore.toMap();
      if (arvore.id == null) {
        id = await txn.insert('cubagens_arvores', map);
        arvore.id = id;
      } else {
        id = arvore.id!;
        await txn.update('cubagens_arvores', map, where: 'id = ?', whereArgs: [id]);
      }
      await txn.delete('cubagens_secoes', where: 'cubagemArvoreId = ?', whereArgs: [id]);
      for (var s in secoes) {
        s.cubagemArvoreId = id;
        await txn.insert('cubagens_secoes', s.toMap());
      }
    });
  }

  Future<List<CubagemArvore>> getTodasCubagens() async {
    final db = await database;
    final maps = await db.query('cubagens_arvores', orderBy: 'id DESC');
    return List.generate(maps.length, (i) => CubagemArvore.fromMap(maps[i]));
  }

  Future<List<CubagemSecao>> getSecoesPorArvoreId(int id) async {
    final db = await database;
    final maps = await db.query(
      'cubagens_secoes',
      where: 'cubagemArvoreId = ?',
      whereArgs: [id],
      orderBy: 'alturaMedicao ASC',
    );
    return List.generate(maps.length, (i) => CubagemSecao.fromMap(maps[i]));
  }

  Future<void> deletarCubagem(int id) async =>
      await (await database).delete('cubagens_arvores', where: 'id = ?', whereArgs: [id]);

  Future<void> deletarMultiplasCubagens(List<int> ids) async {
    if (ids.isEmpty) return;
    await (await database).delete(
      'cubagens_arvores',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
  }

  // --- MÉTODOS DE ANÁLISE E ESTATÍSTICAS ---

  Future<Map<String, double>> getDistribuicaoPorCodigo(int parcelaId) async {
    final db = await database;
    final result = await db.rawQuery(
        'SELECT codigo, COUNT(*) as total FROM arvores WHERE parcelaId = ? GROUP BY codigo',
        [parcelaId]);
    if (result.isEmpty) return {};
    return {
      for (var row in result) (row['codigo'] as String): (row['total'] as int).toDouble()
    };
  }

  Future<List<double>> getValoresCAP(int parcelaId) async {
    final db = await database;
    final result = await db.rawQuery('SELECT cap FROM arvores WHERE parcelaId = ?', [parcelaId]);
    if (result.isEmpty) return [];
    return result.map((row) => row['cap'] as double).toList();
  }

  // Cole este código DENTRO da classe DatabaseHelper, 
// por exemplo, após o método getValoresCAP.

  Future<Map<String, dynamic>> getDadosAgregadosDoTalhao(int talhaoId) async {
    // 1. Busca todas as parcelas que pertencem a este talhão.
    final parcelas = await getParcelasDoTalhao(talhaoId);
    
    // 2. Filtra apenas as parcelas que foram concluídas.
    final concluidas = parcelas.where((p) => p.status == StatusParcela.concluida.name).toList();
    
    // 3. Para cada parcela concluída, busca todas as suas árvores.
    final arvores = <Arvore>[];
    for (final p in concluidas) {
      if (p.dbId != null) {
        arvores.addAll(await getArvoresDaParcela(p.dbId!));
      }
    }

    // 4. Retorna um mapa com a lista de parcelas concluídas e a lista de todas as árvores.
    return {'parcelas': concluidas, 'arvores': arvores};
  }

  // Este método substitui o antigo 'getParcelasByProject' para ser usado no seu 'map_provider.dart'.
  // Ele busca todas as parcelas, de todos os talhões, que já foram concluídas.
  Future<List<Parcela>> getTodasAsParcelasConcluidas() async {
    final db = await database;
    final maps = await db.query('parcelas', where: 'status = ?', whereArgs: [StatusParcela.concluida.name]);
    return List.generate(maps.length, (i) => Parcela.fromMap(maps[i]));
  }

  // --- MÉTODOS DE EXPORTAÇÃO ---

  Future<void> exportarDados(BuildContext context) async {
    final tipoExportacao = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Exportar Coletas de Parcela'),
        content: const Text('Selecione o tipo de exportação:'),
        actions: [
          TextButton(
              child: const Text('Novas Concluídas'),
              onPressed: () => Navigator.pop(c, 'novas_concluidas')),
          TextButton(
              child: const Text('Re-exportar Todas Concluídas'),
              onPressed: () => Navigator.pop(c, 'todas_concluidas')),
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancelar'),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (tipoExportacao == null || tipoExportacao == 'cancelar' || !context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Buscando dados para exportação...')));

    try {
      final db = await database;
      final List<Map<String, dynamic>> parcelasMaps;

      if (tipoExportacao == 'novas_concluidas') {
        parcelasMaps = await db.query('parcelas',
            where: 'status = ? AND exportada = ?',
            whereArgs: [StatusParcela.concluida.name, 0]);
      } else {
        parcelasMaps = await db
            .query('parcelas', where: 'status = ?', whereArgs: [StatusParcela.concluida.name]);
      }

      if (parcelasMaps.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Nenhuma parcela encontrada para este critério.'),
              backgroundColor: Colors.orange));
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gerando arquivo CSV...')));
      }

      // Prepara dados para o CSV
      final prefs = await SharedPreferences.getInstance();
      final nomeLider = prefs.getString('nome_lider') ?? 'N/A';
      final nomesAjudantes = prefs.getString('nomes_ajudantes') ?? 'N/A';
      final nomeZona = prefs.getString('zona_utm_selecionada') ?? 'SIRGAS 2000 / UTM Zona 22S';
      final codigoEpsg = zonasUtmSirgas2000[nomeZona]!;
      final projWGS84 = proj4.Projection.get('EPSG:4326')!;
      final projUTM = proj4.Projection.get('EPSG:$codigoEpsg')!;

      List<List<dynamic>> rows = [];
      rows.add([
        'Lider_Equipe', 'Ajudantes', 'ID_Db_Parcela', 'Codigo_Fazenda', 'Fazenda', 'Talhao',
        'ID_Coleta_Parcela', 'Area_m2', 'Largura_m', 'Comprimento_m', 'Raio_m',
        'Espacamento', 'Observacao_Parcela', 'Easting', 'Northing', 'Data_Coleta',
        'Status_Parcela', 'Linha', 'Posicao_na_Linha', 'Fuste_Num', 'Codigo_Arvore',
        'Codigo_Arvore_2', 'CAP_cm', 'Altura_m', 'Dominante'
      ]);

      List<int> idsParaMarcar = [];
      for (var pMap in parcelasMaps) {
        idsParaMarcar.add(pMap['id'] as int);

        String easting = '', northing = '';
        if (pMap['latitude'] != null && pMap['longitude'] != null) {
          var pUtm = projWGS84.transform(projUTM,
              proj4.Point(x: pMap['longitude'] as double, y: pMap['latitude'] as double));
          easting = pUtm.x.toStringAsFixed(2);
          northing = pUtm.y.toStringAsFixed(2);
        }

        final arvores = await getArvoresDaParcela(pMap['id'] as int);
        if (arvores.isEmpty) {
          rows.add([
            nomeLider, nomesAjudantes, pMap['id'], pMap['idFazenda'], pMap['nomeFazenda'],
            pMap['nomeTalhao'], pMap['idParcela'], pMap['areaMetrosQuadrados'], pMap['largura'],
            pMap['comprimento'], pMap['raio'], pMap['espacamento'], pMap['observacao'], easting,
            northing, pMap['dataColeta'], pMap['status'], null, null, null, null, null, null,
            null, null
          ]);
        } else {
          Map<String, int> fusteCounter = {};
          for (final a in arvores) {
            String key = '${a.linha}-${a.posicaoNaLinha}';
            fusteCounter[key] = (fusteCounter[key] ?? 0) + 1;
            rows.add([
              nomeLider, nomesAjudantes, pMap['id'], pMap['idFazenda'], pMap['nomeFazenda'],
              pMap['nomeTalhao'], pMap['idParcela'], pMap['areaMetrosQuadrados'],
              pMap['largura'], pMap['comprimento'], pMap['raio'], pMap['espacamento'],
              pMap['observacao'], easting, northing, pMap['dataColeta'], pMap['status'],
              a.linha, a.posicaoNaLinha, fusteCounter[key], a.codigo, a.codigo2, a.cap,
              a.altura, a.dominante ? 'Sim' : 'Não'
            ]);
          }
        }
      }

      // Salva e compartilha o arquivo
      final dir = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final pastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDia = Directory('${dir.path}/$pastaData');
      if (!await pastaDia.exists()) await pastaDia.create(recursive: true);

      final fName = 'geoforest_export_parcelas_${DateFormat('HH-mm-ss').format(hoje)}.csv';
      final path = '${pastaDia.path}/$fName';
      await File(path).writeAsString(const ListToCsvConverter().convert(rows));

      // Marca as parcelas como exportadas
      await db.update('parcelas', {'exportada': 1},
          where: 'id IN (${idsParaMarcar.map((_) => '?').join(',')})', whereArgs: idsParaMarcar);

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(path)], subject: 'Exportação GeoForest');
      }
    } catch (e, s) {
      debugPrint('Erro na exportação de parcelas: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha na exportação: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> exportarCubagens(BuildContext context) async {
    final tipoExportacao = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Exportar Cubagens'),
        content: const Text('Selecione o tipo de exportação:'),
        actions: [
          TextButton(
              child: const Text('Exportar Novas'), onPressed: () => Navigator.pop(c, 'novas')),
          TextButton(
              child: const Text('Re-exportar Todas'),
              onPressed: () => Navigator.pop(c, 'todas')),
          TextButton(
            onPressed: () => Navigator.pop(c, 'cancelar'),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (tipoExportacao == null || tipoExportacao == 'cancelar' || !context.mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Buscando dados de cubagem...')));

    try {
      final db = await database;
      final List<Map<String, dynamic>> arvoresMaps;

      if (tipoExportacao == 'novas') {
        arvoresMaps =
            await db.query('cubagens_arvores', where: 'exportada = ?', whereArgs: [0]);
      } else {
        arvoresMaps = await db.query('cubagens_arvores');
      }

      if (arvoresMaps.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).removeCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Nenhuma cubagem para exportar neste critério.'),
              backgroundColor: Colors.orange));
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gerando arquivo CSV de cubagens...')));
      }

      List<CubagemArvore> arvores =
          arvoresMaps.map((map) => CubagemArvore.fromMap(map)).toList();
      List<int> idsParaMarcar = [];
      List<List<dynamic>> rows = [];
      rows.add([
        'id_arvore_db', 'id_fazenda', 'fazenda', 'talhao', 'identificador_arvore',
        'altura_total_m', 'cap_cm', 'altura_medicao_m', 'circunferencia_cm', 'casca1_mm',
        'casca2_mm', 'diametro_cc_cm', 'diametro_sc_cm'
      ]);

      for (var a in arvores) {
        idsParaMarcar.add(a.id!);
        final secoes = await getSecoesPorArvoreId(a.id!);
        if (secoes.isEmpty) {
          rows.add([
            a.id, a.idFazenda, a.nomeFazenda, a.nomeTalhao, a.identificador, a.alturaTotal,
            a.valorCAP, null, null, null, null, null, null
          ]);
        } else {
          for (var s in secoes) {
            rows.add([
              a.id, a.idFazenda, a.nomeFazenda, a.nomeTalhao, a.identificador, a.alturaTotal,
              a.valorCAP, s.alturaMedicao, s.circunferencia, s.casca1_mm, s.casca2_mm,
              s.diametroComCasca.toStringAsFixed(2), s.diametroSemCasca.toStringAsFixed(2)
            ]);
          }
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final pastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDia = Directory('${dir.path}/$pastaData');
      if (!await pastaDia.exists()) await pastaDia.create(recursive: true);

      final fName = 'geoforest_export_cubagens_${DateFormat('HH-mm-ss').format(hoje)}.csv';
      final path = '${pastaDia.path}/$fName';
      final csvData = const ListToCsvConverter().convert(rows);
      await File(path).writeAsString(csvData);

      await db.update('cubagens_arvores', {'exportada': 1},
          where: 'id IN (${idsParaMarcar.map((_) => '?').join(',')})', whereArgs: idsParaMarcar);

      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        await Share.shareXFiles([XFile(path)], subject: 'Exportação de Cubagens');
      }
    } catch (e, s) {
      debugPrint('Erro na exportação de cubagens: $e\n$s');
      if (context.mounted) {
        ScaffoldMessenger.of(context).removeCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Falha na exportação de cubagens: ${e.toString()}'),
            backgroundColor: Colors.red));
      }
    }
  }

  Future<void> exportarUmaCubagem(BuildContext context, int arvoreId) async {
    final db = await database;
    final List<Map<String, dynamic>> arvoreMaps =
        await db.query('cubagens_arvores', where: 'id = ?', whereArgs: [arvoreId]);

    if (arvoreMaps.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Árvore não encontrada.')));
      }
      return;
    }

    final arvore = CubagemArvore.fromMap(arvoreMaps.first);
    final secoes = await getSecoesPorArvoreId(arvore.id!);
    List<List<dynamic>> rows = [];
    rows.add([
      'id_fazenda', 'fazenda', 'talhao', 'identificador_arvore', 'altura_total_m',
      'tipo_medida_cap', 'valor_cap_cm', 'altura_base_m', 'altura_medicao_m',
      'circunferencia_cm', 'casca1_mm', 'casca2_mm', 'diametro_cc_cm', 'diametro_sc_cm'
    ]);

    if (secoes.isEmpty) {
      rows.add([
        arvore.idFazenda, arvore.nomeFazenda, arvore.nomeTalhao, arvore.identificador,
        arvore.alturaTotal, arvore.tipoMedidaCAP, arvore.valorCAP, arvore.alturaBase,
        null, null, null, null, null, null
      ]);
    } else {
      for (var secao in secoes) {
        rows.add([
          arvore.idFazenda, arvore.nomeFazenda, arvore.nomeTalhao, arvore.identificador,
          arvore.alturaTotal, arvore.tipoMedidaCAP, arvore.valorCAP, arvore.alturaBase,
          secao.alturaMedicao, secao.circunferencia, secao.casca1_mm, secao.casca2_mm,
          secao.diametroComCasca.toStringAsFixed(2),
          secao.diametroSemCasca.toStringAsFixed(2)
        ]);
      }
    }

    final csvData = const ListToCsvConverter().convert(rows);
    try {
      final directory = await getApplicationDocumentsDirectory();
      final hoje = DateTime.now();
      final nomePastaData = DateFormat('yyyy-MM-dd').format(hoje);
      final pastaDoDia = Directory('${directory.path}/$nomePastaData');

      if (!await pastaDoDia.exists()) {
        await pastaDoDia.create(recursive: true);
      }

      final sanitizedId = arvore.identificador.replaceAll(RegExp(r'[\\/*?:"<>|]'), '_');
      final fileName = 'Cubagem_${sanitizedId}_${DateFormat('HH-mm-ss').format(hoje)}.csv';
      final path = '${pastaDoDia.path}/$fileName';

      await File(path).writeAsString(csvData);

      if (context.mounted) {
        await Share.shareXFiles([XFile(path)],
            subject: 'Exportação de Cubagem: ${arvore.identificador}');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao exportar: $e')));
      }
    }
  }
}