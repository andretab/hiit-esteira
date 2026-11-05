// Alertas.mc — vibração, tom e luz nas trocas de bloco.
//
// Decisões:
// - Sempre testamos "Attention has :x": nem todo device tem alto-falante/buzzer
//   (ex.: Venu sem tons) e o app não pode quebrar por isso.
// - Padrões diferentes por tipo, para sentir a troca sem olhar o relógio:
//     esforço     -> 2 pulsos longos + tom agudo (ALERT_HI)
//     recuperação -> 1 pulso longo + tom grave (ALERT_LO)
//     outros      -> 1 pulso médio + tom de intervalo
//     fim         -> 3 pulsos + tom de sucesso
//     contagem    -> nos 3 s finais de cada bloco: bipe curto + vibração leve (o "1" mais agudo)
// - Os tons respeitam a configuração "Tons de alerta" do próprio relógio.

import Toybox.Attention;
import Toybox.Lang;

module Alertas {

    const CONTAGEM_SEG = 3;   // bipes em 3, 2 e 1 antes de cada troca

    // Lógica pura da contagem (testável): dado o tempo restante do bloco (arredondado
    // para cima) e o último número já anunciado neste bloco, devolve o número a anunciar
    // agora, ou 0 se nada. Nunca repete (ex.: pausa/retomada no meio) e, se um tick
    // atrasar e pular um segundo, anuncia o atual em vez do perdido.
    function numeroContagem(restanteSeg as Number, ultimoAnunciado as Number) as Number {
        if (restanteSeg < 1 || restanteSeg > CONTAGEM_SEG) {
            return 0;
        }
        if (ultimoAnunciado != 0 && restanteSeg >= ultimoAnunciado) {
            return 0;
        }
        return restanteSeg;
    }

    function trocaDeBloco(tipo as TipoBloco) as Void {
        if (tipo == TIPO_ESFORCO) {
            vibrar([new Attention.VibeProfile(100, 400), new Attention.VibeProfile(0, 150), new Attention.VibeProfile(100, 400)]);
            tocar(Attention.TONE_ALERT_HI);
        } else if (tipo == TIPO_RECUPERACAO) {
            vibrar([new Attention.VibeProfile(100, 600)]);
            tocar(Attention.TONE_ALERT_LO);
        } else {
            vibrar([new Attention.VibeProfile(70, 400)]);
            tocar(Attention.TONE_INTERVAL_ALERT);
        }
        acenderLuz();
    }

    // Contagem regressiva antes da troca: bipe curto + vibração leve.
    // O "1" é mais agudo, para o corpo antecipar a troca que vem no "0".
    function contagem(n as Number) as Void {
        vibrar([new Attention.VibeProfile(60, 120)]);
        if (Attention has :ToneProfile) {
            var freq = n == 1 ? 1320 : 880;
            if (Attention has :playTone) {
                Attention.playTone({ :toneProfile => [new Attention.ToneProfile(freq, 120)] });
            }
        } else {
            tocar(Attention.TONE_KEY);
        }
    }

    function fim() as Void {
        vibrar([
            new Attention.VibeProfile(100, 300), new Attention.VibeProfile(0, 150),
            new Attention.VibeProfile(100, 300), new Attention.VibeProfile(0, 150),
            new Attention.VibeProfile(100, 600)
        ]);
        tocar(Attention.TONE_SUCCESS);
        acenderLuz();
    }

    function vibrar(padrao as Array<Attention.VibeProfile>) as Void {
        if (Attention has :vibrate) {
            Attention.vibrate(padrao);
        }
    }

    function tocar(tom as Attention.Tone) as Void {
        if (Attention has :playTone) {
            Attention.playTone(tom);
        }
    }

    // Em telas AMOLED, ligar a luz com frequência pode lançar exceção
    // (proteção contra burn-in). Não é crítico, então ignoramos o erro.
    function acenderLuz() as Void {
        if (Attention has :backlight) {
            try {
                Attention.backlight(true);
            } catch (e) {
                // sem luz, sem problema
            }
        }
    }
}
