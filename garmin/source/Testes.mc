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
