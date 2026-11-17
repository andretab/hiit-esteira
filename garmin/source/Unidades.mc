// Unidades.mc — conversão e formatação de ritmo e tempo (somente exibição).
//
// Ritmo interno é sempre km/h. Aqui convertemos para texto em km/h ou min/km.
// Observação: as fontes numéricas grandes do Garmin (FONT_NUMBER_*) só garantem
// dígitos, ":" , "." e "-". Por isso há um parâmetro de separador decimal:
// "." nas fontes numéricas, "," nos textos comuns (padrão brasileiro).

import Toybox.Lang;
import Toybox.Math;

module Unidades {

    enum Unidade {
        UNIDADE_KMH = 0,
        UNIDADE_PACE = 1
    }

    // Arredonda para 0,1 km/h (incremento das esteiras).
    function arred1(x as Float) as Float {
        return (Math.round(x * 10.0) / 10.0).toFloat();
    }

    // km/h -> segundos por km (min/km = 60 / km/h).
    function kmhParaSegPorKm(kmh as Float) as Number {
        if (kmh <= 0.0) {
            return 0;
        }
        return Math.round(3600.0 / kmh).toNumber();
    }

    // Só o valor, sem unidade: "14", "14.3" / "14,3" ou "4:17".
    // Valores inteiros saem sem casa decimal (o gerador usa km/h inteiros).
    function valorRitmo(kmh as Float, unidade as Unidade, separador as String) as String {
        if (unidade == UNIDADE_PACE) {
            var s = kmhParaSegPorKm(kmh);
            if (s <= 0) {
                return "--:--";
            }
            return (s / 60).toString() + ":" + (s % 60).format("%02d");
        }
        var d = Math.round(kmh * 10.0).toNumber();
        if (d % 10 == 0) {
            return (d / 10).toString();
        }
        return (d / 10).toString() + separador + (d % 10).toString();
    }

    // Rótulo da unidade.
    function rotulo(unidade as Unidade) as String {
        return unidade == UNIDADE_PACE ? "min/km" : "km/h";
    }

    // Valor + unidade, para textos comuns: "14,0 km/h" ou "4:17 min/km".
    function formatarRitmo(kmh as Float, unidade as Unidade) as String {
        return valorRitmo(kmh, unidade, ",") + " " + rotulo(unidade);
    }

    // Segundos -> "m:ss" (ou "h:mm:ss" a partir de 1 hora).
    function formatarTempo(segundos as Number) as String {
        if (segundos < 0) {
            segundos = 0;
        }
        var h = segundos / 3600;
        var m = (segundos % 3600) / 60;
        var s = segundos % 60;
        if (h > 0) {
            return h.toString() + ":" + m.format("%02d") + ":" + s.format("%02d");
        }
        return m.toString() + ":" + s.format("%02d");
    }
}
