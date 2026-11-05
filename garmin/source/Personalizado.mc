// Personalizado.mc — treinos personalizados: modelo do plano e armazenamento.
//
// Decisões:
// - Um treino personalizado é um PLANO (nome + itens). Cada item é um bloco simples
//   (tipo, ritmo, tempo) ou uma SÉRIE (N x esforço + recuperação). Ao iniciar, o plano é
//   expandido para Array<Intervalo> — o mesmo formato do gerador —, então motor, tela,
//   alertas e histórico funcionam sem nenhuma mudança.
// - Série: N esforços com recuperação ENTRE eles (não depois do último), igual ao gerador.
//   Quem quiser descanso depois da série adiciona um bloco de recuperação.
// - Storage com uma chave por treino ("pers0".."pers9"): nenhum valor fica grande e apagar
//   um treino é só apagar a chave.
// - Itens gravados como arrays compactos [reps, tipo, kmh, seg, recKmh, recSeg] e validados
//   campo a campo na leitura (no Monkey C, null inesperado é erro fatal).

import Toybox.Application;
import Toybox.Lang;

// Um item do plano: bloco simples (reps == 0) ou série (reps >= 1).
class ItemPlano {
    public var reps as Number;      // 0 = bloco simples; N = série com N repetições
    public var tipo as TipoBloco;   // tipo do bloco simples (série é sempre esforço/recuperação)
    public var kmh as Float;        // bloco: ritmo; série: ritmo do esforço
    public var seg as Number;       // bloco: duração; série: duração de cada esforço
    public var recKmh as Float;     // série: ritmo da recuperação
    public var recSeg as Number;    // série: duração de cada recuperação

    function initialize(reps as Number, tipo as TipoBloco, kmh as Float, seg as Number,
                        recKmh as Float, recSeg as Number) {
        self.reps = reps;
        self.tipo = tipo;
        self.kmh = kmh;
        self.seg = seg;
        self.recKmh = recKmh;
        self.recSeg = recSeg;
    }

    static function bloco(tipo as TipoBloco, kmh as Float, seg as Number) as ItemPlano {
        return new ItemPlano(0, tipo, kmh, seg, 0.0, 0);
    }

    static function serie(reps as Number, kmh as Float, seg as Number, recKmh as Float, recSeg as Number) as ItemPlano {
        return new ItemPlano(reps, TIPO_ESFORCO, kmh, seg, recKmh, recSeg);
    }

    function ehSerie() as Boolean {
        return reps > 0;
    }

    function duracaoSeg() as Number {
        if (ehSerie()) {
            return reps * seg + (reps - 1) * recSeg;
        }
        return seg;
    }

    function copia() as ItemPlano {
        return new ItemPlano(reps, tipo, kmh, seg, recKmh, recSeg);
    }

    function toArray() as Array {
        return [reps, tipo as Number, kmh, seg, recKmh, recSeg];
    }

    // null se o array não tiver o formato/faixas esperados.
    static function fromArray(a as Array) as ItemPlano? {
        if (a.size() != 6) { return null; }
        var reps = a[0]; var tipo = a[1]; var kmh = a[2]; var seg = a[3]; var recKmh = a[4]; var recSeg = a[5];
        if (!(reps instanceof Number) || !(tipo instanceof Number) || !(seg instanceof Number)
                || !(recSeg instanceof Number) || !Personalizados.ehNumero(kmh) || !Personalizados.ehNumero(recKmh)) {
            return null;
        }
        var r = reps as Number;
        var t = tipo as Number;
        if (r < 0 || r > Personalizados.MAX_REPS || t < 0 || t > 3) { return null; }
        var item = new ItemPlano(r, t as TipoBloco, (kmh as Numeric).toFloat(), seg as Number,
                                 (recKmh as Numeric).toFloat(), recSeg as Number);
        if (!Personalizados.ritmoValido(item.kmh) || !Personalizados.tempoValido(item.seg)) { return null; }
        if (item.ehSerie() && (!Personalizados.ritmoValido(item.recKmh) || !Personalizados.tempoValido(item.recSeg))) {
            return null;
        }
        return item;
    }

    // Texto curto para menus. Ex.: rótulo "Série 8x", detalhe "E 13,0 1:00 + R 7,0 1:30".
    function rotulo() as String {
        return ehSerie() ? "Série " + reps.toString() + "x" : Tela.nomeTipo(tipo);
    }

    function detalhe(unidade as Unidades.Unidade) as String {
        if (ehSerie()) {
            return "E " + Unidades.valorRitmo(kmh, unidade, ",") + " " + Unidades.formatarTempo(seg)
                + " + R " + Unidades.valorRitmo(recKmh, unidade, ",") + " " + Unidades.formatarTempo(recSeg);
        }
        return Unidades.formatarRitmo(kmh, unidade) + " - " + Unidades.formatarTempo(seg);
    }
}

class TreinoPersonalizado {
    public var nome as String;
    public var itens as Array<ItemPlano>;

    function initialize(nome as String, itens as Array<ItemPlano>) {
        self.nome = nome;
        self.itens = itens;
    }

    // Plano -> lista de intervalos que o MotorTreino executa.
    function expandir() as Treino {
        var blocos = [] as Array<Intervalo>;
        for (var i = 0; i < itens.size(); i++) {
            var it = itens[i];
            if (it.ehSerie()) {
                for (var r = 0; r < it.reps; r++) {
                    blocos.add(new Intervalo(TIPO_ESFORCO, it.kmh, it.seg));
                    if (r < it.reps - 1) {
                        blocos.add(new Intervalo(TIPO_RECUPERACAO, it.recKmh, it.recSeg));
                    }
                }
            } else {
                blocos.add(new Intervalo(it.tipo, it.kmh, it.seg));
            }
        }
        return new Treino(nome, blocos);
    }

    function duracaoSeg() as Number {
        var total = 0;
        for (var i = 0; i < itens.size(); i++) {
            total += itens[i].duracaoSeg();
        }
        return total;
    }

    function toDict() as Dictionary {
        var arr = [] as Array<Array>;
        for (var i = 0; i < itens.size(); i++) {
            arr.add(itens[i].toArray());
        }
        return { "n" => nome, "i" => arr };
    }

    // null se o formato for inválido; itens inválidos são descartados.
    static function fromDict(d as Dictionary) as TreinoPersonalizado? {
        var n = d["n"];
        var i = d["i"];
        if (!(n instanceof String) || !(i instanceof Array)) { return null; }
        var brutos = i as Array;
        var itens = [] as Array<ItemPlano>;
        for (var k = 0; k < brutos.size() && itens.size() < Personalizados.MAX_ITENS; k++) {
            if (brutos[k] instanceof Array) {
                var item = ItemPlano.fromArray(brutos[k] as Array);
                if (item != null) {
                    itens.add(item);
                }
            }
        }
        return new TreinoPersonalizado(n as String, itens);
    }
}

module Personalizados {

    const MAX_TREINOS = 10;
    const MAX_ITENS = 20;
    const MAX_REPS = 30;
    const MAX_NOME = 20;
    const MIN_SEG = 5;
    const MAX_SEG = 3600;
    const MIN_KMH = 3.0;
    const MAX_KMH = 25.0;

    const CHAVE_ATIVO = "persAtivo";            // slot do treino em uso (-1 = automático)
    const CHAVE_IMPORTADO = "persTextoImportado"; // último texto do celular já importado
    const CHAVE_ERRO = "persErroTexto";         // erro do último texto do celular
    const PROP_TEXTO = "treinosTexto";          // Property editada no Garmin Connect

    function ehNumero(v) as Boolean {
        return v instanceof Number || v instanceof Float || v instanceof Double;
    }

    function ritmoValido(kmh as Float) as Boolean {
        return kmh >= MIN_KMH && kmh <= MAX_KMH;
    }

    function tempoValido(seg as Number) as Boolean {
        return seg >= MIN_SEG && seg <= MAX_SEG;
    }

    // ---- Armazenamento ----

    function chave(slot as Number) as String {
        return "pers" + slot.toString();
    }

    function ler(slot as Number) as TreinoPersonalizado? {
        if (slot < 0 || slot >= MAX_TREINOS) { return null; }
        var v = null;
        try {
            v = Storage.getValue(chave(slot));
        } catch (e) {
            return null;
        }
        if (v instanceof Dictionary) {
            return TreinoPersonalizado.fromDict(v as Dictionary);
        }
        return null;
    }

    function gravar(slot as Number, t as TreinoPersonalizado) as Boolean {
        try {
            Storage.setValue(chave(slot), t.toDict() as Dictionary<Application.PropertyKeyType, Application.PropertyValueType>);
            return true;
        } catch (e) {
            return false;
        }
    }

    function apagar(slot as Number) as Void {
        Storage.deleteValue(chave(slot));
        if (ativo() == slot) {
            setAtivo(-1);
        }
    }

    // Slots ocupados, em ordem.
    function slots() as Array<Number> {
        var r = [] as Array<Number>;
        for (var s = 0; s < MAX_TREINOS; s++) {
            if (ler(s) != null) {
                r.add(s);
            }
        }
        return r;
    }

    function slotLivre() as Number {
        for (var s = 0; s < MAX_TREINOS; s++) {
            if (ler(s) == null) {
                return s;
            }
        }
        return -1;
    }

    function slotPorNome(nome as String) as Number {
        for (var s = 0; s < MAX_TREINOS; s++) {
            var t = ler(s);
            if (t != null && t.nome.equals(nome)) {
                return s;
            }
        }
        return -1;
    }

    // ---- Treino ativo ----

    function ativo() as Number {
        var v = Storage.getValue(CHAVE_ATIVO);
        if (v instanceof Number && ler(v as Number) != null) {
            return v as Number;
        }
        return -1;
    }

    function setAtivo(slot as Number) as Void {
        Storage.setValue(CHAVE_ATIVO, slot);
    }

    // Treino a executar quando o usuário aperta START: o personalizado ativo, ou o gerado
    // pela duração. null se o personalizado ativo estiver vazio.
    function treinoParaIniciar() as Treino? {
        var t = ler(ativo());
        if (t != null) {
            var treino = t.expandir();
            return treino.intervalos.size() > 0 ? treino : null;
        }
        return Gerador.gerar(Config.ritmoMax(), Config.duracaoMin());
    }

    // ---- Criação ----

    function nomeNovo(base as String) as String {
        for (var n = 1; n <= MAX_TREINOS + 1; n++) {
            var nome = base + " " + n.toString();
            if (slotPorNome(nome) < 0) {
                return nome;
            }
        }
        return base;
    }

    // Novo treino já preenchido com um exemplo (mais rápido editar do que montar do zero).
    // Devolve o slot criado, ou -1 se não houver espaço.
    function criarExemplo() as Number {
        var s = slotLivre();
        if (s < 0) { return -1; }
        var v = Config.ritmoMax();
        var rec = Gerador.pctV(v, 0.50);
        if (rec < Gerador.RECUPERACAO_MIN) { rec = Gerador.RECUPERACAO_MIN; }
        var itens = [
            ItemPlano.bloco(TIPO_AQUECIMENTO, Gerador.CAMINHADA, 120),
            ItemPlano.bloco(TIPO_AQUECIMENTO, Gerador.pctV(v, 0.58), 180),
            ItemPlano.serie(8, Gerador.pctV(v, 0.90), 60, rec, 90),
            ItemPlano.bloco(TIPO_DESAQUECIMENTO, Gerador.pctV(v, 0.50), 180),
            ItemPlano.bloco(TIPO_DESAQUECIMENTO, Gerador.CAMINHADA_FINAL, 60)
        ] as Array<ItemPlano>;
        gravar(s, new TreinoPersonalizado(nomeNovo("Treino"), itens));
        return s;
    }

    function duplicar(slot as Number) as Number {
        var t = ler(slot);
        var s = slotLivre();
        if (t == null || s < 0) { return -1; }
        var base = t.nome.length() > MAX_NOME - 3 ? t.nome.substring(0, MAX_NOME - 3) as String : t.nome;
        var itens = [] as Array<ItemPlano>;
        for (var i = 0; i < t.itens.size(); i++) {
            itens.add(t.itens[i].copia());
        }
        gravar(s, new TreinoPersonalizado(nomeNovo(base), itens));
        return s;
    }

    // ---- Importação do texto do celular ----

    // Importa só quando o texto mudou: assim, edições feitas no relógio não são
    // sobrescritas a cada abertura do app. Treinos com o mesmo nome são substituídos.
    function importarDoCelular() as Void {
        var texto = "";
        try {
            var v = Properties.getValue(PROP_TEXTO);
            if (v instanceof String) {
                texto = v as String;
            }
        } catch (e) {
            return;
        }
        var anterior = Storage.getValue(CHAVE_IMPORTADO);
        if (anterior instanceof String && (anterior as String).equals(texto)) {
            return;
        }
        Storage.setValue(CHAVE_IMPORTADO, texto);

        var res = TextoTreino.parsear(texto);
        if (res.erro != null) {
            Storage.setValue(CHAVE_ERRO, res.erro);
            return;
        }
        Storage.deleteValue(CHAVE_ERRO);
        for (var i = 0; i < res.treinos.size(); i++) {
            var t = res.treinos[i];
            var s = slotPorNome(t.nome);
            if (s < 0) {
                s = slotLivre();
            }
            if (s < 0) {
                Storage.setValue(CHAVE_ERRO, "Limite de " + MAX_TREINOS.toString() + " treinos: '" + t.nome + "' não importado");
                return;
            }
            gravar(s, t);
        }
    }

    function erroImportacao() as String? {
        var v = Storage.getValue(CHAVE_ERRO);
        return v instanceof String ? v as String : null;
    }
}
