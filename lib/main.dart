import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mala Inteligente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF1E1E1E),
        useMaterial3: true,
      ),
      home: const MalaScreen(),
    );
  }
}

class MalaScreen extends StatefulWidget {
  const MalaScreen({super.key});

  @override
  State<MalaScreen> createState() => _MalaScreenState();
}

class _MalaScreenState extends State<MalaScreen> {
  // Variáveis
  String statusConexao = "Desconectado";
  String logMala = "Nenhuma violação detectada";
  bool isConectado = false;
  
  // Lista de dispositivos encontrados
  List<ScanResult> dispositivosEncontrados = [];

  @override
  void initState() {
    super.initState();
    _pedirPermissoes();
  }

  Future<void> _pedirPermissoes() async {
    // Garante que todas as permissões necessárias foram dadas
    // Se o app fechar sozinho no Android 12+, pode ser falta de permissão no AndroidManifest
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  // --- LÓGICA DO BLUETOOTH ---
  void _buscarDispositivos() async {
    try {
      // Inicia a busca
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint("Erro ao iniciar scan: $e");
    }

    // Abre a janela IMEDIATAMENTE. O StreamBuilder vai preenchê-la.
    if (mounted) {
      _mostrarListaDispositivos();
    }
  }

  void _mostrarListaDispositivos() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: 500,
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              const Text(
                "Dispositivos Próximos", 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
              ),
              const SizedBox(height: 10),
              Expanded(
                child: StreamBuilder<List<ScanResult>>(
                  stream: FlutterBluePlus.scanResults,
                  initialData: const [],
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text("Erro no Scan"));
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("Procurando...", style: TextStyle(color: Colors.grey))
                      );
                    }

                    final resultados = snapshot.data!;

                    return ListView.builder(
                      itemCount: resultados.length,
                      itemBuilder: (context, index) {
                        final resultado = resultados[index];
                        final nome = resultado.device.platformName.isNotEmpty 
                            ? resultado.device.platformName 
                            : "Dispositivo Desconhecido";
                        
                        return ListTile(
                          title: Text(nome, style: const TextStyle(color: Colors.white)),
                          subtitle: Text(resultado.device.remoteId.toString(), style: const TextStyle(color: Colors.grey)),
                          leading: const Icon(Icons.bluetooth, color: Colors.blue),
                          onTap: () {
                            _conectarDispositivo(resultado.device);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ).whenComplete(() {
      FlutterBluePlus.stopScan();
    });
  }

  // Função de conexão corrigida
  void _conectarDispositivo(BluetoothDevice device) async {
    Navigator.pop(context); // Fecha a lista
    
    setState(() {
      statusConexao = "Conectando a ${device.platformName}...";
    });

    try {
      // Conecta com timeout
      await device.connect(timeout: const Duration(seconds: 15));
      
      // Solicita prioridade se for Android (Requer import dart:io)
      if (Platform.isAndroid){
        await device.requestMtu(512);
      }

      if (mounted) {
        setState(() {
          statusConexao = "Conectado a ${device.platformName}";
          isConectado = true;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() {
          statusConexao = "Erro ao conectar: $e";
          isConectado = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitoramento de Mala"),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[900],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              isConectado ? Icons.lock_open : Icons.lock,
              size: 100,
              color: isConectado ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(
              "Status: $statusConexao",
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: _buscarDispositivos,
              icon: const Icon(Icons.bluetooth_searching),
              label: const Text("BUSCAR MALA (DISPOSITIVOS)"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.grey[850],
              child: Padding(
                padding: const EdgeInsets.all(15.0),
                child: Column(
                  children: [
                    const Text(
                      "Histórico de Violação",
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 18),
                    ),
                    const Divider(color: Colors.white24),
                    Text(
                      logMala,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}