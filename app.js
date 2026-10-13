// app.js — interface, navegação e motor de execução do treino.
import * as G from './generator.js';
import * as S from './storage.js';
import * as FX from './efeitos.js';

/* =========================================================
   Utilidades
   ========================================================= */
const $ = (sel, raiz = document) => raiz.querySelector(sel);
const $$ = (sel, raiz = document) => [...raiz.querySelectorAll(sel)];

// Cria elemento com atributos e filhos: el('div', { class: 'x' }, 'texto', outroEl)
function el(tag, attrs = {}, ...filhos) {
  const e = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === false || v == null) continue;
    if (k === 'class') e.className = v;
    else if (k === 'style') e.style.cssText = v;
    else e.setAttribute(k, v === true ? '' : v);
  }
  e.append(...filhos.filter((f) => f != null && f !== false));
  return e;
}

function svg(d) {
  const s = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  s.setAttribute('viewBox', '0 0 24 24');
  const p = document.createElementNS('http://www.w3.org/2000/svg', 'path');
  p.setAttribute('d', d);
  s.append(p);
  return s;
}

// Métrica no formato <div><dt>rótulo</dt><dd>valor <small>sufixo</small></dd></div>
const metrica = (rotulo, valor, sufixo) =>
  el('div', {}, el('dt', {}, rotulo), el('dd', {}, valor, sufixo ? el('small', {}, sufixo) : null));

let timerToast;
function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.classList.add('visivel');
  clearTimeout(timerToast);
  timerToast = setTimeout(() => t.classList.remove('visivel'), 2200);
}

const fmtData = new Intl.DateTimeFormat('pt-BR', { day: '2-digit', month: '2-digit' });
const fmtHora = new Intl.DateTimeFormat('pt-BR', { hour: '2-digit', minute: '2-digit' });
const fmtMes = new Intl.DateTimeFormat('pt-BR', { month: 'short' });

/* =========================================================
   Estado
   ========================================================= */
// normaliza na carga: corrige valores antigos fora dos limites atuais
let config = S.carregarConfig();
config = { ...config, ...G.normalizarConfig(config) };
let sessao = null;          // sessão gerada atual: { protocolo, nome, descricao, fonte, categoria, segmentos }
let chaveSeq = 0;
const novaChave = () => `k${++chaveSeq}`;

// Treino em edição (cada segmento ganha _k para a animação FLIP).
const editor = { id: null, nome: '', segmentos: [] };

function salvarConfig() {
  S.salvarConfig(config);
}

const ritmo = (kmh) => G.formatarRitmo(kmh, config.unidade);
const valor = (kmh) => G.valorRitmo(kmh, config.unidade);
const unidade = () => G.rotuloUnidade(config.unidade);

// Histórico recente para a escolha automática não repetir estímulo.
const recentes = () => S.listarHistorico().filter((h) => h.protocolo).map(({ protocolo, categoria, data }) => ({ protocolo, categoria, data }));

/* =========================================================
   Tema e unidade
   ========================================================= */
const ICONES_TEMA = {
  auto: 'M12 3a9 9 0 1 0 0 18zm0 0a9 9 0 0 1 0 18',
  claro: 'M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2m0 16v2M4.9 4.9l1.4 1.4m11.4 11.4 1.4 1.4M2 12h2m16 0h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
  escuro: 'M20 14.5A8 8 0 1 1 9.5 4a6.5 6.5 0 0 0 10.5 10.5z',
};
const NOMES_TEMA = { auto: 'automático', claro: 'claro', escuro: 'escuro' };
const escuroSistema = matchMedia('(prefers-color-scheme: dark)');

function aplicarTema() {
  const raiz = document.documentElement;
  if (config.tema === 'auto') delete raiz.dataset.tema;
  else raiz.dataset.tema = config.tema;
  const escuro = config.tema === 'escuro' || (config.tema === 'auto' && escuroSistema.matches);
  $('#meta-tema').content = escuro || document.body.classList.contains('imersivo') ? '#0d0d0d' : '#f1f1ec';
  const btn = $('#btn-tema');
  btn.replaceChildren(svg(ICONES_TEMA[config.tema]));
  btn.setAttribute('aria-label', `Tema: ${NOMES_TEMA[config.tema]}`);
  btn.title = `Tema: ${NOMES_TEMA[config.tema]}`;
}

function alternarTema() {
  const ordem = ['auto', 'claro', 'escuro'];
  config.tema = ordem[(ordem.indexOf(config.tema) + 1) % ordem.length];
  salvarConfig();
  FX.transicao(aplicarTema);
  toast(`Tema ${NOMES_TEMA[config.tema]}`);
}

function aplicarUnidade() {
  $$('[data-unidade]').forEach((b) => b.setAttribute('aria-pressed', String(b.dataset.unidade === config.unidade)));
  $$('[data-rotulo-unidade]').forEach((s) => (s.textContent = unidade()));
}

function mudarUnidade(nova) {
  if (nova === config.unidade) return;
  config.unidade = nova;
  salvarConfig();
  aplicarUnidade();
  renderGerar(false);
  renderEditor();
  if (exec.segmentos.length) renderExec(true);
  if (telaAtual === 'historico') renderHistorico();
}

/* =========================================================
   Gráfico (largura ∝ duração, altura ∝ esforço)
   ========================================================= */
// Esforço aproximado: cada 1% de inclinação acima da base vale ~5% de velocidade.
const esforco = (s) => s.ritmo * (1 + 0.05 * Math.max(0, G.inclinacaoDe(s) - 1));

function renderGrafico(container, segmentos, animar = false) {
  $$('.grafico-barra', container).forEach((b) => b.remove());
  const max = Math.max(1, ...segmentos.map(esforco));
  for (const s of segmentos) {
    const tipo = G.tipoSegmento(s);
    const incl = G.inclinacaoDe(s);
    container.append(el('div', {
      class: `grafico-barra t-${tipo}${incl > 2 ? ' inclinado' : ''}`,
      style: `flex: ${s.duracao} 1 0; height: ${Math.max(8, (esforco(s) / max) * 100)}%`,
      title: `${s.rotulo || G.ROTULOS_TIPO[tipo]} · ${ritmo(s.ritmo)}${incl !== 1 ? ` · ${incl}%` : ''} · ${G.formatarTempo(s.duracao)}`,
    }));
  }
  if (animar) FX.crescerBarras(container);
}

// Duração · tempo em esforço · pico
function renderMetricas(dl, segmentos) {
  const r = G.resumoTreino(segmentos);
  dl.replaceChildren(
    metrica('Duração', G.formatarTempo(r.duracao)),
    metrica('Em esforço', G.formatarTempo(r.tempoForte)),
    metrica('Pico', valor(r.ritmoMax), r.inclinacaoMax > 2 ? `${r.inclinacaoMax}%` : null),
  );
}

/* =========================================================
   Tela: Gerar
   ========================================================= */
function renderRitmoMax() {
  const input = $('#in-ritmo');
  input.value = valor(config.ritmoMax);
  input.classList.remove('invalido');
  const outra = config.unidade === 'pace' ? 'kmh' : 'pace';
  $('#dica-ritmo').textContent = `O pico que você aguenta num tiro de 30 s  ·  ${G.formatarRitmo(config.ritmoMax, outra)}`;
}

function definirRitmoMax(kmh) {
  config.ritmoMax = G.arred1(Math.min(G.RITMO_TETO, Math.max(G.RITMO_MAX_MIN, kmh)));
  salvarConfig();
  renderGerar(true);
}

// "+" = mais rápido e "−" = mais lento, nas duas unidades: 0,5 km/h ou 5 s/km.
// (em min/km, mais rápido significa um número MENOR)
function passoRitmo(direcao) {
  if (config.unidade === 'pace') {
    const segKm = Math.round(3600 / config.ritmoMax / 5) * 5 - direcao * 5;
    definirRitmoMax(3600 / segKm);
  } else {
    definirRitmoMax(Math.round((config.ritmoMax + direcao * 0.5) * 2) / 2);
  }
}

function lerRitmoDigitado() {
  const input = $('#in-ritmo');
  const kmh = G.lerRitmo(input.value, config.unidade);
  if (Number.isFinite(kmh) && kmh >= G.RITMO_MAX_MIN && kmh <= G.RITMO_TETO) definirRitmoMax(kmh);
  else {
    input.classList.add('invalido');
    toast(`Entre ${ritmo(G.RITMO_MAX_MIN)} e ${ritmo(G.RITMO_TETO)}`);
    setTimeout(renderRitmoMax, 900);
  }
}

function abasTexto(container, opcoes, atual, chave) {
  container.replaceChildren(...opcoes.map(([id, nome]) =>
    el('button', { type: 'button', role: 'radio', 'aria-checked': String(id === atual), [`data-${chave}`]: id }, nome)));
}

const ICONE_AUTO = 'M4 7h11l-3-3m3 3-3 3M20 17H9l3 3m-3-3 3-3';

function renderProtocolos() {
  const elegiveis = G.protocolosElegiveis(config);
  const auto = el('button', { type: 'button', class: 'protocolo protocolo-auto', role: 'radio', 'aria-checked': String(config.protocolo === 'auto'), 'data-protocolo': 'auto' },
    svg(ICONE_AUTO),
    el('span', {}, el('b', {}, 'Automático'), el('small', {}, 'Varia o estímulo a cada treino')));
  const cartoes = elegiveis.map((id) => {
    const p = G.PROTOCOLOS[id];
    const mini = el('div', { class: 'grafico', 'aria-hidden': 'true' });
    renderGrafico(mini, G.gerarTreino({ ...config, protocolo: id }));
    return el('button', { type: 'button', class: 'protocolo', role: 'radio', 'aria-checked': String(config.protocolo === id), 'data-protocolo': id },
      mini, el('span', {}, el('b', {}, p.nome), el('small', {}, p.curto)));
  });
  const faixa = $('#protocolos');
  const rolagem = faixa.scrollLeft;
  faixa.replaceChildren(auto, ...cartoes);
  faixa.scrollLeft = rolagem;
}

function renderGerar(animar = false) {
  sessao = G.gerarSessao(config, recentes(), Date.now());
  // protocolo escolhido deixou de caber (duração/nível/objetivo mudou): volta ao automático
  if (config.protocolo !== 'auto' && sessao.protocolo !== config.protocolo) config.protocolo = 'auto';

  renderRitmoMax();
  $('#in-duracao').value = config.duracao;
  $('#out-duracao').textContent = config.duracao;
  abasTexto($('#objetivos'), Object.entries(G.OBJETIVOS).map(([id, o]) => [id, o.nome]), config.objetivo, 'objetivo');
  abasTexto($('#niveis'), Object.entries(G.ROTULOS_NIVEL), config.nivel, 'nivel');
  renderProtocolos();
  $('#btn-variar').hidden = config.protocolo !== 'auto';

  const segs = sessao.segmentos;
  $('#previa-sobre').textContent = config.protocolo === 'auto'
    ? `Escolha automática · ${G.OBJETIVOS[config.objetivo].nome}`
    : 'Protocolo escolhido';
  $('#previa-nome').textContent = sessao.nome;
  $('#previa-desc').textContent = sessao.descricao;
  $('#previa-fonte').textContent = sessao.fonte;
  renderGrafico($('#grafico-gerado'), segs, animar);
  renderMetricas($('#metricas-gerado'), segs);
  $('#lista-gerado').replaceChildren(...segs.map((s) => {
    const tipo = G.tipoSegmento(s);
    const incl = G.inclinacaoDe(s);
    return el('li', { class: `t-${tipo}` },
      el('span', {}, s.rotulo || G.ROTULOS_TIPO[tipo]),
      el('span', { class: 'n' }, valor(s.ritmo)),
      el('span', { class: 'i' }, incl !== 1 ? `${incl}%` : ''),
      el('span', { class: 'n' }, G.formatarTempo(s.duracao)));
  }));
  // se a tela de treino ainda mostra o gerado (não iniciado), acompanha a mudança
  if (exec.doGerador && !exec.iniciado) prepararExecucao(segs, nomeGerado(), true, metaGerado());
}

const nomeGerado = () => G.nomeSugerido(config, sessao);
const metaGerado = () => ({ protocolo: sessao.protocolo, categoria: sessao.categoria });

function ligarGerar() {
  $$('[data-passo]').forEach((b) => b.addEventListener('click', () => passoRitmo(Number(b.dataset.passo))));
  const input = $('#in-ritmo');
  input.addEventListener('change', lerRitmoDigitado);
  input.addEventListener('keydown', (e) => { if (e.key === 'Enter') input.blur(); });
  input.addEventListener('focus', () => input.select());

  const range = $('#in-duracao');
  range.addEventListener('input', () => {
    config.duracao = Number(range.value);
    renderGerar(false);
  });
  range.addEventListener('change', () => {
    salvarConfig();
    FX.crescerBarras($('#grafico-gerado'));
  });

  // objetivo, nível e protocolo: delegação de cliques
  $('#tela-gerar').addEventListener('click', (e) => {
    const b = e.target.closest('[data-objetivo], [data-nivel], [data-protocolo]');
    if (!b) return;
    if (b.dataset.objetivo) config.objetivo = b.dataset.objetivo;
    if (b.dataset.nivel) config.nivel = b.dataset.nivel;
    if (b.dataset.protocolo) config.protocolo = b.dataset.protocolo;
    salvarConfig();
    renderGerar(true);
  });

  $('#btn-variar').addEventListener('click', () => {
    // avança a semente até sair um protocolo diferente do atual
    const atual = sessao.protocolo;
    for (let i = 0; i < 20; i++) {
      config.variacao += 1;
      if (G.gerarSessao(config, recentes(), Date.now()).protocolo !== atual) break;
    }
    salvarConfig();
    renderGerar(true);
  });

  $('#btn-gerar-iniciar').addEventListener('click', () => carregarExecucao(sessao.segmentos, nomeGerado(), metaGerado()));
  $('#btn-gerar-editar').addEventListener('click', () => {
    if (editor.segmentos.length && !confirm('Substituir o treino que está em edição pelo gerado?')) return;
    carregarNoEditor({ nome: nomeGerado(), segmentos: sessao.segmentos });
    irPara('editor');
  });
  $('#btn-gerar-salvar').addEventListener('click', () =>
    abrirSalvar({ nome: nomeGerado(), segmentos: sessao.segmentos, origem: sessao.protocolo }));
}

/* =========================================================
   Tela: Editor
   ========================================================= */
const OPCOES_TIPO = Object.entries(G.ROTULOS_TIPO);

function carregarNoEditor({ id = null, nome = '', segmentos = [] }) {
  editor.id = id;
  editor.nome = nome;
  editor.segmentos = segmentos.map((s) => ({ inclinacao: G.INCLINACAO_BASE, ...s, _k: novaChave() }));
  persistirEditor();
  renderEditor();
}

function persistirEditor() {
  S.salvarRascunho(editor);
}

function itemEditor(s, i, total) {
  const tipo = G.tipoSegmento(s);
  const select = el('select', { 'data-campo': 'tipo', 'aria-label': 'Tipo do segmento' },
    ...OPCOES_TIPO.map(([v, r]) => el('option', { value: v, selected: v === tipo }, r)));
  const campo = (rotulo, nome, valorCampo, modo) => el('label', {},
    el('small', {}, rotulo),
    el('input', { class: 'campo campo-num', 'data-campo': nome, inputmode: modo, value: valorCampo, autocomplete: 'off' }));
  return el('li', { class: `seg t-${tipo}`, 'data-i': i, 'data-chave': s._k },
    el('div', { class: 'seg-cabeca' },
      el('span', { class: 'seg-n' }, String(i + 1).padStart(2, '0')),
      select,
      el('div', { class: 'seg-botoes' },
        el('button', { type: 'button', class: 'icone', 'data-acao': 'subir', 'aria-label': 'Mover para cima', disabled: i === 0 }, svg('M12 19V5m-6 6 6-6 6 6')),
        el('button', { type: 'button', class: 'icone', 'data-acao': 'descer', 'aria-label': 'Mover para baixo', disabled: i === total - 1 }, svg('M12 5v14m-6-6 6 6 6-6')),
        el('button', { type: 'button', class: 'icone', 'data-acao': 'remover', 'aria-label': 'Remover segmento' }, svg('M6 6l12 12M18 6 6 18')))),
    el('div', { class: 'seg-campos' },
      campo(unidade(), 'ritmo', valor(s.ritmo), config.unidade === 'pace' ? 'text' : 'decimal'),
      campo('Duração', 'duracao', G.formatarTempo(s.duracao), 'text'),
      campo('Incl. %', 'inclinacao', String(G.inclinacaoDe(s)), 'numeric')));
}

function renderEditor() {
  $('#editor-lista').replaceChildren(...editor.segmentos.map((s, i) => itemEditor(s, i, editor.segmentos.length)));
  $('#in-nome-editor').value = editor.nome;
  $('#editor-vazio').hidden = editor.segmentos.length > 0;
  renderResumoEditor();
}

function renderResumoEditor() {
  const segs = editor.segmentos;
  $('#metricas-editor').hidden = !segs.length;
  if (segs.length) renderMetricas($('#metricas-editor'), segs);
  renderGrafico($('#grafico-editor'), segs);
  $('#btn-ed-salvar').textContent = editor.id ? 'Salvar alterações' : 'Salvar';
}

// Reordena/insere/remove com animação FLIP.
function mudarListaEditor(mudar) {
  FX.flip($('#editor-lista'), () => {
    mudar();
    renderEditor();
  });
  persistirEditor();
}

function ligarEditor() {
  const lista = $('#editor-lista');

  lista.addEventListener('change', (e) => {
    const li = e.target.closest('[data-i]');
    if (!li) return;
    const s = editor.segmentos[Number(li.dataset.i)];
    const campo = e.target.dataset.campo;
    if (campo === 'tipo') {
      Object.assign(s, G.criarSegmento(e.target.value, s.ritmo, s.duracao, G.inclinacaoDe(s)));
      li.className = `seg t-${e.target.value}`;
    } else if (campo === 'ritmo') {
      const kmh = G.lerRitmo(e.target.value, config.unidade);
      if (kmh >= G.RITMO_MINIMO && kmh <= G.RITMO_TETO) s.ritmo = kmh;
      else toast('Ritmo inválido');
      e.target.value = valor(s.ritmo);
    } else if (campo === 'duracao') {
      const seg = G.lerTempo(e.target.value);
      if (seg >= 5 && seg <= 3600) s.duracao = seg;
      else toast('Duração de 5 s a 60 min');
      e.target.value = G.formatarTempo(s.duracao);
    } else if (campo === 'inclinacao') {
      const incl = Number(e.target.value.replace(',', '.'));
      if (Number.isFinite(incl) && incl >= 0 && incl <= 15) s.inclinacao = Math.round(incl * 2) / 2;
      else toast('Inclinação de 0 a 15%');
      e.target.value = String(G.inclinacaoDe(s));
    }
    delete s.rotulo; // segmento editado perde o rótulo do protocolo
    persistirEditor();
    renderResumoEditor();
  });

  lista.addEventListener('click', (e) => {
    const b = e.target.closest('[data-acao]');
    if (!b) return;
    const i = Number(b.closest('[data-i]').dataset.i);
    const segs = editor.segmentos;
    mudarListaEditor(() => {
      if (b.dataset.acao === 'remover') segs.splice(i, 1);
      else {
        const j = b.dataset.acao === 'subir' ? i - 1 : i + 1;
        [segs[i], segs[j]] = [segs[j], segs[i]];
      }
    });
  });

  $('#in-nome-editor').addEventListener('input', (e) => {
    editor.nome = e.target.value;
    persistirEditor();
  });

  $('#btn-ed-adicionar').addEventListener('click', () => {
    const ultimo = editor.segmentos.at(-1);
    // alterna forte/leve a partir do último segmento
    const tipo = !ultimo ? 'aquecimento' : ultimo.forte ? 'leve' : 'forte';
    const kmh = tipo === 'forte' ? config.ritmoMax * 0.85 : tipo === 'leve' ? config.ritmoMax * 0.5 : G.CAMINHADA;
    const seg = { ...G.criarSegmento(tipo, kmh, tipo === 'forte' ? 60 : 90), _k: novaChave() };
    mudarListaEditor(() => editor.segmentos.push(seg));
    requestAnimationFrame(() => $('#editor-lista').lastElementChild?.scrollIntoView({ behavior: 'smooth', block: 'center' }));
  });

  $('#btn-ed-gerado').addEventListener('click', () => {
    if (editor.segmentos.length && !confirm('Substituir pelo treino gerado?')) return;
    carregarNoEditor({ nome: nomeGerado(), segmentos: sessao.segmentos });
  });

  $('#btn-ed-limpar').addEventListener('click', () => {
    if (!editor.segmentos.length || confirm('Remover todos os segmentos?')) carregarNoEditor({});
  });

  $('#btn-ed-iniciar').addEventListener('click', () => {
    if (!editor.segmentos.length) return toast('Adicione ao menos um segmento');
    carregarExecucao(editor.segmentos, editor.nome || 'Treino personalizado');
  });

  $('#btn-ed-salvar').addEventListener('click', () => {
    if (!editor.segmentos.length) return toast('Adicione ao menos um segmento');
    abrirSalvar({
      id: editor.id, nome: editor.nome || 'Treino personalizado', segmentos: editor.segmentos, origem: 'personalizado',
      aoSalvar: (t) => {
        editor.id = t.id;
        editor.nome = t.nome;
        persistirEditor();
        renderEditor();
      },
    });
  });
}

/* =========================================================
   Salvar (diálogo)
   ========================================================= */
let pendenteSalvar = null;

function abrirSalvar(dados) {
  const dlg = $('#dlg-salvar');
  if (!dlg.showModal) {
    // navegadores antigos sem <dialog>
    const nome = prompt('Nome do treino', dados.nome);
    if (nome) concluirSalvar({ ...dados, nome }, 'salvar');
    return;
  }
  pendenteSalvar = dados;
  $('#in-nome-salvar').value = dados.nome;
  $('#btn-salvar-novo').hidden = !dados.id;
  $('#btn-salvar-ok').textContent = dados.id ? 'Atualizar' : 'Salvar';
  dlg.showModal();
  $('#in-nome-salvar').select();
}

function concluirSalvar(dados, acao) {
  const treino = S.salvarTreino({
    id: acao === 'novo' ? null : dados.id, nome: dados.nome, segmentos: dados.segmentos, origem: dados.origem,
  });
  toast(`Salvo: ${treino.nome}`);
  dados.aoSalvar?.(treino);
  if (telaAtual === 'historico') renderHistorico();
}

function ligarSalvar() {
  const dlg = $('#dlg-salvar');
  $('#form-salvar').addEventListener('submit', (e) => {
    e.preventDefault();
    const nome = $('#in-nome-salvar').value.trim();
    if (!nome || !pendenteSalvar) return;
    concluirSalvar({ ...pendenteSalvar, nome }, e.submitter?.value);
    pendenteSalvar = null;
    dlg.close();
  });
  $('#btn-salvar-cancelar').addEventListener('click', () => dlg.close());
}

/* =========================================================
   Som, vibração e tela acesa
   ========================================================= */
const audio = {
  ctx: null,
  // Navegadores só liberam áudio após um gesto do usuário: chamar dentro de um clique.
  desbloquear() {
    if (!config.som) return;
    try {
      this.ctx ??= new (window.AudioContext || window.webkitAudioContext)();
      if (this.ctx.state === 'suspended') this.ctx.resume();
    } catch { /* sem Web Audio: segue sem som */ }
  },
  bipe(freq, inicio = 0, dur = 0.15, vol = 0.22) {
    if (!config.som || !this.ctx) return;
    const t = this.ctx.currentTime + inicio;
    const osc = this.ctx.createOscillator();
    const ganho = this.ctx.createGain();
    osc.type = 'square'; // mais audível com o barulho da esteira
    osc.frequency.value = freq;
    ganho.gain.setValueAtTime(0, t);
    ganho.gain.linearRampToValueAtTime(vol, t + 0.01);
    ganho.gain.setValueAtTime(vol, t + dur - 0.03);
    ganho.gain.linearRampToValueAtTime(0, t + dur);
    osc.connect(ganho).connect(this.ctx.destination);
    osc.start(t);
    osc.stop(t + dur + 0.02);
  },
  forte() { this.bipe(1320, 0, 0.16); this.bipe(1320, 0.24, 0.16); },  // bipe duplo
  leve() { this.bipe(700, 0, 0.4); },                                   // bipe simples
  tique() { this.bipe(1000, 0, 0.05, 0.16); },
  fim() { [784, 988, 1175, 1568].forEach((f, i) => this.bipe(f, i * 0.16, 0.2)); },
};

function vibrar(padrao) {
  if (!config.vibracao || !navigator.vibrate) return;
  try { navigator.vibrate(padrao); } catch { /* ignorado */ }
}

// Wake Lock: mantém a tela acesa enquanto o treino roda (fallback silencioso).
const telaAcesa = {
  sentinela: null,
  async pedir() {
    if (!('wakeLock' in navigator) || this.sentinela || document.visibilityState !== 'visible') return;
    try {
      this.sentinela = await navigator.wakeLock.request('screen');
      this.sentinela.addEventListener('release', () => { this.sentinela = null; });
    } catch { /* bateria fraca, iframe, navegador sem suporte… */ }
  },
  async liberar() {
    try { await this.sentinela?.release(); } catch { /* ignorado */ }
    this.sentinela = null;
  },
};

const ICONE_SOM = {
  true: 'M4 9v6h4l5 4V5L8 9zm12-1a5 5 0 0 1 0 8m2.5-10.5a8.5 8.5 0 0 1 0 13',
  false: 'M4 9v6h4l5 4V5L8 9zm12 0 5 6m0-6-5 6',
};
const ICONE_VIBRA = 'M8 3h8v18H8zM4 8v8M20 8v8';

function renderToggles() {
  const som = $('#btn-som');
  som.replaceChildren(svg(ICONE_SOM[config.som]));
  som.setAttribute('aria-pressed', String(config.som));
  som.title = config.som ? 'Som ligado' : 'Som desligado';
  const vib = $('#btn-vibra');
  vib.replaceChildren(svg(ICONE_VIBRA));
  vib.setAttribute('aria-pressed', String(config.vibracao));
  vib.title = config.vibracao ? 'Vibração ligada' : 'Vibração desligada';
  vib.hidden = !('vibrate' in navigator);
}

/* =========================================================
   Execução do treino
   ========================================================= */
const exec = {
  segmentos: [],
  nome: '',
  meta: {},          // { protocolo, categoria } quando veio do gerador
  doGerador: false,
  inicios: [],       // início (ms) de cada segmento no treino
  totalMs: 0,
  indice: 0,
  msNoSeg: 0,
  msReal: 0,         // tempo efetivamente corrido (não conta segmentos pulados)
  rodando: false,
  iniciado: false,
  concluido: false,
  ultimoTs: 0,
  ultimoTique: null,
  intervalo: null,
};

const emAndamento = () => exec.iniciado && !exec.concluido;

// Prepara o treino na tela de execução (sem navegar).
// "doGerador" = acompanha as mudanças da tela Gerar enquanto não for iniciado.
function prepararExecucao(segmentos, nome, doGerador = false, meta = {}) {
  pararRelogio();
  exec.segmentos = segmentos.map(({ fase, ritmo: r, duracao, forte, inclinacao, rotulo }) =>
    ({ fase, ritmo: r, duracao, forte, inclinacao: inclinacao ?? G.INCLINACAO_BASE, rotulo }));
  exec.nome = nome;
  exec.meta = meta;
  exec.doGerador = doGerador;
  let acum = 0;
  exec.inicios = exec.segmentos.map((s) => { const ini = acum; acum += s.duracao * 1000; return ini; });
  exec.totalMs = acum;
  zerarExecucao();
}

function carregarExecucao(segmentos, nome, meta = {}) {
  if (!segmentos.length) return;
  if (emAndamento() && !confirm('Há um treino em andamento. Substituir?')) return;
  prepararExecucao(segmentos, nome, false, meta);
  irPara('treino');
}

function zerarExecucao() {
  pararRelogio();
  Object.assign(exec, { indice: 0, msNoSeg: 0, msReal: 0, rodando: false, iniciado: false, concluido: false, ultimoTique: null });
  $('#exec-ritmo').dataset.valor = '';
  renderExecEstrutura();
}

function pararRelogio() {
  clearInterval(exec.intervalo);
  exec.intervalo = null;
  exec.rodando = false;
}

function decorridoMs() {
  return (exec.inicios[exec.indice] ?? 0) + exec.msNoSeg;
}

function atualizarImersivo() {
  document.body.classList.toggle('imersivo', telaAtual === 'treino' && exec.segmentos.length > 0);
  aplicarTema();
}

function renderExecEstrutura() {
  const tem = exec.segmentos.length > 0;
  $('#exec-vazio').hidden = tem;
  $('#exec').hidden = !tem || exec.concluido;
  $('#exec-fim').hidden = !exec.concluido;
  atualizarImersivo();
  if (!tem) return;
  $('#exec-nome').textContent = exec.nome;
  $('#exec-total').textContent = G.formatarTempo(exec.totalMs / 1000);
  renderGrafico($('#grafico-exec'), exec.segmentos);
  renderExec(true);
}

// Atualiza a tela do treino (chamado a cada tique do relógio).
function renderExec(completo = false) {
  const { segmentos, indice } = exec;
  const seg = segmentos[indice];
  if (!seg) return;
  const tipo = G.tipoSegmento(seg);
  const durMs = seg.duracao * 1000;
  const restanteSeg = Math.ceil((durMs - exec.msNoSeg) / 1000);

  $('#exec-painel').className = `exec-cor t-${tipo}${exec.rodando && restanteSeg <= 3 ? ' alerta' : ''}`;
  $('#exec-fase').textContent = G.ROTULOS_TIPO[tipo];
  $('#exec-contador').textContent = `${seg.rotulo ? `${seg.rotulo} · ` : ''}${indice + 1}/${segmentos.length}`;
  FX.odometro($('#exec-ritmo'), valor(seg.ritmo));
  const incl = G.inclinacaoDe(seg);
  $('#exec-inclinacao').textContent = incl !== 1 ? `Incl. ${String(incl).replace('.', ',')}%` : '';
  $('#exec-relogio').textContent = G.formatarTempo(restanteSeg);
  $('#exec-barra-seg').style.width = `${(exec.msNoSeg / durMs) * 100}%`;

  const prox = segmentos[indice + 1];
  const ddProx = $('#exec-proximo-valor');
  if (prox) {
    const inclProx = G.inclinacaoDe(prox);
    ddProx.replaceChildren(valor(prox.ritmo),
      el('small', {}, `${G.ROTULOS_TIPO[G.tipoSegmento(prox)]}${inclProx !== incl ? ` · ${inclProx}%` : ''}`));
  } else {
    ddProx.replaceChildren('Fim');
  }

  const dec = decorridoMs();
  $('#exec-restante').textContent = G.formatarTempo(Math.ceil((exec.totalMs - dec) / 1000));
  $('#exec-decorrido').textContent = G.formatarTempo(Math.floor(dec / 1000));
  $('#exec-cursor').style.left = `${(dec / exec.totalMs) * 100}%`;

  if (completo || exec.msNoSeg === 0) {
    $$('#grafico-exec .grafico-barra').forEach((b, i) => b.classList.toggle('passado', i < indice));
  }

  $('#txt-play').textContent = exec.rodando ? 'Em andamento' : exec.iniciado ? 'Pausado' : 'Toque para começar';
  $('#btn-play').setAttribute('aria-label', exec.rodando ? 'Pausar' : exec.iniciado ? 'Continuar' : 'Iniciar');
  $('#ico-play').innerHTML = exec.rodando ? '<path d="M6 4h4v16H6zm8 0h4v16h-4z"/>' : '<path d="M7 4v16l13-8z"/>';
  $('.abas [data-ir="treino"]').classList.toggle('ativo-treino', exec.rodando);
}

function tique() {
  const agora = performance.now();
  const delta = agora - exec.ultimoTs;
  exec.ultimoTs = agora;
  exec.msReal += delta;
  avancar(delta);
  if (!exec.concluido) renderExec();
}

// Avança o relógio por "delta" ms, atravessando segmentos se preciso.
// Usa o tempo real (performance.now), então não acumula atraso mesmo com setInterval impreciso.
function avancar(delta) {
  while (delta > 0) {
    const durMs = exec.segmentos[exec.indice].duracao * 1000;
    const falta = durMs - exec.msNoSeg;
    if (delta < falta) {
      exec.msNoSeg += delta;
      delta = 0;
    } else {
      delta -= falta;
      if (exec.indice === exec.segmentos.length - 1) return concluir();
      entrarSegmento(exec.indice + 1);
    }
  }
  // tiques nos últimos 3 segundos do intervalo (hora de mexer na esteira)
  const restante = Math.ceil((exec.segmentos[exec.indice].duracao * 1000 - exec.msNoSeg) / 1000);
  if (restante >= 1 && restante <= 3 && restante !== exec.ultimoTique) {
    exec.ultimoTique = restante;
    audio.tique();
  }
}

function entrarSegmento(i) {
  exec.indice = i;
  exec.msNoSeg = 0;
  exec.ultimoTique = null;
  avisarSegmento();
}

function avisarSegmento() {
  if (exec.segmentos[exec.indice].forte) {
    audio.forte();
    vibrar([180, 90, 180]);
  } else {
    audio.leve();
    vibrar(300);
  }
}

function continuar() {
  if (!exec.iniciado) {
    exec.iniciado = true;
    avisarSegmento();
  }
  exec.rodando = true;
  exec.ultimoTs = performance.now();
  clearInterval(exec.intervalo);
  exec.intervalo = setInterval(tique, 200);
  telaAcesa.pedir();
  renderExec(true);
}

function pausar() {
  tique();
  pararRelogio();
  telaAcesa.liberar();
  renderExec(true);
}

function alternarPlay() {
  audio.desbloquear();
  if (exec.concluido || !exec.segmentos.length) return;
  if (exec.rodando) pausar();
  else continuar();
}

function pular() {
  if (!exec.segmentos.length || exec.concluido) return;
  audio.desbloquear();
  if (exec.indice === exec.segmentos.length - 1) return concluir();
  if (exec.rodando) tique();
  exec.iniciado = true;
  entrarSegmento(exec.indice + 1);
  exec.ultimoTs = performance.now();
  renderExec(true);
}

function reiniciar() {
  if (exec.iniciado && !confirm('Reiniciar o treino do começo?')) return;
  telaAcesa.liberar();
  zerarExecucao();
}

function registrar(completo) {
  S.registrarConclusao({
    nome: exec.nome,
    duracaoPlanejada: Math.round(exec.totalMs / 1000),
    duracaoRealizada: Math.round(exec.msReal / 1000),
    ritmoMax: G.ritmoPico(exec.segmentos.slice(0, exec.indice + 1)),
    completo,
    ...exec.meta,
  });
}

function concluir() {
  exec.msNoSeg = exec.segmentos[exec.indice].duracao * 1000;
  pararRelogio();
  exec.concluido = true;
  telaAcesa.liberar();
  audio.fim();
  vibrar([200, 100, 200, 100, 400]);
  registrar(true);
  const r = G.resumoTreino(exec.segmentos);
  $('#exec-fim-nome').textContent = exec.nome;
  $('#exec-fim-metricas').replaceChildren(
    metrica('Tempo', G.formatarTempo(exec.msReal / 1000)),
    metrica('Esforço', G.formatarTempo(r.tempoForte)),
    metrica('Pico', valor(r.ritmoMax)),
  );
  FX.transicao(renderExecEstrutura);
  // o próximo treino gerado já considera este (rotação de estímulos)
  if (exec.doGerador || exec.meta.protocolo) renderGerar(false);
}

function encerrar() {
  if (!exec.iniciado) return irPara('gerar');
  if (!confirm('Encerrar o treino agora?')) return;
  if (exec.rodando) tique();
  const decSeg = exec.msReal / 1000;
  if (decSeg >= 60) {
    registrar(false);
    toast(`Registrado: ${G.formatarTempo(decSeg)}`);
  }
  telaAcesa.liberar();
  zerarExecucao();
}

function ligarExecucao() {
  $('#btn-play').addEventListener('click', alternarPlay);
  $('#btn-pular').addEventListener('click', pular);
  $('#btn-reiniciar').addEventListener('click', reiniciar);
  $('#btn-encerrar').addEventListener('click', encerrar);
  $('#btn-fim-repetir').addEventListener('click', zerarExecucao);

  $('#btn-som').addEventListener('click', () => {
    config.som = !config.som;
    salvarConfig();
    audio.desbloquear();
    renderToggles();
    if (config.som) audio.leve();
  });
  $('#btn-vibra').addEventListener('click', () => {
    config.vibracao = !config.vibracao;
    salvarConfig();
    renderToggles();
    vibrar(150);
  });

  // Ao voltar para o app: recupera o tempo perdido e pede a tela acesa de novo
  // (o navegador libera o Wake Lock automaticamente quando a aba fica oculta).
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && exec.rodando) {
      tique();
      telaAcesa.pedir();
    }
  });
  addEventListener('beforeunload', (e) => {
    if (exec.rodando) e.preventDefault();
  });
  // Espaço = play/pausa (útil em tablet com teclado)
  addEventListener('keydown', (e) => {
    if (telaAtual === 'treino' && e.code === 'Space' && !e.target.closest('input, select, textarea, button')) {
      e.preventDefault();
      alternarPlay();
    }
  });
}

/* =========================================================
   Tela: Histórico
   ========================================================= */
function renderHistorico() {
  const hist = S.listarHistorico();
  const tempoTotal = hist.reduce((s, h) => s + h.duracaoRealizada, 0);
  const picoGeral = hist.reduce((m, h) => Math.max(m, h.ritmoMax || 0), 0);
  $('#estatisticas').hidden = hist.length === 0;
  $('#estatisticas').replaceChildren(
    metrica('Treinos', String(hist.length)),
    metrica('Minutos', String(Math.round(tempoTotal / 60))),
    metrica('Pico', picoGeral ? valor(picoGeral) : '—'),
  );

  const salvos = S.listarSalvos();
  $('#salvos-vazio').hidden = salvos.length > 0;
  $('#lista-salvos').replaceChildren(...salvos.map((t) => {
    const grafico = el('div', { class: 'grafico', 'aria-hidden': 'true' });
    renderGrafico(grafico, t.segmentos);
    const r = G.resumoTreino(t.segmentos);
    return el('li', { class: 'item' },
      el('h3', {}, t.nome),
      el('div', { class: 'meta' }, `${G.formatarTempo(r.duracao)} · ${G.formatarTempo(r.tempoForte)} em esforço · pico ${ritmo(r.ritmoMax)} · ${fmtData.format(t.atualizadoEm)}`),
      grafico,
      el('div', { class: 'item-acoes' },
        el('button', { type: 'button', class: 'link', 'data-acao': 'treinar', 'data-id': t.id }, 'Treinar'),
        el('button', { type: 'button', class: 'link', 'data-acao': 'editar', 'data-id': t.id }, 'Editar'),
        el('button', { type: 'button', class: 'link', 'data-acao': 'duplicar', 'data-id': t.id }, 'Duplicar'),
        el('button', { type: 'button', class: 'link', 'data-acao': 'excluir', 'data-id': t.id }, 'Excluir')));
  }));

  $('#historico-vazio').hidden = hist.length > 0;
  $('#btn-limpar-historico').hidden = hist.length === 0;
  $('#lista-historico').replaceChildren(...hist.map((h) => el('li', { class: 'item-hist' },
    el('div', { class: 'dia' }, String(new Date(h.data).getDate()), el('small', {}, fmtMes.format(h.data).replace('.', ''))),
    el('div', {},
      el('b', {}, h.nome),
      el('span', {},
        `${G.formatarTempo(h.duracaoRealizada)}`
        + `${h.duracaoRealizada >= h.duracaoPlanejada - 5 ? '' : ` de ${G.formatarTempo(h.duracaoPlanejada)}`}`
        + ` · pico ${ritmo(h.ritmoMax)} · ${fmtHora.format(h.data)}`)),
    el('span', { class: `selo${h.completo ? '' : ' parcial'}` }, h.completo ? 'Feito' : 'Parcial'))));
}

function ligarHistorico() {
  $('#lista-salvos').addEventListener('click', (e) => {
    const b = e.target.closest('[data-acao]');
    if (!b) return;
    const t = S.obterSalvo(b.dataset.id);
    if (!t) return;
    switch (b.dataset.acao) {
      case 'treinar': {
        const p = G.PROTOCOLOS[t.origem];
        carregarExecucao(t.segmentos, t.nome, p ? { protocolo: t.origem, categoria: p.categoria } : {});
        break;
      }
      case 'editar':
        if (editor.segmentos.length && editor.id !== t.id && !confirm('Substituir o treino que está em edição?')) return;
        carregarNoEditor(t);
        irPara('editor');
        break;
      case 'duplicar':
        S.duplicarTreino(t.id);
        toast('Treino duplicado');
        renderHistorico();
        break;
      case 'excluir':
        if (!confirm(`Excluir “${t.nome}”?`)) return;
        S.excluirTreino(t.id);
        if (editor.id === t.id) { editor.id = null; persistirEditor(); renderResumoEditor(); }
        toast('Treino excluído');
        renderHistorico();
        break;
    }
  });
  $('#btn-limpar-historico').addEventListener('click', () => {
    if (!confirm('Apagar todo o histórico de treinos concluídos?')) return;
    S.limparHistorico();
    renderHistorico();
    renderGerar(false);
  });
}

/* =========================================================
   Navegação (hash → botão "voltar" do Android funciona)
   ========================================================= */
const TELAS = ['gerar', 'editor', 'treino', 'historico'];
let telaAtual = null;

function irPara(tela) {
  if (location.hash.slice(1) === tela) mostrarTela(tela);
  else location.hash = tela;
}

function mostrarTela(tela) {
  if (!TELAS.includes(tela)) tela = 'gerar';
  if (tela === telaAtual) return;
  FX.transicao(() => {
    telaAtual = tela;
    $$('.tela').forEach((s) => (s.hidden = s.dataset.tela !== tela));
    $$('.abas [data-ir]').forEach((b) => (b.dataset.ir === tela ? b.setAttribute('aria-current', 'page') : b.removeAttribute('aria-current')));
    if (tela === 'historico') renderHistorico();
    if (tela === 'treino') renderExecEstrutura();
    else atualizarImersivo();
    scrollTo({ top: 0 });
  });
}

/* =========================================================
   Instalação (PWA) e service worker
   ========================================================= */
let pedidoInstalacao = null;

function ligarInstalacao() {
  addEventListener('beforeinstallprompt', (e) => {
    e.preventDefault();
    pedidoInstalacao = e;
    $('#btn-instalar').hidden = false;
  });
  addEventListener('appinstalled', () => {
    $('#btn-instalar').hidden = true;
    toast('App instalado');
  });
  $('#btn-instalar').addEventListener('click', async () => {
    if (!pedidoInstalacao) return;
    pedidoInstalacao.prompt();
    await pedidoInstalacao.userChoice;
    pedidoInstalacao = null;
    $('#btn-instalar').hidden = true;
  });
  // iOS não tem beforeinstallprompt: mostra a instrução manual.
  const ios = /iphone|ipad|ipod/i.test(navigator.userAgent);
  const instalado = navigator.standalone || matchMedia('(display-mode: standalone)').matches;
  $('#dica-ios').hidden = !(ios && !instalado);
}

function registrarServiceWorker() {
  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    navigator.serviceWorker.register('./sw.js').catch(() => { /* offline indisponível */ });
  }
}

/* =========================================================
   Inicialização
   ========================================================= */
function iniciar() {
  aplicarTema();
  escuroSistema.addEventListener('change', aplicarTema);
  aplicarUnidade();
  renderToggles();

  $('#btn-tema').addEventListener('click', alternarTema);
  $$('[data-unidade]').forEach((b) => b.addEventListener('click', () => mudarUnidade(b.dataset.unidade)));
  document.addEventListener('click', (e) => {
    const alvo = e.target.closest('[data-ir]');
    if (alvo) irPara(alvo.dataset.ir);
  });
  addEventListener('hashchange', () => mostrarTela(location.hash.slice(1)));

  ligarGerar();
  ligarEditor();
  ligarSalvar();
  ligarExecucao();
  ligarHistorico();
  ligarInstalacao();

  renderGerar(true);
  const rascunho = S.carregarRascunho();
  if (rascunho) carregarNoEditor(rascunho);
  else renderEditor();
  // começa com o treino gerado já carregado na tela de execução
  prepararExecucao(sessao.segmentos, nomeGerado(), true, metaGerado());
  mostrarTela(location.hash.slice(1) || 'gerar');
  registrarServiceWorker();
}

iniciar();
