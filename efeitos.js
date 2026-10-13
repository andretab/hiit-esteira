// efeitos.js — microanimações em JS puro (inspiradas na vitrine naocodei.com/free-code).
// Todas respeitam prefers-reduced-motion e degradam para "sem animação".

const reduzido = () => matchMedia('(prefers-reduced-motion: reduce)').matches;
const SUAVE = 'cubic-bezier(.2,.8,.2,1)';

/* ---------- Transição de telas (View Transitions API) ---------- */
export function transicao(atualizar) {
  if (!document.startViewTransition || reduzido() || document.visibilityState !== 'visible') {
    atualizar();
    return;
  }
  // Garante que a atualização roda uma única vez, mesmo que o navegador
  // nunca chame o callback (ex.: janela sem quadros de renderização).
  let feito = false;
  const rodar = () => {
    if (feito) return;
    feito = true;
    atualizar();
  };
  const t = document.startViewTransition(rodar);
  // transição abortada (aba oculta, outra transição) não é erro para o app
  for (const p of [t.ready, t.finished, t.updateCallbackDone]) p.catch(() => {});
  setTimeout(rodar, 300);
}

/* ---------- Odômetro: dígitos que mudaram rolam para cima ---------- */
export function odometro(el, novo) {
  const antigo = el.dataset.valor;
  if (antigo === novo) return;
  el.dataset.valor = novo;
  if (reduzido() || !antigo || antigo.length !== novo.length) {
    el.textContent = novo;
    return;
  }
  el.textContent = '';
  let atraso = 0;
  for (let i = 0; i < novo.length; i++) {
    const c = novo[i];
    if (c === antigo[i]) {
      el.append(c);
      continue;
    }
    // caractere novo entra por baixo enquanto o antigo sai por cima
    const caixa = document.createElement('span');
    caixa.className = 'odo';
    const entra = document.createElement('span');
    entra.textContent = c;
    const sai = document.createElement('span');
    sai.className = 'odo-velho';
    sai.textContent = antigo[i];
    caixa.append(entra, sai);
    el.append(caixa);
    const opcoes = { duration: 420, delay: atraso, easing: SUAVE, fill: 'backwards' };
    entra.animate([{ transform: 'translateY(100%)' }, { transform: 'none' }], opcoes);
    sai.animate([{ transform: 'none' }, { transform: 'translateY(-100%)' }], { ...opcoes, fill: 'forwards' });
    atraso += 60;
  }
  // ao final volta a ser texto simples (sem spans extras)
  setTimeout(() => { if (el.dataset.valor === novo) el.textContent = novo; }, atraso + 480);
}

/* ---------- FLIP: itens deslizam até a nova posição ao reordenar ---------- */
// Os filhos do container precisam de data-chave estável.
export function flip(container, mudar) {
  const antes = new Map();
  for (const el of container.children) antes.set(el.dataset.chave, el.getBoundingClientRect().top);
  mudar();
  if (reduzido()) return;
  for (const el of container.children) {
    const topoAntes = antes.get(el.dataset.chave);
    if (topoAntes === undefined) {
      el.animate([{ opacity: 0, transform: 'scale(.96)' }, { opacity: 1, transform: 'none' }], { duration: 220, easing: SUAVE });
      continue;
    }
    const dy = topoAntes - el.getBoundingClientRect().top;
    if (dy) el.animate([{ transform: `translateY(${dy}px)` }, { transform: 'none' }], { duration: 280, easing: SUAVE });
  }
}

/* ---------- Barras do gráfico crescendo da base ---------- */
export function crescerBarras(container) {
  if (reduzido()) return;
  const barras = container.querySelectorAll('.grafico-barra');
  const passo = Math.min(18, 360 / Math.max(1, barras.length));
  barras.forEach((b, i) => {
    b.animate([{ transform: 'scaleY(0)' }, { transform: 'scaleY(1)' }],
      { duration: 420, delay: i * passo, easing: SUAVE, fill: 'backwards' });
  });
}
