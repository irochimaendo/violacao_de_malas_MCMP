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
    await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Necessário para BLE no Android
    ].request();
  }

  // --- LÓGICA DO BLUETOOTH ---
// --- VERSÃO SEM FILTRO (MOSTRA TUDO) ---
  void _buscarDispositivos() async {
    // 1. Limpa a lista anterior
    setState(() {
      dispositivosEncontrados.clear();
      statusConexao = "Buscando (Modo Aberto)...";
    });

    // 2. Ouve TUDO (Removemos o filtro .where)
    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      setState(() {
        dispositivosEncontrados = results; 
      });
    });

    // 3. Começa a escanear por 10 segundos (aumentei o tempo)
    // AllowDuplicates: true ajuda a achar dispositivos que enviam sinal repetido
    await FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 10),
      androidUsesFineLocation: true,
    );

    // 4. Para de ouvir
    await FlutterBluePlus.stopScan();
    subscription.cancel();

    setState(() {
      statusConexao = "Scan finalizado. ${dispositivosEncontrados.length} encontrados.";
    });
    
    _mostrarListaDispositivos();
  }

  void _mostrarListaDispositivos() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      builder: (context) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(15.0),
              child: Text("Dispositivos Próximos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: dispositivosEncontrados.length,
                itemBuilder: (context, index) {
                  final resultado = dispositivosEncontrados[index];
                  return ListTile(
                    title: Text(resultado.device.platformName, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(resultado.device.remoteId.toString(), style: const TextStyle(color: Colors.grey)),
                    leading: const Icon(Icons.bluetooth, color: Colors.blue),
                    onTap: () {
                      // Aqui vamos conectar no futuro
                      Navigator.pop(context); // Fecha a lista
                      setState(() {
                        statusConexao = "Conectado a ${resultado.device.platformName}";
                        isConectado = true;
                      });
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
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
              onPressed: _buscarDispositivos, // Chama a função de busca
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