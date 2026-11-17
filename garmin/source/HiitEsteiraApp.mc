// HiitEsteiraApp.mc — ponto de entrada (declarado em entry="HiitEsteiraApp" no manifest).
//
// Fluxo de telas (pilha de views do WatchUi):
//   InicioView  --START-->  TreinoView  --fim/encerrar-->  FimView (substitui o treino)
//        ^                                                     |
//        +----------------------- BACK ------------------------+

import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class HiitEsteiraApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        // Traz treinos digitados no Garmin Connect (só se o texto mudou desde a última vez).
        Personalizados.importarDoCelular();
    }

    function onStop(state as Dictionary?) as Void {
        // Se o app for fechado no meio do treino, a atividade é salva em vez de perdida.
        var t = $.treinoEmAndamento;
        if (t != null) {
            t.finalizarAoSair();
        }
    }

    // Chamado quando o usuário salva as configurações no app Garmin Connect com o app
    // aberto no relógio: importa treinos em texto e redesenha (Config lê das Properties).
    function onSettingsChanged() as Void {
        Personalizados.importarDoCelular();
        WatchUi.requestUpdate();
    }

    // Sem anotação de tipo de retorno de propósito: a assinatura oficial mudou entre
    // versões do SDK (Array -> tupla). Sem anotação compila em todas.
    function getInitialView() {
        return [new InicioView(), new InicioDelegate()];
    }
}
