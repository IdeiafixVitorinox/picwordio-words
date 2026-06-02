import 'dart:async'; // IMPORTANTE para o Timer
import 'package:flutter/material.dart';
import 'canvas_painter.dart';
import 'draw_point.dart';
import 'word_manager.dart';
import 'network_manager.dart';
import 'score_manager.dart';

class GameScreen extends StatefulWidget {
  final bool isHost;
  final String? targetIP;
  final String nomeJogador; // <-- Adiciona esta variável

  const GameScreen({
    super.key,
    required this.isHost,
    this.targetIP,
    required this.nomeJogador,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final WordManager _wordManager = WordManager();
  final ScoreManager _scoreManager = ScoreManager();
  List<DrawPoint> points = [];
  String _displayWord = "Escolha um Tema no Menu";
  String _temaAtualAtivo = "";

  final List<String> _chatHistorico = [];

  Color _selectedColor = Colors.black;
  double _selectedWidth = 4.0;

  final Color _verdeEscuro = const Color(0xFF1B4332);
  final Color _laranjaEscuro = const Color(0xFFD35400);
  final Color _violetaEscuro = const Color(0xFF2C1A4D);

  final NetworkManager _networkManager = NetworkManager();
  final TextEditingController _inputController = TextEditingController();
  String _statusRede = "A inicializar...";

  String _meuNome = "";
  // SUBSTUIÇÃO: Sai a String única, entra a lista dinâmica de jogadores ativos
  final List<String> _jogadoresNaSala = [];
  bool _localIsDrawing = false;
  int _rondaAtual = 1;
  final int _maxRondas = 6; // Já deixamos o limite de rondas preparado!
  // === NOVO: Bloqueador de segurança para o estado inicial ===
  bool _jogoComecou = false;

  // --- GESTÃO DE TIMERS ---
  Timer? _rondaTimer;
  int _tempoRestante = 60;

  bool _isChatMode = false;

  @override
  void initState() {
    super.initState();
    _localIsDrawing = widget.isHost;
    // CORREÇÃO: Em vez de "Host" ou "Jogador" fixo, passas a usar o nome real
    _meuNome = widget.nomeJogador;
    _inicializarRede();
  }

  void _inicializarRede() async {
    if (widget.isHost) {
      // === IMPLEMENTADO: Limpeza total antes de abrir a sala ===
      _scoreManager.limparDadosDaSala();
      _jogadoresNaSala
          .clear(); // Limpa a lista de utilizadores para não acumular os da sessão anterior

      setState(() => _statusRede = "Sala aberta (Aguardando...)");
      await _networkManager.startServer((mensagemRecebida) {
        _processarMensagemRede(mensagemRecebida);
      });
    } else {
      setState(() => _statusRede = "A conectar ao Host...");
      try {
        await _networkManager.connectToServer(widget.targetIP!, (
          mensagemRecebida,
        ) {
          _processarMensagemRede(mensagemRecebida);
        });
        setState(() => _statusRede = "Conectado!");

        // Reforço de segurança: Garante que o Host regista este cliente na lista _jogadoresNaSala
        _networkManager.sendToServer("SET_NAME:$_meuNome");
      } catch (e) {
        setState(() => _statusRede = "Erro de conexão.");
      }
    }
  }

  void _startTimer() {
    _rondaTimer?.cancel();
    setState(() => _tempoRestante = 60);

    _rondaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      // SEGURANÇA: Só processa o tempo real se o jogo já tiver começado
      if (!_jogoComecou) {
        _rondaTimer?.cancel();
        return;
      }
      setState(() {
        if (_tempoRestante > 0) {
          _tempoRestante--;
          if (widget.isHost) {
            _networkManager.sendToAllClients("TIMER:$_tempoRestante");
          }
        } else {
          _rondaTimer?.cancel();
          if (widget.isHost) {
            _finalizarRondaPorTempo();
          }
        }
      });
    });
  }

  // Novo método para garantir que o Timer morre localmente e na rede
  void _pararTodosOsTimers() {
    _rondaTimer?.cancel();
    if (widget.isHost) {
      _networkManager.sendToAllClients("STOP_TIMER");
    }
  }

  void _finalizarRondaPorTempo() {
    String palavraCorreta = _wordManager.currentWord;
    _networkManager.sendToAllClients(
      "SYSTEM:O tempo acabou! A palavra era '$palavraCorreta' ⏰",
    );
    _adicionarAoChat("📢 Tempo esgotado! A palavra era '$palavraCorreta'.");
    _pararTodosOsTimers();
    setState(() => points.clear());
    _networkManager.sendToAllClients("CLEAR");
  }

  void _processarMensagemRede(String mensagem) {
    if (mensagem.startsWith("SYSTEM:")) {
      String aviso = mensagem.replaceFirst("SYSTEM:", "");
      if (aviso == "CONECTADO_COM_SUCESSO") {
        setState(() => _statusRede = "Conectado à Sala!");
        _adicionarAoChat("📢 Ligação estabelecida com sucesso! 🎉");
      } else {
        _adicionarAoChat("📢 $aviso");
      }
    } else if (mensagem == "STOP_TIMER") {
      _rondaTimer?.cancel();
    } else if (mensagem.startsWith("TIMER:")) {
      int tempo = int.parse(mensagem.replaceFirst("TIMER:", ""));
      setState(() => _tempoRestante = tempo);
    } else if (mensagem.startsWith("MSG:")) {
      String conversa = mensagem.replaceFirst("MSG:", "");
      _adicionarAoChat("💬 Amigo: $conversa");
    }
    // === CORRIGIDO: SUPORTE A MÚLTIPLOS JOGADORES SEM DUPLICAR EM CHAT ===
    else if (mensagem.startsWith("SET_NAME:")) {
      String nomeDoCliente = mensagem.replaceFirst("SET_NAME:", "").trim();
      if (!_jogadoresNaSala.contains(nomeDoCliente)) {
        setState(() {
          _jogadoresNaSala.add(nomeDoCliente);
        });
        // Agora só avisa o chat se o jogador for REALMENTE novo na lista!
        _adicionarAoChat(
          "👋 $nomeDoCliente entrou na sala! (Total: ${_jogadoresNaSala.length} jogadores de fora)",
        );
      }
    } else if (mensagem.startsWith("UPDATE_SCORE:")) {
      int scoreSincronizado = int.parse(
        mensagem.replaceFirst("UPDATE_SCORE:", ""),
      );
      setState(() {
        _scoreManager.setCurrentRoomScore(scoreSincronizado);
      });
    } else if (mensagem.startsWith("HOF_DATA:")) {
      String dados = mensagem.replaceFirst("HOF_DATA:", "");
      _scoreManager.atualizarHallOfFameLocal(dados);
      setState(() {});
    } else if (mensagem.startsWith("START_ROUND:")) {
      List<String> partes = mensagem
          .replaceFirst("START_ROUND:", "")
          .split(":");
      int novaRonda = int.parse(partes[0]);
      String palavra = partes[1];
      String quemDesenha = partes[2];

      setState(() {
        _jogoComecou = true;
        _rondaAtual = novaRonda;
        points.clear();
        _startTimer();

        if (quemDesenha == "Cliente" && !widget.isHost) {
          _localIsDrawing = true;
          _displayWord = "Desenha: $palavra";
        } else if (quemDesenha == "Host" && widget.isHost) {
          _localIsDrawing = true;
          _displayWord = "Desenha: $palavra";
        } else {
          _localIsDrawing = false;
          _displayWord = "Adivinha o desenho!";
        }
      });
      _adicionarAoChat(
        "🏁 Ronda $_rondaAtual iniciada! É a vez de quem desenha.",
      );
    } else if (mensagem.startsWith("GUESS:")) {
      if (widget.isHost) {
        List<String> partesPalpite = mensagem
            .replaceFirst("GUESS:", "")
            .split(":");
        if (partesPalpite.length >= 2) {
          String quemChutou = partesPalpite[0];
          String palpiteEfetivo = partesPalpite[1];
          _verificarPalpiteDoCliente(palpiteEfetivo, quemChutou);
        }
      }
    } else if (mensagem.startsWith("CLIENT_DRAW:")) {
      String traco = mensagem.replaceFirst("CLIENT_DRAW:", "");
      if (widget.isHost) {
        _networkManager.sendToAllClients(traco);
      }
      _processarPontoRecebido(traco);
    } else {
      _processarPontoRecebido(mensagem);
    }
  }

  void _verificarPalpiteDoCliente(String palpite, String quemAcertou) {
    String palavraCorreta = _wordManager.currentWord.trim().toLowerCase();
    String palpiteFormatado = palpite.trim().toLowerCase();

    if (palavraCorreta.isNotEmpty && palpiteFormatado == palavraCorreta) {
      _pararTodosOsTimers();

      _scoreManager.addPoints(100);

      // Pontua dinamicamente quem acertou!
      _scoreManager.saveToHallOfFame(
        quemAcertou,
        _scoreManager.currentRoomScore,
      );

      // Descobre quem estava a desenhar. Se o Host não desenha, foi algum dos outros clientes.
      // Para já, assumimos o Host como desenhador se _localIsDrawing for true
      String desenhadorAtual = _localIsDrawing ? _meuNome : "Outro Jogador";

      int scoreAtualDoDesenhador = _scoreManager.currentRoomScore - 100;
      _scoreManager.saveToHallOfFame(
        desenhadorAtual,
        scoreAtualDoDesenhador + 50,
      );

      _networkManager.sendToAllClients(
        "SYSTEM:$quemAcertou acertou! Era '$palavraCorreta' 🎉 (+100 PTS para $quemAcertou)",
      );

      _networkManager.sendToAllClients(
        "UPDATE_SCORE:${_scoreManager.currentRoomScore}",
      );
      String dadosHof = _scoreManager.getHallOfFameFormatado();
      _networkManager.sendToAllClients("HOF_DATA:$dadosHof");
      _networkManager.sendToAllClients("CLEAR");

      _adicionarAoChat(
        "🏆 O jogador $quemAcertou acertou! A palavra era '$palavraCorreta'.",
      );
      setState(() {});
    } else {
      _networkManager.sendToAllClients(
        "MSG:$quemAcertou tentou adivinhar '$palpite' mas errou! ❌",
      );
      _adicionarAoChat("❌ Palpite errado de $quemAcertou: $palpite");
    }
  }

  void _verificarPalpiteLocalDoHost(
    String palpite,
    String palavraDaRonda,
    String quemDesenhou,
  ) {
    String palavraCorreta = palavraDaRonda.trim().toLowerCase();
    String palpiteFormatado = palpite.trim().toLowerCase();

    if (palavraCorreta.isNotEmpty && palpiteFormatado == palavraCorreta) {
      _pararTodosOsTimers(); // Para os cronómetros localmente e na rede

      // 1. O HOST ACERTOU: Atualiza a pontuação visível da sala (+100 pontos para o Host)
      _scoreManager.addPoints(100);

      // 2. Grava no Hall of Fame o score do Host (quem adivinhou) com os 100 incluídos
      _scoreManager.saveToHallOfFame(_meuNome, _scoreManager.currentRoomScore);

      // 3. MULTIJOGADOR: O jogador que desenhou ganha o bónus de artista de 50 pontos
      // Vamos buscar o histórico desse jogador específico e somamos os 50 PTS
      int scoreAtualDoDesenhor = _scoreManager.currentRoomScore - 100;
      _scoreManager.saveToHallOfFame(quemDesenhou, scoreAtualDoDesenhor + 50);

      // 4. Notifica a sala sobre a pontuação através da rede
      _networkManager.sendToAllClients(
        "SYSTEM:$_meuNome acertou! Era '$palavraDaRonda' 🎉 (+100 PTS para $_meuNome e +50 PTS de desenho para $quemDesenhou)",
      );

      // 5. SINCRONIZAÇÃO: Atualiza o ecrã de todos os clientes com o novo score do quarto
      _networkManager.sendToAllClients(
        "UPDATE_SCORE:${_scoreManager.currentRoomScore}",
      );

      // 6. SINCRONIZAÇÃO: Envia o Hall of Fame (Top 10) já atualizado para toda a gente
      String dadosHof = _scoreManager.getHallOfFameFormatado();
      _networkManager.sendToAllClients("HOF_DATA:$dadosHof");

      // 7. Limpa o Canvas de desenho de toda a gente para fechar a ronda
      _networkManager.sendToAllClients("CLEAR");

      _adicionarAoChat(
        "🏆 Acertaste! A palavra era '$palavraDaRonda'. O jogador $quemDesenhou ganhou +50 PTS pelo desenho.",
      );
      setState(() {});
    } else {
      _networkManager.sendToAllClients(
        "MSG:$_meuNome tentou adivinhar '$palpite' mas errou! ❌",
      );
      _adicionarAoChat("❌ Palpite errado: $palpite");
    }
  }

  void _enviarTexto() {
    String texto = _inputController.text.trim();
    if (texto.isEmpty) return;

    if (_localIsDrawing) {
      if (_isChatMode) {
        String msgCompleta = "MSG:$_meuNome: $texto";
        if (widget.isHost) {
          _networkManager.sendToAllClients(msgCompleta);
          _adicionarAoChat("💬 Tu (Desenhador): $texto");
        } else {
          _networkManager.sendToServer(msgCompleta);
          _adicionarAoChat("💬 Tu: $texto");
        }
      } else {
        _adicionarAoChat("💡 Quem está a desenhar não pode dar palpites!");
      }
    } else {
      // === SE ESTOU A ADIVINHAR ===
      if (widget.isHost) {
        // CORREÇÃO: Calcula dinamicamente quem é o verdadeiro desenhador desta ronda!
        // Se a ronda for ímpar, o desenhador é o Host (_meuNome). Se for par, é o primeiro cliente da lista.
        String verdadeiroDesenhador = (_rondaAtual % 2 != 0)
            ? _meuNome
            : (_jogadoresNaSala.isNotEmpty
                  ? _jogadoresNaSala.first
                  : "Cliente");

        // Envia o nome real em vez do texto estático fixo
        _verificarPalpiteLocalDoHost(
          texto,
          _wordManager.currentWord,
          verdadeiroDesenhador,
        );
      } else {
        _networkManager.sendToServer("GUESS:$_meuNome:$texto");
        _adicionarAoChat("🎯 Palpite enviado: $texto");
      }
    }

    _inputController.clear();
  }

  void _adicionarAoChat(String linha) {
    setState(() {
      _chatHistorico.add(linha);
    });
  }

  void _processarPontoRecebido(String mensagem) {
    if (mensagem == "CLEAR") {
      _rondaTimer?.cancel(); // Força o congelamento do relógio local do cliente
      setState(() => points.clear());
      return;
    }
    List<String> partes = mensagem.split(';');
    if (partes.length < 5) return;

    double x = double.parse(partes[1]);
    double y = double.parse(partes[2]);
    int corValue = int.parse(partes[3]);
    double espessura = double.parse(partes[4]);

    PointStatus status = partes[0] == "START"
        ? PointStatus.start
        : (partes[0] == "MOVE" ? PointStatus.move : PointStatus.end);

    setState(() {
      points.add(
        DrawPoint(
          x: x,
          y: y,
          status: status,
          color: Color(corValue),
          strokeWidth: espessura,
        ),
      );
    });
  }

  Future<void> _startRound(String themeName) async {
    if (!widget.isHost) return;

    // VALIDADO: Travão de segurança caso tente forçar além do limite das rondas
    if (_rondaAtual > _maxRondas) {
      _finalizarJogo();
      return;
    }

    setState(() {
      _displayWord = "A carregar tema...";
      points.clear();
      _temaAtualAtivo =
          themeName; // Salva o tema na primeira ronda para as seguintes consumirem
    });

    bool success = await _wordManager.loadTheme(themeName);
    if (!success) {
      setState(() => _displayWord = "Erro ao carregar tema!");
      return;
    }

    String novaPalavra = _wordManager.drawNewWord();
    _networkManager.gameStarted = true;

    setState(() {
      _jogoComecou = true; // ATIVAÇÃO: Liberta o Canvas para se poder pintar!
      _startTimer();

      if (_rondaAtual % 2 != 0) {
        _localIsDrawing = true;
        _displayWord = "Desenha: $novaPalavra";
        _networkManager.sendToAllClients("START_ROUND:$_rondaAtual::Host");
      } else {
        _localIsDrawing = false;
        _displayWord = "Um jogador de fora está a desenhar...";
        _networkManager.sendToAllClients(
          "START_ROUND:$_rondaAtual:$novaPalavra:Cliente",
        );
      }
      _networkManager.sendToAllClients("CLEAR");
    });

    _adicionarAoChat("🏁 Iniciada a Ronda $_rondaAtual! Tema: $themeName");
  }

  void _avancarParaProximaRonda() {
    if (!widget.isHost) return;
    _pararTodosOsTimers();

    // VALIDADO: Se atingir o limite de 6 rondas, fecha o jogo imediatamente
    if (_rondaAtual >= _maxRondas) {
      _finalizarJogo();
      return;
    }

    setState(() {
      _rondaAtual++;
      _jogoComecou =
          false; // TRANCA: Evita que desenhem enquanto a nova palavra está a carregar
    });

    // AVANÇO AUTOMÁTICO: Roda a próxima ronda mantendo sempre o mesmo tema ativo!
    _startRound(_temaAtualAtivo);
  }

  void _finalizarJogo() {
    _pararTodosOsTimers();

    setState(() {
      _jogoComecou = false;
      _displayWord = "Fim do Jogo! Obrigado por jogar.";
    });

    // 1. Envia o sinal de fim de jogo para todos os clientes
    if (widget.isHost) {
      String dadosHof = _scoreManager.getHallOfFameFormatado();
      _networkManager.sendToAllClients("GAME_OVER:$dadosHof");
    }

    _adicionarAoChat("🏆 O jogo terminou! Verifiquem as pontuações finais.");

    // 2. Mostra um ecrã/diálogo bonito com o fecho dos resultados
    showDialog(
      context: context,
      barrierDismissible: false, // Força a interagir com o botão
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(
            0xFF2A1B3D,
          ), // Segue o padrão do teu violeta do menu
          title: const Row(
            children: [
              Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Text(
                "FIM DO JOGO",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Atingiram o limite de 6 rondas. Obrigado por jogar!",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              const Text(
                "Pontuação Final da Sala:",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _scoreManager.getHallOfFameFormatado(),
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text(
                "Voltar ao Menu Principal",
                style: TextStyle(color: Colors.cyanAccent),
              ),
              onPressed: () {
                // Cancela as ligações de rede antes de sair se necessário
                // Altera isto na linha 534:
                _networkManager.closeAll();

                // Remove o diálogo e volta para o ecrã inicial do jogo
                Navigator.of(context).pop(); // Fecha o Dialog
                Navigator.of(
                  context,
                ).pop(); // Sai do GameScreen para o MainMenu
              },
            ),
          ],
        );
      },
    );
  }

  void _mostrarHallOfFamePopup() {
    var recordes = _scoreManager.getHallOfFame();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _violetaEscuro,
        title: const Row(
          children: [
            Icon(Icons.emoji_events, color: Colors.amber, size: 28),
            SizedBox(width: 10),
            Text(
              "HALL OF FAME",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: recordes.isEmpty
              ? const Text(
                  "Nenhum recorde guardado ainda! 🚀",
                  style: TextStyle(color: Colors.white70),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: recordes.length,
                  itemBuilder: (context, index) {
                    var entry = recordes[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _laranjaEscuro,
                        child: Text(
                          "#${index + 1}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        entry.key,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      trailing: Text(
                        "${entry.value} PTS",
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("FECHAR", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _rondaTimer?.cancel();
    _inputController.dispose();
    _networkManager.closeAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PICWORDIO (${_scoreManager.currentRoomScore} pts)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            // CORRIGIDO: Mostra dinamicamente o número de jogadores conectados em vez de um único "Adversário"
            Text(
              'Tu: $_meuNome | Jogadores: ${_jogadoresNaSala.length} | Ronda: $_rondaAtual/$_maxRondas | $_statusRede',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        backgroundColor: _verdeEscuro,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // VALIDADO: O botão de avançar ronda só aparece se for o Host, se o timer acabou E se a sala NÃO estiver vazia!
          if (widget.isHost &&
              _rondaTimer != null &&
              _rondaTimer?.isActive == false &&
              _jogadoresNaSala.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.skip_next, size: 18),
                label: Text("Ronda ${_rondaAtual + 1} 🚀"),
                onPressed: _avancarParaProximaRonda,
              ),
            ),
        ],
      ),
      drawer: Drawer(
        child: Container(
          color: _violetaEscuro,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: _verdeEscuro),
                child: const Center(
                  child: Text(
                    "MENU",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // TEMA: ANIMAIS - Bloqueia visualmente e na lógica se não houver adversários
              ListTile(
                leading: Icon(
                  Icons.pets,
                  color: (widget.isHost && _jogadoresNaSala.isNotEmpty)
                      ? Colors.white
                      : Colors.white24,
                ),
                title: Text(
                  "Tema: Animais",
                  style: TextStyle(
                    color: (widget.isHost && _jogadoresNaSala.isNotEmpty)
                        ? Colors.white
                        : Colors.white24,
                  ),
                ),
                onTap: (widget.isHost && _jogadoresNaSala.isNotEmpty)
                    ? () {
                        Navigator.pop(context); // Fecha o Drawer em segurança
                        _startRound('animais');
                      }
                    : null,
              ),
              // TEMA: OBJECTOS - Agora com a mesma tranca idêntica do tema anterior!
              ListTile(
                leading: Icon(
                  Icons.category,
                  color: (widget.isHost && _jogadoresNaSala.isNotEmpty)
                      ? Colors.white
                      : Colors.white24,
                ),
                title: Text(
                  "Tema: Objectos",
                  style: TextStyle(
                    color: (widget.isHost && _jogadoresNaSala.isNotEmpty)
                        ? Colors.white
                        : Colors.white24,
                  ),
                ),
                onTap: (widget.isHost && _jogadoresNaSala.isNotEmpty)
                    ? () {
                        Navigator.pop(context); // Fecha o Drawer em segurança
                        _startRound('objectos');
                      }
                    : null,
              ),
              const Divider(color: Colors.white24),
              ListTile(
                leading: const Icon(Icons.emoji_events, color: Colors.amber),
                title: const Text(
                  "Ver Hall of Fame",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarHallOfFamePopup();
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _localIsDrawing
                      ? "Ronda $_rondaAtual - $_displayWord"
                      : "Ronda $_rondaAtual - Adivinha!",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _verdeEscuro,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _tempoRestante > 10 ? _verdeEscuro : Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "⏱️ $_tempoRestante s",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_localIsDrawing)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children:
                        [
                              Colors.black,
                              Colors.red,
                              Colors.blue,
                              Colors.green,
                              Colors.orange,
                            ]
                            .map(
                              (cor) => GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedColor = cor),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: cor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedColor == cor
                                          ? Colors.grey.shade800
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                  ),
                  DropdownButton<double>(
                    value: _selectedWidth,
                    items: [2.0, 4.0, 8.0, 12.0].map((double value) {
                      return DropdownMenuItem<double>(
                        value: value,
                        child: Text("Tam: ${value.toInt()}"),
                      );
                    }).toList(),
                    onChanged: (novoTamanho) {
                      if (novoTamanho != null) {
                        setState(() => _selectedWidth = novoTamanho);
                      }
                    },
                  ),
                ],
              ),
            ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: _verdeEscuro, width: 2),
                ),
                child: ClipRect(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // CORREÇÃO: Só ativa as funções se _localIsDrawing for true E o jogo já tiver começado
                    onPanStart: (_localIsDrawing && _jogoComecou)
                        ? (details) {
                            setState(() {
                              DrawPoint p = DrawPoint(
                                x: details.localPosition.dx,
                                y: details.localPosition.dy,
                                status: PointStatus.start,
                                color: _selectedColor,
                                strokeWidth: _selectedWidth,
                              );
                              points.add(p);
                              String cmd =
                                  "START;${p.x};${p.y};${p.color.value};${p.strokeWidth}";
                              if (widget.isHost) {
                                _networkManager.sendToAllClients(cmd);
                              } else {
                                _networkManager.sendToServer(
                                  "CLIENT_DRAW:$cmd",
                                );
                              }
                            });
                          }
                        : null,
                    onPanUpdate: _localIsDrawing
                        ? (details) {
                            setState(() {
                              DrawPoint p = DrawPoint(
                                x: details.localPosition.dx,
                                y: details.localPosition.dy,
                                status: PointStatus.move,
                                color: _selectedColor,
                                strokeWidth: _selectedWidth,
                              );
                              points.add(p);
                              String cmd =
                                  "MOVE;${p.x};${p.y};${p.color.value};${p.strokeWidth}";
                              if (widget.isHost) {
                                _networkManager.sendToAllClients(cmd);
                              } else {
                                _networkManager.sendToServer(
                                  "CLIENT_DRAW:$cmd",
                                );
                              }
                            });
                          }
                        : null,
                    onPanEnd: _localIsDrawing
                        ? (_) {
                            setState(() {
                              if (points.isNotEmpty) {
                                DrawPoint p = DrawPoint(
                                  x: points.last.x,
                                  y: points.last.y,
                                  status: PointStatus.end,
                                  color: _selectedColor,
                                  strokeWidth: _selectedWidth,
                                );
                                points.add(p);
                                String cmd =
                                    "END;${p.x};${p.y};${p.color.value};${p.strokeWidth}";
                                if (widget.isHost) {
                                  _networkManager.sendToAllClients(cmd);
                                } else {
                                  _networkManager.sendToServer(
                                    "CLIENT_DRAW:$cmd",
                                  );
                                }
                              }
                            });
                          }
                        : null,
                    child: CustomPaint(
                      painter: GameCanvasPainter(points),
                      size: Size.infinite,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ListView.builder(
                itemCount: _chatHistorico.length,
                itemBuilder: (context, idx) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _chatHistorico[idx],
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
          ),
          // --- BARRA INFERIOR DE FERRAMENTAS / INPUT ORIGINAL RESTAURADA ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: _localIsDrawing
                  ? Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() => points.clear());
                            _networkManager.sendToAllClients("CLEAR");
                          },
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isChatMode
                                ? _laranjaEscuro
                                : Colors.grey,
                          ),
                          onPressed: () =>
                              setState(() => _isChatMode = !_isChatMode),
                          child: Text(
                            _isChatMode
                                ? "Modo: Conversar 💬"
                                : "Modo: Bloqueado 🎯",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        if (_isChatMode)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: TextField(
                                controller: _inputController,
                                onSubmitted: (_) => _enviarTexto(),
                                decoration: const InputDecoration(
                                  hintText: "Falar na sala...",
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _isChatMode ? Icons.chat : Icons.lightbulb,
                            color: _isChatMode ? _verdeEscuro : _laranjaEscuro,
                          ),
                          onPressed: () =>
                              setState(() => _isChatMode = !_isChatMode),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            onSubmitted: (_) => _enviarTexto(),
                            decoration: InputDecoration(
                              hintText: _isChatMode
                                  ? "Escreve uma mensagem..."
                                  : "Qual é a palavra secreta?",
                              filled: true,
                              fillColor: Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: _enviarTexto,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
