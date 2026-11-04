// Tela.mc — helpers de desenho compartilhados entre as views.

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;

module Tela {

    const CENTRO = Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER;

    function corDoTipo(tipo as TipoBloco) as Graphics.ColorType {
        if (tipo == TIPO_ESFORCO) { return Graphics.COLOR_RED; }
        if (tipo == TIPO_RECUPERACAO) { return Graphics.COLOR_GREEN; }
        if (tipo == TIPO_AQUECIMENTO) { return Graphics.COLOR_YELLOW; }
        return Graphics.COLOR_BLUE;
    }

    function nomeDoTipo(tipo as TipoBloco) as String {
        if (tipo == TIPO_ESFORCO) { return "ESFORÇO"; }
        if (tipo == TIPO_RECUPERACAO) { return "RECUPERAÇÃO"; }
        if (tipo == TIPO_AQUECIMENTO) { return "AQUECIMENTO"; }
        return "DESAQUEC.";
    }

    function abrevTipo(tipo as TipoBloco) as String {
        if (tipo == TIPO_ESFORCO) { return "Esforço"; }
        if (tipo == TIPO_RECUPERACAO) { return "Recup."; }
        if (tipo == TIPO_AQUECIMENTO) { return "Aquec."; }
        return "Desaq.";
    }

    function telaRedonda() as Boolean {
        return System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
    }

    function limpar(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
    }

    // Barra horizontal de progresso centralizada (p de 0.0 a 1.0).
    function barra(dc as Graphics.Dc, cy as Numeric, largura as Number, altura as Number,
                   p as Float, cor as Graphics.ColorType) as Void {
        var x = (dc.getWidth() - largura) / 2;
        var y = cy.toNumber() - altura / 2;
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(x, y, largura, altura);
        var cheio = (largura * p).toNumber();
        if (cheio > 0) {
            dc.setColor(cor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, cheio, altura);
        }
    }
}
