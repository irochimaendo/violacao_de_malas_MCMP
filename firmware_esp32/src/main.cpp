#include <Arduino.h>
#include <Wire.h>
#include <RTClib.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Preferences.h>

#define MEU_SDA 8
#define MEU_SCL 9
#define PINO_LDR 0 
#define LIMITE_LUZ 4000 

RTC_DS3231 rtc;
Preferences memoria;
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;

bool sistemaArmado = false;   
bool sistemaViolado = false;  
uint32_t momentoViolacao = 0;

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

void salvarTudo() {
  memoria.begin("mala_app", false); 
  memoria.putBool("armado", sistemaArmado);
  memoria.putBool("violado", sistemaViolado);
  memoria.putUInt("momento_v", momentoViolacao);
  memoria.end(); 
  Serial.println(">>> DADOS BLINDADOS NA MEMORIA FLASH <<<");
}

void enviarEstado() {
  if (deviceConnected) {
    String mensagem;
    
    if (sistemaViolado && momentoViolacao > 0) {
      uint32_t agora = rtc.now().unixtime();
      
      uint32_t segundosAtras = 0;
      if (agora >= momentoViolacao) {
         segundosAtras = agora - momentoViolacao;
      }
      
      mensagem = "V:" + String(segundosAtras); 
      Serial.println("Status: VIOLADO (" + mensagem + ")");
    } 
    else if (sistemaArmado) {
      mensagem = "S"; 
      Serial.println("Status: ARMADO");
    } 
    else {
      mensagem = "A"; 
      Serial.println("Status: DESARMADO");
    }
    
    pCharacteristic->setValue(mensagem.c_str());
    pCharacteristic->notify();
  }
}

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
      Serial.println("Celular CONECTADO.");
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      Serial.println("Celular DESCONECTADO.");
      delay(100); 
      BLEDevice::startAdvertising();
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      String comando = String(pCharacteristic->getValue().c_str());
      Serial.println("Comando: " + comando);

      if (comando == "STATUS") {
        enviarEstado(); 
      }
      else if (comando == "ARMAR") {
        sistemaArmado = true;
        sistemaViolado = false;
        momentoViolacao = 0;
        salvarTudo(); 
        enviarEstado();
      } 
      else if (comando == "RESET") {
        sistemaArmado = false;
        sistemaViolado = false;
        momentoViolacao = 0;
        salvarTudo(); 
        enviarEstado();
      }
      else if (comando.startsWith("T:")) {
         String dados = comando.substring(2); 
         int ano = dados.substring(0, dados.indexOf(':')).toInt(); dados = dados.substring(dados.indexOf(':') + 1);
         int mes = dados.substring(0, dados.indexOf(':')).toInt(); dados = dados.substring(dados.indexOf(':') + 1);
         int dia = dados.substring(0, dados.indexOf(':')).toInt(); dados = dados.substring(dados.indexOf(':') + 1);
         int hora = dados.substring(0, dados.indexOf(':')).toInt(); dados = dados.substring(dados.indexOf(':') + 1);
         int minuto = dados.substring(0, dados.indexOf(':')).toInt(); dados = dados.substring(dados.indexOf(':') + 1);
         int seg = dados.toInt();
         
         if (ano > 2020) {
            rtc.adjust(DateTime(ano, mes, dia, hora, minuto, seg));
            pCharacteristic->setValue("HORA_OK");
            pCharacteristic->notify();
         }
      }
    }
};

void setup() {
  Serial.begin(115200);
  Wire.begin(MEU_SDA, MEU_SCL);
  
  if (!rtc.begin()) {
    Serial.println("ERRO CRITICO: RTC NAO ENCONTRADO");
  }
  
  DateTime agora = rtc.now();
  if (agora.year() < 2025) { 
    Serial.println("RTC desatualizado! Ajustando para hora da compilacao...");
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  } else {
    Serial.println("RTC com hora valida (Bateria OK). Mantendo contagem...");
  }
  
  memoria.begin("mala_app", true);
  sistemaArmado = memoria.getBool("armado", false);
  sistemaViolado = memoria.getBool("violado", false);
  momentoViolacao = memoria.getUInt("momento_v", 0);
  memoria.end(); 

  Serial.println("--- SISTEMA INICIADO ---");
  Serial.print("Armado: "); Serial.println(sistemaArmado);
  Serial.print("Violado: "); Serial.println(sistemaViolado);

  BLEDevice::init("Mala Inteligente");
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(CHARACTERISTIC_UUID, BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_NOTIFY);
  pCharacteristic->setCallbacks(new MyCallbacks());
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();
  BLEDevice::startAdvertising();
}

void loop() {
  if (sistemaArmado && !sistemaViolado) {
    if (analogRead(PINO_LDR) < LIMITE_LUZ) {
      
      sistemaViolado = true;
      momentoViolacao = rtc.now().unixtime(); 
      
      Serial.println("!!! VIOLACAO REGISTRADA !!!");
      
      salvarTudo(); 
      enviarEstado(); 
    }
  }
  delay(200);
}
