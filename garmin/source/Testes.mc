// Testes.mc — testes unitários (framework Toybox.Test do Connect IQ).
//
// Funções marcadas com (:test) só entram no build de teste (monkeyc --unit-test);
// não ocupam memória no app instalado. Ver README para rodar.

import Toybox.Lang;
import Toybox.Test;

(:test)
function testeTextoCompleto(logger as Test.Logger) as Boolean {
    var r = TextoTreino.parsear("Tiros = AQ 5,5 3:00; 8x(E 13 1:00 + R 7 1:30); DQ 6 3");
    Test.assertMessage(r.erro == null, "erro inesperado: " + r.erro);
    Test.assertEqual(r.treinos.size(), 1);
    var t = r.treinos[0];
    Test.assertEqual(t.nome, "Tiros");
    Test.assertEqual(t.itens.size(), 3);
    // aquecimento
    Test.assertEqual(t.itens[0].tipo, TIPO_AQUECIMENTO);
    Test.assertEqual(t.itens[0].kmh, 5.5);
    Test.assertEqual(t.itens[0].seg, 180);
    // série
    Test.assertEqual(t.itens[1].reps, 8);
    Test.assertEqual(t.itens[1].kmh, 13.0);
    Test.assertEqual(t.itens[1].seg, 60);
    Test.assertEqual(t.itens[1].recKmh, 7.0);
    Test.assertEqual(t.itens[1].recSeg, 90);
    // desaquecimento com tempo em minutos sem ":"
    Test.assertEqual(t.itens[2].tipo, TIPO_DESAQUECIMENTO);
    Test.assertEqual(t.itens[2].seg, 180);
    // 180 + (8*60 + 7*90) + 180 = 1470 s
    Test.assertEqual(t.duracaoSeg(), 1470);
    return true;
}

(:test)
function testeExpansaoSerie(logger as Test.Logger) as Boolean {
    var t = new TreinoPersonalizado("x", [ItemPlano.serie(3, 13.0, 60, 7.0, 90)] as Array<ItemPlano>);
    var treino = t.expandir();
    // E R E R E  (sem recuperação depois do último tiro)
    Test.assertEqual(treino.intervalos.size(), 5);
    Test.assertEqual(treino.intervalos[0].tipo, TIPO_ESFORCO);
    Test.assertEqual(treino.intervalos[1].tipo, TIPO_RECUPERACAO);
    Test.assertEqual(treino.intervalos[4].tipo, TIPO_ESFORCO);
    Test.assertEqual(treino.duracaoTotal(), t.duracaoSeg());
    Test.assertEqual(treino.contarEsforcos(), 3);
    return true;
}

(:test)
function testeVariosTreinosEFormatos(logger as Test.Logger) as Boolean {
    var r = TextoTreino.parsear("  a = e 12.5 90s ; r 6,5 1,5 | B=AQ 5 2min|  ");
    Test.assertMessage(r.erro == null, "erro inesperado: " + r.erro);
    Test.assertEqual(r.treinos.size(), 2);
    Test.assertEqual(r.treinos[0].nome, "a");
    Test.assertEqual(r.treinos[0].itens[0].kmh, 12.5);
    Test.assertEqual(r.treinos[0].itens[0].seg, 90);
    Test.assertEqual(r.treinos[0].itens[1].kmh, 6.5);
    Test.assertEqual(r.treinos[0].itens[1].seg, 90);   // 1,5 min
    Test.assertEqual(r.treinos[1].nome, "B");
    Test.assertEqual(r.treinos[1].itens[0].seg, 120);
    return true;
}

(:test)
function testeSemNomeESerieSemLetras(logger as Test.Logger) as Boolean {
    var r = TextoTreino.parsear("4x(14 0:30 + 6 0:30)");
    Test.assertMessage(r.erro == null, "erro inesperado: " + r.erro);
    Test.assertEqual(r.treinos[0].nome, "Celular 1");
    Test.assertEqual(r.treinos[0].itens[0].reps, 4);
    Test.assertEqual(r.treinos[0].itens[0].recSeg, 30);
    return true;
}

(:test)
function testeErros(logger as Test.Logger) as Boolean {
    Test.assert(TextoTreino.parsear("X = Z 10 1:00").erro != null);               // tipo inválido
    Test.assert(TextoTreino.parsear("X = E 30 1:00").erro != null);               // ritmo fora da faixa
    Test.assert(TextoTreino.parsear("X = E 12 1:75").erro != null);               // segundos > 59
    Test.assert(TextoTreino.parsear("X = E 12").erro != null);                    // falta o tempo
    Test.assert(TextoTreino.parsear("X = 8x(E 13 1:00)").erro != null);           // série sem recuperação
    Test.assert(TextoTreino.parsear("X = 8(E 13 1:00 + R 7 1:00)").erro != null); // falta o x
    Test.assert(TextoTreino.parsear("X = 99x(E 13 1:00 + R 7 1:00)").erro != null); // reps demais
    Test.assert(TextoTreino.parsear("X = ").erro != null);                        // sem itens
    // mensagem aponta o treino e o item
    var e = TextoTreino.parsear("Meu = AQ 5 3:00; E abc 1:00").erro as String;
    Test.assertMessage(e.find("Meu, item 2") != null, "mensagem: " + e);
    return true;
}

(:test)
function testeTextoVazio(logger as Test.Logger) as Boolean {
    var r = TextoTreino.parsear("");
    Test.assert(r.erro == null);
    Test.assertEqual(r.treinos.size(), 0);
    return true;
}

(:test)
function testeContagem(logger as Test.Logger) as Boolean {
    // fora da janela: nada
    Test.assertEqual(Alertas.numeroContagem(10, 0), 0);
    Test.assertEqual(Alertas.numeroContagem(4, 0), 0);
    // sequência normal 3, 2, 1
    Test.assertEqual(Alertas.numeroContagem(3, 0), 3);
    Test.assertEqual(Alertas.numeroContagem(3, 3), 0);   // mesmo segundo em outro tick: não repete
    Test.assertEqual(Alertas.numeroContagem(2, 3), 2);
    Test.assertEqual(Alertas.numeroContagem(1, 2), 1);
    Test.assertEqual(Alertas.numeroContagem(1, 1), 0);
    // tick atrasado pulou o 2: anuncia o 1
    Test.assertEqual(Alertas.numeroContagem(1, 3), 1);
    // bloco que já começa dentro da janela (ex.: 2 s restantes ao entrar)
    Test.assertEqual(Alertas.numeroContagem(2, 0), 2);
    // fim do bloco (0 restante) é a troca, não contagem
    Test.assertEqual(Alertas.numeroContagem(0, 1), 0);
    return true;
}

(:test)
function testeIdaEVoltaStorage(logger as Test.Logger) as Boolean {
    var t = new TreinoPersonalizado("rt", [
        ItemPlano.bloco(TIPO_AQUECIMENTO, 5.5, 120),
        ItemPlano.serie(5, 12.0, 45, 6.0, 75)
    ] as Array<ItemPlano>);
    var volta = TreinoPersonalizado.fromDict(t.toDict());
    Test.assert(volta != null);
    var v = volta as TreinoPersonalizado;
    Test.assertEqual(v.nome, "rt");
    Test.assertEqual(v.itens.size(), 2);
    Test.assertEqual(v.itens[1].reps, 5);
    Test.assertEqual(v.itens[1].recSeg, 75);
    Test.assertEqual(v.duracaoSeg(), t.duracaoSeg());
    // item corrompido é descartado, o resto sobrevive
    var d = { "n" => "c", "i" => [[0, 1, 12.0, 60, 0.0, 0], [0, 9, null, "x", 0.0, 0]] };
    var c = TreinoPersonalizado.fromDict(d) as TreinoPersonalizado;
    Test.assertEqual(c.itens.size(), 1);
    return true;
}

// Treino gerado: km/h inteiros, nenhum bloco abaixo de 40 s e duração exata (10 a 50 min).
(:test)
function testeGeradorRegrasDeEsteira(logger as Test.Logger) as Boolean {
    var maximos = [14.0, 13.7, 10.5] as Array<Float>;
    for (var m = 0; m < maximos.size(); m++) {
        for (var dur = 10; dur <= 50; dur += 5) {
            var t = Gerador.gerar(maximos[m], dur);
            Test.assertEqual(t.duracaoTotal(), dur * 60);
            for (var i = 0; i < t.intervalos.size(); i++) {
                var b = t.intervalos[i];
                Test.assertMessage(b.kmh == b.kmh.toNumber().toFloat(), "ritmo não inteiro: " + b.kmh);
                Test.assertMessage(b.kmh <= maximos[m], "acima do máximo: " + b.kmh);
                Test.assertMessage(b.duracaoSeg >= 40, dur + " min: bloco de " + b.duracaoSeg + " s");
            }
        }
    }
    Test.assertEqual(Unidades.valorRitmo(14.0, Unidades.UNIDADE_KMH, ","), "14");
    Test.assertEqual(Unidades.valorRitmo(13.5, Unidades.UNIDADE_KMH, ","), "13,5");
    return true;
}

// Histórico: métricas vão e voltam do Storage; registro antigo (sem métricas) continua válido.
(:test)
function testeHistoricoComMetricas(logger as Test.Logger) as Boolean {
    var r = new RegistroTreino(1700000000, "HIIT 30 min", 1800, 1800, 10, 10, 14.0, true);
    r.metricas = new ResumoMetricas(312, 4.24, 151, 178, [60, 300, 600, 500, 340] as Array<Number>);
    var volta = RegistroTreino.fromDict(r.toDict()) as RegistroTreino;
    var m = volta.metricas as ResumoMetricas;
    Test.assertEqual(m.kcal, 312);
    Test.assertEqual(m.fcMax, 178);
    Test.assertEqual(m.zonasSeg[2], 600);
    Test.assertEqual(m.textoGasto(), "312 kcal · 4,2 km");
    Test.assertEqual(m.textoFc(), "FC 151 méd · 178 máx");

    var antigo = { "i" => 1, "n" => "x", "f" => 90, "p" => 600, "t" => 1, "tp" => 5, "v" => 12.0, "c" => false };
    var a = RegistroTreino.fromDict(antigo);
    Test.assert(a != null);
    Test.assert((a as RegistroTreino).metricas == null);
    return true;
}

// Coletor: sem FC usa a estimativa pelo ritmo; com FC registra média, máxima e zonas.
(:test)
function testeColetorResumo(logger as Test.Logger) as Boolean {
    var p = new PerfilMetricas();
    p.limites = [100, 120, 140, 160, 180, 200] as Array<Number>;
    var c = new ColetorMetricas(p);
    c.amostrar(1800.0, 12.0, null);           // 30 min a 12 km/h sem FC
    var r = c.resumo(null);
    Test.assert(r.km > 5.99 && r.km < 6.01);
    Test.assert(r.kcal > 0);
    Test.assert(!r.temFc());
    c.amostrar(60.0, 12.0, 150);              // 1 min em Z3
    r = c.resumo(400);                          // calorias da Garmin têm prioridade
    Test.assertEqual(r.kcal, 400);
    Test.assertEqual(r.fcMedia, 150);
    Test.assertEqual(r.zonasSeg[2], 60);
    return true;
}
