// Tela.mc — helpers de desenho compartilhados entre as views.

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
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

    // Nome por extenso, para menus.
    function nomeTipo(tipo as TipoBloco) as String {
        if (tipo == TIPO_ESFORCO) { return "Esforço"; }
        if (tipo == TIPO_RECUPERACAO) { return "Recuperação"; }
        if (tipo == TIPO_AQUECIMENTO) { return "Aquecimento"; }
        return "Desaquecimento";
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

    // Largura útil de uma linha de texto na altura y. Em tela redonda é a corda do
    // círculo naquela altura (menos a margem); em tela retangular, a largura toda.
    function larguraNaAltura(dc as Graphics.Dc, y as Numeric, margem as Number) as Number {
        var w = dc.getWidth();
        if (!telaRedonda()) {
            return w - 2 * margem;
        }
        var r = w / 2.0;
        var dy = y.toFloat() - dc.getHeight() / 2.0;
        var quad = r * r - dy * dy;
        if (quad <= 0.0) {
            return 0;
        }
        return (2.0 * Math.sqrt(quad)).toNumber() - 2 * margem;
    }

    // Primeira fonte da lista (da maior para a menor) em que o texto cabe.
    function fonteQueCabe(dc as Graphics.Dc, texto as String, larguraMax as Number,
                          fontes as Array<Graphics.FontDefinition>) as Graphics.FontDefinition {
        for (var i = 0; i < fontes.size(); i++) {
            if (dc.getTextWidthInPixels(texto, fontes[i]) <= larguraMax) {
                return fontes[i];
            }
        }
        return fontes[fontes.size() - 1];
    }

    // Desenha texto centralizado em y, reduzindo a fonte se não couber na tela.
    function textoAjustado(dc as Graphics.Dc, y as Numeric, texto as String,
                           fontes as Array<Graphics.FontDefinition>) as Void {
        var margem = dc.getWidth() / 30 + 4;  // espaço do anel colorido
        var fonte = fonteQueCabe(dc, texto, larguraNaAltura(dc, y, margem), fontes);
        dc.drawText(dc.getWidth() / 2, y, fonte, texto, CENTRO);
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
