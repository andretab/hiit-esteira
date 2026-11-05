// InicioView.mc — tela inicial: mostra o treino que será executado.
//
// Dois modos:
//   - Automático: treino gerado pela duração e pelo ritmo máximo. UP/DOWN muda a duração.
//   - Personalizado: o treino escolhido em MENU > Treinos personalizados. UP/DOWN não faz
//     nada (a duração é a soma dos blocos); para voltar ao automático, use o menu.
//
// Controles:
//   UP / DOWN  : duração +1 / -1 min (só no automático)
//   MENU       : histórico, treinos e ajustes — segurar UP nos Forerunner
//   START      : inicia o treino
//   BACK       : sai do app

import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

class InicioView extends WatchUi.View {

    function initialize() {
        View.initialize();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Tela.limpar(dc);
        var h = dc.getHeight();
        var unidade = Config.unidade();

        var pers = Personalizados.ler(Personalizados.ativo());
        if (pers != null) {
            desenharPersonalizado(dc, pers, unidade);
        } else {
            desenharAutomatico(dc, unidade);
        }

        var cx = dc.getWidth() / 2;
        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.82, Graphics.FONT_XTINY, "START p/ iniciar", Tela.CENTRO);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        Tela.textoAjustado(dc, h * 0.89, "MENU: opções", [Graphics.FONT_XTINY]);
    }

    private function desenharAutomatico(dc as Graphics.Dc, unidade as Unidades.Unidade) as Void {
        var h = dc.getHeight();
        var cx = dc.getWidth() / 2;
        var ritmo = Config.ritmoMax();
        var duracao = Config.duracaoMin();
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
    }

    private function desenharPersonalizado(dc as Graphics.Dc, pers as TreinoPersonalizado,
                                           unidade as Unidades.Unidade) as Void {
        var h = dc.getHeight();
        var cx = dc.getWidth() / 2;
        var treino = pers.expandir();

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        Tela.textoAjustado(dc, h * 0.17, pers.nome, [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);

        if (treino.intervalos.size() == 0) {
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.45, Graphics.FONT_SMALL, "Treino vazio", Tela.CENTRO);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.60, Graphics.FONT_XTINY, "Adicione blocos no menu", Tela.CENTRO);
            return;
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.38, Graphics.FONT_NUMBER_MEDIUM, Unidades.formatarTempo(treino.duracaoTotal()), Tela.CENTRO);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.53, Graphics.FONT_TINY, "personalizado", Tela.CENTRO);
        dc.drawText(cx, h * 0.64, Graphics.FONT_XTINY,
            treino.intervalos.size().toString() + " blocos", Tela.CENTRO);
        Tela.textoAjustado(dc, h * 0.72,
            treino.contarEsforcos().toString() + " tiros, pico " + Unidades.formatarRitmo(treino.ritmoPico(), unidade),
            [Graphics.FONT_XTINY]);
    }
}

class InicioDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onSelect() as Boolean {
        var treino = Personalizados.treinoParaIniciar();
        if (treino == null) {
            // personalizado vazio: avisa com uma vibração curta em vez de iniciar
            Alertas.vibrar([new Attention.VibeProfile(50, 200)]);
            return true;
        }
        var view = new TreinoView(treino);
        WatchUi.pushView(view, new TreinoDelegate(view), WatchUi.SLIDE_LEFT);
        return true;
    }

    // UP
    function onPreviousPage() as Boolean {
        return mudarDuracao(Config.DURACAO_PASSO);
    }

    // DOWN
    function onNextPage() as Boolean {
        return mudarDuracao(-Config.DURACAO_PASSO);
    }

    private function mudarDuracao(delta as Number) as Boolean {
        if (Personalizados.ativo() < 0) {
            Config.setDuracaoMin(Config.duracaoMin() + delta);
            WatchUi.requestUpdate();
        }
        return true;
    }

    function onMenu() as Boolean {
        Ajustes.abrir();
        return true;
    }
}
