// Gravacao.mc — grava o treino como atividade do relógio (Corrida > Esteira).
//
// A atividade aparece no Garmin Connect como qualquer corrida na esteira: FC, calorias e
// carga de treino calculadas pela própria Garmin, mais o que este app acrescenta:
// - Cada troca de bloco é uma VOLTA (addLap): no Connect, a aba Voltas mostra bloco a bloco.
// - Campos FIT extras (fitContributions em resources/fit):
//     0 velocidade-alvo a cada segundo   -> gráfico "Velocidade-alvo"
//     1 velocidade-alvo de cada volta    -> coluna na aba Voltas
//     2 distância pelo ritmo-alvo        -> resumo da atividade
//   Na esteira o relógio estima a distância pelo pulso (costuma errar); a distância
//   pelo ritmo-alvo é a que a esteira mostraria.
// - Pausa no app = pausa na gravação (stop/start), igual ao botão de pausa nativo.
//
// Tudo protegido: se o relógio não puder gravar (sem permissão, outra atividade aberta),
// o treino segue normalmente e só o histórico local é salvo.

import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;

class GravadorAtividade {

    const NOME_ATIVIDADE = "HIIT Esteira";
    const CAMPO_ALVO = 0;
    const CAMPO_ALVO_VOLTA = 1;
    const CAMPO_DIST_ALVO = 2;

    private var _sessao as ActivityRecording.Session? = null;
    private var _campoAlvo as FitContributor.Field? = null;
    private var _campoAlvoVolta as FitContributor.Field? = null;
    private var _campoDistAlvo as FitContributor.Field? = null;
    private var _encerrada as Boolean = false;

    function initialize() {
        try {
            var s = ActivityRecording.createSession({
                :name => NOME_ATIVIDADE,
                :sport => Activity.SPORT_RUNNING,
                :subSport => Activity.SUB_SPORT_TREADMILL
            });
            _campoAlvo = s.createField("vel_alvo", CAMPO_ALVO, FitContributor.DATA_TYPE_FLOAT,
                { :mesgType => FitContributor.MESG_TYPE_RECORD, :units => "km/h" });
            _campoAlvoVolta = s.createField("vel_alvo_volta", CAMPO_ALVO_VOLTA, FitContributor.DATA_TYPE_FLOAT,
                { :mesgType => FitContributor.MESG_TYPE_LAP, :units => "km/h" });
            _campoDistAlvo = s.createField("dist_alvo", CAMPO_DIST_ALVO, FitContributor.DATA_TYPE_FLOAT,
                { :mesgType => FitContributor.MESG_TYPE_SESSION, :units => "km" });
            _sessao = s;
        } catch (e) {
            _sessao = null;   // sem gravação: o app funciona igual, só sem atividade
        }
    }

    function disponivel() as Boolean {
        return _sessao != null;
    }

    // Largada: começa a gravar com o ritmo do primeiro bloco.
    function iniciar(kmh as Float) as Void {
        definir(_campoAlvo, kmh);
        definir(_campoAlvoVolta, kmh);
        var s = _sessao;
        if (s != null && !s.isRecording()) {
            s.start();
        }
    }

    function pausar() as Void {
        var s = _sessao;
        if (s != null && s.isRecording()) {
            s.stop();
        }
    }

    function retomar() as Void {
        var s = _sessao;
        if (s != null && !_encerrada && !s.isRecording()) {
            s.start();
        }
    }

    // Troca de bloco: fecha a volta do bloco que terminou e passa a registrar o novo alvo.
    // O campo de volta é gravado no momento do addLap, por isso recebe o ritmo ANTERIOR.
    function novaVolta(kmhAnterior as Float, kmhNovo as Float) as Void {
        var s = _sessao;
        if (s == null || !s.isRecording()) {
            return;
        }
        definir(_campoAlvoVolta, kmhAnterior);
        s.addLap();
        definir(_campoAlvoVolta, kmhNovo);
        definir(_campoAlvo, kmhNovo);
    }

    // Calorias calculadas pela Garmin para esta gravação (null se indisponível).
    function caloriasGarmin() as Number? {
        if (_sessao == null) {
            return null;
        }
        var info = Activity.getActivityInfo();
        if (info != null && info.calories != null && (info.calories as Number) > 0) {
            return info.calories as Number;
        }
        return null;
    }

    // Fim do treino. salvar=false descarta (treino curto demais). Devolve true se a
    // atividade foi salva (vai para o Garmin Connect na próxima sincronização).
    function encerrar(salvar as Boolean, kmAlvo as Float) as Boolean {
        var s = _sessao;
        if (s == null || _encerrada) {
            return false;
        }
        _encerrada = true;
        try {
            if (s.isRecording()) {
                s.stop();
            }
            if (salvar) {
                definir(_campoDistAlvo, kmAlvo);
                return s.save();
            }
            s.discard();
        } catch (e) {
            // falha ao salvar não pode derrubar o resumo
        }
        return false;
    }

    private function definir(campo as FitContributor.Field?, valor as Float) as Void {
        if (campo != null) {
            campo.setData(valor);
        }
    }
}

// Treino em andamento, para o app salvar a atividade se for fechado no meio do treino.
var treinoEmAndamento as TreinoView? = null;
