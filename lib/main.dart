import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ScanPage(),
  ));
}

// ==========================================
// TELA 1: BUSCA (Igual a anterior)
// ==========================================
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  List<ScanResult> _scanResults = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _pedirPermissoes();
  }

  Future<void> _pedirPermissoes() async {
    await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.location].request();
  }

  Future<void> _iniciarScan() async {
    setState(() { _isScanning = true; _scanResults.clear(); });
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));
    FlutterBluePlus.scanResults.listen((results) {
      final filtered = results.where((r) => r.device.platformName.isNotEmpty).toList();
      if (mounted) setState(() => _scanResults = filtered);
    });
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) setState(() => _isScanning = false);
  }

  void _irParaMonitor(BluetoothDevice device) {
    FlutterBluePlus.stopScan();
    Navigator.push(context, MaterialPageRoute(builder: (context) => MonitorPage(device: device)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parear Mala"), centerTitle: true),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: ElevatedButton.icon(
              onPressed: _isScanning ? null : _iniciarScan,
              icon: _isScanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Icon(Icons.search),
              label: Text(_isScanning ? "Buscando..." : "BUSCAR DISPOSITIVOS"),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            ),
          ),
          const Divider(),
          Expanded(
            child: _scanResults.isEmpty
                ? const Center(child: Text("Nenhum dispositivo encontrado."))
                : ListView.builder(
                    itemCount: _scanResults.length,
                    itemBuilder: (context, index) {
                      final result = _scanResults[index];
                      return Card(
                        child: ListTile(
                          title: Text(result.device.platformName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(result.device.remoteId.toString()),
                          trailing: ElevatedButton(child: const Text("CONECTAR"), onPressed: () => _irParaMonitor(result.device)),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// TELA 2: MONITORAMENTO (Atualizada com Lógica Ativar/Desativar)
// ==========================================
class MonitorPage extends StatefulWidget {
  final BluetoothDevice device;
  const MonitorPage({super.key, required this.device});

  @override
  State<MonitorPage> createState() => _MonitorPageState();
}

class _MonitorPageState extends State<MonitorPage> {
  final String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String CHAR_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  BluetoothCharacteristic? _characteristic;
  
  // Estados da Interface
  String _statusMessage = "Conectando...";
  Color _bgColor = Colors.grey;
  String _horaViolacao = "--:--";
  
  // Variáveis de controle lógico
  bool _estaViolada = false;
  bool _estaDesativada = false; // Novo estado

  @override
  void initState() {
    super.initState();
    _conectarMala();
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }

  Future<void> _conectarMala() async {
    try {
      await widget.device.connect();
      setState(() => _statusMessage = "Conectado! Lendo dados...");
      
      List<BluetoothService> services = await widget.device.discoverServices();
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
      setState(() => _statusMessage = "Erro de conexão.");
    }
  }

  Future<void> _configurarNotificacoes(BluetoothCharacteristic c) async {
    await c.setNotifyValue(true);
    c.lastValueStream.listen((value) {
      String mensagem = String.fromCharCodes(value);
      _processarMensagem(mensagem);
    });
  }

  void _processarMensagem(String msg) {
    if (!mounted) return;
    setState(() {
      if (msg == "S") {
        // MALA SEGURA
        _estaViolada = false;
        _estaDesativada = false;
        _statusMessage = "Mala Segura";
        _bgColor = Colors.green;
      } 
      else if (msg == "D") {
        // MALA DESATIVADA (Standby)
        _estaViolada = false;
        _estaDesativada = true;
        _statusMessage = "Monitoramento Pausado";
        _bgColor = Colors.blueGrey; // Cor diferente para indicar pausa
      }
      else if (msg.startsWith("V:")) {
        // VIOLAÇÃO
        _estaViolada = true;
        _estaDesativada = false;
        _statusMessage = "⚠️ MALA VIOLADA ⚠️";
        _bgColor = Colors.red;

        String milissegundosStr = msg.substring(2); 
        int msAtras = int.tryParse(milissegundosStr) ?? 0;
        DateTime dataViolacao = DateTime.now().subtract(Duration(milliseconds: msAtras));
        String hora = dataViolacao.hour.toString().padLeft(2, '0');
        String minuto = dataViolacao.minute.toString().padLeft(2, '0');
        _horaViolacao = "$hora:$minuto";
      }
    });
  }

  // Função genérica para enviar comandos
  void _enviarComando(String comando) async {
    if (_characteristic != null) {
      await _characteristic!.write(utf8.encode(comando));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Text(widget.device.platformName), 
        elevation: 0, 
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ÍCONE MUDA CONFORME O ESTADO
            Icon(
              _estaViolada ? Icons.lock_open : (_estaDesativada ? Icons.pause_circle_filled : Icons.lock),
              size: 100,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            
            // SE ESTIVER VIOLADA -> MOSTRA HORA E BOTÃO DESATIVAR
            if (_estaViolada) ...[
              const SizedBox(height: 10),
              Text(
                "Ocorreu às: $_horaViolacao",
                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.yellow),
              ),
              const SizedBox(height: 40),
              
              ElevatedButton.icon(
                onPressed: () => _enviarComando("DESATIVAR"), // Manda comando para parar
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text("DESATIVAR ALARME"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                ),
              )
            ],

            // SE ESTIVER DESATIVADA -> MOSTRA BOTÃO DE REATIVAR
            if (_estaDesativada) ...[
              const SizedBox(height: 40),
              const Text(
                "O sistema está dormindo.\nClique abaixo para voltar a vigiar.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _enviarComando("ATIVAR"), // Manda comando para voltar
                icon: const Icon(Icons.play_circle_fill),
                label: const Text("REATIVAR MONITORAMENTO"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.blueGrey,
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