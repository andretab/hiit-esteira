// Config.mc — preferências do usuário (ritmo máximo, duração, unidade).
//
// Decisões:
// - Guardadas em Application.Properties (declaradas em resources/settings/properties.xml),
//   não no Storage: só Properties aparecem no app Garmin Connect para edição pelo celular.
//   O menu de ajustes do relógio grava nas mesmas Properties: uma única fonte de verdade.
// - O Storage fica reservado para DADOS (histórico de treinos).
// - Toda leitura valida faixa e tipo: o valor pode vir do celular, de uma versão antiga
//   do app, ou faltar. Nunca deixamos um valor ruim chegar ao gerador.

import Toybox.Application;
import Toybox.Lang;

module Config {

    const RITMO_MAX_PADRAO = 14.0;  // km/h
    const RITMO_MAX_MIN = 8.0;
    const RITMO_MAX_MAX = 25.0;
    const RITMO_PASSO = 1.0;        // UP/DOWN no ajuste do relógio: ±1 km/h (pedido do usuário)

    const DURACAO_PADRAO = 30;      // minutos
    const DURACAO_MIN = 10;
    const DURACAO_MAX = 50;
    const DURACAO_PASSO = 5;

    // Acelera o relógio do treino (1 = tempo real). Use 30 no simulador para ver as
    // trocas de bloco sem esperar o treino inteiro. VOLTE PARA 1 antes de instalar!
    const FATOR_VELOCIDADE = 1;

    const CHAVE_RITMO = "ritmoMax";
    const CHAVE_DURACAO = "duracaoMin";
    const CHAVE_UNIDADE = "unidade";

    // Lê um número das Properties, com valor padrão se faltar ou tiver tipo errado.
    function lerNumero(chave as String, padrao as Numeric) as Numeric {
        var v = null;
        try {
            v = Properties.getValue(chave);
        } catch (e) {
            // chave inexistente (ex.: properties.xml antigo): usa o padrão
        }
        if (v instanceof Number || v instanceof Float || v instanceof Double) {
            return v as Numeric;
        }
        return padrao;
    }

    // ---- Ritmo máximo ----

    function ritmoMax() as Float {
        var v = Unidades.arred1(lerNumero(CHAVE_RITMO, RITMO_MAX_PADRAO).toFloat());
        if (v < RITMO_MAX_MIN || v > RITMO_MAX_MAX) {
            return RITMO_MAX_PADRAO;
        }
        return v;
    }

    function limitarRitmo(kmh as Float) as Float {
        if (kmh < RITMO_MAX_MIN) { return RITMO_MAX_MIN; }
        if (kmh > RITMO_MAX_MAX) { return RITMO_MAX_MAX; }
        return Unidades.arred1(kmh);
    }

    function setRitmoMax(kmh as Float) as Void {
        Properties.setValue(CHAVE_RITMO, limitarRitmo(kmh));
    }

    // ---- Duração ----

    // Arredonda para o múltiplo de 5 mais próximo e limita a 10..50.
    function limitarDuracao(min as Number) as Number {
        min = ((min + DURACAO_PASSO / 2) / DURACAO_PASSO) * DURACAO_PASSO;
        if (min < DURACAO_MIN) { return DURACAO_MIN; }
        if (min > DURACAO_MAX) { return DURACAO_MAX; }
        return min;
    }

    function duracaoMin() as Number {
        return limitarDuracao(lerNumero(CHAVE_DURACAO, DURACAO_PADRAO).toNumber());
    }

    function setDuracaoMin(min as Number) as Void {
        Properties.setValue(CHAVE_DURACAO, limitarDuracao(min));
    }

    // ---- Unidade ----

    function unidade() as Unidades.Unidade {
        var v = lerNumero(CHAVE_UNIDADE, Unidades.UNIDADE_KMH as Number).toNumber();
        return v == 1 ? Unidades.UNIDADE_PACE : Unidades.UNIDADE_KMH;
    }

    function alternarUnidade() as Unidades.Unidade {
        var nova = unidade() == Unidades.UNIDADE_KMH ? Unidades.UNIDADE_PACE : Unidades.UNIDADE_KMH;
        Properties.setValue(CHAVE_UNIDADE, nova as Number);
        return nova;
    }
}
