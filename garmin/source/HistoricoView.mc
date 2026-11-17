// HistoricoView.mc — lista do histórico (Menu2), detalhe de um treino e "Apagar tudo".
//
// Decisões:
// - Lista em Menu2 nativo: rolagem, toque e botões de graça. Cada item mostra a data
//   (rótulo) e um resumo (sublabel); o id do item é o índice do registro.
// - Apagar usa Confirmation. Como a Confirmation só sai da pilha depois de onResponse,
//   em vez de mexer na pilha ali reconstruímos os itens do próprio menu (fica "vazio").

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

module HistoricoMenu {

    function abrir() as Void {
        var menu = new WatchUi.Menu2({ :title => "Histórico" });
        var delegate = new HistoricoDelegate(menu);
        delegate.preencher();
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_LEFT);
    }
}

class HistoricoDelegate extends WatchUi.Menu2InputDelegate {
    private var _menu as WatchUi.Menu2;
    private var _registros as Array<RegistroTreino> = [] as Array<RegistroTreino>;
    private var _qtdItens as Number = 0;

    function initialize(menu as WatchUi.Menu2) {
        Menu2InputDelegate.initialize();
        _menu = menu;
    }

    // (Re)monta os itens a partir do Storage.
    function preencher() as Void {
        for (var k = _qtdItens - 1; k >= 0; k--) {
            _menu.deleteItem(k);
        }
        _registros = Historico.listar();
        if (_registros.size() == 0) {
            _menu.addItem(new WatchUi.MenuItem("Nenhum treino", "Termine um treino p/ ver aqui", :vazio, null));
            _qtdItens = 1;
            return;
        }
        for (var k = 0; k < _registros.size(); k++) {
            var r = _registros[k];
            _menu.addItem(new WatchUi.MenuItem(r.dataHora(), r.resumo(), k, null));
        }
        _menu.addItem(new WatchUi.MenuItem("Apagar tudo", _registros.size().toString() + " treinos", :apagar, null));
        _qtdItens = _registros.size() + 1;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            var view = new DetalheTreinoView(_registros[id as Number]);
            WatchUi.pushView(view, new DetalheTreinoDelegate(), WatchUi.SLIDE_LEFT);
        } else if (id == :apagar) {
            WatchUi.pushView(new WatchUi.Confirmation("Apagar histórico?"),
                             new ApagarHistoricoDelegate(self), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function apagarConfirmado() as Void {
        Historico.apagarTudo();
        preencher();
        WatchUi.requestUpdate();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}

class ApagarHistoricoDelegate extends WatchUi.ConfirmationDelegate {
    private var _historico as HistoricoDelegate;

    function initialize(historico as HistoricoDelegate) {
        ConfirmationDelegate.initialize();
        _historico = historico;
    }

    function onResponse(resposta as WatchUi.Confirm) as Boolean {
        if (resposta == WatchUi.CONFIRM_YES) {
            _historico.apagarConfirmado();
        }
        return true;
    }
}

// Detalhe de um treino do histórico.
class DetalheTreinoView extends WatchUi.View {
    private var _r as RegistroTreino;

    function initialize(registro as RegistroTreino) {
        View.initialize();
        _r = registro;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Tela.limpar(dc);
        var h = dc.getHeight();
        var cx = dc.getWidth() / 2;

        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.17, Graphics.FONT_SMALL, _r.dataHora(), Tela.CENTRO);

        dc.setColor(_r.concluido ? Graphics.COLOR_GREEN : Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.28, Graphics.FONT_XTINY, _r.concluido ? "Concluído" : "Interrompido", Tela.CENTRO);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.44, Graphics.FONT_NUMBER_MEDIUM, Unidades.formatarTempo(_r.feitoSeg), Tela.CENTRO);

        // Linhas abaixo do tempo; registros antigos (sem métricas) mostram plano e nome.
        var linhas = [_r.tiros.toString() + " de " + _r.tirosPlanejados.toString() + " tiros"] as Array<String>;
        var m = _r.metricas;
        if (m != null) {
            linhas.add(m.textoGasto());
            if (m.temFc()) {
                linhas.add(m.textoFc());
            }
        } else {
            linhas.add("de " + Unidades.formatarTempo(_r.planejadoSeg) + " planejados");
        }
        linhas.add("Pico " + Unidades.formatarRitmo(_r.ritmoPico, Config.unidade()));
        if (linhas.size() < 4) {
            linhas.add(_r.nome);
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        for (var k = 0; k < linhas.size(); k++) {
            Tela.textoAjustado(dc, h * (0.59 + k * 0.09), linhas[k], [Graphics.FONT_TINY, Graphics.FONT_XTINY]);
        }
    }
}

class DetalheTreinoDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onSelect() as Boolean {
        return onBack();
    }
}
