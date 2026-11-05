// TextoTreino.mc — lê treinos escritos em texto no app Garmin Connect (celular).
//
// Formato (espaços extras são ignorados, maiúsculas/minúsculas tanto faz):
//
//   Tiros = AQ 5,5 3:00; 8x(E 13 1:00 + R 7 1:30); DQ 6 3:00 | Pirâmide = ...
//
//   |            separa treinos
//   Nome =       nome do treino (opcional; sem ele vira "Celular 1", "Celular 2"...)
//   ;            separa itens
//   TIPO RITMO TEMPO   bloco simples. TIPO: AQ (aquecimento), E (esforço),
//                      R (recuperação), DQ (desaquecimento)
//   Nx(E RITMO TEMPO + R RITMO TEMPO)   série; as letras E/R dentro dela são opcionais
//   RITMO        km/h, com vírgula ou ponto: 13 / 13,5 / 13.5
//   TEMPO        1:30 (min:s) · 90s (segundos) · 3 ou 3min (minutos) · 1,5 (minutos)
//
// Decisão: "+" separa esforço e recuperação dentro da série (e não ","), para não
// conflitar com a vírgula decimal ("13,5"). Qualquer erro aborta a importação inteira
// com uma mensagem que diz o treino e o item — melhor do que importar pela metade.

import Toybox.Lang;
import Toybox.Math;
import Toybox.StringUtil;

module TextoTreino {

    class Resultado {
        public var treinos as Array<TreinoPersonalizado> = [] as Array<TreinoPersonalizado>;
        public var erro as String? = null;

        function initialize() {
        }
    }

    function parsear(texto as String) as Resultado {
        var res = new Resultado();
        var blocos = dividir(texto, '|');
        var n = 0;
        for (var w = 0; w < blocos.size(); w++) {
            var bruto = aparar(blocos[w]);
            if (bruto.length() == 0) {
                continue;
            }
            n++;
            if (n > Personalizados.MAX_TREINOS) {
                res.erro = "Mais de " + Personalizados.MAX_TREINOS.toString() + " treinos no texto";
                return res;
            }

            var nome = "Celular " + n.toString();
            var corpo = bruto;
            var eq = bruto.find("=");
            if (eq != null) {
                var antes = aparar(bruto.substring(0, eq) as String);
                if (antes.length() > 0) {
                    nome = antes.length() > Personalizados.MAX_NOME
                        ? antes.substring(0, Personalizados.MAX_NOME) as String : antes;
                }
                corpo = bruto.substring(eq + 1, bruto.length()) as String;
            }

            var itens = [] as Array<ItemPlano>;
            var partes = dividir(corpo, ';');
            for (var k = 0; k < partes.size(); k++) {
                var p = aparar(partes[k]);
                if (p.length() == 0) {
                    continue;
                }
                var r = parsearItem(p);
                if (r instanceof String) {
                    res.erro = nome + ", item " + (itens.size() + 1).toString() + ": " + r;
                    return res;
                }
                itens.add(r as ItemPlano);
                if (itens.size() > Personalizados.MAX_ITENS) {
                    res.erro = nome + ": mais de " + Personalizados.MAX_ITENS.toString() + " itens";
                    return res;
                }
            }
            if (itens.size() == 0) {
                res.erro = nome + ": nenhum item";
                return res;
            }
            res.treinos.add(new TreinoPersonalizado(nome, itens));
        }
        return res;
    }

    // Um item: bloco simples ou série. Devolve ItemPlano ou mensagem de erro.
    function parsearItem(p as String) as ItemPlano or String {
        var abre = indiceDe(p, '(');
        if (abre >= 0) {
            var x = indiceDe(p.toUpper(), 'X');
            if (x < 0 || x > abre) {
                return "série sem 'x' (ex.: 8x(E 13 1:00 + R 7 1:30))";
            }
            var reps = (aparar(p.substring(0, x) as String)).toNumber();
            if (reps == null || reps < 1 || reps > Personalizados.MAX_REPS) {
                return "repetições inválidas (1 a " + Personalizados.MAX_REPS.toString() + ")";
            }
            var fecha = indiceDe(p, ')');
            if (fecha < abre) {
                return "faltou ')'";
            }
            var lados = dividir(p.substring(abre + 1, fecha) as String, '+');
            if (lados.size() != 2) {
                return "série precisa de esforço + recuperação";
            }
            var e = parsearRitmoTempo(lados[0]);
            if (e instanceof String) { return e; }
            var r = parsearRitmoTempo(lados[1]);
            if (r instanceof String) { return r; }
            var ea = e as Array<Numeric>;
            var ra = r as Array<Numeric>;
            return ItemPlano.serie(reps, ea[0].toFloat(), ea[1].toNumber(), ra[0].toFloat(), ra[1].toNumber());
        }

        var toks = tokens(p);
        if (toks.size() != 3) {
            return "use TIPO RITMO TEMPO (ex.: E 13 1:00)";
        }
        var tipo = parsearTipo(toks[0]);
        if (tipo == null) {
            return "tipo '" + toks[0] + "' inválido (AQ, E, R ou DQ)";
        }
        var v = parsearRitmo(toks[1]);
        if (v == null) {
            return "ritmo '" + toks[1] + "' inválido";
        }
        var s = parsearTempo(toks[2]);
        if (s == null) {
            return "tempo '" + toks[2] + "' inválido";
        }
        return ItemPlano.bloco(tipo, v, s);
    }

    // "E 13 1:00" ou "13 1:00" -> [kmh, seg]
    function parsearRitmoTempo(s as String) as Array<Numeric> or String {
        var toks = tokens(s);
        if (toks.size() == 3) {
            toks = toks.slice(1, null);
        }
        if (toks.size() != 2) {
            return "dentro da série use RITMO TEMPO (ex.: E 13 1:00)";
        }
        var v = parsearRitmo(toks[0]);
        if (v == null) {
            return "ritmo '" + toks[0] + "' inválido";
        }
        var seg = parsearTempo(toks[1]);
        if (seg == null) {
            return "tempo '" + toks[1] + "' inválido";
        }
        return [v, seg] as Array<Numeric>;
    }

    function parsearTipo(tok as String) as TipoBloco? {
        var u = tok.toUpper();
        if (u.length() == 0) { return null; }
        var c = u.toCharArray()[0];
        if (c == 'A') { return TIPO_AQUECIMENTO; }
        if (c == 'E') { return TIPO_ESFORCO; }
        if (c == 'R') { return TIPO_RECUPERACAO; }
        if (c == 'D') { return TIPO_DESAQUECIMENTO; }
        return null;
    }

    function parsearRitmo(tok as String) as Float? {
        var v = trocarVirgula(tok).toFloat();
        if (v == null) { return null; }
        var r = Unidades.arred1(v);
        return Personalizados.ritmoValido(r) ? r : null;
    }

    // Segundos, ou null se inválido/fora da faixa.
    function parsearTempo(tok as String) as Number? {
        var t = tok.toLower();
        var seg = null;
        var dois = indiceDe(t, ':');
        if (dois >= 0) {
            var m = (t.substring(0, dois) as String).toNumber();
            var s = (t.substring(dois + 1, t.length()) as String).toNumber();
            if (m == null || s == null || m < 0 || s < 0 || s > 59) { return null; }
            seg = m * 60 + s;
        } else if (terminaCom(t, "min")) {
            var m = trocarVirgula(t.substring(0, t.length() - 3) as String).toFloat();
            if (m == null) { return null; }
            seg = Math.round(m * 60.0).toNumber();
        } else if (terminaCom(t, "s")) {
            seg = (t.substring(0, t.length() - 1) as String).toNumber();
        } else {
            var m = trocarVirgula(t).toFloat();
            if (m == null) { return null; }
            seg = Math.round(m * 60.0).toNumber();
        }
        if (seg == null || !Personalizados.tempoValido(seg)) { return null; }
        return seg;
    }

    // ---- utilitários de texto ----

    function dividir(s as String, sep as Char) as Array<String> {
        var partes = [] as Array<String>;
        var atual = [] as Array<Char>;
        var cs = s.toCharArray();
        for (var i = 0; i < cs.size(); i++) {
            if (cs[i] == sep) {
                partes.add(StringUtil.charArrayToString(atual));
                atual = [] as Array<Char>;
            } else {
                atual.add(cs[i]);
            }
        }
        partes.add(StringUtil.charArrayToString(atual));
        return partes;
    }

    // Palavras separadas por espaço (vazias descartadas).
    function tokens(s as String) as Array<String> {
        var brutos = dividir(s, ' ');
        var r = [] as Array<String>;
        for (var i = 0; i < brutos.size(); i++) {
            var t = aparar(brutos[i]);
            if (t.length() > 0) {
                r.add(t);
            }
        }
        return r;
    }

    function ehEspaco(c as Char) as Boolean {
        return c == ' ' || c == '\t' || c == '\n' || c == '\r';
    }

    function aparar(s as String) as String {
        var cs = s.toCharArray();
        var ini = 0;
        var fim = cs.size();
        while (ini < fim && ehEspaco(cs[ini])) { ini++; }
        while (fim > ini && ehEspaco(cs[fim - 1])) { fim--; }
        return s.substring(ini, fim) as String;
    }

    function indiceDe(s as String, c as Char) as Number {
        var cs = s.toCharArray();
        for (var i = 0; i < cs.size(); i++) {
            if (cs[i] == c) { return i; }
        }
        return -1;
    }

    function terminaCom(s as String, sufixo as String) as Boolean {
        var n = s.length();
        var k = sufixo.length();
        return n > k && (s.substring(n - k, n) as String).equals(sufixo);
    }

    function trocarVirgula(s as String) as String {
        var cs = s.toCharArray();
        for (var i = 0; i < cs.size(); i++) {
            if (cs[i] == ',') { cs[i] = '.'; }
        }
        return StringUtil.charArrayToString(cs);
    }
}
