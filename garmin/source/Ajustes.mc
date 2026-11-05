// Ajustes.mc — menu de configurações no relógio (MENU na tela inicial).
//
// Decisões:
// - Menu2 nativo para a lista (visual do sistema, funciona com botões e toque).
// - Para editar números, uma tela própria (AjusteView) em vez do Picker nativo: UP/DOWN
//   muda o valor, START salva, BACK cancela. Menos código que Picker+Factory e mais
//   rápido de usar com a mão suada.
// - A AjusteView não sabe o que está editando: recebe valor/limites/passo e devolve o
//   resultado por callback. Quem grava é o menu (via Config).

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.WatchUi;

module Ajustes {

    function abrir() as Void {
        // Menu principal: histórico no topo, ajustes abaixo.
        var menu = new WatchUi.Menu2({ :title => "HIIT Esteira" });
        menu.addItem(new WatchUi.MenuItem("Histórico", "", :historico, null));
        menu.addItem(new WatchUi.MenuItem("Ritmo máximo", "", :ritmo, null));
        menu.addItem(new WatchUi.MenuItem("Duração", "", :duracao, null));
        menu.addItem(new WatchUi.MenuItem("Unidade", "", :unidade, null));
        var delegate = new AjustesDelegate(menu);
        delegate.atualizarRotulos();
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_UP);
    }
}

class AjustesDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as WatchUi.Menu2;

    function initialize(menu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    // Mostra o valor atual de cada item como sublabel.
    function atualizarRotulos() as Void {
        var unidade = Config.unidade();
        var qtd = Historico.quantidade();
        rotular(:historico, qtd == 0 ? "Vazio" : qtd.toString() + (qtd == 1 ? " treino" : " treinos"));
        rotular(:ritmo, Unidades.formatarRitmo(Config.ritmoMax(), unidade));
        rotular(:duracao, Config.duracaoMin().toString() + " min");
        rotular(:unidade, Unidades.rotulo(unidade));
    }

    private function rotular(id as Symbol, texto as String) as Void {
        var i = _menu.findItemById(id);
        if (i >= 0) {
            var item = _menu.getItem(i);
            if (item != null) {
                item.setSubLabel(texto);
            }
        }
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :historico) {
            HistoricoMenu.abrir();
        } else if (id == :ritmo) {
            var view = new AjusteView("Ritmo máximo", AJUSTE_RITMO, Config.ritmoMax(),
                Config.RITMO_MAX_MIN, Config.RITMO_MAX_MAX, Config.RITMO_PASSO, method(:salvarRitmo));
            WatchUi.pushView(view, new AjusteDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (id == :duracao) {
            var view = new AjusteView("Duração", AJUSTE_DURACAO, Config.duracaoMin().toFloat(),
                Config.DURACAO_MIN.toFloat(), Config.DURACAO_MAX.toFloat(),
                Config.DURACAO_PASSO.toFloat(), method(:salvarDuracao));
            WatchUi.pushView(view, new AjusteDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (id == :unidade) {
            Config.alternarUnidade();
            atualizarRotulos();
            WatchUi.requestUpdate();
        }
    }

    function salvarRitmo(valor as Float) as Void {
        Config.setRitmoMax(valor);
        atualizarRotulos();
    }

    function salvarDuracao(valor as Float) as Void {
        Config.setDuracaoMin(Math.round(valor).toNumber());
        atualizarRotulos();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

// O que a AjusteView está editando (só muda a formatação do valor).
enum TipoAjuste {
    AJUSTE_RITMO = 0,
    AJUSTE_DURACAO = 1
}

// Tela genérica de ajuste numérico.
class AjusteView extends WatchUi.View {
    private var _titulo as String;
    private var _tipo as TipoAjuste;
    private var _valor as Float;
    private var _min as Float;
    private var _max as Float;
    private var _passo as Float;
    private var _aoSalvar as Method(valor as Float) as Void;

    function initialize(titulo as String, tipo as TipoAjuste, valor as Float, min as Float,
                        max as Float, passo as Float, aoSalvar as Method(valor as Float) as Void) {
        View.initialize();
        _titulo = titulo;
        _tipo = tipo;
        _valor = valor;
        _min = min;
        _max = max;
        _passo = passo;
        _aoSalvar = aoSalvar;
    }

    // direcao: +1 ou -1. Arredonda a 0,1 para não acumular erro de ponto flutuante.
    function mudar(direcao as Number) as Void {
        var v = Unidades.arred1(_valor + direcao * _passo);
        if (v < _min) { v = _min; }
        if (v > _max) { v = _max; }
        _valor = v;
        WatchUi.requestUpdate();
    }

    function salvar() as Void {
        _aoSalvar.invoke(_valor);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Tela.limpar(dc);
        var h = dc.getHeight();
        var cx = dc.getWidth() / 2;

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        Tela.textoAjustado(dc, h * 0.20, _titulo, [Graphics.FONT_SMALL, Graphics.FONT_TINY]);

        var principal;
        var unidadeTxt;
        var secundario = "";
        if (_tipo == AJUSTE_RITMO) {
            // Valor grande na unidade preferida; a outra unidade embaixo, como referência.
            var u = Config.unidade();
            var outra = u == Unidades.UNIDADE_KMH ? Unidades.UNIDADE_PACE : Unidades.UNIDADE_KMH;
            principal = Unidades.valorRitmo(_valor, u, ".");
            unidadeTxt = Unidades.rotulo(u);
            secundario = "= " + Unidades.formatarRitmo(_valor, outra);
        } else {
            principal = Math.round(_valor).toNumber().toString();
            unidadeTxt = "min";
        }

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.42, Graphics.FONT_NUMBER_MEDIUM, principal, Tela.CENTRO);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.57, Graphics.FONT_TINY, unidadeTxt, Tela.CENTRO);
        if (!secundario.equals("")) {
            dc.drawText(cx, h * 0.66, Graphics.FONT_XTINY, secundario, Tela.CENTRO);
        }

        dc.setColor(Graphics.COLOR_GREEN, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.78, Graphics.FONT_XTINY, "UP/DOWN ajusta", Tela.CENTRO);
        dc.drawText(cx, h * 0.85, Graphics.FONT_XTINY, "START salva", Tela.CENTRO);
    }
}

class AjusteDelegate extends WatchUi.BehaviorDelegate {
    private var _view as AjusteView;

    function initialize(view as AjusteView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onPreviousPage() as Boolean {  // UP
        _view.mudar(1);
        return true;
    }

    function onNextPage() as Boolean {      // DOWN
        _view.mudar(-1);
        return true;
    }

    function onSelect() as Boolean {
        _view.salvar();
        return true;
    }

    function onBack() as Boolean {          // cancela sem salvar
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
