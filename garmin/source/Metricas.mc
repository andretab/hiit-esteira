// Metricas.mc — calorias, distância e frequência cardíaca do treino.
//
// Decisões:
// - Calorias integradas segundo a segundo (na verdade, a cada tick de 250 ms):
//     * com FC válida   -> Keytel et al. (2005): usa FC, peso, idade e sexo. Num HIIT a FC
//                          reflete o esforço real (inclusive inclinação, que o app não sabe).
//     * sem FC (sensor travando, sem sinal) -> ACSM pelo ritmo-alvo (equação metabólica de
//                          caminhada/corrida, inclinação 0%).
//   Assim um buraco de sinal não zera nem distorce o total.
// - Ambas as fórmulas dão gasto BRUTO (inclui o metabolismo de repouso), como a Garmin mostra.
// - Distância = soma de ritmo-alvo x tempo. Na esteira, o ritmo real é o alvo.
// - Perfil (peso, idade, sexo, zonas de FC de corrida) vem do UserProfile; se faltar algo,
//   usamos padrões (70 kg, 35 anos, zonas por % de 220 - idade).
// - As fórmulas são funções puras (testadas em Testes.mc); o coletor só integra.

import Toybox.Lang;
import Toybox.Math;
import Toybox.Sensor;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.UserProfile;

module Metricas {

    const PESO_PADRAO_KG = 70.0;
    const IDADE_PADRAO = 35;
    const FC_MIN_VALIDA = 40;
    const FC_MAX_VALIDA = 230;
    const KMH_CORRIDA = 7.0;    // abaixo disso usamos a equação de caminhada do ACSM

    // ---- Fórmulas (puras) ----

    // ACSM: VO2 (ml/kg/min) = 3,5 + k x velocidade (m/min); k = 0,1 caminhando, 0,2 correndo.
    // kcal/min = VO2 (L/min) x 5.
    function kcalPorMinAcsm(kmh as Float, pesoKg as Float) as Float {
        var mPorMin = kmh * 1000.0 / 60.0;
        var k = kmh < KMH_CORRIDA ? 0.1 : 0.2;
        var vo2 = 3.5 + k * mPorMin;
        return vo2 * pesoKg / 1000.0 * 5.0;
    }

    // Keytel (2005). genero: UserProfile.GENDER_MALE / GENDER_FEMALE, ou null (média dos dois).
    function kcalPorMinKeytel(fc as Number, pesoKg as Float, idade as Number, genero as Number?) as Float {
        var masc = (-55.0969 + 0.6309 * fc + 0.1988 * pesoKg + 0.2017 * idade) / 4.184;
        var fem = (-20.4022 + 0.4472 * fc - 0.1263 * pesoKg + 0.074 * idade) / 4.184;
        var r;
        if (genero == UserProfile.GENDER_MALE) {
            r = masc;
        } else if (genero == UserProfile.GENDER_FEMALE) {
            r = fem;
        } else {
            r = (masc + fem) / 2.0;
        }
        return r > 0.0 ? r : 0.0;
    }

    // Zona 1..5 a partir dos 6 limites do perfil Garmin [mín Z1, máx Z1, máx Z2, máx Z3,
    // máx Z4, máx Z5]. 0 = abaixo da Z1.
    function zonaDe(fc as Number, limites as Array<Number>) as Number {
        if (limites.size() < 6 || fc < limites[0]) {
            return 0;
        }
        for (var z = 1; z <= 5; z++) {
            if (fc <= limites[z]) {
                return z;
            }
        }
        return 5;
    }

    // Zonas padrão (50/60/70/80/90/100% da FC máx = 220 - idade) se o perfil não tiver.
    function limitesPadrao(idade as Number) as Array<Number> {
        var max = 220 - idade;
        return [
            Math.round(max * 0.5).toNumber(), Math.round(max * 0.6).toNumber(),
            Math.round(max * 0.7).toNumber(), Math.round(max * 0.8).toNumber(),
            Math.round(max * 0.9).toNumber(), max
        ] as Array<Number>;
    }

    function fcValida(fc as Number?) as Boolean {
        return fc != null && fc >= FC_MIN_VALIDA && fc <= FC_MAX_VALIDA;
    }

    // ---- Leitura do relógio ----

    // FC atual do sensor (óptico do pulso ou cinta pareada), ou null.
    function fcAtual() as Number? {
        var info = Sensor.getInfo();
        if (info has :heartRate) {
            return info.heartRate;
        }
        return null;
    }

    // Liga também cintas/sensores externos de FC, se houver (o óptico já vem ligado).
    function ligarSensorFc() as Void {
        try {
            Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE] as Array<Sensor.SensorType>);
        } catch (e) {
            // sem permissão/sensor: seguimos com o que houver
        }
    }
}

// Perfil do usuário com valores padrão para o que faltar.
class PerfilMetricas {
    public var pesoKg as Float = Metricas.PESO_PADRAO_KG;
    public var idade as Number = Metricas.IDADE_PADRAO;
    public var genero as Number? = null;
    public var limites as Array<Number>;

    function initialize() {
        var limitesPerfil = null;
        try {
            var p = UserProfile.getProfile();
            if (p.weight != null && p.weight > 20000) {          // gramas
                pesoKg = p.weight / 1000.0;
            }
            if (p.birthYear != null) {
                var ano = Gregorian.info(Time.now(), Time.FORMAT_SHORT).year as Number;
                var i = ano - (p.birthYear as Number);
                if (i >= 10 && i <= 100) {
                    idade = i;
                }
            }
            genero = p.gender;
            limitesPerfil = UserProfile.getHeartRateZones(UserProfile.HR_ZONE_SPORT_RUNNING);
        } catch (e) {
            // perfil indisponível: ficam os padrões
        }
        if (limitesPerfil != null && limitesPerfil.size() >= 6) {
            limites = limitesPerfil;
        } else {
            limites = Metricas.limitesPadrao(idade);
        }
    }
}

// Acumula as métricas ao longo do treino. amostrar() é chamado a cada tick com o tempo
// que passou, o ritmo-alvo do bloco e a FC lida (ou null).
class ColetorMetricas {
    public var kcal as Float = 0.0;
    public var km as Float = 0.0;
    public var fcMax as Number = 0;
    public var zonasSeg as Array<Float> = [0.0, 0.0, 0.0, 0.0, 0.0] as Array<Float>;  // Z1..Z5
    private var _somaFc as Float = 0.0;     // FC x segundos (média ponderada pelo tempo)
    private var _segComFc as Float = 0.0;
    private var _perfil as PerfilMetricas;

    function initialize(perfil as PerfilMetricas) {
        _perfil = perfil;
    }

    function amostrar(dtSeg as Float, kmh as Float, fc as Number?) as Void {
        if (dtSeg <= 0.0) {
            return;
        }
        km += kmh * dtSeg / 3600.0;
        var kcalMin;
        if (Metricas.fcValida(fc)) {
            var f = fc as Number;
            _somaFc += f * dtSeg;
            _segComFc += dtSeg;
            if (f > fcMax) {
                fcMax = f;
            }
            var z = Metricas.zonaDe(f, _perfil.limites);
            if (z >= 1) {
                zonasSeg[z - 1] += dtSeg;
            }
            kcalMin = Metricas.kcalPorMinKeytel(f, _perfil.pesoKg, _perfil.idade, _perfil.genero);
        } else {
            kcalMin = Metricas.kcalPorMinAcsm(kmh, _perfil.pesoKg);
        }
        kcal += kcalMin * dtSeg / 60.0;
    }

    function temFc() as Boolean {
        return _segComFc > 0.0;
    }

    function fcMedia() as Number {
        return _segComFc > 0.0 ? Math.round(_somaFc / _segComFc).toNumber() : 0;
    }

    // Fecha as métricas. kcalGarmin (da gravação da atividade) tem prioridade sobre a estimativa.
    function resumo(kcalGarmin as Number?) as ResumoMetricas {
        var k = kcalGarmin != null ? kcalGarmin : Math.round(kcal).toNumber();
        return new ResumoMetricas(k, km, fcMedia(), fcMax, zonasInteiras());
    }

    // Zonas em segundos inteiros (para gravar no histórico).
    function zonasInteiras() as Array<Number> {
        var r = [] as Array<Number>;
        for (var i = 0; i < 5; i++) {
            r.add(Math.round(zonasSeg[i]).toNumber());
        }
        return r;
    }
}

// Métricas finais de um treino (tela de resumo e histórico).
// kcal vem da Garmin quando a atividade foi gravada; senão, da nossa estimativa.
class ResumoMetricas {
    public var kcal as Number;
    public var km as Float;
    public var fcMedia as Number;      // 0 = sem FC
    public var fcMax as Number;
    public var zonasSeg as Array<Number>;   // Z1..Z5 em segundos

    function initialize(kcal as Number, km as Float, fcMedia as Number, fcMax as Number, zonasSeg as Array<Number>) {
        self.kcal = kcal;
        self.km = km;
        self.fcMedia = fcMedia;
        self.fcMax = fcMax;
        self.zonasSeg = zonasSeg;
    }

    function temFc() as Boolean {
        return fcMedia > 0;
    }

    // "312 kcal · 4,2 km"
    function textoGasto() as String {
        var d = Math.round(km * 10.0).toNumber();
        return kcal.toString() + " kcal · " + (d / 10).toString() + "," + (d % 10).toString() + " km";
    }

    // "FC 145 méd · 178 máx"
    function textoFc() as String {
        return "FC " + fcMedia.toString() + " méd · " + fcMax.toString() + " máx";
    }
}
