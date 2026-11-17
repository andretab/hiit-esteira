# HIIT Esteira

PWA instalável e offline-first que **gera e executa treinos HIIT de corrida na esteira**.
É HTML + CSS + JavaScript puro, sem framework, sem build e sem backend. Tudo roda no celular e fica salvo localmente.

## Funcionalidades

- **16 protocolos de treino intervalado** tirados da literatura e adaptados à esteira (velocidade + inclinação). Veja a tabela abaixo.
- **Escolha automática com rotação**: o app sorteia um protocolo compatível com objetivo, nível e duração. Ele evita repetir a mesma *categoria* de estímulo da sessão anterior e o mesmo protocolo na mesma semana; depois de sprints, prefere algo de limiar ou de subida. "Outra variação" sorteia de novo.
- **Objetivo** (Variado, Gordura, Fôlego/VO2máx, Velocidade, Limiar) e **nível** (Iniciante, Intermediário, Avançado). Iniciante não recebe sprints nem tiros 45/75 e não passa de 90% do ritmo máximo.
- **Limites de segurança**: no máximo ~3 min por sessão acima de 95% do ritmo máximo. Sessões intensas ganham acelerações progressivas no aquecimento. Recuperações abaixo de 6,5 km/h viram caminhada.
- **Unidades**: km/h (`14,0`) ou min/km em notação de corredor (`4'17"`), em toda a interface.
- **Editor**: adiciona, remove, reordena e edita tipo, ritmo, duração e inclinação de cada segmento. Pode partir do treino gerado.
- **Execução**: tela imersiva na cor da fase. Mostra o ritmo gigante, a inclinação, o tempo do intervalo, o próximo ritmo e o tempo restante, com o perfil do treino e um cursor de progresso.
- **Avisos**: bipe duplo ao entrar no forte, bipe simples ao mudar para um segmento leve, tiques nos últimos 3 s (hora de apertar o botão da esteira). Vibração opcional. A tela fica acesa (Wake Lock).
- **Salvos e histórico**: salvar, treinar de novo, editar, duplicar e excluir. O histórico guarda o protocolo, que alimenta a rotação.
- **Tema** automático ou manual. Microanimações (odômetro, barras, FLIP, transição de tela) inspiradas em [naocodei.com/free-code](https://naocodei.com/free-code/), desligadas com "reduzir movimento".

## Protocolos

"V" é o ritmo máximo configurado (o pico de um tiro de ~30 s). Conversões usadas: vVO2máx ≈ 80–85% V, limiar ≈ 70–75% V, trote ≈ 50–55% V. A inclinação base é 1% (equivale à corrida na rua).

| Protocolo | Estrutura (núcleo) | Categoria | Nível mín. | Fonte |
|---|---|---|---|---|
| 10×1 min | 1 min a 78–85% V / 1 min leve | intervalo curto | Iniciante | Little et al., J Physiol 2010 |
| 40/40 | 40 s a 85–88% V / 40 s leve, em séries | intervalo curto | Intermediário | Billat et al., 2000 (adaptado) |
| 60-40-40 | blocos de 3 × (60 s leve, 40 s médio, 40 s forte) | intervalo curto | Iniciante | adaptado de Gunnarsson & Bangsbo, 2012 |
| 4×4 | 4 min a 72–80% V / 3 min leve (às vezes em subida a 6%) | intervalo longo | Iniciante | Helgerud et al., MSSE 2007 |
| Pirâmide | 1-2-3-2-1 min, mais rápido quanto mais curto | intervalo longo | Iniciante | RunnersConnect |
| Escada | 4-3-2-1 min de 74% a 92% V (ou crescente) | intervalo longo | Intermediário | Active.com |
| Subidas longas | 90 s a 74% V e 4–6% / 2,5 min plano | subida | Iniciante | Runner's World, TrainingPeaks |
| Rampas curtas | 45 s a 70% V e 8–10% / 90 s plano | subida | Intermediário | TrainingPeaks |
| Caminhada inclinada | 90 s a 5,5–6 km/h e 8–12% / 90 s plano | subida | Iniciante | ACSM, ACE |
| Fartlek | blocos de 1/1 min, cada bloco mais rápido | intervalo curto | Iniciante | Runkeeper |
| Over-under | 2,5 min a 69% V + 1 min a 80% V, em blocos | limiar | Intermediário | TrainingPeaks |
| Sprints 40 s | 3–4 × 40 s a 95% V / 3 min andando | sprint | Avançado | Gist et al., Sports Med 2014 (adaptado) |
| 45/75 | 6–10 × (45 s a 90–92% V / 75 s leve) | sprint | Intermediário | Buchheit & Laursen, 2013 |
| Progressivo | degraus contínuos de 55% a 75% V + final forte | limiar | Iniciante | Polar |
| A cada 2 min | a cada 2 min, 40 → 60 → 80 s rápidos | intervalo curto | Intermediário | treino funcional (EMOM) |
| Misto | 40/40 + over-under + rampas na mesma sessão | misto | Intermediário | combinação |

Sobre as adaptações: a esteira leva de 5 a 15 s para trocar de velocidade. Por isso nenhum trecho gerado tem menos de 40 s (o Tabata, o 10-20-30 e o 30/30 originais foram alongados) e todas as velocidades geradas são km/h inteiros, fáceis de digitar no painel.
A conversão "vVO2máx ≈ 80–85% de V" é uma aproximação a partir da literatura de reserva de velocidade anaeróbia. As constantes ficam todas em `generator.js`.

> Treino de alta intensidade não é indicado sem liberação médica para quem tem condição cardíaca, hipertensão não controlada ou está voltando de lesão. Use sempre o clipe de segurança da esteira.

## Estrutura

```
index.html        marcação das 4 telas (Gerar, Editor, Treino, Histórico)
styles.css        tokens de cor/tipografia em :root, tema escuro, layout mobile-first
app.js            interface, navegação e motor de execução (relógio, som, vibração, wake lock)
generator.js      catálogo de protocolos, gerarSessao/gerarTreino e conversões (funções puras)
storage.js        persistência em localStorage (config, salvos, histórico, rascunho)
efeitos.js        microanimações (odômetro, barras, FLIP, transição de tela)
sw.js             service worker (cache offline)
manifest.json     manifesto do PWA
icons/            ícones (gerados por tools/gerar_icones.py)
tests/            testes do gerador e das conversões
```

### Modelo de dados

```js
gerarSessao({ ritmoMax: 14, duracao: 30, objetivo: 'condicionamento', nivel: 'intermediario', protocolo: 'auto', variacao: 0 }, recentes)
// → { protocolo: 'noruegues', nome: '4×4', descricao, fonte, categoria: 'A', segmentos: [...] }

gerarTreino(config)  // só os segmentos:
// → [{ fase: 'aquecimento' | 'hiit' | 'desaceleracao', ritmo: 10.8 /* km/h */, duracao: 240 /* s */,
//      forte: true, inclinacao: 1 /* % */, rotulo: 'Tiro 1/4' }, ...]
```

Internamente o ritmo é sempre guardado em km/h, arredondado a 0,1 (o passo das esteiras). Por isso um pace digitado
pode "encaixar" no valor mais próximo: 9:00 min/km vira 6,7 km/h, que aparece como 8:57.

## Rodar localmente

Service worker e ES modules não funcionam abrindo o arquivo direto (`file://`). Use qualquer servidor estático:

```bash
python -m http.server 8080
```

Depois abra http://localhost:8080. Também funciona com `npx serve -l 8080 .`.

Para testar no celular na mesma rede Wi-Fi, abra `http://IP-DO-PC:8080`. Atenção: fora de `localhost`, o service worker,
o Wake Lock e a instalação **exigem HTTPS**. Para um teste rápido com HTTPS, use um túnel (`npx localtunnel --port 8080`,
`cloudflared tunnel --url http://localhost:8080`) ou faça o deploy.

## Testes

No navegador: com o servidor rodando, abra http://localhost:8080/tests/

No terminal (se tiver Node 18+):

```bash
node tests/run-node.js
```

Os testes cobrem as conversões km/h ↔ min/km (com tabela de referência) e a leitura e formatação de pace e tempo.
Em todos os protocolos, durações e níveis, conferem a soma exata do tempo, os ritmos entre o piso e o máximo, o limite de
esforço acima de 95%, as restrições do nível iniciante, o filtro por objetivo, a rotação de categorias e se a função é pura.

## Deploy

Qualquer hospedagem estática com HTTPS serve. Os caminhos são relativos, então o app também funciona em subpasta.

- **GitHub Pages**: suba a pasta para um repositório → Settings → Pages → branch `main`, pasta `/ (root)`.
- **Netlify / Cloudflare Pages / Vercel**: arraste a pasta ou conecte o repositório. Sem comando de build, diretório de publicação `.`.

**Ao publicar uma nova versão**, o service worker serve o cache na hora e atualiza em segundo plano, então a mudança aparece
na visita seguinte. Se mudar a lista de arquivos do app shell, incremente `VERSAO` em `sw.js` para limpar o cache antigo.

## Instalar na tela inicial

- **Android (Chrome)**: aparece o botão de download no topo do app, ou use o menu ⋮ → *Instalar app*.
- **iPhone (Safari)**: Compartilhar → *Adicionar à Tela de Início*. O app mostra essa dica na primeira tela.

Depois de aberto uma vez com internet, o app funciona 100% offline. As fontes Barlow também ficam em cache; sem elas,
o app cai nas fontes do sistema.

### Observações sobre iPhone

- O som da Web Audio respeita a chave de silencioso do iPhone. Se não ouvir os bipes, desligue o modo silencioso.
- O Safari não tem Vibration API, então o botão de vibração fica oculto.
- O Wake Lock funciona no iOS 16.4+ (no app instalado, a partir do iOS 18.4).

## Ícones

Para regerar os PNGs depois de mudar o desenho:

```bash
python tools/gerar_icones.py
```

Requer `pip install pillow`. O `icons/icon.svg` é editado à mão.
