// Config.mc — preferências do usuário, persistidas no Application.Storage.
//
// Decisão: toda leitura/escrita de preferência passa por aqui. Na próxima iteração
// (settings), só este módulo muda — o resto do app continua chamando Config.ritmoMax() etc.

import Toybox.Application;
import Toybox.Lang;

module Config {

    const RITMO_MAX_PADRAO = 14.0;  // km/h
    const RITMO_MAX_MIN = 8.0;
    const RITMO_MAX_MAX = 25.0;

    const DURACAO_PADRAO = 30;      // minutos
    const DURACAO_MIN = 10;
    const DURACAO_MAX = 50;
    const DURACAO_PASSO = 5;

    // Acelera o relógio do treino (1 = tempo real). Use 10 ou 30 no simulador
    // para ver as trocas de bloco sem esperar o treino inteiro. VOLTE PARA 1 no relógio!
    const FATOR_VELOCIDADE = 1;

    const CHAVE_RITMO = "ritmoMax";
    const CHAVE_DURACAO = "duracaoMin";
    const CHAVE_UNIDADE = "unidade";

    // Lê um número do Storage com valor padrão (o Storage pode ter lixo de versões antigas).
    function lerNumero(chave as String, padrao as Numeric) as Numeric {
        var v = Storage.getValue(chave);
        if (v instanceof Number || v instanceof Float || v instanceof Double) {
            return v as Numeric;
        }
        return padrao;
    }

    function ritmoMax() as Float {
        var v = lerNumero(CHAVE_RITMO, RITMO_MAX_PADRAO).toFloat();
        if (v < RITMO_MAX_MIN || v > RITMO_MAX_MAX) {
            return RITMO_MAX_PADRAO;
        }
        return v;
    }

    function setRitmoMax(kmh as Float) as Void {
        Storage.setValue(CHAVE_RITMO, kmh);
    }

    function duracaoMin() as Number {
        var v = lerNumero(CHAVE_DURACAO, DURACAO_PADRAO).toNumber();
        if (v < DURACAO_MIN || v > DURACAO_MAX) {
            return DURACAO_PADRAO;
        }
        return v;
    }

    function setDuracaoMin(min as Number) as Void {
        if (min < DURACAO_MIN) {
            min = DURACAO_MIN;
        } else if (min > DURACAO_MAX) {
            min = DURACAO_MAX;
        }
        Storage.setValue(CHAVE_DURACAO, min);
    }

    function unidade() as Unidades.Unidade {
        var v = lerNumero(CHAVE_UNIDADE, Unidades.UNIDADE_KMH as Number).toNumber();
        return v == 1 ? Unidades.UNIDADE_PACE : Unidades.UNIDADE_KMH;
    }

    function alternarUnidade() as Unidades.Unidade {
        var nova = unidade() == Unidades.UNIDADE_KMH ? Unidades.UNIDADE_PACE : Unidades.UNIDADE_KMH;
        Storage.setValue(CHAVE_UNIDADE, nova as Number);
        return nova;
    }
}
