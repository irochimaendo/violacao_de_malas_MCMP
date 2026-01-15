#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>
#include <BLE2902.h> 

// CONFIGURAÇÃO DO PINO
#define LDR_PIN1 0  // Verifique se é o pino 0 mesmo no seu ESP32-C3

// UUIDs (Identificadores do Bluetooth)
#define NOME_MALA "MALA_TESTE_LDR"
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;
bool oldDeviceConnected = false;

// Callbacks para saber quando conectou/desconectou
class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
      // Reinicia o anúncio para poder conectar de novo sem resetar o ESP
      BLEDevice::startAdvertising(); 
    }
};

void setup() {
  Serial.begin(115200);
  
  // Configura o pino do LDR
  pinMode(LDR_PIN1, INPUT);

  // Inicializa o Bluetooth
  BLEDevice::init(NOME_MALA);
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);

  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY | // Importante para enviar dados
                      BLECharacteristic::PROPERTY_INDICATE
                    );

  pCharacteristic->addDescriptor(new BLE2902());

  pService->start();
  
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x0); 
  BLEDevice::startAdvertising();
  
  Serial.println("Bluetooth ligado! Conecte o celular...");
}

void loop() {
  // 1. Ler o sensor
  int valorLDR = analogRead(LDR_PIN1);

  // Debug via cabo (caso esteja conectado no PC)
  // Serial.printf("LDR: %d\n", valorLDR);

  // 2. Enviar via Bluetooth (Se tiver alguém conectado)
  if (deviceConnected) {
      
      // Converte o número inteiro para Texto (String) para enviar
      // Exemplo: envia "2500"
      String valorString = String(valorLDR);
      
      // Define o valor na característica
      pCharacteristic->setValue(valorString.c_str());
      
      // Envia a notificação para o celular
      pCharacteristic->notify();
      
      Serial.printf("Enviado via BLE: %s\n", valorString.c_str());
      
      // Delay para não travar o app do celular com dados demais
      delay(500); 
  }

  // Lógica para reconexão automática (estabilidade)
  if (!deviceConnected && oldDeviceConnected) {
      delay(500); 
      pServer->startAdvertising(); 
      Serial.println("Reiniciando advertising...");
      oldDeviceConnected = deviceConnected;
  }
  if (deviceConnected && !oldDeviceConnected) {
      oldDeviceConnected = deviceConnected;
  }
}