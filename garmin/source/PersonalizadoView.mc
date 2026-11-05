// PersonalizadoView.mc — menus para criar e editar treinos personalizados no relógio.
//
// Navegação:
//   Personalizados (lista)  ->  Treino (usar/editar/duplicar/apagar)
//                                  -> Itens (blocos e séries)  ->  Item (campos)  ->  AjusteView
//
// Decisões:
// - Cada menu tem um delegate com preencher(), que relê o treino do Storage e monta os
//   itens. Ao voltar, o filho chama o callback aoVoltar do pai: assim o pai sempre mostra
//   valores atualizados sem depender de onShow do Menu2.
// - MenuVivo atualiza rótulos no lugar quando a estrutura não mudou (o cursor não pula
//   para o topo) e só reconstrói quando itens entram ou saem.
// - Delegates trabalham pelo slot e relêem/gravam o Storage a cada ação: não há cópia
//   em memória que possa ficar desatualizada.

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Timer;
import Toybox.WatchUi;

// Definição de um item de menu (rótulo, sublabel, id).
class DefItem {
    public var rotulo as String;
    public var sub as String?;
    public var id as Object;

    function initialize(rotulo as String, sub as String?, id as Object) {
        self.rotulo = rotulo;
        self.sub = sub;
        self.id = id;
    }
}

// Menu2 que sabe se atualizar a partir de uma lista de DefItem.
class MenuVivo extends WatchUi.Menu2 {
    private var _ids as Array<Object> = [] as Array<Object>;

    function initialize(titulo as String) {
        Menu2.initialize({ :title => titulo });
    }

    function definir(itens as Array<DefItem>) as Void {
        var mesma = itens.size() == _ids.size();
        for (var i = 0; mesma && i < itens.size(); i++) {
            if (!itens[i].id.equals(_ids[i])) {
                mesma = false;
            }
        }
        if (mesma) {
            for (var i = 0; i < itens.size(); i++) {
                var it = getItem(i);
                if (it != null) {
                    it.setLabel(itens[i].rotulo);
                    it.setSubLabel(itens[i].sub);
                }
            }
        } else {
            for (var k = _ids.size() - 1; k >= 0; k--) {
                deleteItem(k);
            }
            _ids = [] as Array<Object>;
            for (var i = 0; i < itens.size(); i++) {
                addItem(new WatchUi.MenuItem(itens[i].rotulo, itens[i].sub, itens[i].id, null));
                _ids.add(itens[i].id);
            }
        }
        WatchUi.requestUpdate();
    }
}

// Base: guarda o menu e o callback do pai; BACK volta e avisa o pai.
class MenuBaseDelegate extends WatchUi.Menu2InputDelegate {
    protected var _menu as MenuVivo;
    protected var _aoVoltar as Method?;

    function initialize(menu as MenuVivo, aoVoltar as Method?) {
        Menu2InputDelegate.initialize();
        _menu = menu;
        _aoVoltar = aoVoltar;
    }

    function preencher() as Void {
    }

    function avisarPai() as Void {
        var m = _aoVoltar;
        if (m != null) {
            m.invoke();
        }
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        avisarPai();
    }
}

// Volta uma tela com um pequeno atraso. Necessário depois de uma Confirmation, que só
// sai da pilha após onResponse (mexer na pilha ali tiraria a view errada).
module Navegacao {
    var _timer as Timer.Timer? = null;
    var _depois as Method? = null;

    function voltarDepois(depois as Method?) as Void {
        _depois = depois;
        var t = new Timer.Timer();
        _timer = t;
        t.start(new Lang.Method(Navegacao, :executar), 100, false);
    }

    function executar() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        var d = _depois;
        _depois = null;
        if (d != null) {
            d.invoke();
        }
    }
}

module TelasPersonalizado {

    function abrirLista(aoVoltar as Method?) as Void {
        var m = new MenuVivo("Personalizados");
        var d = new PersonalizadosDelegate(m, aoVoltar);
        d.preencher();
        WatchUi.pushView(m, d, WatchUi.SLIDE_LEFT);
    }

    function abrirTreino(slot as Number, aoVoltar as Method?) as Void {
        var t = Personalizados.ler(slot);
        var m = new MenuVivo(t != null ? t.nome : "Treino");
        var d = new TreinoMenuDelegate(m, aoVoltar, slot);
        d.preencher();
        WatchUi.pushView(m, d, WatchUi.SLIDE_LEFT);
    }

    function abrirItens(slot as Number, aoVoltar as Method?) as Void {
        var m = new MenuVivo("Blocos");
        var d = new ItensMenuDelegate(m, aoVoltar, slot);
        d.preencher();
        WatchUi.pushView(m, d, WatchUi.SLIDE_LEFT);
    }

    function abrirItem(slot as Number, indice as Number, aoVoltar as Method?) as Void {
        var m = new MenuVivo("Item " + (indice + 1).toString());
        var d = new ItemMenuDelegate(m, aoVoltar, slot, indice);
        d.preencher();
        WatchUi.pushView(m, d, WatchUi.SLIDE_LEFT);
    }

    function resumo(t as TreinoPersonalizado) as String {
        var treino = t.expandir();
        return Unidades.formatarTempo(treino.duracaoTotal()) + " - " + treino.contarEsforcos().toString() + " tiros";
    }
}

// ---- Lista de treinos ----

class PersonalizadosDelegate extends MenuBaseDelegate {

    function initialize(menu as MenuVivo, aoVoltar as Method?) {
        MenuBaseDelegate.initialize(menu, aoVoltar);
    }

    function preencher() as Void {
        var itens = [] as Array<DefItem>;
        var erro = Personalizados.erroImportacao();
        if (erro != null) {
            itens.add(new DefItem("Erro no texto", erro, :erro));
        }
        var ativo = Personalizados.ativo();
        var slots = Personalizados.slots();
        for (var i = 0; i < slots.size(); i++) {
            var t = Personalizados.ler(slots[i]);
            if (t != null) {
                var sub = (slots[i] == ativo ? "Em uso - " : "") + TelasPersonalizado.resumo(t);
                itens.add(new DefItem(t.nome, sub, slots[i]));
            }
        }
        if (slots.size() < Personalizados.MAX_TREINOS) {
            itens.add(new DefItem("+ Novo treino", "Começa de um exemplo", :novo));
        }
        if (ativo >= 0) {
            itens.add(new DefItem("Usar automático", "Gerado pela duração", :auto));
        }
        _menu.definir(itens);
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            TelasPersonalizado.abrirTreino(id as Number, method(:preencher));
        } else if (id == :novo) {
            var s = Personalizados.criarExemplo();
            if (s >= 0) {
                preencher();
                TelasPersonalizado.abrirTreino(s, method(:preencher));
            }
        } else if (id == :auto) {
            Personalizados.setAtivo(-1);
            preencher();
        } else if (id == :erro) {
            var erro = Personalizados.erroImportacao();
            if (erro != null) {
                WatchUi.pushView(new MensagemView("Erro no texto", erro), new MensagemDelegate(), WatchUi.SLIDE_LEFT);
            }
        }
    }
}

// ---- Um treino ----

class TreinoMenuDelegate extends MenuBaseDelegate {
    private var _slot as Number;

    function initialize(menu as MenuVivo, aoVoltar as Method?, slot as Number) {
        MenuBaseDelegate.initialize(menu, aoVoltar);
        _slot = slot;
    }

    function preencher() as Void {
        var t = Personalizados.ler(_slot);
        if (t == null) {
            _menu.definir([new DefItem("Treino apagado", null, :nada)] as Array<DefItem>);
            return;
        }
        var emUso = Personalizados.ativo() == _slot;
        _menu.definir([
            new DefItem(emUso ? "Em uso" : "Usar este treino", TelasPersonalizado.resumo(t), :usar),
            new DefItem("Editar blocos", t.itens.size().toString() + " itens", :editar),
            new DefItem("Duplicar", null, :duplicar),
            new DefItem("Apagar", null, :apagar)
        ] as Array<DefItem>);
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :usar) {
            Personalizados.setAtivo(_slot);
            preencher();
        } else if (id == :editar) {
            TelasPersonalizado.abrirItens(_slot, method(:preencher));
        } else if (id == :duplicar) {
            var s = Personalizados.duplicar(_slot);
            preencher();
            var t = Personalizados.ler(s);
            item.setSubLabel(t != null ? "Criado: " + t.nome : "Limite de 10 treinos");
            WatchUi.requestUpdate();
        } else if (id == :apagar) {
            var t = Personalizados.ler(_slot);
            var nome = t != null ? t.nome : "treino";
            WatchUi.pushView(new WatchUi.Confirmation("Apagar " + nome + "?"),
                             new ApagarTreinoDelegate(self), WatchUi.SLIDE_IMMEDIATE);
        }
    }

    function apagarConfirmado() as Void {
        Personalizados.apagar(_slot);
        Navegacao.voltarDepois(_aoVoltar);
    }
}

class ApagarTreinoDelegate extends WatchUi.ConfirmationDelegate {
    private var _dono as TreinoMenuDelegate;

    function initialize(dono as TreinoMenuDelegate) {
        ConfirmationDelegate.initialize();
        _dono = dono;
    }

    function onResponse(resposta as WatchUi.Confirm) as Boolean {
        if (resposta == WatchUi.CONFIRM_YES) {
            _dono.apagarConfirmado();
        }
        return true;
    }
}

// ---- Lista de itens (blocos e séries) ----

class ItensMenuDelegate extends MenuBaseDelegate {
    private var _slot as Number;

    function initialize(menu as MenuVivo, aoVoltar as Method?, slot as Number) {
        MenuBaseDelegate.initialize(menu, aoVoltar);
        _slot = slot;
    }

    function preencher() as Void {
        var t = Personalizados.ler(_slot);
        if (t == null) {
            _menu.definir([new DefItem("Treino apagado", null, :nada)] as Array<DefItem>);
            return;
        }
        var unidade = Config.unidade();
        var itens = [] as Array<DefItem>;
        for (var i = 0; i < t.itens.size(); i++) {
            var it = t.itens[i];
            itens.add(new DefItem((i + 1).toString() + ". " + it.rotulo(), it.detalhe(unidade), i));
        }
        if (t.itens.size() < Personalizados.MAX_ITENS) {
            itens.add(new DefItem("+ Bloco", "Um trecho com ritmo e tempo", :addBloco));
            itens.add(new DefItem("+ Série", "Esforço + recuperação x N", :addSerie));
        }
        _menu.definir(itens);
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id instanceof Number) {
            TelasPersonalizado.abrirItem(_slot, id as Number, method(:preencher));
            return;
        }
        if (id != :addBloco && id != :addSerie) {
            return;
        }
        var t = Personalizados.ler(_slot);
        if (t == null || t.itens.size() >= Personalizados.MAX_ITENS) {
            return;
        }
        var v = Config.ritmoMax();
        var rec = Gerador.pctV(v, 0.50);
        if (rec < Gerador.RECUPERACAO_MIN) { rec = Gerador.RECUPERACAO_MIN; }
        if (id == :addBloco) {
            t.itens.add(ItemPlano.bloco(TIPO_ESFORCO, Gerador.pctV(v, 0.90), 60));
        } else {
            t.itens.add(ItemPlano.serie(4, Gerador.pctV(v, 0.90), 60, rec, 60));
        }
        Personalizados.gravar(_slot, t);
        preencher();
        // abre direto o item novo para editar
        TelasPersonalizado.abrirItem(_slot, t.itens.size() - 1, method(:preencher));
    }
}

// ---- Um item (campos) ----

class ItemMenuDelegate extends MenuBaseDelegate {
    private var _slot as Number;
    private var _indice as Number;
    private var _campo as Symbol = :nada;   // campo sendo editado na AjusteView

    function initialize(menu as MenuVivo, aoVoltar as Method?, slot as Number, indice as Number) {
        MenuBaseDelegate.initialize(menu, aoVoltar);
        _slot = slot;
        _indice = indice;
    }

    private function item(t as TreinoPersonalizado?) as ItemPlano? {
        if (t == null || _indice < 0 || _indice >= t.itens.size()) {
            return null;
        }
        return t.itens[_indice];
    }

    function preencher() as Void {
        var t = Personalizados.ler(_slot);
        var it = item(t);
        if (it == null) {
            _menu.definir([new DefItem("Item removido", null, :nada)] as Array<DefItem>);
            return;
        }
        var u = Config.unidade();
        var itens = [] as Array<DefItem>;
        if (it.ehSerie()) {
            itens.add(new DefItem("Repetições", it.reps.toString() + "x", :reps));
            itens.add(new DefItem("Esforço: ritmo", Unidades.formatarRitmo(it.kmh, u), :ritmo));
            itens.add(new DefItem("Esforço: tempo", Unidades.formatarTempo(it.seg), :tempo));
            itens.add(new DefItem("Recup.: ritmo", Unidades.formatarRitmo(it.recKmh, u), :recRitmo));
            itens.add(new DefItem("Recup.: tempo", Unidades.formatarTempo(it.recSeg), :recTempo));
        } else {
            itens.add(new DefItem("Tipo", Tela.nomeTipo(it.tipo), :tipo));
            itens.add(new DefItem("Ritmo", Unidades.formatarRitmo(it.kmh, u), :ritmo));
            itens.add(new DefItem("Tempo", Unidades.formatarTempo(it.seg), :tempo));
        }
        if (_indice > 0) {
            itens.add(new DefItem("Mover para cima", null, :subir));
        }
        if ((t as TreinoPersonalizado).itens.size() < Personalizados.MAX_ITENS) {
            itens.add(new DefItem("Duplicar", null, :duplicar));
        }
        itens.add(new DefItem("Apagar item", null, :apagar));
        _menu.definir(itens);
    }

    function onSelect(menuItem as WatchUi.MenuItem) as Void {
        var id = menuItem.getId();
        var t = Personalizados.ler(_slot);
        var it = item(t);
        if (it == null || t == null) {
            return;
        }
        if (id == :tipo) {
            it.tipo = (((it.tipo as Number) + 1) % 4) as TipoBloco;   // cicla AQ -> E -> R -> DQ
            salvarEAtualizar(t);
        } else if (id == :ritmo || id == :recRitmo) {
            var titulo = id == :ritmo ? (it.ehSerie() ? "Esforço: ritmo" : "Ritmo") : "Recup.: ritmo";
            editar(id as Symbol, titulo, AJUSTE_RITMO, id == :ritmo ? it.kmh : it.recKmh,
                   Personalizados.MIN_KMH, Personalizados.MAX_KMH, Config.RITMO_PASSO);
        } else if (id == :tempo || id == :recTempo) {
            var titulo = id == :tempo ? (it.ehSerie() ? "Esforço: tempo" : "Tempo") : "Recup.: tempo";
            editar(id as Symbol, titulo, AJUSTE_TEMPO, (id == :tempo ? it.seg : it.recSeg).toFloat(),
                   Personalizados.MIN_SEG.toFloat(), Personalizados.MAX_SEG.toFloat(), 5.0);
        } else if (id == :reps) {
            editar(:reps, "Repetições", AJUSTE_REPS, it.reps.toFloat(), 1.0, Personalizados.MAX_REPS.toFloat(), 1.0);
        } else if (id == :subir && _indice > 0) {
            var acima = t.itens[_indice - 1];
            t.itens[_indice - 1] = it;
            t.itens[_indice] = acima;
            _indice--;
            _menu.setTitle("Item " + (_indice + 1).toString());
            salvarEAtualizar(t);
        } else if (id == :duplicar) {
            var novos = [] as Array<ItemPlano>;
            for (var i = 0; i < t.itens.size(); i++) {
                novos.add(t.itens[i]);
                if (i == _indice) {
                    novos.add(it.copia());
                }
            }
            t.itens = novos;
            salvarEAtualizar(t);
        } else if (id == :apagar) {
            var restantes = [] as Array<ItemPlano>;
            for (var i = 0; i < t.itens.size(); i++) {
                if (i != _indice) {
                    restantes.add(t.itens[i]);
                }
            }
            t.itens = restantes;
            Personalizados.gravar(_slot, t);
            onBack();
        }
    }

    private function editar(campo as Symbol, titulo as String, tipo as TipoAjuste, valor as Float,
                            min as Float, max as Float, passo as Float) as Void {
        _campo = campo;
        var view = new AjusteView(titulo, tipo, valor, min, max, passo, method(:salvarCampo));
        WatchUi.pushView(view, new AjusteDelegate(view), WatchUi.SLIDE_LEFT);
    }

    // Callback da AjusteView.
    function salvarCampo(valor as Float) as Void {
        var t = Personalizados.ler(_slot);
        var it = item(t);
        if (it == null || t == null) {
            return;
        }
        if (_campo == :ritmo) {
            it.kmh = Unidades.arred1(valor);
        } else if (_campo == :recRitmo) {
            it.recKmh = Unidades.arred1(valor);
        } else if (_campo == :tempo) {
            it.seg = Math.round(valor).toNumber();
        } else if (_campo == :recTempo) {
            it.recSeg = Math.round(valor).toNumber();
        } else if (_campo == :reps) {
            it.reps = Math.round(valor).toNumber();
        }
        salvarEAtualizar(t);
    }

    private function salvarEAtualizar(t as TreinoPersonalizado) as Void {
        Personalizados.gravar(_slot, t);
        preencher();
    }
}

// ---- Mensagem de texto longo (ex.: erro do texto do celular) ----

class MensagemView extends WatchUi.View {
    private var _titulo as String;
    private var _texto as String;

    function initialize(titulo as String, texto as String) {
        View.initialize();
        _titulo = titulo;
        _texto = texto;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        Tela.limpar(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.20, Graphics.FONT_SMALL, _titulo, Tela.CENTRO);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var caixa = Graphics.fitTextToArea(_texto, Graphics.FONT_XTINY, (w * 0.72).toNumber(), (h * 0.55).toNumber(), true);
        dc.drawText(w / 2, h * 0.57, Graphics.FONT_XTINY, caixa, Tela.CENTRO);
    }
}

class MensagemDelegate extends WatchUi.BehaviorDelegate {

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
