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
    }

    function onStop(state as Dictionary?) as Void {
    }

    // Sem anotação de tipo de retorno de propósito: a assinatura oficial mudou entre
    // versões do SDK (Array -> tupla). Sem anotação compila em todas.
    function getInitialView() {
        return [new InicioView(), new InicioDelegate()];
    }
}
