import 'package:flutter/material.dart';
import 'network_manager.dart';
import 'game_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  final Color _verdeEscuro = const Color(0xFF1B4332);
  final Color _laranjaEscuro = const Color(0xFFD35400);
  final Color _violetaEscuro = const Color(0xFF2C1A4D);

  final TextEditingController _ipController = TextEditingController();
  // === NOVO: Controlador global para o nome do jogador (Host ou Cliente) ===
  final TextEditingController _nomeJogadorController = TextEditingController();
  final NetworkManager _networkManager = NetworkManager();

  String _localIP = "A detetar IP...";

  @override
  void initState() {
    super.initState();
    _loadLocalIP();
  }

  Future<void> _loadLocalIP() async {
    String? ip = await _networkManager.getLocalIP();
    setState(() {
      if (ip != null) {
        _localIP = "O teu IP local: $ip";
      } else {
        _localIP = "Não conectado ao Wi-Fi";
      }
    });
  }

  // CORRIGIDO: Passa o nome introduzido ou "Host" se estiver vazio
  void _createRoom() {
    String nome = _nomeJogadorController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GameScreen(
          isHost: true,
          targetIP: null,
          nomeJogador: nome.isEmpty ? "Host" : nome,
        ),
      ),
    );
  }

  void _joinRoom() async {
    String ip = _ipController.text.trim();
    String nome = _nomeJogadorController.text.trim();

    // Validação extra: Garante que o cliente também digita o nome antes de tentar ligar
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, introduz o teu nome primeiro!'),
        ),
      );
      return;
    }

    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, introduz o IP do teu amigo!')),
      );
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('A tentar ligar ao Host...')));

    try {
      await _networkManager.connectToServer(ip, (msg) {});

      if (mounted) {
        // Envia o nome de imediato ao ligar e avança para o jogo
        _networkManager.sendToServer("SET_NAME:$nome");

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                GameScreen(isHost: false, targetIP: ip, nomeJogador: nome),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erro de ligação: Não foi possível entrar na sala.'),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _nomeJogadorController.dispose(); // Limpeza de memória do novo controlador
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _violetaEscuro,
      body: SafeArea(
        child: SingleChildScrollView(
          // Proteção contra quebras de ecrã quando o teclado abre
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  "PICWORDIO",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        offset: const Offset(2, 4),
                        blurRadius: 5,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Jogo Multijogador Local",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 40),

                // === NOVO: CAMPO DE TEXTO DO NOME PARA AMBOS OS JOGADORES ===
                TextField(
                  controller: _nomeJogadorController,
                  maxLength: 12,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Ex: Rui, Pedro, Ana...",
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    labelText: "O Teu Nome de Jogador",
                    labelStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.bold,
                    ),
                    prefixIcon: const Icon(Icons.person, color: Colors.white70),
                    counterStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.05),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: _laranjaEscuro, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verdeEscuro,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                  ),
                  onPressed: _createRoom,
                  icon: const Icon(Icons.gite, color: Colors.white, size: 24),
                  label: const Text(
                    "CRIAR NOVA SALA",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  _localIP,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        "OU ENTRAR NUMA SALA",
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _ipController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: false,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: InputDecoration(
                          hintText: "Ex: 192.168.1.75",
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          labelText: "IP do Host (Telemóvel do teu amigo)",
                          labelStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.sensors,
                            color: Colors.white70,
                          ),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                              color: _laranjaEscuro,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _laranjaEscuro,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 2,
                        ),
                        onPressed: _joinRoom,
                        icon: const Icon(
                          Icons.login,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: const Text(
                          "ENTRAR NA SALA",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
