import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class ScoreManager {
  int _currentRoomScore = 0;

  // Mantemos o Map para leitura rápida, mas a lógica vai garantir que só sobram 10
  Map<String, int> _localHallOfFame = {};

  int get currentRoomScore => _currentRoomScore;

  // Novo setter para atualizar o score do quarto (útil para os clientes sincronizarem)
  void setCurrentRoomScore(int score) {
    _currentRoomScore = score;
  }

  // Construtor: tenta carregar os recordes guardados assim que o gestor é criado
  ScoreManager() {
    loadHallOfFame();
  }

  void addPoints(int points) {
    _currentRoomScore += points;
  }

  void resetRoomScore() {
    _currentRoomScore = 0;
  }

  List<MapEntry<String, int>> getHallOfFame() {
    var sortedEntries = _localHallOfFame.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sortedEntries;
  }

  // === CARREGAR DADOS DO DISCO ===
  Future<void> loadHallOfFame() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString('hall_of_fame_picwordio');

      if (jsonString != null) {
        Map<String, dynamic> decoded = jsonDecode(jsonString);
        _localHallOfFame = decoded.map(
          (key, value) => MapEntry(key, value as int),
        );
      }
    } catch (e) {
      print("Erro ao carregar Hall of Fame: $e");
    }
  }

  // === GUARDAR DADOS NO DISCO DE FORMA PERSISTENTE (APENAS TOP 10) ===
  Future<void> saveToHallOfFame(String name, int score) async {
    // 1. Atualiza ou insere o recorde do jogador atual
    if (_localHallOfFame.containsKey(name)) {
      _localHallOfFame[name] = max(_localHallOfFame[name]!, score);
    } else {
      _localHallOfFame[name] = score;
    }

    // 2. FILTRAGEM DO TOP 10: Convertemos para lista, ordenamos e cortamos o excesso
    var sortedEntries = _localHallOfFame.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (sortedEntries.length > 10) {
      sortedEntries = sortedEntries.sublist(0, 10);
    }

    // 3. Reconverte a lista filtrada de volta para o mapa local
    _localHallOfFame = Map.fromEntries(sortedEntries);

    // 4. Grava no SharedPreferences (apenas os 10 sobreviventes)
    try {
      final prefs = await SharedPreferences.getInstance();
      String jsonString = jsonEncode(_localHallOfFame);
      await prefs.setString('hall_of_fame_picwordio', jsonString);
    } catch (e) {
      print("Erro ao guardar no Hall of Fame: $e");
    }
  }

  // === NOVO: GERAR STRING FORMATADA PARA ENVIAR AOS CLIENTES VIA REDE ===
  String getHallOfFameFormatado() {
    if (_localHallOfFame.isEmpty) return "";
    // Transforma o mapa numa String compacta. Exemplo: "Rui:150;Pedro:100"
    return _localHallOfFame.entries.map((e) => "${e.key}:${e.value}").join(";");
  }

  // === NOVO: ATUALIZAR O HALL OF FAME LOCAL DO CLIENTE COM OS DADOS DO HOST ===
  void atualizarHallOfFameLocal(String dadosFormatados) {
    if (dadosFormatados.isEmpty) return;
    try {
      Map<String, int> novoHof = {};
      List<String> linhas = dadosFormatados.split(";");
      for (String linha in linhas) {
        List<String> partes = linha.split(":");
        if (partes.length == 2) {
          novoHof[partes[0]] = int.parse(partes[1]);
        }
      }
      _localHallOfFame = novoHof;
    } catch (e) {
      print("Erro ao processar HOF enviado pelo Host: $e");
    }
  }

  // === ADICIONA ESTE MÉTODO NO TEU SCOREMANAGER ===
  void limparDadosDaSala() {
    _currentRoomScore = 0;
    // NOTA: Não limpamos o _localHallOfFame aqui para não apagar os recordes históricos do disco,
    // mas garantimos que a pontuação da sessão atual começa virgem!
  }
}
