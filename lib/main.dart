import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necessário para bloquear a rotação
import 'main_menu_screen.dart'; // Importa a nova página de menu

void main() {
  // Garante que os serviços nativos estão prontos antes de trancar o ecrã
  WidgetsFlutterBinding.ensureInitialized();

  // Tranca o telemóvel apenas em modo Vertical
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Picwordio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home:
          const MainMenuScreen(), // Define o Menu Inicial como ponto de partida!
    );
  }
}
