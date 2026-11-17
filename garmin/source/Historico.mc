// Historico.mc — registro dos treinos feitos, guardado no Application.Storage.
//
// Decisões:
// - Storage (não Properties): é dado do app, não configuração do usuário.
// - Uma única chave com a lista dos últimos MAXIMO treinos, do mais novo para o mais
//   antigo. Cada registro é um Dictionary pequeno (~100 bytes): 30 cabem com folga.
// - Leitura defensiva: no Monkey C, chamar método em null é erro FATAL (try/catch não
//   segura). Por isso fromDict valida cada campo e devolve null se algo estiver errado;
//   registro ruim é descartado em vez de derrubar o app.
// - Treinos com menos de MINIMO_SEG não são salvos (START apertado sem querer).
// - Métricas (kcal, km, FC, zonas) são campos OPCIONAIS: registros antigos, sem elas,
//   continuam válidos e só não mostram essas linhas.

import Toybox.Application;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;

class RegistroTreino {
    public var inicio as Number;          // epoch em segundos (UTC)
    public var nome as String;
    public var feitoSeg as Number;        // tempo realmente treinado
    public var planejadoSeg as Number;
    public var tiros as Number;           // tiros completados
    public var tirosPlanejados as Number;
    public var ritmoPico as Float;        // km/h
    public var concluido as Boolean;
    public var metricas as ResumoMetricas? = null;

    function initialize(inicio as Number, nome as String, feitoSeg as Number, planejadoSeg as Number,
                        tiros as Number, tirosPlanejados as Number, ritmoPico as Float, concluido as Boolean) {
        self.inicio = inicio;
        self.nome = nome;
        self.feitoSeg = feitoSeg;
        self.planejadoSeg = planejadoSeg;
        self.tiros = tiros;
        self.tirosPlanejados = tirosPlanejados;
        self.ritmoPico = ritmoPico;
        self.concluido = concluido;
    }

    function toDict() as Dictionary {
        var d = {
            "i" => inicio, "n" => nome, "f" => feitoSeg, "p" => planejadoSeg,
            "t" => tiros, "tp" => tirosPlanejados, "v" => ritmoPico, "c" => concluido
        };
        var m = metricas;
        if (m != null) {
            d["k"] = m.kcal;
            d["d"] = m.km;
            d["fm"] = m.fcMedia;
            d["fx"] = m.fcMax;
            d["z"] = m.zonasSeg;
        }
        return d;
    }

    // Devolve null se o dicionário não tiver o formato esperado.
    static function fromDict(d as Dictionary) as RegistroTreino? {
        var i = d["i"]; var n = d["n"]; var f = d["f"]; var p = d["p"];
        var t = d["t"]; var tp = d["tp"]; var v = d["v"]; var c = d["c"];
        if (!(i instanceof Number) || !(n instanceof String) || !(f instanceof Number)
                || !(p instanceof Number) || !(t instanceof Number) || !(tp instanceof Number)
                || !(v instanceof Float || v instanceof Number) || !(c instanceof Boolean)) {
            return null;
        }
        var r = new RegistroTreino(i as Number, n as String, f as Number, p as Number,
                                   t as Number, tp as Number, (v as Numeric).toFloat(), c as Boolean);
        r.metricas = RegistroTreino.metricasDe(d);
        return r;
    }

    // Métricas opcionais; null se ausentes ou com formato inesperado.
    static function metricasDe(d as Dictionary) as ResumoMetricas? {
        var k = d["k"]; var km = d["d"]; var fm = d["fm"]; var fx = d["fx"]; var z = d["z"];
        if (!(k instanceof Number) || !(km instanceof Float || km instanceof Number)
                || !(fm instanceof Number) || !(fx instanceof Number)) {
            return null;
        }
        var zonas = [0, 0, 0, 0, 0] as Array<Number>;
        if (z instanceof Array && (z as Array).size() == 5) {
            for (var q = 0; q < 5; q++) {
                var v = (z as Array)[q];
                if (v instanceof Number) {
                    zonas[q] = v as Number;
                }
            }
        }
        return new ResumoMetricas(k as Number, (km as Numeric).toFloat(), fm as Number, fx as Number, zonas);
    }

    // "04/11 18:30" no fuso do relógio.
    function dataHora() as String {
        var info = Gregorian.info(new Time.Moment(inicio), Time.FORMAT_SHORT);
        return (info.day as Number).format("%02d") + "/" + (info.month as Number).format("%02d") + " "
            + (info.hour as Number).format("%02d") + ":" + (info.min as Number).format("%02d");
    }

    // Resumo de uma linha para a lista: "30:00 - 10/10 tiros" ou "Parou 12:30 - 4/10".
    function resumo() as String {
        var tirosTxt = tiros.toString() + "/" + tirosPlanejados.toString();
        if (concluido) {
            return Unidades.formatarTempo(feitoSeg) + " - " + tirosTxt + " tiros";
        }
        return "Parou " + Unidades.formatarTempo(feitoSeg) + " - " + tirosTxt;
    }
}

module Historico {

    const CHAVE = "historico";
    const MAXIMO = 30;
    const MINIMO_SEG = 60;

    // Lista bruta (dicionários) do Storage; vazia se não houver ou estiver corrompida.
    function lerBruto() as Array<Dictionary> {
        var v = null;
        try {
            v = Storage.getValue(CHAVE);
        } catch (e) {
            // Storage indisponível: trata como vazio
        }
        var saida = [] as Array<Dictionary>;
        if (v instanceof Array) {
            var arr = v as Array;
            for (var k = 0; k < arr.size(); k++) {
                if (arr[k] instanceof Dictionary) {
                    saida.add(arr[k] as Dictionary);
                }
            }
        }
        return saida;
    }

    // Registros válidos, do mais novo para o mais antigo.
    function listar() as Array<RegistroTreino> {
        var bruto = lerBruto();
        var lista = [] as Array<RegistroTreino>;
        for (var k = 0; k < bruto.size(); k++) {
            var r = RegistroTreino.fromDict(bruto[k]);
            if (r != null) {
                lista.add(r);
            }
        }
        return lista;
    }

    function quantidade() as Number {
        return listar().size();
    }

    // Salva o treino que acabou. Devolve true se gravou.
    function registrar(motor as MotorTreino, metricas as ResumoMetricas?) as Boolean {
        if (motor.decorridoSeg() < MINIMO_SEG) {
            return false;
        }
        var treino = motor.treino();
        var novo = new RegistroTreino(motor.inicioEpoch(), treino.nome, motor.decorridoSeg(),
            motor.totalSeg(), motor.esforcosConcluidos(), treino.contarEsforcos(),
            treino.ritmoPico(), motor.concluido());
        novo.metricas = metricas;

        var lista = [novo.toDict()] as Array<Dictionary>;
        var antigos = lerBruto();
        for (var k = 0; k < antigos.size() && lista.size() < MAXIMO; k++) {
            lista.add(antigos[k]);
        }
        try {
            Storage.setValue(CHAVE, lista as Array<Application.PropertyValueType>);
            return true;
        } catch (e) {
            return false;  // armazenamento cheio: o treino não é salvo, mas o app segue
        }
    }

    function apagarTudo() as Void {
        Storage.deleteValue(CHAVE);
    }
}
