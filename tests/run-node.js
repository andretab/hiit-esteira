// Executa os testes no terminal: node tests/run-node.js
import { executarTestes } from './testes.js';

const resultados = executarTestes();
for (const r of resultados) console.log(`${r.ok ? '✔' : '✘'} ${r.nome}${r.ok ? '' : `\n    ${r.erro}`}`);
const falhas = resultados.filter((r) => !r.ok).length;
console.log(`\n${resultados.length - falhas}/${resultados.length} passaram`);
process.exitCode = falhas ? 1 : 0;
