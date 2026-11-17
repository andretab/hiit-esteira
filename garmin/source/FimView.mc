// FimView.mc — resumo ao terminar (ou interromper) o treino.
// O treino já foi gravado (atividade + histórico) pela TreinoView; aqui só mostramos.
//
// Página 1: tempo, tiros, kcal/km, FC média/máxima e onde foi salvo.
// Página 2 (DOWN): tempo em cada zona de FC. UP/DOWN alternam; BACK/START voltam ao início.

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// O que a TreinoView entrega ao fechar o treino.
class ResultadoFim {
    public var metricas as ResumoMetricas;
    public var noHistorico as Boolean;
    public var atividadeSalva as Boolean;

    function initialize(metricas as ResumoMetricas, noHistorico as Boolean, atividadeSalva as Boolean) {
        self.metricas = metricas;
        self.noHistorico = noHistorico;
        self.atividadeSalva = atividadeSalva;
    }
}

class FimView extends WatchUi.View {
    private var _motor as MotorTreino;
    private var _fim as ResultadoFim;
    private var _pagina as Number = 0;

    function initialize(motor as MotorTreino, fim as ResultadoFim) {
        View.initialize();
        _motor = motor;
        _fim = fim;
    }

    function trocarPagina() as Void {
        _pagina = 1 - _pagina;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Tela.limpar(dc);
        if (_pagina == 0) {
            desenharResumo(dc);
        } else {
            desenharZonas(dc);
        }
    }

    private function desenharResumo(dc as Graphics.Dc) as Void {
        var h = dc.getHeight();
        var cx = dc.getWidth() / 2;
        var m = _fim.metricas;
        var concluido = _motor.concluido();

        dc.setColor(concluido ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.17, Graphics.FONT_SMALL, concluido ? "Concluído!" : "Interrompido", Tela.CENTRO);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.34, Graphics.FONT_NUMBER_MEDIUM,
            Unidades.formatarTempo(_motor.decorridoSeg()), Tela.CENTRO);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var tiros = _motor.esforcosConcluidos().toString() + " de " + _motor.treino().contarEsforcos().toString() + " tiros";
        Tela.textoAjustado(dc, h * 0.50, tiros, [Graphics.FONT_TINY, Graphics.FONT_XTINY]);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        Tela.textoAjustado(dc, h * 0.60, m.textoGasto(), [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        if (m.temFc()) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            Tela.textoAjustado(dc, h * 0.69, m.textoFc(), [Graphics.FONT_XTINY]);
        }

        var aviso;
        if (_fim.atividadeSalva) {
            aviso = "Atividade salva";
        } else if (_fim.noHistorico) {
            aviso = "Salvo só no histórico";
        } else {
            aviso = "Curto demais p/ salvar";
        }
        dc.setColor(_fim.atividadeSalva ? Graphics.COLOR_GREEN : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        Tela.textoAjustado(dc, h * 0.78, aviso, [Graphics.FONT_XTINY]);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.88, Graphics.FONT_XTINY, "DOWN: zonas", Tela.CENTRO);
    }

    // Barras horizontais Z1..Z5, proporcionais à zona com mais tempo.
    private function desenharZonas(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var m = _fim.metricas;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.15, Graphics.FONT_SMALL, "Zonas de FC", Tela.CENTRO);

        if (!m.temFc()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.5, Graphics.FONT_TINY, "Sem dados de FC", Tela.CENTRO);
            return;
        }

        var cores = [Graphics.COLOR_LT_GRAY, Graphics.COLOR_BLUE, Graphics.COLOR_GREEN,
                     Graphics.COLOR_ORANGE, Graphics.COLOR_RED] as Array<Graphics.ColorType>;
        var maior = 1;
        for (var z = 0; z < 5; z++) {
            if (m.zonasSeg[z] > maior) { maior = m.zonasSeg[z]; }
        }
        var xRotulo = (w * 0.20).toNumber();
        var xBarra = (w * 0.29).toNumber();
        var larguraMax = (w * 0.38).toNumber();
        var xTempo = (w * 0.80).toNumber();
        var altura = h / 22 + 2;
        for (var z = 0; z < 5; z++) {
            var y = (h * (0.30 + z * 0.13)).toNumber();
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xRotulo, y, Graphics.FONT_XTINY, "Z" + (z + 1).toString(),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            var largura = (larguraMax * m.zonasSeg[z] / maior).toNumber();
            if (largura < 2) { largura = 2; }
            dc.setColor(cores[z], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(xBarra, y - altura / 2, largura, altura);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(xTempo, y, Graphics.FONT_XTINY, Unidades.formatarTempo(m.zonasSeg[z]),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}

class FimDelegate extends WatchUi.BehaviorDelegate {
    private var _view as FimView;

    function initialize(view as FimView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        return true;
    }

    function onSelect() as Boolean {
        return onBack();
    }

    function onNextPage() as Boolean {
        _view.trocarPagina();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.trocarPagina();
        return true;
    }
}
