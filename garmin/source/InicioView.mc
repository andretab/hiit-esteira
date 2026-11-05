// InicioView.mc — tela inicial: mostra o treino que será gerado e permite ajustar a duração.
//
// Controles:
//   UP / DOWN  : duração +5 / -5 min (10 a 50)
//   MENU       : ajustes (ritmo máx., duração, unidade) — segurar UP nos Forerunner
//   START      : inicia o treino
//   BACK       : sai do app

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class InicioView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Tela.limpar(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var ritmo = Config.ritmoMax();
        var duracao = Config.duracaoMin();
        var unidade = Config.unidade();
        // Gerar é barato (dezenas de blocos), então geramos a prévia a cada redesenho.
        var previa = Gerador.gerar(ritmo, duracao);

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.17, Graphics.FONT_SMALL, "HIIT Esteira", Tela.CENTRO);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.38, Graphics.FONT_NUMBER_MEDIUM, duracao.toString(), Tela.CENTRO);
        dc.drawText(cx, h * 0.53, Graphics.FONT_TINY, "min", Tela.CENTRO);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.64, Graphics.FONT_XTINY,
            "Máx " + Unidades.formatarRitmo(ritmo, unidade), Tela.CENTRO);
        dc.drawText(cx, h * 0.72, Graphics.FONT_XTINY,
            previa.contarEsforcos().toString() + " tiros a " + Unidades.formatarRitmo(previa.ritmoPico(), unidade),
            Tela.CENTRO);

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.82, Graphics.FONT_XTINY, "START p/ iniciar", Tela.CENTRO);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        Tela.textoAjustado(dc, h * 0.89, "MENU: ajustes", [Graphics.FONT_XTINY]);
    }
}

class InicioDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        var treino = Gerador.gerar(Config.ritmoMax(), Config.duracaoMin());
        var view = new TreinoView(treino);
        WatchUi.pushView(view, new TreinoDelegate(view), WatchUi.SLIDE_LEFT);
        return true;
    }

    // UP
    function onPreviousPage() as Boolean {
        Config.setDuracaoMin(Config.duracaoMin() + Config.DURACAO_PASSO);
        WatchUi.requestUpdate();
        return true;
    }

    // DOWN
    function onNextPage() as Boolean {
        Config.setDuracaoMin(Config.duracaoMin() - Config.DURACAO_PASSO);
        WatchUi.requestUpdate();
        return true;
    }

    function onMenu() as Boolean {
        Ajustes.abrir();
        return true;
    }
}
