// TreinoView.mc — tela durante o treino.
//
// Responsabilidades: dono do Timer, chama o MotorTreino, dispara Alertas nos eventos
// e desenha. Toda a regra de tempo/bloco fica no motor.
//
// Layout (frações da altura, pensado para telas redondas 218–454 px):
//   anel colorido na borda = cor do bloco; arco = progresso DO BLOCO
//   0.17  tipo do bloco (ex.: "ESFORÇO 3/10") ou "PAUSADO" — fonte reduz se não couber
//   0.33  ritmo-alvo (grande)
//   0.475 unidade
//   0.585 tempo restante do bloco
//   0.71  próximo bloco
//   0.78  barra = progresso TOTAL
//   0.86  tempo total decorrido / duração
//
// Controles: START pausa/retoma · UP/DOWN alterna unidade · BACK pede confirmação p/ encerrar.
//
// Gravação: o treino é gravado como atividade (Corrida > Esteira) pelo GravadorAtividade;
// cada troca de bloco vira uma volta e a pausa do app pausa a gravação.

import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

class TreinoView extends WatchUi.View {

    // 250 ms: a troca de bloco é detectada no máximo 1/4 s depois do horário certo.
    // Só redesenhamos quando o segundo exibido muda, para economizar bateria.
    const INTERVALO_TICK_MS = 250;

    private var _motor as MotorTreino;
    private var _timer as Timer.Timer;
    private var _unidade as Unidades.Unidade;
    private var _ultimoSeg as Number = -1;
    private var _confirmando as Boolean = false;
    private var _finalizada as Boolean = false;
    private var _contagemLigada as Boolean;
    private var _ultimaContagem as Number = 0;   // último número da contagem já tocado neste bloco
    private var _metricas as ColetorMetricas;
    private var _ultimoMsAmostrado as Number = 0;
    private var _gravador as GravadorAtividade;

    function initialize(treino as Treino) {
        View.initialize();
        _motor = new MotorTreino(treino);
        _metricas = new ColetorMetricas(new PerfilMetricas());
        Metricas.ligarSensorFc();
        _gravador = new GravadorAtividade();
        _unidade = Config.unidade();
        _contagemLigada = Config.contagem();   // lido uma vez: evita ler Properties 4x/s
        _timer = new Timer.Timer();
    }

    function onShow() as Void {
        _confirmando = false;  // voltando da tela de confirmação
        if (_motor.estado() == ESTADO_PRONTO) {
            _motor.iniciar();
            _gravador.iniciar(_motor.blocoAtual().kmh);
            $.treinoEmAndamento = self;
            Alertas.trocaDeBloco(_motor.blocoAtual().tipo);  // sinal de largada
            _timer.start(method(:aoTick), INTERVALO_TICK_MS, true);
        }
    }

    // Callback do Timer. Precisa ser público para method(:aoTick).
    function aoTick() as Void {
        var kmhAntes = _motor.blocoAtual().kmh;   // ritmo do trecho que acabou de passar
        var evento = _motor.atualizar();
        amostrarMetricas(kmhAntes);
        if (evento == EVENTO_FIM) {
            Alertas.fim();
            finalizar();
            return;
        }
        if (evento == EVENTO_TROCA) {
            _gravador.novaVolta(kmhAntes, _motor.blocoAtual().kmh);
            Alertas.trocaDeBloco(_motor.blocoAtual().tipo);
            _ultimaContagem = 0;
            _ultimoSeg = -1;  // força redesenho
        }
        // Contagem 3-2-1 antes da próxima troca (ou do fim).
        if (_contagemLigada && _motor.estado() == ESTADO_RODANDO) {
            var n = Alertas.numeroContagem(_motor.restanteBlocoSeg(), _ultimaContagem);
            if (n > 0) {
                _ultimaContagem = n;
                Alertas.contagem(n);
            }
        }
        var seg = _motor.decorridoSeg();
        if (seg != _ultimoSeg) {
            _ultimoSeg = seg;
            WatchUi.requestUpdate();
        }
    }

    // Integra calorias/distância/FC do tempo que passou desde a última amostra.
    // Pausado, o motor não avança: dt = 0 e nada é somado.
    private function amostrarMetricas(kmh as Float) as Void {
        var agora = _motor.decorridoMs();
        var dt = (agora - _ultimoMsAmostrado) / 1000.0;
        _ultimoMsAmostrado = agora;
        _metricas.amostrar(dt, kmh, Metricas.fcAtual());
    }

    // ---- Ações chamadas pelo delegate ----

    function alternarPausa() as Void {
        _motor.alternarPausa();
        if (_motor.estado() == ESTADO_PAUSADO) {
            _gravador.pausar();
        } else {
            _gravador.retomar();
        }
        Alertas.vibrar([new Attention.VibeProfile(50, 150)]);
        WatchUi.requestUpdate();
    }

    function alternarUnidade() as Void {
        _unidade = Config.alternarUnidade();
        WatchUi.requestUpdate();
    }

    function pedirConfirmacaoSaida() as Void {
        // O treino continua correndo durante a confirmação (a esteira não para sozinha).
        _confirmando = true;
        WatchUi.pushView(new WatchUi.Confirmation("Encerrar treino?"),
                         new ConfirmarSaidaDelegate(self), WatchUi.SLIDE_IMMEDIATE);
    }

    // Usuário confirmou. A Confirmation só sai da pilha DEPOIS de onResponse, então
    // agendamos a troca de tela com um timer curto em vez de mexer na pilha agora.
    function encerrarAgora() as Void {
        _motor.encerrar();
        _timer.stop();
        _timer.start(method(:finalizar), 100, false);
    }

    // Troca esta view pela tela de resumo (BACK no resumo volta ao início).
    function finalizar() as Void {
        if (_finalizada) { return; }
        var fim = fecharTreino();
        if (_confirmando) {
            // Treino acabou enquanto a confirmação estava aberta: tira ela antes.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        }
        var view = new FimView(_motor, fim);
        WatchUi.switchToView(view, new FimDelegate(view), WatchUi.SLIDE_UP);
    }

    // App fechado no meio do treino (ex.: sistema encerrou o app): salva o que deu.
    function finalizarAoSair() as Void {
        if (!_finalizada) {
            fecharTreino();
        }
    }

    // Para o relógio, salva a atividade (ou descarta, se curta) e grava o histórico.
    private function fecharTreino() as ResultadoFim {
        _finalizada = true;
        _timer.stop();
        _motor.encerrar();
        $.treinoEmAndamento = null;
        var salvar = _motor.decorridoSeg() >= Historico.MINIMO_SEG;
        var kcalGarmin = _gravador.caloriasGarmin();   // ler antes de encerrar a gravação
        var metricas = _metricas.resumo(kcalGarmin);
        var atividade = _gravador.encerrar(salvar, metricas.km);
        var historico = Historico.registrar(_motor, metricas);
        return new ResultadoFim(metricas, historico, atividade);
    }

    // ---- Desenho ----

    function onUpdate(dc as Graphics.Dc) as Void {
        Tela.limpar(dc);
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        var bloco = _motor.blocoAtual();
        var cor = Tela.corDoTipo(bloco.tipo);
        var pausado = _motor.estado() == ESTADO_PAUSADO;

        // Anel do bloco (só em tela redonda).
        if (Tela.telaRedonda()) {
            var espessura = w / 30;
            var raio = w / 2 - espessura / 2;
            dc.setPenWidth(espessura);
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawCircle(cx, h / 2, raio);
            var p = _motor.progressoBloco();
            if (p > 0.005) {
                dc.setColor(cor, Graphics.COLOR_TRANSPARENT);
                // começa no topo (90°) e anda no sentido horário
                dc.drawArc(cx, h / 2, raio, Graphics.ARC_CLOCKWISE, 90, 90 - (360 * p).toNumber());
            }
            dc.setPenWidth(1);
        }

        // Cabeçalho: tipo do bloco (+ nº do tiro) ou PAUSADO.
        var titulo;
        if (pausado) {
            titulo = "PAUSADO";
            dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        } else {
            titulo = Tela.nomeDoTipo(bloco.tipo);
            var n = _motor.numeroEsforco();
            if (n > 0) {
                titulo += " " + n.toString() + "/" + _motor.treino().contarEsforcos().toString();
            }
            dc.setColor(cor, Graphics.COLOR_TRANSPARENT);
        }
        Tela.textoAjustado(dc, h * 0.17, titulo,
            [Graphics.FONT_SMALL, Graphics.FONT_TINY, Graphics.FONT_XTINY]);

        // Ritmo-alvo: o dado mais importante, em fonte numérica grande.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.33, Graphics.FONT_NUMBER_HOT,
            Unidades.valorRitmo(bloco.kmh, _unidade, "."), Tela.CENTRO);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.475, Graphics.FONT_XTINY, Unidades.rotulo(_unidade), Tela.CENTRO);

        // Tempo restante do bloco. Nos últimos segundos (contagem), tempo e "Próx:" ganham
        // a cor do PRÓXIMO bloco: dá para saber o que vem sem ler o texto.
        var restante = _motor.restanteBlocoSeg();
        var prox = _motor.proximoBloco();
        var emContagem = _contagemLigada && !pausado && restante <= Alertas.CONTAGEM_SEG;
        var corProx = prox != null ? Tela.corDoTipo((prox as Intervalo).tipo) : Graphics.COLOR_YELLOW;
        var corTempo = Graphics.COLOR_WHITE;
        if (pausado) {
            corTempo = Graphics.COLOR_YELLOW;
        } else if (emContagem) {
            corTempo = corProx;
        }
        dc.setColor(corTempo, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.585, Graphics.FONT_NUMBER_MILD, Unidades.formatarTempo(restante), Tela.CENTRO);

        // Próximo bloco.
        dc.setColor(emContagem ? corProx : Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var textoProx = "Último bloco";
        if (prox != null) {
            var b = prox as Intervalo;
            textoProx = "Próx: " + Tela.abrevTipo(b.tipo) + " " + Unidades.valorRitmo(b.kmh, _unidade, ",");
        }
        Tela.textoAjustado(dc, h * 0.71, textoProx, [Graphics.FONT_XTINY]);

        // Progresso total.
        Tela.barra(dc, h * 0.78, (w * 0.55).toNumber(), h / 50 + 2, _motor.progresso(), Graphics.COLOR_ORANGE);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.86, Graphics.FONT_XTINY,
            Unidades.formatarTempo(_motor.decorridoSeg()) + " / " + Unidades.formatarTempo(_motor.totalSeg()),
            Tela.CENTRO);
    }
}

class TreinoDelegate extends WatchUi.BehaviorDelegate {
    private var _view as TreinoView;

    function initialize(view as TreinoView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onSelect() as Boolean {
        _view.alternarPausa();
        return true;
    }

    function onBack() as Boolean {
        _view.pedirConfirmacaoSaida();
        return true;
    }

    function onNextPage() as Boolean {
        _view.alternarUnidade();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.alternarUnidade();
        return true;
    }
}

class ConfirmarSaidaDelegate extends WatchUi.ConfirmationDelegate {
    private var _view as TreinoView;

    function initialize(view as TreinoView) {
        ConfirmationDelegate.initialize();
        _view = view;
    }

    function onResponse(resposta as WatchUi.Confirm) as Boolean {
        if (resposta == WatchUi.CONFIRM_YES) {
            _view.encerrarAgora();
        }
        return true;
    }
}
