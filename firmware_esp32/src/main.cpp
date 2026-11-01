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

// ---- Calibração e detecção de violação ----
#define LIMITE_LUZ_PADRAO 2000        // valor inicial, usado só antes da primeira calibração (ARMAR)
#define TOLERANCIA_PERCENTUAL 5.0     // % de variação aceitável (pra mais ou pra menos) em torno do LIMITE_LUZ
#define TAMANHO_BUFFER 10             // nº de leituras consecutivas usadas para calcular a média
#define INTERVALO_LEITURA_MS 100      // intervalo entre leituras rápidas enquanto armado (ms)
#define INTERVALO_CALIBRACAO_MS 15    // intervalo entre leituras durante a calibração do LIMITE_LUZ (ms)

RTC_DS3231 rtc;
Preferences memoria;
BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;

bool sistemaArmado = false;   
bool sistemaViolado = false;  
uint32_t momentoViolacao = 0;

int limiteLuz = LIMITE_LUZ_PADRAO;   // calibrado dinamicamente a cada "ARMAR" (mala fechada)

// Buffer (janela deslizante) com as últimas leituras do LDR, usado para tirar a média
int bufferLeituras[TAMANHO_BUFFER];
int indiceBuffer = 0;
int amostrasNoBuffer = 0;
unsigned long ultimaLeituraMs = 0;

#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"

void resetarBuffer() {
  indiceBuffer = 0;
  amostrasNoBuffer = 0;
}

void adicionarLeituraBuffer(int valor) {
  bufferLeituras[indiceBuffer] = valor;
  indiceBuffer = (indiceBuffer + 1) % TAMANHO_BUFFER;
  if (amostrasNoBuffer < TAMANHO_BUFFER) amostrasNoBuffer++;
}

float calcularMediaBuffer() {
  long soma = 0;
  for (int i = 0; i < amostrasNoBuffer; i++) {
    soma += bufferLeituras[i];
  }
  return amostrasNoBuffer > 0 ? (float)soma / amostrasNoBuffer : 0.0;
}

// Faz várias leituras rápidas e tira a média -> usado para calibrar o LIMITE_LUZ
// no momento em que a mala é "fechada" (ARMAR), evitando que uma única leitura
// ruidosa do LDR vire a referência de todo o monitoramento
int capturarLuminosidadeBase() {
  long soma = 0;
  for (int i = 0; i < TAMANHO_BUFFER; i++) {
    soma += analogRead(PINO_LDR);
    delay(INTERVALO_CALIBRACAO_MS);
  }
  return (int)(soma / TAMANHO_BUFFER);
}

void salvarTudo() {
  memoria.begin("mala_app", false); 
  memoria.putBool("armado", sistemaArmado);
  memoria.putBool("violado", sistemaViolado);
  memoria.putUInt("momento_v", momentoViolacao);
  memoria.putInt("limite_luz", limiteLuz);
  memoria.end(); 
  Serial.println(">>> ESTADO GRAVADO NA FLASH (PERMANENTE) <<<");
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
      Serial.println("Enviando para App: VIOLADO (" + mensagem + ")");
    } 
    else if (sistemaArmado) {
      mensagem = "S"; 
      Serial.println("Enviando para App: ARMADO");
    } 
    else {
      mensagem = "A"; 
      Serial.println("Enviando para App: DESARMADO");
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
        // Mala sendo "fechada" agora: captura a luminosidade atual (média de
        // várias leituras rápidas) e usa como nova referência (LIMITE_LUZ)
        // para este ciclo de monitoramento
        limiteLuz = capturarLuminosidadeBase();
        resetarBuffer();
        ultimaLeituraMs = millis();

        sistemaArmado = true;
        sistemaViolado = false;
        momentoViolacao = 0;
        salvarTudo(); 
        enviarEstado();

        Serial.println(">>> Novo LIMITE_LUZ calibrado: " + String(limiteLuz));
      } 
      else if (comando == "RESET") {
        resetarBuffer();
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
    Serial.println("RTC perdido no tempo! Ajustando provisoriamente...");
    rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
  } else {
    Serial.println("RTC Saudavel. Mantendo horario da bateria.");
  }
  
  memoria.begin("mala_app", true);
  sistemaArmado = memoria.getBool("armado", false);
  sistemaViolado = memoria.getBool("violado", false);
  momentoViolacao = memoria.getUInt("momento_v", 0);
  limiteLuz = memoria.getInt("limite_luz", LIMITE_LUZ_PADRAO);
  memoria.end(); 

  Serial.println("--- DIAGNOSTICO DE BOOT ---");
  Serial.print("Estava Armado? "); Serial.println(sistemaArmado ? "SIM" : "NAO");
  Serial.print("Estava Violado? "); Serial.println(sistemaViolado ? "SIM" : "NAO");
  Serial.print("LIMITE_LUZ calibrado: "); Serial.println(limiteLuz);
  
  if(sistemaViolado) {
     Serial.println(">>> ATENCAO: SISTEMA REINICIOU EM ESTADO DE VIOLACAO! <<<");
     Serial.println("Mantendo data original da violacao.");
  }

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

  if (sistemaViolado) {
      delay(1000); 
  }
  
  else if (sistemaArmado) {
    unsigned long agoraMs = millis();

    if (agoraMs - ultimaLeituraMs >= INTERVALO_LEITURA_MS) {
      ultimaLeituraMs = agoraMs;

      int leituraAtual = analogRead(PINO_LDR);
      adicionarLeituraBuffer(leituraAtual);

      // só avalia violação depois de já ter TAMANHO_BUFFER leituras consecutivas
      // (assim 1 leitura pontual fora da faixa, isolada, nunca dispara o alarme)
      if (amostrasNoBuffer >= TAMANHO_BUFFER) {
        float media = calcularMediaBuffer();
        float limiteInferior = limiteLuz * (1.0 - TOLERANCIA_PERCENTUAL / 100.0);
        float limiteSuperior = limiteLuz * (1.0 + TOLERANCIA_PERCENTUAL / 100.0);

        if (media < limiteInferior || media > limiteSuperior) {

          sistemaViolado = true;
          momentoViolacao = rtc.now().unixtime(); 
          
          Serial.println("!!! VIOLACAO DETECTADA (media=" + String(media) +
                          ", faixa aceita=[" + String(limiteInferior) + " , " + String(limiteSuperior) + "]) !!!");

          salvarTudo(); 

          enviarEstado(); 
        }
      }
    }
  }
  
  delay(10);
}
