import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:math';

class WordManager {
  // Substitui pelo teu nome de utilizador do GitHub e repositório quando o criares!
  // Por enquanto, criei um repositório temporário de testes com listas reais.
  final String _baseUrl =
      "https://raw.githubusercontent.com/IdeiafixVitorinox/picwordio-words/refs/heads/main/themes";

  List<String> _currentWords = [];
  String _selectedWord = "";

  // 1. Descarrega o ficheiro .txt do GitHub baseado no tema escolhido
  Future<bool> loadTheme(String themeName) async {
    final url = Uri.parse('$_baseUrl/$themeName.txt');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      // ADICIONA ESTAS DUAS LINHAS AQUI PARA INVESTIGARMOS:
      print("🔗 URL TENTADA: $url");
      print("Status Code do GitHub: ${response.statusCode}");

      if (response.statusCode == 200) {
        // Limpa caracteres invisíveis de quebra de linha comuns no Windows/Web (\r)
        final limpo = response.body.replaceAll('\r', '');

        _currentWords = const LineSplitter()
            .convert(limpo)
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && !e.startsWith('#'))
            .toList();

        return _currentWords.isNotEmpty;
      }
    } catch (e, stacktrace) {
      // Isto vai imprimir o erro exato e a linha onde ele falhou no teu terminal
      print("❌ ERRO COMPLETO DA REDE: $e");
      print("❌ STACKTRACE: $stacktrace");
    }
    return false;
  }

  // 2. Sorteia uma palavra aleatória da lista carregada
  String drawNewWord() {
    if (_currentWords.isEmpty) return "PICWORDIO";

    final random = Random();
    _selectedWord = _currentWords[random.nextInt(_currentWords.length)];
    return _selectedWord.toUpperCase();
  }

  // 3. Devolve a palavra atual (útil para o Host e Desenhador)
  String get currentWord => _selectedWord.toUpperCase();

  // 4. Transforma a palavra em traços para os adivinhadores (ex: "GATO" -> "_ _ _ _")
  String get maskedWord {
    return _selectedWord.replaceAll(RegExp(r'[A-Za-zA-ZÀ-ÿ]'), '_ ');
  }
}
