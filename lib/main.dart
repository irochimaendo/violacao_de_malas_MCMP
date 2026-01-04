import 'dart:async';
import 'dart:convert'; // Para usar utf8
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MalaPage(),
  ));
}

class MalaPage extends StatefulWidget {
  const MalaPage({super.key});

  @override
  State<MalaPage> createState() => _MalaPageState();
}

class _MalaPageState extends State<MalaPage> {
  // UUIDs (Precisam ser iguais aos do ESP32)
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // Variáveis de Estado
  BluetoothDevice? _device;
  BluetoothCharacteristic? _characteristic;
  String _statusMessage = "Procurando Mala...";
  Color _bgColor = Colors.grey;
  String _horaViolacao = "--:--";
  bool _estaViolada = false;
  bool _conectado = false;

  @override
  void initState() {
    super.initState();
    _iniciarBusca();
  }

  // 1. Pede permissão e busca a mala
  Future<void> _iniciarBusca() async {
    // Pede permissões no Android
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Começa a escanear
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    // Ouve os resultados do scan
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Se achou o dispositivo pelo nome
        if (r.device.platformName == "MALA_INTELIGENTE" || 
            r.device.platformName == "MALA_TESTE_LDR") { // Coloquei os dois nomes por garantia
          
          FlutterBluePlus.stopScan(); // Para de buscar
          _conectarMala(r.device);
          break;
        }
      }
    });
  }

  // 2. Conecta e descobre os serviços
  Future<void> _conectarMala(BluetoothDevice device) async {
    setState(() {
      _statusMessage = "Conectando...";
    });

    try {
      await device.connect();
      _device = device;
      
      setState(() {
        _conectado = true;
        _statusMessage = "Conectado! Lendo dados...";
      });

      // Descobre os serviços
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (var c in service.characteristics) {
            if (c.uuid.toString() == CHAR_UUID) {
              _characteristic = c;
              _configurarNotificacoes(c);
            }
          }
        }
      }
    } catch (e) {
      print("Erro ao conectar: $e");
    }
  }

  // 3. Ouve o que o ESP32 está falando
  Future<void> _configurarNotificacoes(BluetoothCharacteristic c) async {
    await c.setNotifyValue(true);
    
    // Escuta o fluxo de dados
    c.lastValueStream.listen((value) {
      // Converte bytes para Texto
      String mensagem = String.fromCharCodes(value);
      _processarMensagem(mensagem);
    });
  }

  // 4. A Lógica Inteligente (Traduz o código do ESP)
  void _processarMensagem(String msg) {
    setState(() {
      if (msg == "S") {
        // MALA SEGURA
        _estaViolada = false;
        _statusMessage = "Mala Segura";
        _bgColor = Colors.green;
      } else if (msg.startsWith("V:")) {
        // VIOLAÇÃO DETECTADA!
        _estaViolada = true;
        _statusMessage = "⚠️ MALA VIOLADA ⚠️";
        _bgColor = Colors.red;

        // Pega o número depois do "V:" (ex: 15000)
        String milissegundosStr = msg.substring(2); 
        int msAtras = int.tryParse(milissegundosStr) ?? 0;

        // Calcula a hora exata da violação
        // Hora Atual - Tempo decorrido
        DateTime dataViolacao = DateTime.now().subtract(Duration(milliseconds: msAtras));
        
        // Formata para mostrar hora e minuto (ex: 14:35)
        String hora = dataViolacao.hour.toString().padLeft(2, '0');
        String minuto = dataViolacao.minute.toString().padLeft(2, '0');
        _horaViolacao = "$hora:$minuto";
      }
    });
  }

  // 5. Função de Reset (Igual você fez no nRF Connect)
  void _resetarAlarme() async {
    if (_characteristic != null) {
      // Envia a palavra "RESET" para o ESP32
      await _characteristic!.write(utf8.encode("RESET"));
      
      // Feedback visual imediato
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Comando de Reset enviado!"))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor, // Muda a cor do fundo dinamicamente
      appBar: AppBar(title: const Text("Monitor de Mala"), elevation: 0, backgroundColor: Colors.transparent,),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ícone Gigante
            Icon(
              _estaViolada ? Icons.lock_open : Icons.lock,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            
            // Texto de Status
            Text(
              _statusMessage,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            
            // Se estiver violada, mostra a hora
            if (_estaViolada) ...[
              const SizedBox(height: 10),
              Text(
                "Ocorreu às: $_horaViolacao",
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.yellow),
              ),
              const SizedBox(height: 40),
              
              // Botão de RESET
              ElevatedButton.icon(
                onPressed: _resetarAlarme,
                icon: const Icon(Icons.refresh),
                label: const Text("DESATIVAR ALARME / RESETAR"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}