// FimView.mc — resumo ao terminar (ou interromper) o treino.
// Na próxima iteração é aqui que o treino será gravado no histórico (Storage).

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class FimView extends WatchUi.View {
    private var _motor as MotorTreino;

    function initialize(motor as MotorTreino) {
        View.initialize();
        _motor = motor;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Tela.limpar(dc);
        var h = dc.getHeight();
        var cx = dc.getWidth() / 2;
        var concluido = _motor.concluido();

        dc.setColor(concluido ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.22, Graphics.FONT_SMALL, concluido ? "Concluído!" : "Interrompido", Tela.CENTRO);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.43, Graphics.FONT_NUMBER_MEDIUM,
            Unidades.formatarTempo(_motor.decorridoSeg()), Tela.CENTRO);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var tiros = _motor.esforcosConcluidos().toString() + " de " + _motor.treino().contarEsforcos().toString() + " tiros";
        dc.drawText(cx, h * 0.60, Graphics.FONT_TINY, tiros, Tela.CENTRO);
        dc.drawText(cx, h * 0.70, Graphics.FONT_XTINY, _motor.treino().nome, Tela.CENTRO);

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.84, Graphics.FONT_XTINY, "BACK p/ voltar", Tela.CENTRO);
    }
}

class FimDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        return onBack();
    }
}
