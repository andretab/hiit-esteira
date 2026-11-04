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
// - Os tons respeitam a configuração "Tons de alerta" do próprio relógio.

import Toybox.Attention;
import Toybox.Lang;

module Alertas {

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
