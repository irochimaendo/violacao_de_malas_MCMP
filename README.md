# 🧳 Violação de Malas

Sistema de detecção de violação de malas baseado em **ESP32** e **sensores LDR**, com aplicativo **Flutter** que se comunica por **Bluetooth Low Energy (BLE)** para monitorar, configurar e alertar sobre a abertura da mala em tempo real.

---

## 📖 Visão geral

Quando uma mala é aberta, a luz externa entra no compartimento interno. O projeto aproveita isso: um ou mais sensores LDR (resistores dependentes de luz) instalados dentro da mala medem continuamente a luminosidade. Se o nível ultrapassa um limiar configurado, o ESP32 interpreta como **possível violação** e notifica o aplicativo no celular, que dispara o alerta ao usuário.

## ✨ Funcionalidades

- 🔍 **Monitoramento** em tempo real do estado da mala (fechada / aberta) e das leituras dos sensores
- ⚙️ **Configuração** pelo app (ex.: sensibilidade/limiar de detecção, ativar/desativar monitoramento)
- 🚨 **Alerta** no celular quando a abertura é detectada
- 📡 **Comunicação BLE** entre o ESP32 e o app, sem necessidade de internet
- 💾 **Persistência local** das configurações no aparelho

## 🏗️ Arquitetura

```
┌──────────────┐   luminosidade   ┌─────────────┐    BLE     ┌──────────────────┐
│ Sensores LDR │ ───────────────► │    ESP32    │ ◄────────► │   App Flutter    │
│ (dentro da   │   (ADC)          │  (firmware) │  notific./ │ monitorar,       │
│   mala)      │                  │             │  comandos  │ configurar,      │
└──────────────┘                  └─────────────┘            │ alertar          │
                                                             └──────────────────┘
```

**Fluxo:**
1. O ESP32 lê os LDRs pelo conversor analógico-digital (ADC).
2. Compara as leituras com o limiar de abertura.
3. Envia o estado/leituras ao app por BLE.
4. O app exibe o status e emite o alerta quando detecta a violação.
5. Configurações alteradas no app são enviadas de volta ao ESP32.

## 🧰 Tecnologias

| Camada | Tecnologia |
|---|---|
| Microcontrolador | ESP32 |
| Sensores | LDR (fotorresistor) |
| Comunicação | Bluetooth Low Energy |
| App | Flutter / Dart (SDK ^3.10.4) |
| BLE no app | [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus) |
| Permissões | [`permission_handler`](https://pub.dev/packages/permission_handler) |
| Armazenamento local | [`shared_preferences`](https://pub.dev/packages/shared_preferences), [`path_provider`](https://pub.dev/packages/path_provider) |
| Utilidades | `intl`, `path`, `camera` |

## 📁 Estrutura do repositório

```
violacao_de_malas_MCMP/
├── firmware_esp32/   # Código do ESP32 (leitura dos LDRs + servidor BLE)
├── lib/              # Código-fonte do app Flutter (Dart)
├── android/          # Projeto nativo Android
├── ios/              # Projeto nativo iOS
├── web/ linux/ macos/ windows/   # Plataformas geradas pelo Flutter
├── test/             # Testes
└── pubspec.yaml      # Dependências do app
```

## 🔌 Hardware

### Materiais
- 1× placa ESP32-c3 supermini
- `4`× sensor LDR
- `1`× potenciômetro de 10 kΩ (divisor de tensão para cada LDR)
- Protoboard, jumpers e fonte de alimentação

### Ligações

O arranjo em paralelo dos sensores LDR forma um divisor de tensão com o potenciômetro fixo, e o ponto central vai a uma entrada ADC do ESP32:
```
3V3 ──[ LDR ]──┬──[ R fixo ]── GND
               │
            GPIO <pino ADC>
```

> 💡 Prefira pinos do **ADC1**, pois o ADC2 fica indisponível quando o Wi-Fi/BLE está em uso em alguns cenários.

## 🚀 Como executar

### 1. Firmware (ESP32)

1. Abra a pasta `firmware_esp32/` na IDE (`<Arduino IDE / PlatformIO / ESP-IDF>`).
2. Instale as bibliotecas necessárias (`<listar>`).
3. Selecione a placa **ESP32** e a porta serial correta.
4. Compile e faça o upload.
5. Abra o monitor serial (`<baud rate>`) para conferir as leituras.

### 2. Aplicativo (Flutter)

**Pré-requisitos:** [Flutter SDK](https://docs.flutter.dev/get-started/install) compatível com Dart ^3.10.4 e um dispositivo físico (BLE não funciona de forma confiável em emuladores).

```bash
git clone https://github.com/irochimaendo/violacao_de_malas_MCMP.git
cd violacao_de_malas_MCMP
flutter pub get
flutter run
```

**Permissões:** ao abrir o app, conceda as permissões de Bluetooth (e localização no Android, quando exigido para varredura BLE).

## 📲 Como usar

1. Alimente o ESP32 dentro da mala e **feche-a**.
2. Abra o app e conceda as permissões de Bluetooth.
3. Procure e **conecte** ao dispositivo.
5. Ative o monitoramento. Se a mala for aberta, o app dispara o alerta.

## 📡 Protocolo BLE

| Item | Valor |
|---|---|
| Nome do dispositivo | `<nome>` |
| Service UUID | `<uuid>` |
| Característica de leitura/notificação | `<uuid>` — estado/leituras dos LDRs |
| Característica de configuração | `<uuid>` — envio de limiar e comandos |

## 🛣️ Melhorias futuras

- [ ] Calibração automática do limiar conforme a luz ambiente
- [ ] Histórico de eventos de abertura com data e hora
- [ ] Notificações em segundo plano com o app fechado
- [ ] Modo de baixo consumo (deep sleep) para economizar bateria
- [ ] Reconexão automática ao dispositivo

## 👥 Autores

- `<seu nome>` — [@irochimaendo](https://github.com/irochimaendo)
