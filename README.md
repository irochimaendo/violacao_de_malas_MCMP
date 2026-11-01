# Sistema IoT para Detecção de Violação de Malas

Projeto de um sistema embarcado para detectar possíveis violações em malas por meio de sensores de luminosidade, utilizando um microcontrolador ESP32-C3 e comunicação Bluetooth Low Energy (BLE).

A proposta é identificar alterações nas condições internas da mala que possam indicar sua abertura indevida, oferecendo uma solução de monitoramento baseada em hardware de baixo custo, firmware embarcado e comunicação sem fio.

## Sobre o projeto

O sistema utiliza um conjunto de quatro sensores LDR (*Light Dependent Resistors*) para monitorar a luminosidade no interior da mala. As leituras são processadas pelo microcontrolador, que utiliza uma calibração dinâmica para estabelecer uma referência e identificar variações relevantes nos valores medidos.

O projeto também contempla parâmetros configuráveis de tolerância, permitindo ajustar a sensibilidade da detecção, além de um buffer circular para armazenamento temporário de dados.

A comunicação Bluetooth Low Energy permite a integração com uma aplicação móvel desenvolvida em Flutter, possibilitando a interação com o sistema sem a necessidade de uma conexão física com o microcontrolador.

### Objetivos

- Detectar alterações de luminosidade que possam indicar a abertura da mala.
- Implementar a leitura e o processamento de sensores em um microcontrolador.
- Utilizar calibração dinâmica para estabelecer referências de medição.
- Permitir a configuração da tolerância utilizada na detecção.
- Explorar a comunicação BLE entre um dispositivo embarcado e uma aplicação móvel.
- Integrar hardware, firmware e software em uma solução IoT.

## Arquitetura do sistema

O projeto é composto por três elementos principais:

| Componente | Responsabilidade |
|---|---|
| Sensores LDR | Detectar variações na luminosidade do ambiente monitorado. |
| ESP32-C3 | Realizar as leituras dos sensores, executar a lógica de detecção e gerenciar a comunicação sem fio. |
| Aplicação móvel em Flutter | Fornecer uma interface para interação com o sistema por meio de Bluetooth Low Energy. |

De forma simplificada, o fluxo de funcionamento é:

1. O conjunto de sensores detecta a luminosidade no interior da mala.
2. O ESP32-C3 realiza a leitura do sinal elétrico associado aos sensores.
3. O firmware utiliza a calibração dinâmica para estabelecer uma referência de funcionamento.
4. As leituras são avaliadas considerando a tolerância configurada.
5. O sistema identifica variações que atendam aos critérios de detecção implementados.
6. A comunicação BLE permite a interação entre o dispositivo embarcado e a aplicação móvel.

A detecção depende das condições de instalação dos sensores e dos critérios implementados no firmware. Uma alteração de luminosidade é um indício que pode ser utilizado pelo sistema, mas não comprova, isoladamente, que houve uma violação da mala.

## Hardware

### Microcontrolador

**ESP32-C3**

O ESP32-C3 é responsável pela aquisição dos sinais dos sensores, pelo processamento das leituras e pela comunicação Bluetooth Low Energy.

### Sensores de luminosidade

O circuito utiliza um arranjo de **quatro LDRs conectados em paralelo**, associado a uma única entrada GPIO do microcontrolador.

O circuito também utiliza um **potenciômetro de 10 kΩ**, posicionado entre o arranjo de sensores e o pino GPIO, conforme a montagem do projeto.

O uso do conjunto de sensores permite monitorar a luminosidade em diferentes pontos, enquanto a leitura compartilhada concentra o sinal do arranjo em uma única entrada do microcontrolador.

É importante considerar que, em uma ligação paralela, os quatro LDRs não fornecem quatro leituras independentes: o microcontrolador recebe o sinal elétrico resultante da configuração do circuito.

### Componentes principais

- ESP32-C3.
- 4 sensores LDR conectados em paralelo.
- 1 potenciômetro de 10 kΩ.
- Circuito de conexão entre os sensores e a entrada GPIO.
- Dispositivo móvel compatível com Bluetooth Low Energy para comunicação com a aplicação.

## Firmware embarcado

O firmware executado no ESP32-C3 é responsável por coordenar a aquisição de dados, o processamento das leituras e a comunicação com a aplicação móvel.

Entre os recursos contemplados pelo projeto estão:

- **Aquisição de dados:** leitura do sinal proveniente do conjunto de sensores.
- **Calibração dinâmica:** estabelecimento de uma referência a partir das condições de funcionamento do sistema.
- **Tolerância configurável:** ajuste do critério utilizado para avaliar as variações detectadas.
- **Buffer circular:** armazenamento temporário de dados com reutilização das posições do buffer.
- **Comunicação BLE:** troca de informações entre o dispositivo embarcado e a aplicação móvel.

Esses recursos permitem explorar aspectos importantes do desenvolvimento de sistemas embarcados, incluindo leitura de sensores, processamento de sinais, gerenciamento de memória e comunicação sem fio.

## Comunicação Bluetooth Low Energy

O sistema utiliza Bluetooth Low Energy (BLE) para estabelecer a comunicação entre o ESP32-C3 e a aplicação móvel.

Essa tecnologia permite a interação sem fio com o dispositivo, sendo adequada para aplicações IoT que precisam trocar pequenas quantidades de dados com baixo consumo de energia.

A comunicação entre os componentes depende dos serviços, das características e do protocolo implementados no firmware e na aplicação.

## Aplicação móvel

O projeto contempla uma aplicação móvel desenvolvida com Flutter para interação com o sistema embarcado.

A utilização do Flutter permite desenvolver a interface da aplicação utilizando uma base de código multiplataforma, enquanto o BLE fornece o canal de comunicação com o ESP32-C3.

A aplicação faz parte da arquitetura do projeto, conectando o funcionamento do dispositivo físico à interação com o usuário.

## Tecnologias utilizadas

| Tecnologia | Aplicação no projeto |
|---|---|
| C/C++ | Desenvolvimento do firmware embarcado. |
| ESP32-C3 | Plataforma de processamento e comunicação. |
| LDR | Detecção de variações de luminosidade. |
| GPIO | Aquisição do sinal elétrico proveniente do circuito de sensores. |
| Bluetooth Low Energy (BLE) | Comunicação sem fio entre o microcontrolador e a aplicação. |
| Flutter | Desenvolvimento da aplicação móvel. |
| Git e GitHub | Controle de versão e organização do código-fonte. |
| LaTeX | Elaboração da documentação técnica do projeto. |

## Conceitos aplicados

O desenvolvimento do sistema envolve diferentes áreas da Engenharia de Computação:

- Sistemas embarcados e programação de microcontroladores.
- Aquisição de dados provenientes de sensores.
- Eletrônica aplicada à instrumentação.
- Processamento e interpretação de leituras.
- Algoritmos de calibração e detecção de variações.
- Estruturas de dados, incluindo buffers circulares.
- Comunicação sem fio utilizando BLE.
- Integração entre firmware e aplicação móvel.
- Documentação técnica de projetos de engenharia.

## Contexto acadêmico

O projeto foi desenvolvido no contexto acadêmico, com foco na construção de uma solução IoT para monitoramento de malas.

Além da implementação do sistema, o trabalho envolve a integração de componentes de hardware e software, a definição de critérios de detecção e a documentação técnica da solução.

O projeto permite aplicar conhecimentos de programação, eletrônica, sistemas embarcados e comunicação entre dispositivos em um problema prático.

## Licença

A utilização e a redistribuição do código-fonte estão sujeitas à licença definida no repositório.
