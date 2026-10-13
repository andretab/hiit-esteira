// storage.js — persistência local (localStorage).
// Os dados são pequenos (dezenas de treinos), então localStorage basta.
// Toda leitura/escrita é protegida: em modo privado ou com armazenamento bloqueado
// o app continua funcionando, só não persiste.

const CHAVES = {
  config: 'hiit.config.v1',
  salvos: 'hiit.salvos.v1',
  historico: 'hiit.historico.v1',
  rascunho: 'hiit.rascunho.v1',
};

export const CONFIG_PADRAO = {
  ritmoMax: 14,
  duracao: 30,
  objetivo: 'variado',  // 'variado' | 'gordura' | 'condicionamento' | 'velocidade' | 'resistencia'
  nivel: 'intermediario',
  protocolo: 'auto',    // 'auto' ou id de generator.js/PROTOCOLOS
  variacao: 0,          // semente da escolha automática
  unidade: 'kmh',     // 'kmh' | 'pace'
  tema: 'auto',       // 'auto' | 'claro' | 'escuro'
  som: true,
  vibracao: true,
};

const LIMITE_HISTORICO = 200;

function ler(chave, padrao) {
  try {
    const bruto = localStorage.getItem(chave);
    return bruto ? JSON.parse(bruto) : padrao;
  } catch {
    return padrao;
  }
}

function gravar(chave, valor) {
  try {
    localStorage.setItem(chave, JSON.stringify(valor));
    return true;
  } catch {
    return false;
  }
}

// Identificador curto e único o suficiente para uso local.
export function novoId() {
  return Date.now().toString(36) + Math.random().toString(36).slice(2, 7);
}

// Cópia profunda simples dos segmentos (evita compartilhar referências).
function copiarSegmentos(segmentos) {
  return segmentos.map(({ fase, ritmo, duracao, forte, inclinacao = 1, rotulo }) => ({
    fase, ritmo, duracao, forte: !!forte, inclinacao, ...(rotulo ? { rotulo } : {}),
  }));
}

/* ---------------- Configuração ---------------- */

export function carregarConfig() {
  return { ...CONFIG_PADRAO, ...ler(CHAVES.config, {}) };
}

export function salvarConfig(config) {
  return gravar(CHAVES.config, config);
}

/* ---------------- Treinos salvos ---------------- */

export function listarSalvos() {
  const lista = ler(CHAVES.salvos, []);
  return Array.isArray(lista) ? lista.sort((a, b) => b.atualizadoEm - a.atualizadoEm) : [];
}

export function obterSalvo(id) {
  return listarSalvos().find((t) => t.id === id) || null;
}

// Cria (sem id) ou atualiza (com id) um treino salvo. Retorna o treino gravado.
export function salvarTreino({ id, nome, segmentos, origem = 'personalizado' }) {
  const lista = listarSalvos();
  const agora = Date.now();
  const existente = id ? lista.find((t) => t.id === id) : null;
  const treino = {
    id: existente ? existente.id : novoId(),
    nome: (nome || 'Treino sem nome').trim(),
    segmentos: copiarSegmentos(segmentos),
    origem,
    criadoEm: existente ? existente.criadoEm : agora,
    atualizadoEm: agora,
  };
  const nova = existente ? lista.map((t) => (t.id === treino.id ? treino : t)) : [treino, ...lista];
  gravar(CHAVES.salvos, nova);
  return treino;
}

export function duplicarTreino(id) {
  const original = obterSalvo(id);
  if (!original) return null;
  return salvarTreino({ nome: `${original.nome} (cópia)`, segmentos: original.segmentos, origem: original.origem });
}

export function excluirTreino(id) {
  gravar(CHAVES.salvos, listarSalvos().filter((t) => t.id !== id));
}

/* ---------------- Histórico de treinos concluídos ---------------- */

export function listarHistorico() {
  const lista = ler(CHAVES.historico, []);
  return Array.isArray(lista) ? lista.sort((a, b) => b.data - a.data) : [];
}

// registro: { nome, duracaoPlanejada, duracaoRealizada, ritmoMax, completo, protocolo?, categoria? }
export function registrarConclusao(registro) {
  const entrada = { id: novoId(), data: Date.now(), ...registro };
  const lista = [entrada, ...listarHistorico()].slice(0, LIMITE_HISTORICO);
  gravar(CHAVES.historico, lista);
  return entrada;
}

export function excluirDoHistorico(id) {
  gravar(CHAVES.historico, listarHistorico().filter((h) => h.id !== id));
}

export function limparHistorico() {
  gravar(CHAVES.historico, []);
}

/* ---------------- Rascunho do editor ---------------- */
// Mantém o treino personalizado em edição entre recarregamentos.

export function carregarRascunho() {
  const r = ler(CHAVES.rascunho, null);
  return r && Array.isArray(r.segmentos) ? r : null;
}

export function salvarRascunho({ id = null, nome = '', segmentos = [] }) {
  gravar(CHAVES.rascunho, { id, nome, segmentos: copiarSegmentos(segmentos) });
}
