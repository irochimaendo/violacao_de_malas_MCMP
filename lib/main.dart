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
  // UUIDs (DEVEM SER IGUAIS AOS DO ESP32)
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

  // 1. Busca dispositivo
  Future<void> _iniciarBusca() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // Filtra pelo UUID do serviço para achar mais rápido
    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 15),
      withServices: [Guid(SERVICE_UUID)], 
    );

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        // Aceita qualquer nome, desde que tenha o UUID certo
        if (r.device.platformName == "Mala Inteligente" || r.advertisementData.serviceUuids.contains(Guid(SERVICE_UUID))) {
          FlutterBluePlus.stopScan();
          _conectarMala(r.device);
          break;
        }
      }
    });
  }

  // 2. Conecta
  Future<void> _conectarMala(BluetoothDevice device) async {
    setState(() {
      _statusMessage = "Conectando...";
    });

    try {
      await device.connect();
      _device = device;
      
      setState(() {
        _conectado = true;
        _statusMessage = "Conectado! Aguardando...";
      });

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
      print("Erro: $e");
      setState(() {
        _statusMessage = "Erro ao conectar.";
      });
    }
  }

  // 3. Ouve notificações
  Future<void> _configurarNotificacoes(BluetoothCharacteristic c) async {
    await c.setNotifyValue(true);
    
    c.lastValueStream.listen((value) {
      String mensagem = String.fromCharCodes(value);
      _processarMensagem(mensagem);
    });
  }

// 4. Lógica (CORRIGIDA)
void _processarMensagem(String msg) {
    setState(() {
      if (msg == "S") {
        _estaViolada = false;
        _statusMessage = "Mala Segura";
        _bgColor = Colors.green;
      } 
      else if (msg == "A") { // Adicionei o estado Desarmado pra ficar bonitinho
         _estaViolada = false;
         _statusMessage = "Sistema Desarmado";
         _bgColor = Colors.grey;
      }
      else if (msg.startsWith("V:")) {
        _estaViolada = true;
        _statusMessage = "⚠️ MALA VIOLADA ⚠️";
        _bgColor = Colors.red;

        // 1. Pega o número de segundos que veio depois do "V:"
        String segundosStr = msg.substring(2);
        int segundosAtras = int.tryParse(segundosStr) ?? 0;

        // 2. Faz a conta mágica: Hora do Celular - Segundos de atraso
        DateTime dataExata = DateTime.now().subtract(Duration(seconds: segundosAtras));

        // 3. Formata para mostrar na tela (Dia/Mes Hora:Minuto)
        String dia = dataExata.day.toString().padLeft(2, '0');
        String mes = dataExata.month.toString().padLeft(2, '0');
        String hora = dataExata.hour.toString().padLeft(2, '0');
        String min = dataExata.minute.toString().padLeft(2, '0');
        
        _horaViolacao = "$dia/$mes às $hora:$min";
      }
    });
  }

  // 5. Envia COMANDOS
  void _enviarComando(String cmd) async {
    if (_characteristic != null) {
      await _characteristic!.write(utf8.encode(cmd));
    }
  }

  // --- NOVO: Função para Sincronizar Relógio ---
  void _sincronizarRelogio() {
    DateTime agora = DateTime.now();
    // Formata no padrão T:AAAA:MM:DD:HH:MM:SS
    String cmd = "T:${agora.year}:${agora.month}:${agora.day}:${agora.hour}:${agora.minute}:${agora.second}";
    
    print("Enviando hora: $cmd"); // Debug
    _enviarComando(cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text("App Mala Inteligente"), 
        backgroundColor: Colors.transparent, 
        elevation: 0,
        actions: [
          // Ícone para ver se está conectado
          Icon(_conectado ? Icons.bluetooth_connected : Icons.bluetooth_disabled),
          const SizedBox(width: 20),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _estaViolada ? Icons.no_encryption : Icons.lock,
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            
            if (_estaViolada) ...[
              const SizedBox(height: 10),
              Container(
                padding: EdgeInsets.all(10),
                color: Colors.black26,
                child: Text(
                  "Data: $_horaViolacao",
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.yellow),
                ),
              ),
            ],

            const SizedBox(height: 50),

            // --- BOTÕES DE CONTROLE ---
            
            // 1. Botão ARMAR
            if (!_estaViolada)
              ElevatedButton.icon(
                onPressed: () => _enviarComando("ARMAR"),
                icon: const Icon(Icons.security),
                label: const Text("ATIVAR ALARME"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green[800],
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                ),
              ),

            const SizedBox(height: 20),

            // 2. Botão RESET (Aparece sempre para permitir cancelar ou limpar erro)
            ElevatedButton.icon(
              onPressed: () => _enviarComando("RESET"),
              icon: const Icon(Icons.refresh),
              label: const Text("RESETAR / DESARMAR"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),

            const SizedBox(height: 40),
            Divider(color: Colors.white54),
            
            // 3. Botão SINCRONIZAR RELÓGIO (Novo!)
            TextButton.icon(
              onPressed: _conectado ? _sincronizarRelogio : null,
              icon: const Icon(Icons.access_time, color: Colors.white),
              label: const Text("Sincronizar Relógio com Celular", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }
}