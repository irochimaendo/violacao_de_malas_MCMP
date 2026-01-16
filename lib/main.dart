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
    // SCANNER ABERTO (Sem filtro de UUID para evitar bug de não encontrar)
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
  
  // ESTADOS DA TELA
  String _statusMessage = "Conectando...";
  Color _bgColor = Colors.blueGrey;
  String _horaViolacao = "--:--";
  
  // ESTADOS LÓGICOS
  bool _conectado = false;
  bool _estaViolada = false;
  bool _estaArmada = false; 

  @override
  void initState() {
    super.initState();
    _conectarMala();
  }
  
  @override
  void dispose() {
    // Ao sair da tela, desconecta para economizar bateria
    widget.device.disconnect();
    super.dispose();
  }

  Future<void> _conectarMala() async {
    setState(() => _statusMessage = "Sincronizando...");
    try {
      await widget.device.connect();
      
      List<BluetoothService> services = await widget.device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString() == SERVICE_UUID) {
          for (var c in service.characteristics) {
            if (c.uuid.toString() == CHAR_UUID) {
              _characteristic = c;
            
              await c.setNotifyValue(true);
              c.lastValueStream.listen((value) {
                String msg = String.fromCharCodes(value);
                _processarMensagem(msg);
              });
              
              await Future.delayed(const Duration(milliseconds: 200)); // Pequeno respiro
              await c.write(utf8.encode("STATUS"));
              
              if(mounted) setState(() => _conectado = true);
            }
          }
        }
      }
    } catch (e) {
      if(mounted) setState(() { _statusMessage = "Erro de Conexão"; _conectado = false; });
    }
  }

  void _processarMensagem(String msg) {
    if (!mounted) return;
    setState(() {
      // ESTADO: DESARMADO (A)
      if (msg == "A") {
        _estaViolada = false;
        _estaArmada = false;
        _statusMessage = "Sistema Desarmado";
        _bgColor = Colors.grey[700]!;
      } 
      // ESTADO: ARMADO/SEGURO (S)
      else if (msg == "S") {
        _estaViolada = false;
        _estaArmada = true;
        _statusMessage = "🛡️ Mala Protegida";
        _bgColor = Colors.green[800]!;
      }
      // ESTADO: VIOLADO 
      else if (msg.startsWith("V:")) {
        _estaViolada = true;
        _estaArmada = true; // Continua armada, mas violada
        _statusMessage = "⚠️ MALA VIOLADA ⚠️";
        _bgColor = Colors.red[900]!;

        String segundosStr = msg.substring(2);
        int segundosAtras = int.tryParse(segundosStr) ?? 0;
        DateTime dataExata = DateTime.now().subtract(Duration(seconds: segundosAtras));
        
        String dia = dataExata.day.toString().padLeft(2, '0');
        String mes = dataExata.month.toString().padLeft(2, '0');
        String hora = dataExata.hour.toString().padLeft(2, '0');
        String min = dataExata.minute.toString().padLeft(2, '0');
        _horaViolacao = "$dia/$mes às $hora:$min";
      }

      else if (msg == "HORA_OK") {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Relógio Sincronizado!")));
      }
    });
  }

  void _enviarComando(String cmd) async {
    if (_characteristic != null) {
      await _characteristic!.write(utf8.encode(cmd));
    }
  }
  
  void _sincronizarRelogio() {
    DateTime agora = DateTime.now();
    String cmd = "T:${agora.year}:${agora.month}:${agora.day}:${agora.hour}:${agora.minute}:${agora.second}";
    _enviarComando(cmd);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: const Text("Monitoramento"), backgroundColor: Colors.transparent, elevation: 0,
        actions: [
          IconButton(
             icon: const Icon(Icons.access_time),
             onPressed: _conectado ? _sincronizarRelogio : null,
             tooltip: "Sincronizar Relógio",
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _estaViolada ? Icons.lock_open : (_estaArmada ? Icons.lock : Icons.lock_open_outlined),
              size: 100, color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            
            if (_estaViolada) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.black38,
                  border: Border.all(color: Colors.yellow, width: 2),
                  borderRadius: BorderRadius.circular(10)
                ),
                child: Column(
                  children: [
                    const Text("Abertura ocorreu em:", style: TextStyle(color: Colors.white70)),
                    Text(_horaViolacao, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.yellow)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 50),

            
            if (_conectado) ...[
              if (!_estaArmada)
                ElevatedButton.icon(
                  onPressed: () => _enviarComando("ARMAR"),
                  icon: const Icon(Icons.shield),
                  label: const Text("ATIVAR MONITORAMENTO"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: Colors.green[900],
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),


              if (_estaArmada)
                ElevatedButton.icon(
                  onPressed: () => _enviarComando("RESET"),
                  icon: const Icon(Icons.power_settings_new),
                  label: Text(_estaViolada ? "RESETAR ALARME" : "DESATIVAR"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white, foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                ),
            ] else ...[
               const CircularProgressIndicator(color: Colors.white),
               const SizedBox(height: 10),
               const Text("Sincronizando...", style: TextStyle(color: Colors.white))
            ]
          ],
        ),
      ),
    );
  }
}
