// Modelo.mc — modelo de dados do treino.
//
// Decisões:
// - Ritmo SEMPRE em km/h (Float) internamente. min/km é só formato de exibição
//   (ver Unidades.mc). Assim gerador, motor e histórico não precisam saber a unidade.
// - Durações SEMPRE em segundos inteiros (Number).
// - Classes simples, sem lógica de UI, para poderem ser serializadas no Storage
//   (via toDict/fromDict) quando entrar o histórico e o modo personalizado.

import Toybox.Lang;

// Tipo de cada bloco. Valores fixos porque serão gravados no Storage.
enum TipoBloco {
    TIPO_AQUECIMENTO = 0,
    TIPO_ESFORCO = 1,
    TIPO_RECUPERACAO = 2,
    TIPO_DESAQUECIMENTO = 3
}

// Um bloco do treino: tipo + ritmo-alvo + duração.
class Intervalo {
    public var tipo as TipoBloco;
    public var kmh as Float;          // ritmo-alvo em km/h
    public var duracaoSeg as Number;  // duração em segundos

    function initialize(tipo as TipoBloco, kmh as Float, duracaoSeg as Number) {
        self.tipo = tipo;
        self.kmh = kmh;
        self.duracaoSeg = duracaoSeg;
    }

    // Formato compacto para o Storage (só tipos primitivos são aceitos lá).
    function toDict() as Dictionary {
        return { "t" => tipo as Number, "v" => kmh, "d" => duracaoSeg };
    }

    static function fromDict(d as Dictionary) as Intervalo {
        return new Intervalo(d["t"] as TipoBloco, (d["v"] as Numeric).toFloat(), d["d"] as Number);
    }
}

// Treino = nome + lista ordenada de intervalos.
class Treino {
    public var nome as String;
    public var intervalos as Array<Intervalo>;

    function initialize(nome as String, intervalos as Array<Intervalo>) {
        self.nome = nome;
        self.intervalos = intervalos;
    }

    // Duração total em segundos.
    function duracaoTotal() as Number {
        var total = 0;
        for (var i = 0; i < intervalos.size(); i++) {
            total += intervalos[i].duracaoSeg;
        }
        return total;
    }

    // Quantidade de blocos de esforço ("tiros").
    function contarEsforcos() as Number {
        var n = 0;
        for (var i = 0; i < intervalos.size(); i++) {
            if (intervalos[i].tipo == TIPO_ESFORCO) {
                n++;
            }
        }
        return n;
    }

    // Maior ritmo-alvo do treino (km/h).
    function ritmoPico() as Float {
        var pico = 0.0;
        for (var i = 0; i < intervalos.size(); i++) {
            if (intervalos[i].kmh > pico) {
                pico = intervalos[i].kmh;
            }
        }
        return pico;
    }
}
