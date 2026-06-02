import 'dart:io';
import 'dart:convert';
import 'package:network_info_plus/network_info_plus.dart';

class NetworkManager {
  final NetworkInfo _networkInfo = NetworkInfo();

  ServerSocket? _serverSocket;
  final List<Socket> _connectedClients = [];
  Socket? _clientSocket;

  // Flag para trancar a entrada de novos jogadores assim que o jogo inicia
  bool gameStarted = false;

  Future<String?> getLocalIP() async {
    try {
      return await _networkInfo.getWifiIP();
    } catch (e) {
      return null;
    }
  }

  // ==========================================
  // LÓGICA DO HOST (SERVIDOR)
  // ==========================================

  Future<void> startServer(Function(String message) onMessageReceived) async {
    try {
      await _serverSocket?.close();
    } catch (_) {}

    try {
      _serverSocket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        4040,
        shared: true,
      );

      _serverSocket!.listen((Socket client) {
        // Se o jogo já começou, rejeita o participante imediatamente
        if (gameStarted) {
          client.write(
            "SYSTEM:A sala já está em andamento! Não podes entrar agora.❌\n",
          );
          client.close();
          return;
        }

        _connectedClients.add(client);
        client.write("SYSTEM:CONECTADO_COM_SUCESSO\n");

        client.listen(
          (data) {
            String message = utf8.decode(data);
            for (var msg in message.split('\n')) {
              if (msg.trim().isNotEmpty) {
                onMessageReceived(msg.trim());
              }
            }
          },
          onDone: () {
            _connectedClients.remove(client);
            client.close();
          },
          onError: (error) {
            _connectedClients.remove(client);
            client.close();
          },
        );
      });
    } catch (e) {
      print("Erro crítico ao iniciar o servidor TCP: $e");
    }
  }

  void sendToAllClients(String message) {
    final formattedMessage = "$message\n";
    for (var client in _connectedClients) {
      try {
        client.write(formattedMessage);
      } catch (e) {
        // Ignora falhas individuais de envio
      }
    }
  }

  // ==========================================
  // LÓGICA DO ADIVINHADOR (CLIENTE)
  // ==========================================

  Future<void> connectToServer(
    String targetIP,
    Function(String message) onMessageReceived,
  ) async {
    try {
      _clientSocket = await Socket.connect(
        targetIP,
        4040,
        timeout: const Duration(seconds: 5),
      );

      _clientSocket!.listen(
        (data) {
          String message = utf8.decode(data);
          for (var msg in message.split('\n')) {
            if (msg.trim().isNotEmpty) {
              onMessageReceived(msg.trim());
            }
          }
        },
        onDone: () {
          _clientSocket?.close();
        },
        onError: (error) {
          _clientSocket?.close();
        },
        cancelOnError: true,
      );
    } catch (e) {
      rethrow;
    }
  }

  void sendToServer(String message) {
    if (_clientSocket != null) {
      try {
        _clientSocket!.write("$message\n");
      } catch (e) {
        print("Erro ao enviar mensagem para o servidor: $e");
      }
    }
  }

  void closeAll() {
    try {
      _serverSocket?.close();
      for (var client in _connectedClients) {
        client.close();
      }
      _connectedClients.clear();
      _clientSocket?.close();
      _clientSocket = null;
      gameStarted = false;
    } catch (e) {
      print("Erro ao fechar conexões: $e");
    }
  }
}
