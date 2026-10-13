// generator.js — protocolos de treino intervalado e conversões de unidade.
// Tudo aqui são funções puras (sem DOM, sem relógio, sem Math.random): a variação vem de uma
// semente explícita (config.variacao) e o histórico recente é passado como dado.
//
// Convenções internas: ritmo SEMPRE em km/h; durações SEMPRE em segundos; inclinação em %.
// "V" = ritmo máximo configurado: o pico que a pessoa aguenta num tiro curto (20–60 s).
// Referências de intensidade (aproximadas):
//   vVO2max ≈ 80–85% V · limiar ≈ 70–75% V · trote leve ≈ 50–55% V · "all-out" na esteira ≈ 95–100% V.
// Inclinação base de 1%: equivale ao custo da corrida na rua (Jones & Doust, 1996).

export const DURACAO_MIN = 10;
export const DURACAO_MAX = 50;
export const DURACAO_PASSO = 5;
export const RITMO_MAX_PADRAO = 14;
export const RITMO_MINIMO = 4;    // piso de qualquer segmento (15:00 min/km)
export const RITMO_MAX_MIN = 8;   // menor ritmo máximo aceito (7:30 min/km)
export const RITMO_TETO = 25;
export const INCLINACAO_BASE = 1;
export const CAMINHADA = 5.5;     // km/h — caminhada de recuperação
export const CAMINHADA_RAPIDA = 6;

/* =========================================================
   Conversões de unidade
   ========================================================= */

// Arredonda para 0,1 km/h (incremento das esteiras).
export function arred1(x) {
  return Math.round(x * 10) / 10;
}

// km/h -> pace em minutos decimais por km (min/km = 60 / km/h).
export function kmhParaPace(kmh) {
  if (!(kmh > 0)) return NaN;
  return 60 / kmh;
}

// pace (minutos decimais por km) -> km/h (km/h = 60 / min/km).
export function paceParaKmh(minPorKm) {
  if (!(minPorKm > 0)) return NaN;
  return 60 / minPorKm;
}

// Pace decimal como "m:ss" (ex.: 4.2857 -> "4:17").
export function formatarPace(minPorKm) {
  if (!Number.isFinite(minPorKm) || minPorKm <= 0) return '--:--';
  const totalSeg = Math.round(minPorKm * 60);
  return `${Math.floor(totalSeg / 60)}:${String(totalSeg % 60).padStart(2, '0')}`;
}

// Lê pace digitado e retorna minutos decimais (ou NaN).
// "4:17", "4'17", 4'17", "4.17" e "4,17" = 4 min 17 s (ponto/vírgula com 2 dígitos = m:ss,
// que é como corredores escrevem pace). Com 1 dígito, "4,5" é decimal = 4:30. "5" = 5:00.
export function lerPace(texto) {
  const t = String(texto ?? '').trim().replace(/["”″]/g, '');
  const m = t.match(/^(\d{1,2})\s*(?:[:'’′h]\s*(\d{1,2})|[.,](\d{2}))$/);
  if (m) {
    const seg = Number(m[2] ?? m[3]);
    if (seg >= 60) return NaN;
    const v = Number(m[1]) + seg / 60;
    return v > 0 ? v : NaN;
  }
  const v = Number(t.replace(',', '.'));
  return t !== '' && Number.isFinite(v) && v > 0 ? v : NaN;
}

// Lê km/h digitado ("12,5" ou "12.5").
export function lerKmh(texto) {
  const t = String(texto ?? '').trim().replace(',', '.');
  const v = Number(t);
  return t !== '' && Number.isFinite(v) && v > 0 ? v : NaN;
}

// Converte o texto digitado na unidade escolhida para km/h (já arredondado a 0,1).
export function lerRitmo(texto, unidade) {
  const kmh = unidade === 'pace' ? paceParaKmh(lerPace(texto)) : lerKmh(texto);
  return Number.isFinite(kmh) ? arred1(kmh) : NaN;
}

// Valor do ritmo (sem unidade) na notação de corredor: "12,6" (km/h) ou 4'17" (min/km).
export function valorRitmo(kmh, unidade) {
  if (unidade === 'pace') {
    const p = formatarPace(kmhParaPace(kmh));
    return p.includes('-') ? '--' : `${p.replace(':', "'")}"`;
  }
  return Number.isFinite(kmh) ? arred1(kmh).toFixed(1).replace('.', ',') : '--';
}

export function rotuloUnidade(unidade) {
  return unidade === 'pace' ? 'min/km' : 'km/h';
}

export function formatarRitmo(kmh, unidade) {
  return `${valorRitmo(kmh, unidade)} ${rotuloUnidade(unidade)}`;
}

/* =========================================================
   Tempo
   ========================================================= */

// Segundos -> "m:ss" (ou "h:mm:ss" acima de 1 h).
export function formatarTempo(segundos) {
  const s = Math.max(0, Math.round(segundos));
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  const r = String(s % 60).padStart(2, '0');
  return h > 0 ? `${h}:${String(m).padStart(2, '0')}:${r}` : `${m}:${r}`;
}

// "1:30" -> 90; "90" -> 90 (segundos); "2m" -> 120. Retorna NaN se inválido.
export function lerTempo(texto) {
  const t = String(texto ?? '').trim().toLowerCase();
  let m = t.match(/^(\d{1,3}):(\d{1,2})$/);
  if (m) return Number(m[2]) < 60 ? Number(m[1]) * 60 + Number(m[2]) : NaN;
  m = t.match(/^(\d{1,3})\s*m(in)?$/);
  if (m) return Number(m[1]) * 60;
  m = t.match(/^(\d{1,4})\s*s?$/);
  if (m) return Number(m[1]);
  return NaN;
}

/* =========================================================
   Segmentos
   ========================================================= */

// Tipo usado na interface (cor + rótulo). "forte"/"leve" pertencem à fase "hiit".
export function tipoSegmento(seg) {
  if (seg.fase === 'hiit') return seg.forte ? 'forte' : 'leve';
  return seg.fase; // 'aquecimento' | 'desaceleracao'
}

export const ROTULOS_TIPO = {
  aquecimento: 'Aquecimento',
  forte: 'Forte',
  leve: 'Leve',
  desaceleracao: 'Desaceleração',
};

// Cria um segmento a partir do tipo da interface.
export function criarSegmento(tipo, ritmo, duracao, inclinacao = INCLINACAO_BASE, rotulo) {
  const fase = tipo === 'forte' || tipo === 'leve' ? 'hiit' : tipo;
  const seg = { fase, ritmo: arred1(ritmo), duracao: Math.round(duracao), forte: tipo === 'forte', inclinacao };
  if (rotulo) seg.rotulo = rotulo;
  return seg;
}

export const inclinacaoDe = (seg) => seg.inclinacao ?? INCLINACAO_BASE;

export function duracaoTotal(segmentos) {
  return segmentos.reduce((soma, s) => soma + s.duracao, 0);
}

export function ritmoPico(segmentos) {
  return segmentos.reduce((max, s) => Math.max(max, s.ritmo), 0);
}

// Resumo para cartões e histórico.
export function resumoTreino(segmentos) {
  return {
    duracao: duracaoTotal(segmentos),
    ritmoMax: ritmoPico(segmentos),
    tiros: segmentos.filter((s) => s.forte).length,
    tempoForte: duracaoTotal(segmentos.filter((s) => s.forte)),
    inclinacaoMax: segmentos.reduce((m, s) => Math.max(m, inclinacaoDe(s)), 0),
    segmentos: segmentos.length,
  };
}

/* =========================================================
   Configuração
   ========================================================= */

export const OBJETIVOS = {
  variado: { nome: 'Variado', descricao: 'Alterna estímulos a cada sessão' },
  gordura: { nome: 'Gordura', descricao: 'Mais volume de trabalho, menos impacto' },
  condicionamento: { nome: 'Fôlego', descricao: 'VO2máx: tempo perto do seu limite aeróbio' },
  velocidade: { nome: 'Velocidade', descricao: 'Tiros curtos e fortes, recuperação longa' },
  resistencia: { nome: 'Limiar', descricao: 'Ritmo forte sustentado por mais tempo' },
};

export const NIVEIS = ['iniciante', 'intermediario', 'avancado'];
export const ROTULOS_NIVEL = { iniciante: 'Iniciante', intermediario: 'Intermediário', avancado: 'Avançado' };

// Garante valores válidos. Aceita configs antigas (objetivo "equilibrado").
export function normalizarConfig(config = {}) {
  let ritmoMax = Number(config.ritmoMax);
  if (!Number.isFinite(ritmoMax)) ritmoMax = RITMO_MAX_PADRAO;
  ritmoMax = arred1(Math.min(RITMO_TETO, Math.max(RITMO_MAX_MIN, ritmoMax)));

  let duracao = Number(config.duracao);
  if (!Number.isFinite(duracao)) duracao = 30;
  duracao = Math.round(duracao / DURACAO_PASSO) * DURACAO_PASSO;
  duracao = Math.min(DURACAO_MAX, Math.max(DURACAO_MIN, duracao));

  const objetivo = OBJETIVOS[config.objetivo] ? config.objetivo : 'variado';
  const nivel = NIVEIS.includes(config.nivel) ? config.nivel : 'intermediario';
  const protocolo = PROTOCOLOS[config.protocolo] ? config.protocolo : 'auto';
  const variacao = Number.isInteger(config.variacao) ? config.variacao : 0;
  return { ritmoMax, duracao, objetivo, nivel, protocolo, variacao };
}

/* =========================================================
   Aleatoriedade determinística
   ========================================================= */

// mulberry32: gerador pseudoaleatório pequeno e rápido a partir de uma semente inteira.
export function criarRng(semente) {
  let a = semente >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function hashTexto(texto) {
  let h = 2166136261;
  for (const c of texto) h = Math.imul(h ^ c.charCodeAt(0), 16777619);
  return h >>> 0;
}

/* =========================================================
   Peças comuns: aquecimento e volta à calma
   ========================================================= */

// Construtor de segmentos para um ritmo máximo V.
function fabrica(V) {
  const kmh = (pct) => Math.max(RITMO_MINIMO, Math.min(V, arred1(V * pct)));
  // recuperação: abaixo de ~6,5 km/h ninguém "trota", então vira caminhada rápida
  const recKmh = (pct) => {
    const v = kmh(pct);
    return v < 6.5 ? CAMINHADA_RAPIDA : v;
  };
  return {
    kmh,
    forte: (pct, dur, rotulo, incl = INCLINACAO_BASE) => criarSegmento('forte', kmh(pct), dur, incl, rotulo),
    // "forte" com velocidade absoluta (caminhada inclinada)
    forteAbs: (v, dur, rotulo, incl) => criarSegmento('forte', v, dur, incl, rotulo),
    leve: (pct, dur, rotulo = 'Recuperação', incl = INCLINACAO_BASE) => criarSegmento('leve', recKmh(pct), dur, incl, rotulo),
    caminhada: (dur, rotulo = 'Caminhada', v = CAMINHADA, incl = INCLINACAO_BASE) => criarSegmento('leve', v, dur, incl, rotulo),
  };
}

// Minutos de aquecimento / volta à calma conforme a duração total.
export function minutosAquecimento(duracaoMin) {
  if (duracaoMin <= 10) return 3;
  if (duracaoMin <= 15) return 4;
  if (duracaoMin <= 20) return 5;
  if (duracaoMin <= 30) return 6;
  return 8;
}

export function minutosDesaceleracao(duracaoMin) {
  if (duracaoMin <= 10) return 2;
  if (duracaoMin <= 15) return 3;
  if (duracaoMin <= 30) return 4;
  return 5;
}

// Aquecimento: rampa de caminhada (5,5 km/h) até trote (~58% V).
// Sessões intensas (≥ 85% V) ganham acelerações progressivas de 20 s no final ("AQ+").
function aquecimento(V, minutos, intenso) {
  const segs = [];
  const comAceleracoes = intenso && minutos >= 5;
  const minutosRampa = comAceleracoes ? minutos - 2 : minutos;
  const ini = Math.max(CAMINHADA, RITMO_MINIMO);
  const fim = Math.max(ini, V * 0.58);
  for (let i = 0; i < minutosRampa; i++) {
    const t = minutosRampa === 1 ? 1 : i / (minutosRampa - 1);
    segs.push(criarSegmento('aquecimento', ini + (fim - ini) * t, 60, INCLINACAO_BASE, i === 0 ? 'Caminhada' : 'Rampa'));
  }
  if (comAceleracoes) {
    // 2 × (20 s acelerando + 40 s trote): 75% e depois 85% V
    for (const pct of [0.75, 0.85]) {
      segs.push(criarSegmento('aquecimento', arred1(V * pct), 20, INCLINACAO_BASE, 'Aceleração'));
      segs.push(criarSegmento('aquecimento', arred1(V * 0.55), 40, INCLINACAO_BASE, 'Trote'));
    }
  }
  return segs;
}

// Volta à calma: de ~50% V descendo até caminhada a 5 km/h.
function desaceleracao(V, minutos) {
  const segs = [];
  const ini = Math.max(5, V * 0.5);
  for (let i = 0; i < minutos; i++) {
    const t = minutos === 1 ? 1 : i / (minutos - 1);
    segs.push(criarSegmento('desaceleracao', ini + (5 - ini) * t, 60, INCLINACAO_BASE, i === minutos - 1 ? 'Caminhada' : 'Soltando'));
  }
  return segs;
}

/* =========================================================
   Protocolos
   =========================================================
   Cada protocolo monta só o "núcleo" a partir de ctx = { V, disp, nivel (0–2), rng, f }.
   disp = segundos disponíveis para o núcleo. O núcleo deve caber em disp (sobra é completada
   depois). Retornar null = não cabe / não indicado para o caso.
   Categorias (Buchheit & Laursen, 2013): A intervalos longos · B intervalos curtos ·
   C sprint/anaeróbio · D limiar/contínuo · E subida/baixo impacto · M misto.
   Notas por objetivo: 0 = não indicado, 1 = serve, 2 = bom, 3 = ideal. */

const ate = (n, max) => Math.max(0, Math.min(n, max));

// Repete um ciclo [esforço, recuperação] n vezes, sem recuperação após o último.
function repetir(n, montarCiclo) {
  const segs = [];
  for (let i = 0; i < n; i++) segs.push(...montarCiclo(i, n));
  return segs;
}

export const PROTOCOLOS = {
  gibala: {
    nome: '10×1 min',
    curto: '1 min forte · 1 min leve',
    descricao: 'Clássico de baixo volume: minutos fortes perto do limite aeróbio com recuperação de igual duração.',
    fonte: 'Little et al., J Physiol 2010',
    categoria: 'B', nivelMin: 0, minDur: 10, maxDur: 40, intenso: false,
    objetivos: { gordura: 2, condicionamento: 2, velocidade: 1, resistencia: 1 },
    montar({ disp, nivel, f }) {
      const n = ate(Math.floor((disp + 60) / 120), 15);
      if (n < 3) return null;
      const pct = [0.78, 0.82, 0.85][nivel];
      return repetir(n, (i) => [
        f.forte(pct, 60, `Tiro ${i + 1}/${n}`),
        ...(i < n - 1 ? [nivel === 0 ? f.caminhada(60, 'Recuperação', CAMINHADA_RAPIDA) : f.leve(0.45, 60)] : []),
      ]);
    },
  },

  billat: {
    nome: '30/30',
    curto: '30 s forte · 30 s leve',
    descricao: 'Intermitente de Billat: o consumo de oxigênio fica alto mesmo nas pausas curtas, acumulando muito tempo perto do VO2máx.',
    fonte: 'Billat et al., 2000',
    categoria: 'B', nivelMin: 1, minDur: 20, maxDur: 45, intenso: true,
    objetivos: { gordura: 1, condicionamento: 3, velocidade: 2, resistencia: 1 },
    montar({ disp, nivel, f }) {
      const pct = nivel === 2 ? 0.88 : 0.85;
      const porSerie = nivel === 2 ? 10 : 8;
      const ciclo = 60;
      const pausaSerie = 180;
      // quantas séries completas cabem (com pausa entre elas), até 3
      let series = 1;
      while (series < 3 && (series + 1) * porSerie * ciclo + series * pausaSerie <= disp) series++;
      const reps = series === 1 ? ate(Math.floor((disp + 30) / ciclo), 16) : porSerie;
      if (reps < 8) return null;
      const segs = [];
      for (let s = 0; s < series; s++) {
        segs.push(...repetir(reps, (i) => [
          f.forte(pct, 30, `Série ${s + 1} · ${i + 1}/${reps}`),
          ...(i < reps - 1 ? [f.leve(0.45, 30)] : []),
        ]));
        if (s < series - 1) segs.push(f.leve(0.5, pausaSerie, 'Pausa entre séries'));
      }
      return segs;
    },
  },

  bangsbo: {
    nome: '10-20-30',
    curto: 'Blocos de 30 s leve · 20 s médio · 10 s forte',
    descricao: 'Blocos de 5 min com aceleração crescente dentro de cada minuto. Muita evidência em pessoas destreinadas e ótimo para a saúde cardiovascular.',
    fonte: 'Gunnarsson & Bangsbo, J Appl Physiol 2012',
    categoria: 'B', nivelMin: 0, minDur: 25, maxDur: 50, intenso: true,
    objetivos: { gordura: 2, condicionamento: 2, velocidade: 1, resistencia: 1 },
    montar({ disp, nivel, f }) {
      const bloco = 300;
      const pausa = 120;
      const blocos = ate(Math.floor((disp + pausa) / (bloco + pausa)), [2, 4, 5][nivel]);
      if (blocos < 2) return null;
      const pico = [0.9, 0.95, 0.97][nivel];
      const segs = [];
      for (let b = 0; b < blocos; b++) {
        for (let r = 0; r < 5; r++) {
          segs.push(f.leve(0.52, 30, `Bloco ${b + 1} · ${r + 1}/5`));
          segs.push(criarSegmento('leve', f.kmh(0.72), 20, INCLINACAO_BASE, 'Médio'));
          // limite de ~3 min acima de 95% V por sessão: do 4º bloco em diante o pico cai para 93%
          segs.push(f.forte(b < 3 ? pico : Math.min(pico, 0.93), 10, 'Sprint'));
        }
        if (b < blocos - 1) segs.push(f.caminhada(pausa, 'Pausa entre blocos', CAMINHADA_RAPIDA));
      }
      return segs;
    },
  },

  noruegues: {
    nome: '4×4',
    curto: '4 min forte · 3 min leve',
    descricao: 'Protocolo norueguês: tiros longos a 90–95% da FC máxima. Um dos mais estudados para aumentar o VO2máx.',
    fonte: 'Helgerud et al., MSSE 2007',
    categoria: 'A', nivelMin: 0, minDur: 20, maxDur: 50, intenso: false,
    objetivos: { gordura: 2, condicionamento: 3, velocidade: 0, resistencia: 2 },
    montar({ disp, nivel, rng, f }) {
      const esforco = 240;
      const rec = 180;
      const n = ate(Math.floor((disp + rec) / (esforco + rec)), [2, 4, 5][nivel]);
      if (n < 1) return null;
      // variação de "embalagem": mesma carga em subida (velocidade menor, 6% de inclinação)
      const subida = rng() < 0.35;
      const pct = subida ? 0.68 : [0.72, 0.77, 0.8][nivel];
      const incl = subida ? 6 : INCLINACAO_BASE;
      return repetir(n, (i) => [
        f.forte(pct, esforco, `Tiro ${i + 1}/${n}${subida ? ' · subida' : ''}`, incl),
        ...(i < n - 1 ? [f.leve(0.52, rec)] : []),
      ]);
    },
  },

  piramide: {
    nome: 'Pirâmide',
    curto: '1-2-3-2-1 min',
    descricao: 'Tiros que crescem e voltam a diminuir. Quanto mais longo o tiro, menor a velocidade.',
    fonte: 'RunnersConnect',
    categoria: 'A', nivelMin: 0, minDur: 20, maxDur: 50, intenso: false,
    objetivos: { gordura: 1, condicionamento: 3, velocidade: 1, resistencia: 2 },
    montar({ disp, nivel, f }) {
      const formas = [[1, 2, 3, 4, 3, 2, 1], [1, 2, 3, 2, 1], [1, 2, 1]];
      const pctMin = { 1: 0.88, 2: 0.82, 3: 0.78, 4: 0.74 };
      const ajuste = nivel === 0 ? -0.04 : 0;
      const recDe = (min) => Math.max(60, min * 30);
      const montar = (forma) => repetir(forma.length, (i) => {
        const min = forma[i];
        return [
          f.forte(pctMin[min] + ajuste, min * 60, `${min} min · ${i + 1}/${forma.length}`),
          ...(i < forma.length - 1 ? [f.leve(0.5, recDe(min))] : []),
        ];
      });
      for (const forma of formas) {
        if (nivel === 0 && forma.includes(4)) continue;
        const segs = montar(forma);
        if (duracaoTotal(segs) <= disp) return segs;
      }
      return null;
    },
  },

  escada: {
    nome: 'Escada',
    curto: '4-3-2-1 min, cada vez mais rápido',
    descricao: 'Tiros que encurtam e aceleram: começa no limiar e termina perto do máximo. Avançados sobem a escada ao contrário.',
    fonte: 'Active.com · RunnersConnect',
    categoria: 'A', nivelMin: 1, minDur: 20, maxDur: 50, intenso: true,
    objetivos: { gordura: 1, condicionamento: 2, velocidade: 2, resistencia: 2 },
    montar({ disp, nivel, rng, f }) {
      let degraus = [[4, 0.74, 120], [3, 0.78, 90], [2, 0.84, 60], [1, 0.92, 0]];
      if (nivel === 2 && rng() < 0.5) {
        // escada crescente: termina no tiro mais longo
        degraus = [[1, 0.88, 60], [2, 0.82, 90], [3, 0.78, 120], [4, 0.74, 0]];
      }
      const umaEscada = (k, total) => degraus.flatMap(([min, pct, rec], i) => [
        f.forte(pct, min * 60, `${min} min${total > 1 ? ` · escada ${k + 1}` : ''}`),
        ...(i < degraus.length - 1 ? [f.leve(0.5, rec)] : []),
      ]);
      const dur = duracaoTotal(umaEscada(0, 1));
      const pausa = 180;
      const n = ate(Math.floor((disp + pausa) / (dur + pausa)), 3);
      if (n < 1) return null;
      const segs = [];
      for (let k = 0; k < n; k++) {
        segs.push(...umaEscada(k, n));
        if (k < n - 1) segs.push(f.leve(0.5, pausa, 'Pausa entre escadas'));
      }
      return segs;
    },
  },

  subidaLonga: {
    nome: 'Subidas longas',
    curto: '90 s em subida · 2,5 min plano',
    descricao: 'Tiros em inclinação de 4–6%: força específica e VO2máx com menos velocidade e menos impacto.',
    fonte: "Runner's World · TrainingPeaks",
    categoria: 'E', nivelMin: 0, minDur: 20, maxDur: 50, intenso: false,
    objetivos: { gordura: 3, condicionamento: 2, velocidade: 1, resistencia: 2 },
    montar({ disp, nivel, f }) {
      const n = ate(Math.floor((disp + 150) / 240), 10);
      if (n < 4) return null;
      const incl = [4, 5, 6][nivel];
      return repetir(n, (i) => [
        f.forte(0.74, 90, `Subida ${i + 1}/${n}`, incl),
        ...(i < n - 1 ? [f.leve(0.48, 150)] : []),
      ]);
    },
  },

  subidaCurta: {
    nome: 'Rampas curtas',
    curto: '30 s em rampa forte · 90 s plano',
    descricao: 'Velocidade moderada e inclinação alta (8–10%). Potência de perna sem precisar correr no limite da esteira.',
    fonte: 'TrainingPeaks',
    categoria: 'E', nivelMin: 1, minDur: 15, maxDur: 40, intenso: false,
    objetivos: { gordura: 2, condicionamento: 2, velocidade: 2, resistencia: 1 },
    montar({ disp, nivel, f }) {
      const n = ate(Math.floor((disp + 90) / 120), 12);
      if (n < 6) return null;
      const incl = nivel === 2 ? 10 : 8;
      return repetir(n, (i) => [
        f.forte(0.7, 30, `Rampa ${i + 1}/${n}`, incl),
        ...(i < n - 1 ? [f.leve(0.45, 90)] : []),
      ]);
    },
  },

  caminhadaInclinada: {
    nome: 'Caminhada inclinada',
    curto: 'Alterna 8–12% e plano, caminhando',
    descricao: 'HIIT de baixo impacto: a intensidade vem da inclinação, não da velocidade. Ótimo para queimar gordura e para dias de recuperação.',
    fonte: 'ACSM (equação de caminhada) · ACE',
    categoria: 'E', nivelMin: 0, minDur: 10, maxDur: 50, intenso: false,
    objetivos: { gordura: 3, condicionamento: 1, velocidade: 0, resistencia: 1 },
    montar({ disp, nivel, f }) {
      const n = ate(Math.floor((disp + 90) / 180), 16);
      if (n < 2) return null;
      const incl = [8, 10, 12][nivel];
      const v = nivel === 0 ? 5.5 : 6;
      return repetir(n, (i) => [
        f.forteAbs(v, 90, `Subida ${i + 1}/${n}`, incl),
        ...(i < n - 1 ? [f.caminhada(90, 'Plano', 5)] : []),
      ]);
    },
  },

  fartlek: {
    nome: 'Fartlek',
    curto: 'Cada bloco mais rápido que o anterior',
    descricao: 'Blocos de 1 min forte / 1 min leve. A cada bloco o tiro acelera: ritmo de 10 km, de 5 km e de prova curta.',
    fonte: 'Runkeeper · Human Kinetics',
    categoria: 'B', nivelMin: 0, minDur: 20, maxDur: 50, intenso: true,
    objetivos: { gordura: 2, condicionamento: 2, velocidade: 1, resistencia: 2 },
    montar({ disp, nivel, f }) {
      const reps = nivel === 0 ? 3 : 4;
      const durBloco = reps * 120 - 60;
      const pausa = 90;
      const blocos = ate(Math.floor((disp + pausa) / (durBloco + pausa)), 4);
      if (blocos < 2) return null;
      const escala = blocos === 4 ? [0.74, 0.79, 0.84, 0.89] : blocos === 3 ? [0.75, 0.81, 0.88] : [0.78, 0.86];
      const teto = nivel === 0 ? 0.82 : 1;
      const segs = [];
      for (let b = 0; b < blocos; b++) {
        const pct = Math.min(escala[b], teto);
        segs.push(...repetir(reps, (i) => [
          f.forte(pct, 60, `Bloco ${b + 1} · ${i + 1}/${reps}`),
          ...(i < reps - 1 ? [f.leve(0.5, 60)] : []),
        ]));
        if (b < blocos - 1) segs.push(f.leve(0.5, pausa, 'Entre blocos'));
      }
      return segs;
    },
  },

  overUnder: {
    nome: 'Over-under',
    curto: 'Oscila acima e abaixo do limiar',
    descricao: 'Blocos contínuos: 2,5 min logo abaixo do limiar e 1 min acima dele. Ensina o corpo a limpar lactato em movimento.',
    fonte: 'TrainingPeaks · Triathlon Magazine',
    categoria: 'D', nivelMin: 1, minDur: 25, maxDur: 50, intenso: false,
    objetivos: { gordura: 1, condicionamento: 1, velocidade: 0, resistencia: 3 },
    montar({ disp, f }) {
      const bloco = 3 * (150 + 60);
      const pausa = 180;
      const n = ate(Math.floor((disp + pausa) / (bloco + pausa)), 3);
      if (n < 1) return null;
      const segs = [];
      for (let b = 0; b < n; b++) {
        for (let r = 0; r < 3; r++) {
          segs.push(criarSegmento('leve', f.kmh(0.69), 150, INCLINACAO_BASE, `Under · bloco ${b + 1}`));
          segs.push(f.forte(0.8, 60, `Over ${r + 1}/3`));
        }
        if (b < n - 1) segs.push(f.leve(0.5, pausa, 'Pausa entre blocos'));
      }
      return segs;
    },
  },

  sprint: {
    nome: 'Sprints 30 s',
    curto: '30 s no máximo · 3,5 min andando',
    descricao: 'Sprint interval training: poucos tiros curtíssimos no limite com recuperação longa. Só para quem já tem base.',
    fonte: 'Gist et al., Sports Med 2014',
    categoria: 'C', nivelMin: 2, minDur: 25, maxDur: 40, intenso: true,
    objetivos: { gordura: 1, condicionamento: 2, velocidade: 3, resistencia: 0 },
    montar({ disp, f }) {
      const n = ate(Math.floor((disp + 210) / 240), 6);
      if (n < 4) return null;
      return repetir(n, (i) => [
        f.forte(0.97, 30, `Sprint ${i + 1}/${n}`),
        ...(i < n - 1 ? [f.caminhada(210)] : []),
      ]);
    },
  },

  tabata: {
    nome: 'Tabata',
    curto: '20 s forte · 40 s leve × 8',
    descricao: 'Tabata adaptado à esteira: os 10 s de pausa do original viram 40 s, porque a esteira demora para trocar de velocidade.',
    fonte: 'Tabata et al., MSSE 1996',
    categoria: 'C', nivelMin: 1, minDur: 15, maxDur: 35, intenso: true,
    objetivos: { gordura: 1, condicionamento: 2, velocidade: 3, resistencia: 0 },
    montar({ disp, f }) {
      const bloco = 8 * 60 - 40;
      const pausa = 180;
      const n = ate(Math.floor((disp + pausa) / (bloco + pausa)), 3);
      if (n < 1) return null;
      const segs = [];
      for (let b = 0; b < n; b++) {
        // tempo total ≥ 95% V limitado a ~2–3 min por sessão: só o 1º bloco vai a 95%
        const pct = b === 0 ? 0.95 : 0.9;
        segs.push(...repetir(8, (i) => [
          f.forte(pct, 20, `Tabata ${n > 1 ? `${b + 1} · ` : ''}${i + 1}/8`),
          ...(i < 7 ? [f.leve(0.48, 40)] : []),
        ]));
        if (b < n - 1) segs.push(f.leve(0.5, pausa, 'Pausa entre blocos'));
      }
      return segs;
    },
  },

  progressivo: {
    nome: 'Progressivo',
    curto: 'Contínuo, acelerando aos poucos',
    descricao: 'Sem pausas: degraus de ritmo que sobem de trote a limiar, com final forte. Bom dia "moderado" entre sessões intensas.',
    fonte: 'Polar — negative splits',
    categoria: 'D', nivelMin: 0, minDur: 15, maxDur: 50, intenso: false,
    objetivos: { gordura: 2, condicionamento: 1, velocidade: 0, resistencia: 3 },
    montar({ disp, nivel, f }) {
      // com tempo sobrando, termina com 4 × 30/30
      const comAcabamento = disp >= 20 * 60 && nivel > 0;
      const acabamento = comAcabamento ? 4 * 60 - 30 : 0;
      const continuo = disp - acabamento;
      const degraus = [0.55, 0.6, 0.65, 0.7, 0.75];
      const teto = [0.72, 0.82, 0.85][nivel];
      const passo = Math.floor(continuo / (degraus.length + 1) / 30) * 30;
      if (passo < 120) return null;
      const segs = degraus.map((pct, i) =>
        criarSegmento(pct >= 0.7 ? 'forte' : 'leve', f.kmh(pct), passo, INCLINACAO_BASE, `Degrau ${i + 1}/${degraus.length + 1}`));
      segs.push(f.forte(teto, passo, 'Final forte'));
      if (comAcabamento) {
        segs.push(...repetir(4, (i) => [
          ...(i === 0 ? [] : [f.leve(0.5, 30)]),
          f.forte(0.9, 30, `Acabamento ${i + 1}/4`),
        ]));
      }
      return segs;
    },
  },

  emom: {
    nome: 'EMOM',
    curto: 'A cada minuto, tiro cada vez mais longo',
    descricao: 'Every minute on the minute: começa com 20 s rápidos por minuto e termina com 40 s. A densidade sobe sem a velocidade mudar.',
    fonte: 'Prática de treino funcional',
    categoria: 'B', nivelMin: 1, minDur: 10, maxDur: 40, intenso: true,
    objetivos: { gordura: 2, condicionamento: 2, velocidade: 2, resistencia: 1 },
    montar({ disp, nivel, f }) {
      const n = ate(Math.floor(disp / 60), 18);
      if (n < 5) return null;
      const pct = nivel === 2 ? 0.88 : 0.85;
      return repetir(n, (i) => {
        const terco = Math.min(2, Math.floor((i * 3) / n));
        const rapido = [20, 30, 40][terco];
        return [f.forte(pct, rapido, `Minuto ${i + 1}/${n}`), f.leve(0.5, 60 - rapido)];
      });
    },
  },

  misto: {
    nome: 'Misto',
    curto: '30/30 + over-under + rampas',
    descricao: 'Três estímulos diferentes na mesma sessão, com pausa entre eles: intermitente curto, limiar e força em subida.',
    fonte: 'Combinação dos protocolos acima',
    categoria: 'M', nivelMin: 1, minDur: 40, maxDur: 50, intenso: true,
    objetivos: { gordura: 2, condicionamento: 2, velocidade: 1, resistencia: 2 },
    montar({ disp, f }) {
      const pausa = () => f.leve(0.5, 180, 'Troca de bloco');
      const segs = [
        ...repetir(6, (i) => [f.forte(0.85, 30, `30/30 · ${i + 1}/6`), ...(i < 5 ? [f.leve(0.45, 30)] : [])]),
        pausa(),
        ...repetir(2, (i) => [
          criarSegmento('leve', f.kmh(0.69), 150, INCLINACAO_BASE, `Under ${i + 1}/2`),
          f.forte(0.8, 60, `Over ${i + 1}/2`),
        ]),
        pausa(),
        ...repetir(6, (i) => [f.forte(0.7, 30, `Rampa ${i + 1}/6`, 8), ...(i < 5 ? [f.leve(0.45, 60)] : [])]),
      ];
      return duracaoTotal(segs) <= disp ? segs : null;
    },
  },
};

/* =========================================================
   Seleção e montagem da sessão
   ========================================================= */

// Protocolos possíveis para duração/nível/objetivo (independe do histórico).
export function protocolosElegiveis(config) {
  const c = normalizarConfig(config);
  const nivel = NIVEIS.indexOf(c.nivel);
  return Object.entries(PROTOCOLOS)
    .filter(([, p]) => nivel >= p.nivelMin && c.duracao >= p.minDur && c.duracao <= p.maxDur)
    .filter(([, p]) => c.objetivo === 'variado' || p.objetivos[c.objetivo] > 0)
    .filter(([id]) => montarSessao(c, id) !== null)
    .map(([id]) => id);
}

// Escolha automática: pondera pela nota do objetivo e evita repetir estímulo.
// recentes = [{ protocolo, categoria, data }] (mais recente primeiro).
export function escolherProtocolo(config, recentes = [], agora = 0) {
  const c = normalizarConfig(config);
  const candidatos = protocolosElegiveis(c);
  if (!candidatos.length) return null;

  const ultimo = recentes[0];
  const seteDias = 7 * 24 * 3600 * 1000;
  const usadosNaSemana = new Set(recentes.filter((r) => !agora || agora - r.data < seteDias).map((r) => r.protocolo));

  const pesos = candidatos.map((id) => {
    const p = PROTOCOLOS[id];
    let peso = c.objetivo === 'variado' ? 2 : p.objetivos[c.objetivo] ** 2;
    if (ultimo && p.categoria === ultimo.categoria) peso *= 0.1;       // não repetir a mesma categoria
    if (ultimo?.categoria === 'C' && !['D', 'E'].includes(p.categoria)) peso *= 0.3; // após sprint, algo leve
    if (usadosNaSemana.has(id)) peso *= 0.25;                           // não repetir o protocolo na semana
    return peso;
  });

  const rng = criarRng(hashTexto(`${c.variacao}|${c.duracao}|${c.objetivo}|${c.nivel}|${ultimo?.protocolo ?? ''}`));
  let alvo = rng() * pesos.reduce((a, b) => a + b, 0);
  for (let i = 0; i < candidatos.length; i++) {
    alvo -= pesos[i];
    if (alvo <= 0) return candidatos[i];
  }
  return candidatos.at(-1);
}

// Monta a sessão completa de um protocolo, fechando exatamente a duração. null se não couber.
function montarSessao(c, id) {
  const p = PROTOCOLOS[id];
  const V = c.ritmoMax;
  const nivel = NIVEIS.indexOf(c.nivel);
  const f = fabrica(V);
  const minAq = minutosAquecimento(c.duracao);
  const minVc = minutosDesaceleracao(c.duracao);
  const disp = (c.duracao - minAq - minVc) * 60;
  const rng = criarRng(hashTexto(`${id}|${c.variacao}|${c.duracao}|${c.nivel}`));

  const nucleo = p.montar({ V, disp, nivel, rng, f });
  if (!nucleo || duracaoTotal(nucleo) > disp) return null;

  const aq = aquecimento(V, minAq, p.intenso);
  const vc = desaceleracao(V, minVc);

  // Sobra: até 2 min alongam aquecimento e volta à calma; acima disso vira trote leve antes da volta à calma.
  let sobra = c.duracao * 60 - duracaoTotal(aq) - duracaoTotal(nucleo) - duracaoTotal(vc);
  const extras = [];
  if (sobra > 120) {
    const trote = sobra - 60;
    extras.push(f.leve(0.52, trote, 'Trote leve'));
    sobra -= trote;
  }
  const noAq = Math.floor(sobra / 2);
  aq[0] = { ...aq[0], duracao: aq[0].duracao + noAq };
  vc[vc.length - 1] = { ...vc[vc.length - 1], duracao: vc[vc.length - 1].duracao + (sobra - noAq) };

  return [...aq, ...nucleo, ...extras, ...vc];
}

/**
 * Gera a sessão: escolhe o protocolo (ou usa o pedido) e monta os segmentos.
 * @param config { ritmoMax, duracao, objetivo, nivel, protocolo ('auto' | id), variacao }
 * @param recentes histórico recente [{ protocolo, categoria, data }] para variar o estímulo
 * @returns { protocolo, nome, descricao, fonte, categoria, segmentos }
 */
export function gerarSessao(config, recentes = [], agora = 0) {
  const c = normalizarConfig(config);
  let id = c.protocolo !== 'auto' ? c.protocolo : null;
  if (!id || !protocolosElegiveis(c).includes(id)) id = escolherProtocolo(c, recentes, agora);
  // garantia: Gibala cabe em qualquer duração e nível
  if (!id) id = 'gibala';
  const p = PROTOCOLOS[id];
  return {
    protocolo: id,
    nome: p.nome,
    descricao: p.descricao,
    fonte: p.fonte,
    categoria: p.categoria,
    segmentos: montarSessao(c, id) ?? montarSessao({ ...c, nivel: 'iniciante' }, 'gibala'),
  };
}

// Compatível com a API original: só os segmentos.
export function gerarTreino(config, recentes = [], agora = 0) {
  return gerarSessao(config, recentes, agora).segmentos;
}

// Nome sugerido para salvar um treino gerado.
export function nomeSugerido(config, sessao) {
  const { duracao } = normalizarConfig(config);
  return `${sessao ? sessao.nome : 'HIIT'} · ${duracao} min`;
}
