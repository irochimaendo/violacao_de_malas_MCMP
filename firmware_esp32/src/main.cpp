#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h> 

// --- CONFIGURAÇÕES ---
#define LDR_PIN 0           // Pino do sensor
#define LIMITE_LUZ 2000     // Ajuste conforme seu teste (ex: abaixo de 2000 é luz, acima é escuro ou vice-versa)
// NOTA: No ESP32-C3, analogRead varia de 0 a 4095. 
// Geralmente: Valor ALTO = Escuro, Valor BAIXO = Claro (mas depende da ligação do resistor).
// Ajustaremos a lógica no loop abaixo.

// UUIDs (Não mude para garantir que o app ache)
#define NOME_MALA "MALA_INTELIGENTE"
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

// Variáveis de Estado
bool violacaoDetectada = false; 
unsigned long momentoDaViolacao = 0;
bool deviceConnected = false;
bool oldDeviceConnected = false;

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;

// 1. CALLBACKS DE CONEXÃO (Saber quando o celular conecta/desconecta)
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println(">> Celular CONECTADO!");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println(">> Celular desconectado.");
      // Reinicia o anuncio para conectar novamente depois
      BLEDevice::startAdvertising();
    }
};

// 2. CALLBACKS DE ESCRITA (Para receber o comando de "RESET" do App)
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();

      if (value.length() > 0) {
        Serial.print("Comando recebido do App: ");
        Serial.println(value.c_str());

        // Se o App mandar a palavra "RESET", a gente desliga o alarme
        if (value == "RESET") {
           violacaoDetectada = false;
           momentoDaViolacao = 0;
           Serial.println("ALARME RESETADO PELO USUÁRIO!");
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  pinMode(LDR_PIN, INPUT);

  Serial.println("=== INICIANDO MALA INTELIGENTE ===");

  // Inicializa BLE
  BLEDevice::init(NOME_MALA);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Cria a característica (Agora com permissão de WRITE também)
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  | 
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );

  pCharacteristic->addDescriptor(new BLE2902());
  pCharacteristic->setCallbacks(new MyCallbacks()); // Adiciona o callback de leitura

  pService->start();

  // Configurações de Anúncio (Advertising)
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0); 
  BLEDevice::startAdvertising();
  
  Serial.println("Aguardando conexao...");
}

void loop() {
  // Leitura do Sensor (Melhor usar Analog para calibrar sensibilidade)
  int valorLuz = analogRead(LDR_PIN);
  
  // --- LÓGICA DE DETECÇÃO ---
  // Se o valor for MENOR que o limite, significa que entrou LUZ (ajuste se seu sensor for invertido)
  // Supondo: 0 = Muita Luz, 4095 = Escuridão Total
  bool temLuz = (valorLuz < LIMITE_LUZ); 

  if (temLuz && !violacaoDetectada) {
     // Violação ocorreu AGORA
     violacaoDetectada = true;
     momentoDaViolacao = millis();
     Serial.println("!!! VIOLACAO DETECTADA !!!");
  }

  // --- ENVIO DE DADOS ---
  if (deviceConnected) {
      String mensagem = "";

      if (violacaoDetectada) {
          // Envia: "V:15000" (Violação detectada há 15000 milissegundos)
          unsigned long tempoDecorrido = millis() - momentoDaViolacao;
          mensagem = "V:" + String(tempoDecorrido);
      } else {
          // Envia: "S" (Seguro / Safe)
          mensagem = "S"; 
      }

      // Envia para o celular
      pCharacteristic->setValue((char*)mensagem.c_str());
      pCharacteristic->notify();
      
      // Debug no Serial
      // Serial.print("LDR: "); Serial.print(valorLuz);
      // Serial.print(" | Envio: "); Serial.println(mensagem);
      
      delay(500); // Envia a cada meio segundo para não travar o app
  } else {
      delay(100);
  }

  // Reconexão automática caso bugue
  if (!deviceConnected && oldDeviceConnected) {
      delay(500); 
      pServer->startAdvertising(); 
      oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }
}