// Gerador.mc — geração automática do HIIT a partir do ritmo máximo e da duração.
//
// Estrutura: aquecimento -> núcleo (esforço/recuperação alternados) -> desaquecimento.
// Tempos de aquecimento/desaquecimento vêm da mesma tabela do protótipo PWA.
//
// Diferença proposital em relação ao PWA: lá o aquecimento é uma rampa minuto a minuto.
// No relógio, cada troca de bloco vibra e apita, então rampa de 1 em 1 min viraria
// alarme demais. Aqui o aquecimento são 2 blocos (caminhada + trote) e o
// desaquecimento também (trote leve + caminhada).
//
// Padrão do núcleo conforme o tempo disponível (V = ritmo máximo):
//   núcleo <= 8 min  : 40 s a 92% V / 40 s recuperação  (tiros curtos)
//   núcleo <= 20 min : 60 s a 90% V / 60 s recuperação
//   núcleo  > 20 min : 2 min a 85% V / 90 s recuperação  (intervalos longos)
// A sobra que não fecha um ciclo completo é dividida entre aquecimento e desaquecimento.
//
// Regras de esteira (iguais ao PWA): velocidades em km/h INTEIROS (fáceis de digitar no
// painel) e nenhum bloco com menos de 40 s (a esteira demora para trocar de velocidade).

import Toybox.Lang;
import Toybox.Math;

module Gerador {

    const CAMINHADA = 5.0;          // km/h
    const CAMINHADA_FINAL = 5.0;    // km/h
    const RITMO_MINIMO = 4.0;       // piso de qualquer bloco
    const RECUPERACAO_MIN = 6.0;    // abaixo de ~6,5 km/h ninguém trota: vira caminhada rápida
    const CAMINHADA_INICIO_SEG = 60;
    const CAMINHADA_FIM_SEG = 60;

    function minutosAquecimento(duracaoMin as Number) as Number {
        if (duracaoMin <= 10) { return 3; }
        if (duracaoMin <= 15) { return 4; }
        if (duracaoMin <= 20) { return 5; }
        if (duracaoMin <= 30) { return 6; }
        return 8;
    }

    function minutosDesaquecimento(duracaoMin as Number) as Number {
        if (duracaoMin <= 10) { return 2; }
        if (duracaoMin <= 15) { return 3; }
        if (duracaoMin <= 30) { return 4; }
        return 5;
    }

    // Percentual de V em km/h inteiro, limitado a [RITMO_MINIMO, V arredondado para baixo].
    function pctV(v as Float, pct as Float) as Float {
        var r = Math.round(v * pct).toFloat();
        var teto = Math.floor(v + 0.001).toFloat();
        if (r < RITMO_MINIMO) { return RITMO_MINIMO; }
        if (r > teto) { return teto; }
        return r;
    }

    function gerar(ritmoMax as Float, duracaoMin as Number) as Treino {
        var v = ritmoMax;
        var minAq = minutosAquecimento(duracaoMin);
        var minVc = minutosDesaquecimento(duracaoMin);
        var disp = (duracaoMin - minAq - minVc) * 60;  // segundos para o núcleo

        // Escolhe o padrão do núcleo.
        var esfSeg = 40;
        var recSeg = 40;
        var pctEsf = 0.92;
        if (disp <= 480) {
            // tiros curtos (valores iniciais acima)
        } else if (disp <= 1200) {
            esfSeg = 60; recSeg = 60; pctEsf = 0.90;
        } else {
            esfSeg = 120; recSeg = 90; pctEsf = 0.85;
        }

        // n ciclos cabem se n*esf + (n-1)*rec <= disp  =>  n = (disp + rec) / (esf + rec)
        var n = (disp + recSeg) / (esfSeg + recSeg);
        if (n < 1) { n = 1; }
        var nucleoSeg = n * esfSeg + (n - 1) * recSeg;
        var sobra = disp - nucleoSeg;
        if (sobra < 0) { sobra = 0; }

        var aqSeg = minAq * 60 + sobra / 2;
        var vcSeg = minVc * 60 + (sobra - sobra / 2);

        var kmhEsf = pctV(v, pctEsf);
        var kmhRec = pctV(v, 0.50);
        if (kmhRec < RECUPERACAO_MIN) { kmhRec = RECUPERACAO_MIN; }
        var kmhTrote = pctV(v, 0.58);
        if (kmhTrote < CAMINHADA) { kmhTrote = CAMINHADA; }
        var kmhSoltar = pctV(v, 0.50);
        if (kmhSoltar < CAMINHADA_FINAL) { kmhSoltar = CAMINHADA_FINAL; }

        var blocos = [] as Array<Intervalo>;

        // Aquecimento: 1 min caminhando + resto em trote.
        blocos.add(new Intervalo(TIPO_AQUECIMENTO, CAMINHADA, CAMINHADA_INICIO_SEG));
        blocos.add(new Intervalo(TIPO_AQUECIMENTO, kmhTrote, aqSeg - CAMINHADA_INICIO_SEG));

        // Núcleo: esforço / recuperação, sem recuperação depois do último tiro
        // (o desaquecimento já cumpre esse papel).
        for (var i = 0; i < n; i++) {
            blocos.add(new Intervalo(TIPO_ESFORCO, kmhEsf, esfSeg));
            if (i < n - 1) {
                blocos.add(new Intervalo(TIPO_RECUPERACAO, kmhRec, recSeg));
            }
        }

        // Desaquecimento: trote leve + 1 min caminhando.
        blocos.add(new Intervalo(TIPO_DESAQUECIMENTO, kmhSoltar, vcSeg - CAMINHADA_FIM_SEG));
        blocos.add(new Intervalo(TIPO_DESAQUECIMENTO, CAMINHADA_FINAL, CAMINHADA_FIM_SEG));

        return new Treino("HIIT " + duracaoMin.toString() + " min", blocos);
    }
}
