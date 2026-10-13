// tests/testes.js — testes do gerador de protocolos e das conversões de unidade.
// Sem dependências: roda no navegador (tests/index.html) e no Node (node tests/run-node.js).

import {
  gerarTreino, gerarSessao, normalizarConfig, kmhParaPace, paceParaKmh, formatarPace, lerPace,
  lerRitmo, valorRitmo, formatarTempo, lerTempo, duracaoTotal, ritmoPico, protocolosElegiveis,
  escolherProtocolo, PROTOCOLOS, NIVEIS, OBJETIVOS, RITMO_MINIMO, inclinacaoDe,
} from '../generator.js';

const casos = [];
const teste = (nome, fn) => casos.push({ nome, fn });

function igual(atual, esperado, msg = '') {
  if (atual !== esperado) throw new Error(`${msg} esperado ${JSON.stringify(esperado)}, obtido ${JSON.stringify(atual)}`);
}
function perto(atual, esperado, tol = 1e-9, msg = '') {
  if (Math.abs(atual - esperado) > tol) throw new Error(`${msg} esperado ≈${esperado}, obtido ${atual}`);
}
function verdade(cond, msg) {
  if (!cond) throw new Error(msg);
}

const DURACOES = [10, 15, 20, 25, 30, 35, 40, 45, 50];
const V = 14;

/* ---------- Conversões ---------- */

teste('km/h → min/km: 60 / km/h', () => {
  perto(kmhParaPace(12), 5);
  perto(kmhParaPace(10), 6);
  perto(kmhParaPace(14), 60 / 14);
});

teste('min/km → km/h: 60 / min/km', () => {
  perto(paceParaKmh(5), 12);
  perto(paceParaKmh(4), 15);
});

teste('conversão de ida e volta é identidade', () => {
  for (const kmh of [6, 8.5, 12, 14, 18.3]) perto(paceParaKmh(kmhParaPace(kmh)), kmh, 1e-12);
});

teste('formatarPace usa m:ss', () => {
  igual(formatarPace(kmhParaPace(14)), '4:17');
  igual(formatarPace(5), '5:00');
  igual(formatarPace(NaN), '--:--');
});

teste('lerPace aceita 4:17, 4\'17", 4.17 (m.ss) e decimal', () => {
  perto(lerPace('4:17'), 4 + 17 / 60);
  perto(lerPace('4\'17"'), 4 + 17 / 60);
  perto(lerPace('4.17'), 4 + 17 / 60);   // ponto com 2 dígitos = m:ss, não 4,17 min
  perto(lerPace('4,17'), 4 + 17 / 60);
  perto(lerPace('4,5'), 4.5);            // 1 dígito = decimal (4:30)
  perto(lerPace('5'), 5);
  verdade(Number.isNaN(lerPace('4:75')), 'segundos ≥ 60 devem ser inválidos');
  verdade(Number.isNaN(lerPace('abc')), 'texto deve ser inválido');
});

teste('exibição em notação de corredor: 14,0 e 4\'17"', () => {
  igual(valorRitmo(14, 'kmh'), '14,0');
  igual(valorRitmo(12.6, 'kmh'), '12,6');
  igual(valorRitmo(14, 'pace'), '4\'17"');
  igual(lerRitmo('12,5', 'kmh'), 12.5);
  igual(lerRitmo(valorRitmo(14, 'pace'), 'pace'), 14);  // o que é exibido pode ser lido de volta
});

teste('tabela de referência km/h ↔ min/km', () => {
  const tabela = [[3, '20:00'], [6, '10:00'], [8, '7:30'], [10, '6:00'], [12, '5:00'], [14, '4:17'], [15, '4:00'], [20, '3:00']];
  for (const [kmh, pace] of tabela) {
    igual(formatarPace(kmhParaPace(kmh)), pace, `${kmh} km/h:`);
    igual(lerRitmo(pace, 'pace'), kmh, `${pace} min/km:`);
  }
});

teste('formatarTempo / lerTempo', () => {
  igual(formatarTempo(90), '1:30');
  igual(formatarTempo(5), '0:05');
  igual(formatarTempo(3725), '1:02:05');
  igual(lerTempo('1:30'), 90);
  igual(lerTempo('45'), 45);
  igual(lerTempo('3m'), 180);
});

/* ---------- Configuração ---------- */

teste('normalizarConfig: limites, padrões e configs antigas', () => {
  igual(normalizarConfig({ duracao: 3 }).duracao, 10);
  igual(normalizarConfig({ duracao: 90 }).duracao, 50);
  igual(normalizarConfig({ duracao: 27 }).duracao, 25);
  igual(normalizarConfig({}).ritmoMax, 14);
  igual(normalizarConfig({ ritmoMax: 6.3 }).ritmoMax, 8);
  igual(normalizarConfig({ objetivo: 'equilibrado' }).objetivo, 'variado');
  igual(normalizarConfig({}).nivel, 'intermediario');
  igual(normalizarConfig({ protocolo: 'xyz' }).protocolo, 'auto');
});

/* ---------- Protocolos ---------- */

// Percorre toda combinação elegível de duração × nível × protocolo.
function cadaSessao(fn) {
  for (const nivel of NIVEIS) {
    for (const duracao of DURACOES) {
      for (const protocolo of protocolosElegiveis({ ritmoMax: V, duracao, nivel })) {
        fn(gerarSessao({ ritmoMax: V, duracao, nivel, protocolo }), { nivel, duracao, protocolo });
      }
    }
  }
}

teste('toda duração e nível tem pelo menos 1 protocolo', () => {
  for (const nivel of NIVEIS) {
    for (const duracao of DURACOES) {
      verdade(protocolosElegiveis({ duracao, nivel }).length > 0, `${nivel} ${duracao} min sem protocolo`);
    }
  }
});

teste('duração total é exata em todas as combinações', () => {
  cadaSessao((s, c) => igual(duracaoTotal(s.segmentos), c.duracao * 60, `${c.protocolo} ${c.nivel} ${c.duracao} min:`));
});

teste('ritmos entre o piso e o ritmo máximo, inclinação 0–12%', () => {
  cadaSessao((s, c) => {
    for (const seg of s.segmentos) {
      verdade(seg.ritmo >= RITMO_MINIMO && seg.ritmo <= V, `${c.protocolo}: ritmo ${seg.ritmo}`);
      verdade(inclinacaoDe(seg) >= 0 && inclinacaoDe(seg) <= 12, `${c.protocolo}: inclinação ${seg.inclinacao}`);
      verdade(Number.isInteger(seg.duracao) && seg.duracao > 0, `${c.protocolo}: duração ${seg.duracao}`);
      verdade(['aquecimento', 'hiit', 'desaceleracao'].includes(seg.fase), `fase ${seg.fase}`);
      verdade(typeof seg.forte === 'boolean', 'forte deve ser booleano');
    }
  });
});

teste('começa com aquecimento e termina com desaceleração', () => {
  cadaSessao((s, c) => {
    igual(s.segmentos[0].fase, 'aquecimento', `${c.protocolo}:`);
    igual(s.segmentos.at(-1).fase, 'desaceleracao', `${c.protocolo}:`);
    verdade(s.segmentos.some((x) => x.forte), `${c.protocolo}: sem esforço`);
  });
});

teste('esforço ≥ 95% do máximo não passa de 3 min por sessão', () => {
  cadaSessao((s, c) => {
    const alto = duracaoTotal(s.segmentos.filter((x) => x.forte && x.ritmo >= V * 0.95));
    verdade(alto <= 180, `${c.protocolo} ${c.duracao} min: ${alto} s acima de 95%`);
  });
});

teste('iniciante não recebe sprints, Tabata nem esforço acima de 90%', () => {
  for (const duracao of DURACOES) {
    const ids = protocolosElegiveis({ duracao, nivel: 'iniciante' });
    verdade(!ids.includes('sprint') && !ids.includes('tabata'), `${duracao} min: ${ids}`);
  }
  cadaSessao((s, c) => {
    if (c.nivel !== 'iniciante') return;
    const nucleo = s.segmentos.filter((x) => x.fase === 'hiit');
    verdade(ritmoPico(nucleo) <= V * 0.9 + 0.05, `${c.protocolo}: pico ${ritmoPico(nucleo)}`);
  });
});

teste('objetivo filtra protocolos não indicados', () => {
  const ids = protocolosElegiveis({ duracao: 30, nivel: 'avancado', objetivo: 'velocidade' });
  verdade(!ids.includes('caminhadaInclinada'), 'caminhada inclinada não serve para velocidade');
  verdade(ids.includes('sprint'), 'sprint deveria servir para velocidade');
});

teste('variação produz protocolos diferentes', () => {
  const vistos = new Set();
  for (let variacao = 0; variacao < 40; variacao++) vistos.add(gerarSessao({ duracao: 30, variacao }).protocolo);
  verdade(vistos.size >= 5, `só ${vistos.size} protocolos em 40 variações`);
});

teste('escolha automática evita repetir a categoria da última sessão', () => {
  let repeticoes = 0;
  for (let variacao = 0; variacao < 50; variacao++) {
    const ultimo = gerarSessao({ duracao: 30, variacao: variacao + 1000 });
    const proximo = escolherProtocolo({ duracao: 30, variacao }, [{ protocolo: ultimo.protocolo, categoria: ultimo.categoria, data: 0 }]);
    if (PROTOCOLOS[proximo].categoria === ultimo.categoria) repeticoes++;
  }
  verdade(repeticoes <= 8, `repetiu a categoria ${repeticoes}/50 vezes`);
});

teste('protocolo pedido explicitamente é respeitado', () => {
  igual(gerarSessao({ duracao: 30, protocolo: 'noruegues' }).protocolo, 'noruegues');
  const tiros = gerarTreino({ duracao: 30, protocolo: 'noruegues' }).filter((s) => s.forte && s.fase === 'hiit');
  verdade(tiros.every((t) => t.duracao === 240), '4×4 deve ter tiros de 4 min');
});

teste('gerador é puro (mesma entrada → mesma saída)', () => {
  const cfg = { ritmoMax: 13.5, duracao: 35, objetivo: 'condicionamento', variacao: 7 };
  igual(JSON.stringify(gerarSessao(cfg)), JSON.stringify(gerarSessao(cfg)));
});

teste('todo protocolo do catálogo é alcançável em alguma configuração', () => {
  const alcancados = new Set();
  cadaSessao((s) => alcancados.add(s.protocolo));
  for (const id of Object.keys(PROTOCOLOS)) verdade(alcancados.has(id), `${id} nunca é elegível`);
  verdade(Object.keys(OBJETIVOS).length === 5, 'objetivos');
});

export function executarTestes() {
  return casos.map(({ nome, fn }) => {
    try {
      fn();
      return { nome, ok: true };
    } catch (e) {
      return { nome, ok: false, erro: e.message };
    }
  });
}
