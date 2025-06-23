// ignore_for_file: deprecated_member_use, duplicate_ignore

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geoforestcoletor/pages/home_page.dart';
import 'package:geoforestcoletor/pages/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:geoforestcoletor/pages/map_import_page.dart';
import 'package:geoforestcoletor/pages/equipe_page.dart';


// Função main agora é async para usar 'await'
Future<void> main() async {
  // Garante que os bindings do Flutter estão prontos
  WidgetsFlutterBinding.ensureInitialized();

  // Define as orientações do app
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Inicializa o SQFlite para desktop
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Bloco try-catch para lidar com erros de inicialização (principalmente do Firebase)
  try {
    // Inicializa o Firebase AQUI, antes de runApp
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Se a inicialização for bem-sucedida, roda o app normalmente
    runApp(const MyApp());
  } catch (e) {
    // Se a inicialização falhar, roda o app com a tela de erro
    runApp(
      MaterialApp(
        home: ErrorScreen(
          message: 'Failed to initialize Firebase:\n${e.toString()}',
          // O botão de "Tentar Novamente" agora reinicia o app de forma segura
          onRetry: () => main(),
        ),
      ),
    );
  }
}

// Widget principal do aplicativo
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Geo Forest Analytics',
      debugShowCheckedModeBanner: false,
      theme: _buildThemeData(Brightness.light),
      darkTheme: _buildThemeData(Brightness.dark),
      initialRoute: '/',
      // =============================================================
      // ======================= CORREÇÃO AQUI =======================
      // =============================================================
      routes: {
        '/': (context) => const LoginPage(),
        '/equipe': (context) => const EquipePage(),
        '/home': (context) => const HomePage(title: 'Geo Forest Analytics'),
        '/map_import': (context) => const MapImportPage(), // Rota adicionada para usar o import
      },
      // =============================================================
      navigatorObservers: [RouteObserver<PageRoute>()],
      builder: (context, child) {
        // Define um ErrorWidget customizado para erros que ocorrem após a inicialização
        ErrorWidget.builder = (FlutterErrorDetails details) {
          // Log do erro para o console para debug
          debugPrint('Caught a Flutter error: ${details.exception}');
          return ErrorScreen(
            message: 'An unexpected error occurred.\nPlease restart the app.',
            onRetry: null, // Desabilita o botão para erros de runtime
          );
        };

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
          child: child!,
        );
      },
    );
  }

  // Função para construir o tema do app
  ThemeData _buildThemeData(Brightness brightness) {
    final baseColor = const Color(0xFF617359);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: baseColor,
        brightness: brightness,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor:
            brightness == Brightness.light ? baseColor : Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: baseColor,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: Color(0xFF1D4433),
          fontWeight: FontWeight.bold,
        ),
        bodyLarge: TextStyle(color: Color(0xFF1D4433)),
        bodyMedium: TextStyle(color: Color(0xFF1D4433)),
      ),
    );
  }
}


// Widget para tela de erro
class ErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorScreen({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F4),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red[700], size: 60),
              const SizedBox(height: 20),
              Text(
                'Application Error',
                style: TextStyle(
                  color: Colors.red[700],
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 30),
              if (onRetry != null)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF617359),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onRetry,
                  child: const Text('Try Again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}