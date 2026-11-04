// MotorTreino.mc — máquina de estados do treino (sem UI, sem Timer, sem Attention).
//
// Decisões:
// - O motor não tem Timer próprio: a View chama atualizar() periodicamente. Isso deixa
//   o motor testável e independente de tela.
// - O tempo vem de System.getTimer() (ms desde o boot) e é ACUMULADO por diferença,
//   em vez de contar "ticks". Ticks de Timer atrasam e se acumulam; diferenças de
//   relógio não. Pausa = simplesmente parar de acumular.
// - O bloco atual é DERIVADO do tempo decorrido (busca nos fins acumulados), então
//   nunca "perde" uma troca mesmo se um tick atrasar.
// - atualizar() devolve um evento (troca/fim); quem decide vibrar/apitar é a View.

import Toybox.Lang;
import Toybox.System;

enum EstadoTreino {
    ESTADO_PRONTO = 0,
    ESTADO_RODANDO = 1,
    ESTADO_PAUSADO = 2,
    ESTADO_FINALIZADO = 3
}

enum EventoTreino {
    EVENTO_NENHUM = 0,
    EVENTO_TROCA = 1,
    EVENTO_FIM = 2
}

class MotorTreino {
    private var _treino as Treino;
    private var _finsMs as Array<Number>;  // fim acumulado de cada bloco, em ms
    private var _totalMs as Number;
    private var _decorridoMs as Number = 0;
    private var _ultimoTimer as Number = 0;
    private var _indice as Number = 0;
    private var _estado as EstadoTreino = ESTADO_PRONTO;
    private var _concluido as Boolean = false;  // true só se chegou ao fim (não interrompido)

    function initialize(treino as Treino) {
        _treino = treino;
        _finsMs = [] as Array<Number>;
        var acc = 0;
        for (var i = 0; i < treino.intervalos.size(); i++) {
            acc += treino.intervalos[i].duracaoSeg * 1000;
            _finsMs.add(acc);
        }
        _totalMs = acc;
    }

    // ---- Controle ----

    function iniciar() as Void {
        if (_estado == ESTADO_PRONTO) {
            _ultimoTimer = System.getTimer();
            _estado = ESTADO_RODANDO;
        }
    }

    function alternarPausa() as Void {
        if (_estado == ESTADO_RODANDO) {
            acumular();
            _estado = ESTADO_PAUSADO;
        } else if (_estado == ESTADO_PAUSADO) {
            _ultimoTimer = System.getTimer();  // descarta o tempo parado
            _estado = ESTADO_RODANDO;
        }
    }

    // Interrompe o treino antes do fim.
    function encerrar() as Void {
        if (_estado == ESTADO_RODANDO) {
            acumular();
        }
        _estado = ESTADO_FINALIZADO;
    }

    // Avança o relógio e informa se houve troca de bloco ou fim.
    function atualizar() as EventoTreino {
        if (_estado != ESTADO_RODANDO) {
            return EVENTO_NENHUM;
        }
        acumular();

        if (_decorridoMs >= _totalMs) {
            _decorridoMs = _totalMs;
            _indice = _finsMs.size() - 1;
            _estado = ESTADO_FINALIZADO;
            _concluido = true;
            return EVENTO_FIM;
        }

        var novo = _indice;
        while (novo < _finsMs.size() - 1 && _decorridoMs >= _finsMs[novo]) {
            novo++;
        }
        if (novo != _indice) {
            _indice = novo;
            return EVENTO_TROCA;
        }
        return EVENTO_NENHUM;
    }

    private function acumular() as Void {
        var agora = System.getTimer();
        _decorridoMs += (agora - _ultimoTimer) * Config.FATOR_VELOCIDADE;
        _ultimoTimer = agora;
    }

    // ---- Consultas (para a View) ----

    function estado() as EstadoTreino { return _estado; }
    function concluido() as Boolean { return _concluido; }
    function treino() as Treino { return _treino; }
    function indice() as Number { return _indice; }
    function totalBlocos() as Number { return _finsMs.size(); }

    function blocoAtual() as Intervalo {
        return _treino.intervalos[_indice];
    }

    function proximoBloco() as Intervalo? {
        if (_indice + 1 < _treino.intervalos.size()) {
            return _treino.intervalos[_indice + 1];
        }
        return null;
    }

    // Segundos restantes no bloco (arredondado para cima: mostra "1" até o último instante).
    function restanteBlocoSeg() as Number {
        var resta = _finsMs[_indice] - _decorridoMs;
        if (resta < 0) { resta = 0; }
        return (resta + 999) / 1000;
    }

    function decorridoSeg() as Number { return _decorridoMs / 1000; }
    function totalSeg() as Number { return _totalMs / 1000; }

    // Progresso total 0.0 .. 1.0
    function progresso() as Float {
        if (_totalMs <= 0) { return 0.0; }
        return _decorridoMs.toFloat() / _totalMs.toFloat();
    }

    // Progresso dentro do bloco atual 0.0 .. 1.0
    function progressoBloco() as Float {
        var dur = blocoAtual().duracaoSeg * 1000;
        if (dur <= 0) { return 1.0; }
        var inicio = _finsMs[_indice] - dur;
        var p = (_decorridoMs - inicio).toFloat() / dur.toFloat();
        if (p < 0.0) { return 0.0; }
        if (p > 1.0) { return 1.0; }
        return p;
    }

    // Quantos tiros foram completados (útil no resumo de treino interrompido).
    function esforcosConcluidos() as Number {
        var n = 0;
        for (var i = 0; i < _finsMs.size(); i++) {
            if (_treino.intervalos[i].tipo == TIPO_ESFORCO && _finsMs[i] <= _decorridoMs) {
                n++;
            }
        }
        return n;
    }

    // Número do tiro atual entre os esforços (1-based); 0 se o bloco não é esforço.
    function numeroEsforco() as Number {
        if (blocoAtual().tipo != TIPO_ESFORCO) { return 0; }
        var n = 0;
        for (var i = 0; i <= _indice; i++) {
            if (_treino.intervalos[i].tipo == TIPO_ESFORCO) { n++; }
        }
        return n;
    }
}
