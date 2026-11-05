# HIIT Esteira — Garmin Connect IQ

App de relógio (device app) para HIIT na esteira. O app **não lê** velocidade: mostra o
ritmo-alvo de cada bloco e avisa (vibração + tom) a cada troca, para você ajustar a esteira.

## Estrutura

```
garmin/
├── manifest.xml          # tipo watch-app, devices-alvo, API mínima 3.2.0
├── monkey.jungle         # build (aponta o manifest)
├── resources/
│   ├── strings/strings.xml
│   ├── settings/         # properties.xml + settings.xml (configurações no celular)
│   └── drawables/        # ícone do launcher
└── source/
    ├── HiitEsteiraApp.mc # entrada; abre a InicioView
    ├── Modelo.mc         # TipoBloco, Intervalo, Treino (ritmo sempre em km/h)
    ├── Unidades.mc       # km/h <-> min/km e formatação de tempo (só exibição)
    ├── Config.mc         # preferências em Application.Properties
    ├── Ajustes.mc        # menu principal + tela de ajuste numérico
    ├── Historico.mc      # RegistroTreino + gravação/leitura no Application.Storage
    ├── HistoricoView.mc  # lista, detalhe e "apagar tudo"
    ├── Personalizado.mc  # ItemPlano, TreinoPersonalizado (plano -> intervalos) + Storage
    ├── TextoTreino.mc    # parser do texto digitado no Garmin Connect
    ├── PersonalizadoView.mc # menus de edição (lista, treino, blocos, item)
    ├── Testes.mc         # testes unitários (só entram no build --unit-test)
    ├── Gerador.mc        # gera aquecimento + esforço/recuperação + desaquecimento
    ├── MotorTreino.mc    # máquina de estados do treino (sem UI)
    ├── Alertas.mc        # vibração, tom e luz
    ├── Tela.mc           # cores, nomes, barra e texto que se ajusta à tela redonda
    ├── InicioView.mc     # tela inicial (duração, prévia)
    ├── TreinoView.mc     # tela do treino + delegates (pausa, encerrar)
    └── FimView.mc        # resumo
```

### Camadas

```
Views/Delegates  ──►  MotorTreino  ──►  Treino/Intervalo
     │       │             ▲
     ▼       ▼             │
  Alertas  Historico   Gerador ◄── Config
           (Storage)               (Properties)
```

- **Motor sem UI:** a View chama `motor.atualizar()` a cada 250 ms e recebe um evento
  (`TROCA`/`FIM`). O motor mede tempo por diferença de `System.getTimer()`, então não
  acumula atraso de timer, e o bloco atual é deduzido do tempo decorrido.
- **Ritmo em km/h internamente:** min/km é só formato de tela.
- **Configuração ≠ dado:** preferências em `Properties` (editáveis no celular), histórico em
  `Storage`. Toda leitura dos dois valida tipo e faixa.

## Controles

| Tela       | START             | UP / DOWN                        | MENU (segurar UP) | BACK               |
|------------|-------------------|----------------------------------|-------------------|--------------------|
| Início     | inicia o treino   | duração ±1 min (só automático)   | menu principal    | sai do app         |
| Menu       | abre o item       | navega                           | —                 | volta              |
| Ajuste     | salva             | ritmo ±0,5 km/h · duração ±1 min · tempo ±5 s (até 1 min) / ±15 s · repetições ±1 | — | cancela |
| Histórico  | abre o detalhe    | navega                           | —                 | volta              |
| Treino     | pausa / retoma    | km/h ↔ min/km                    | —                 | confirma e encerra |
| Resumo     | volta ao início   | —                                | —                 | volta ao início    |

### Treinos personalizados

Até 10 treinos com nome. Cada um é uma lista de até 20 itens; um item é um **bloco**
(tipo, ritmo, tempo) ou uma **série** (N × esforço + recuperação, sem recuperação depois do
último tiro). Ao iniciar, o plano vira a mesma lista de intervalos do modo automático, então
tela, alertas e histórico são os mesmos.

**No relógio:** MENU → Treinos personalizados. "+ Novo treino" já vem com um exemplo
(aquecimento, 8 tiros, desaquecimento) para editar. Em cada treino: Usar este treino, Editar
blocos (+ Bloco, + Série, mover, duplicar, apagar), Duplicar, Apagar. "Usar automático" volta
ao treino gerado pela duração.

**No celular:** Garmin Connect → Configurações do app → *Treinos personalizados*:

```
Tiros = AQ 5,5 3:00; 8x(E 13 1:00 + R 7 1:30); DQ 6 3:00 | Pirâmide = AQ 6 5; E 12 1:00; R 7 1; E 13 2:00; R 7 1; E 14 1:00; DQ 6 3
```

- `|` separa treinos · `Nome =` (opcional) · `;` separa itens
- Bloco: `TIPO RITMO TEMPO` — AQ aquecimento, E esforço, R recuperação, DQ desaquecimento
- Série: `8x(E 13 1:00 + R 7 1:30)` (as letras E/R dentro da série são opcionais)
- Ritmo em km/h (`13`, `13,5` ou `13.5`) · Tempo: `1:30`, `90s`, `3` ou `3min`, `1,5` (min)

O texto é importado ao abrir o app e quando você salva as configurações, **só se mudou**
(edições feitas no relógio não são sobrescritas). Um treino com o mesmo nome é substituído.
Se houver erro, nada é importado e o menu mostra "Erro no texto" com o treino e o item.

### Histórico

Ao terminar (ou encerrar) um treino com pelo menos 1 minuto, ele é gravado no
`Application.Storage`: data/hora, tempo feito e planejado, tiros feitos/planejados, ritmo de
pico e se foi concluído. Ficam os últimos 30. MENU → Histórico mostra a lista (mais novo
primeiro); selecionar abre o detalhe; "Apagar tudo" pede confirmação.

### Configurações

Ritmo máximo (8–25 km/h), duração (10–50 min) e unidade ficam em `Application.Properties`
(`resources/settings/`). Dá para editar de dois jeitos, e ambos gravam no mesmo lugar:

- **No relógio:** MENU na tela inicial (segurar UP nos Forerunner).
- **No celular:** app Garmin Connect → seu relógio → Connect IQ → HIIT Esteira → Configurações.
  Lá o ritmo aceita décimos (ex.: 14,3) e a duração qualquer minuto de 10 a 50.

O `Application.Storage` fica reservado para dados (histórico).

## Treino gerado (ritmo máx. V)

| Duração (min) | Núcleo                              |
|---------------|-------------------------------------|
| 10–17         | 30 s a 95% V / 30 s recuperação     |
| 18–33         | 60 s a 90% V / 60 s recuperação     |
| 34–50         | 2 min a 85% V / 90 s recuperação    |

(O padrão é escolhido pelo tempo que sobra para o núcleo depois de aquecimento e
desaquecimento. A conta fecha exatamente em todas as durações de 10 a 50 min.)

Aquecimento: 1 min caminhando a 5,5 km/h + trote a 58% V. Desaquecimento: trote a 50% V +
1 min a 5,0 km/h. A recuperação é 50% V, com piso de 6,0 km/h.

## Como rodar no simulador (Windows)

### Estado atual desta máquina (04/11/2026)

Já instalado: JDK 17 (Temurin), VS Code + extensão Monkey C, Connect IQ SDK 9.3.0 em
`%APPDATA%\Garmin\ConnectIQ\Sdks\` (baixado direto do servidor da Garmin, sem o SDK Manager),
chave em `C:\Users\André Freitas\garmin\developer_key.der`. Os 9 devices do manifest compilam.
Para compilar e abrir no simulador:

```powershell
$sdk = Get-Content "$env:APPDATA\Garmin\ConnectIQ\current-sdk.cfg"
& "$sdk\bin\monkeyc.bat" -d fr965 -f monkey.jungle -o bin\HiitEsteira.prg -y "$env:USERPROFILE\garmin\developer_key.der"
Start-Process "$sdk\bin\simulator.exe"; Start-Sleep 8
& "$sdk\bin\monkeydo.bat" bin\HiitEsteira.prg fr965
```

Testes unitários (parser do texto, expansão das séries, Storage), com o simulador aberto:

```powershell
& "$sdk\bin\monkeyc.bat" -d fr965 -f monkey.jungle -o bin\testes.prg -y "$env:USERPROFILE\garmin\developer_key.der" --unit-test
& "$sdk\bin\monkeydo.bat" bin\testes.prg fr965 /t
```

### 1. Instalar o SDK (uma vez, em outra máquina)

1. Instale um **JDK 17** (ex.: Eclipse Temurin). O Java 8 que já está na máquina é antigo
   demais para os SDKs atuais.
2. Baixe o **Connect IQ SDK Manager** em developer.garmin.com/connect-iq/sdk, faça login com
   sua conta Garmin e baixe:
   - o SDK mais recente (aba *SDKs*, depois *Use this SDK*);
   - os devices que vai testar (aba *Devices*, ao menos o **fr965**).
3. No VS Code, instale a extensão **Monkey C** (Garmin). Depois rode
   `Ctrl+Shift+P → Monkey C: Verify Installation`.
4. Gere a chave de desenvolvedor: `Ctrl+Shift+P → Monkey C: Generate a Developer Key`.
   Salve **fora do repositório** (ex.: `C:\Users\<você>\garmin\developer_key.der`).

### 2. Rodar pelo VS Code (mais simples)

1. Abra a pasta `garmin/` no VS Code (*File → Open Folder*).
2. Abra qualquer `.mc` e pressione **F5** (ou `Ctrl+Shift+P → Monkey C: Run`).
3. Escolha o device (ex.: `fr965`). O simulador abre e carrega o app.

### 3. Ou pela linha de comando

```powershell
# compila para um device
monkeyc -d fr965 -f monkey.jungle -o bin\HiitEsteira.prg -y C:\caminho\developer_key.der

# abre o simulador (deixe aberto) e envia o app para ele
connectiq
monkeydo bin\HiitEsteira.prg fr965
```

(`monkeyc`, `connectiq` e `monkeydo` ficam na pasta `bin` do SDK; adicione-a ao PATH.)

### Dicas no simulador

- **Botões:** clique nos botões do relógio desenhado no simulador (passe o mouse para ver o nome).
- **Treino acelerado:** em `source/Config.mc`, troque `FATOR_VELOCIDADE = 1` por `30`.
  Um treino de 30 min passa em 1 min e dá para ver todas as trocas. **Volte para 1**
  antes de instalar no relógio.
- **Tom:** o simulador toca os tons no PC. A vibração aparece só como evento (não há motor).
- **Storage:** *File → Edit Persistent Storage* mostra/limpa o que o app gravou.
- **Outras telas:** troque o device no simulador para conferir o layout em telas pequenas
  (fr255, 260 px) e grandes (fr965, 454 px).

## Instalar no relógio (sideload)

1. `Ctrl+Shift+P → Monkey C: Build for Device`, escolha o modelo.
2. Conecte o relógio por USB e copie o `.prg` para `GARMIN\APPS\`.

## Roadmap

- [x] v1a: estrutura, gerador, motor do treino, alertas, telas de início/treino/resumo
- [x] Settings: ritmo máximo, duração e unidade (no relógio e no app Garmin Connect)
- [x] Histórico de treinos (Application.Storage) + tela de listagem
- [x] Modo personalizado: sequência manual de blocos (ritmo + tempo), no relógio e no celular
- [ ] Contagem regressiva (3-2-1) antes de cada troca
- [ ] Futuro: ler velocidade real de footpod; gravar a sessão como atividade FIT
