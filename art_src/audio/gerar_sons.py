"""Gera por síntese os efeitos sonoros do jogo (design/audio/audio-sonoplastia-geral.md).

Python puro (sem numpy): cada som é uma soma de osciladores, ruído e envelopes, com filtros
de um polo. Sementes fixas: rodar de novo produz os mesmos arquivos.

Saída: assets/audio/sfx/<id>_<n>.wav (mono, 16 bits, 22 050 Hz).
Uso:   python art_src/audio/gerar_sons.py [filtro]   (filtro = trecho do id, opcional)

Passo 1 da ordem de produção: combate, interface e alertas críticos. Os sons que a spec
marca como biblioteca CC0 (explosões, impactos pesados) saem daqui como provisórios e
podem ser trocados por gravações depois.
"""
import math
import os
import random
import struct
import sys
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "sfx")


# ------------------------------------------------------------------ blocos básicos

def n_samples(dur):
    return int(dur * RATE)


def silence(dur):
    return [0.0] * n_samples(dur)


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, v in enumerate(t):
            out[i] += v
    return out


def delay(track, secs):
    return silence(secs) + track


def gain(track, g):
    return [v * g for v in track]


def env_ad(n, attack, decay_pow=1.0):
    """Envelope ataque linear + queda (curva por decay_pow) até o fim."""
    a = max(1, int(attack * RATE))
    out = []
    for i in range(n):
        if i < a:
            out.append(i / a)
        else:
            t = (i - a) / max(1, n - a)
            out.append((1.0 - t) ** decay_pow)
    return out


def apply_env(track, env):
    return [v * e for v, e in zip(track, env)]


def osc(dur, f0, f1=None, shape="sine", curve=1.0):
    """Oscilador com glissando de f0 a f1 (curve > 1 cai rápido no começo)."""
    n = n_samples(dur)
    f1 = f0 if f1 is None else f1
    ph = 0.0
    out = []
    for i in range(n):
        t = (i / n) ** (1.0 / curve) if curve != 1.0 else i / n
        f = f0 + (f1 - f0) * t
        ph += f / RATE
        x = ph % 1.0
        if shape == "sine":
            v = math.sin(2 * math.pi * ph)
        elif shape == "square":
            v = 1.0 if x < 0.5 else -1.0
        elif shape == "saw":
            v = 2.0 * x - 1.0
        else:  # triangle
            v = 4.0 * abs(x - 0.5) - 1.0
        out.append(v)
    return out


def noise(dur, rng):
    return [rng.uniform(-1.0, 1.0) for _ in range(n_samples(dur))]


def lowpass(track, c0, c1=None):
    """Passa-baixa de um polo, corte (Hz) indo de c0 a c1 ao longo do som."""
    c1 = c0 if c1 is None else c1
    n = len(track)
    y = 0.0
    out = []
    for i, v in enumerate(track):
        c = c0 + (c1 - c0) * i / max(1, n)
        a = 1.0 - math.exp(-2 * math.pi * c / RATE)
        y += a * (v - y)
        out.append(y)
    return out


def highpass(track, c):
    lp = lowpass(track, c)
    return [v - l for v, l in zip(track, lp)]


def crush(track, levels):
    return [round(v * levels) / levels for v in track]


def normalize(track, peak=0.89):
    m = max((abs(v) for v in track), default=0.0)
    if m <= 0.0:
        return track
    return [v * peak / m for v in track]


def fade_out(track, secs=0.01):
    n = min(len(track), n_samples(secs))
    for i in range(n):
        track[-1 - i] *= i / n
    return track


def write(name, track):
    os.makedirs(OUT, exist_ok=True)
    data = normalize(fade_out(track))
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in data))
    return path


# ------------------------------------------------------------------ receitas

def boom(rng, dur, low=55.0, bright=2200.0, rumble=0.7):
    """Explosão: ruído com corte descendo + grave de corpo."""
    body = apply_env(lowpass(noise(dur, rng), bright, 120.0), env_ad(n_samples(dur), 0.004, 2.2))
    sub = apply_env(osc(dur, low * 1.6, low * 0.7, curve=2.0), env_ad(n_samples(dur), 0.006, 1.6))
    return mix(body, gain(sub, rumble))


def zap(rng, dur, f0, f1, shape="saw", fizz=0.25, bright=6000.0):
    tone = apply_env(osc(dur, f0, f1, shape, curve=2.5), env_ad(n_samples(dur), 0.002, 1.8))
    hiss = apply_env(highpass(noise(dur, rng), 2500.0), env_ad(n_samples(dur), 0.001, 3.0))
    return lowpass(mix(tone, gain(hiss, fizz)), bright)


def wet(rng, dur, cut=1800.0):
    """Estalo úmido: ruído em rajadas curtas com passa-baixa."""
    n = noise(dur, rng)
    gate = []
    k = 0.0
    for i in range(len(n)):
        if rng.random() < 0.004:
            k = 1.0
        k *= 0.995
        gate.append(k)
    return apply_env(lowpass([v * g for v, g in zip(n, gate)], cut), env_ad(len(n), 0.003, 1.2))


def metal(rng, dur, base=420.0):
    """Batida metálica: parciais inarmônicas decaindo."""
    parts = []
    for ratio, amp in ((1.0, 1.0), (2.76, 0.6), (5.4, 0.35), (8.9, 0.2)):
        f = base * ratio * rng.uniform(0.97, 1.03)
        parts.append(gain(apply_env(osc(dur, f), env_ad(n_samples(dur), 0.001, 3.0)), amp))
    return mix(*parts)


def beep(dur, f, shape="sine", vol=1.0):
    return gain(apply_env(osc(dur, f, shape=shape), env_ad(n_samples(dur), 0.004, 1.5)), vol)


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


RECIPES = {}


def recipe(sound_id, variants=1):
    def deco(fn):
        RECIPES[sound_id] = (fn, variants)
        return fn
    return deco


# --- 3.1 armas e impactos
@recipe("sfx_weapon_rifle_fire", 3)
def _rifle(rng):
    return zap(rng, 0.16, rng.uniform(1700, 2000), 380, "saw", 0.3)


@recipe("sfx_weapon_smg_fire", 3)
def _smg(rng):
    return zap(rng, 0.08, rng.uniform(2300, 2600), 900, "square", 0.35, 5000)


@recipe("sfx_weapon_mg_fire", 3)
def _mg(rng):
    shots = []
    for k in range(3):
        shots.append(delay(zap(rng, 0.07, rng.uniform(1500, 1700), 600, "square", 0.4, 4500), k * 0.065))
    return mix(*shots)


@recipe("sfx_weapon_sniper_fire", 2)
def _sniper(rng):
    crack = apply_env(highpass(noise(0.05, rng), 1500.0), env_ad(n_samples(0.05), 0.0005, 2.0))
    beam = zap(rng, 0.22, 3200, 500, "saw", 0.2, 8000)
    tail = apply_env(lowpass(noise(0.5, rng), 900.0, 200.0), env_ad(n_samples(0.5), 0.01, 2.0))
    return mix(crack, beam, gain(tail, 0.35))


@recipe("sfx_weapon_at_fire", 2)
def _at(rng):
    whoosh = apply_env(lowpass(noise(0.45, rng), 600.0, 3500.0), env_ad(n_samples(0.45), 0.02, 1.4))
    thump = apply_env(osc(0.18, 140, 60, curve=2.0), env_ad(n_samples(0.18), 0.002, 2.0))
    return mix(gain(whoosh, 0.8), thump)


@recipe("sfx_weapon_cannon_fire", 2)
def _cannon(rng):
    return mix(boom(rng, 0.8, 50.0, 3000.0, 1.0), gain(metal(rng, 0.25, 180.0), 0.25))


@recipe("sfx_weapon_missile_launch", 2)
def _missile_launch(rng):
    hiss = apply_env(highpass(noise(0.6, rng), 900.0), env_ad(n_samples(0.6), 0.03, 1.2))
    rise = apply_env(osc(0.6, 200, 700, "saw"), env_ad(n_samples(0.6), 0.03, 1.5))
    return mix(hiss, gain(lowpass(rise, 2500.0), 0.3))


@recipe("sfx_weapon_legion_pulse_fire", 3)
def _pulse(rng):
    f = rng.uniform(600, 700)
    p = []
    for k in range(2):
        t = crush(apply_env(osc(0.06, f * 2, f, "square"), env_ad(n_samples(0.06), 0.001, 1.0)), 6)
        p.append(delay(t, k * 0.05))
    return lowpass(mix(*p), 5000.0)


@recipe("sfx_weapon_acid_spit_fire", 3)
def _spit(rng):
    gurgle = apply_env(osc(0.18, rng.uniform(220, 260), 120, "triangle"), env_ad(n_samples(0.18), 0.003, 1.5))
    return mix(wet(rng, 0.22, 2500.0), gain(gurgle, 0.5))


@recipe("sfx_impact_beam", 3)
def _imp_beam(rng):
    return apply_env(highpass(noise(0.09, rng), 1800.0), env_ad(n_samples(0.09), 0.001, 2.5))


@recipe("sfx_impact_at", 2)
def _imp_at(rng):
    return mix(gain(metal(rng, 0.4, rng.uniform(300, 380)), 0.7), boom(rng, 0.35, 90.0, 2500.0, 0.4))


@recipe("sfx_impact_cannon", 2)
def _imp_cannon(rng):
    return boom(rng, 0.7, 60.0, 2600.0, 0.9)


@recipe("sfx_impact_missile", 2)
def _imp_missile(rng):
    return boom(rng, 0.55, 70.0, 3200.0, 0.7)


@recipe("sfx_impact_acid", 2)
def _imp_acid(rng):
    sizzle = apply_env(highpass(noise(0.45, rng), 3000.0), env_ad(n_samples(0.45), 0.01, 1.2))
    return mix(gain(sizzle, 0.6), wet(rng, 0.3, 1500.0))


# --- 3.2 mortes e explosões
@recipe("sfx_death_infantry_human", 3)
def _death_hum(rng):
    thud = apply_env(osc(0.2, rng.uniform(110, 130), 60, curve=2.0), env_ad(n_samples(0.2), 0.002, 2.0))
    gear = apply_env(lowpass(noise(0.3, rng), 1400.0), env_ad(n_samples(0.3), 0.005, 2.0))
    return mix(delay(thud, 0.08), gain(gear, 0.5), gain(delay(metal(rng, 0.15, 900.0), 0.12), 0.15))


@recipe("sfx_death_infantry_explode", 2)
def _death_blast(rng):
    return mix(boom(rng, 0.5, 80.0, 2800.0, 0.6), gain(wet(rng, 0.4, 1200.0), 0.5))


@recipe("sfx_death_robot", 3)
def _death_rob(rng):
    crackle = []
    for k in range(5):
        crackle.append(delay(zap(rng, 0.05, rng.uniform(2500, 4000), 800, "square", 0.6), k * rng.uniform(0.04, 0.08)))
    fall = delay(metal(rng, 0.5, rng.uniform(250, 320)), 0.25)
    down = apply_env(osc(0.5, 400, 60, "saw"), env_ad(n_samples(0.5), 0.01, 1.2))
    return mix(*crackle, gain(fall, 0.8), gain(lowpass(down, 1500.0), 0.4))


@recipe("sfx_death_insect", 3)
def _death_ins(rng):
    chitter = apply_env(crush(osc(0.15, rng.uniform(1800, 2400), 900, "square"), 4), env_ad(n_samples(0.15), 0.002, 2.0))
    return mix(wet(rng, 0.32, 1600.0), gain(lowpass(chitter, 3500.0), 0.3))


@recipe("sfx_explosion_vehicle", 3)
def _exp_veh(rng):
    return mix(boom(rng, 1.1, 50.0, 3000.0, 1.0), gain(delay(metal(rng, 0.6, 200.0), 0.05), 0.3))


@recipe("sfx_explosion_building_small", 2)
def _exp_bld(rng):
    a = boom(rng, 1.4, 45.0, 2600.0, 1.0)
    b = delay(boom(rng, 0.9, 55.0, 1800.0, 0.6), 0.35)
    return mix(a, gain(b, 0.7))


@recipe("sfx_explosion_building_large", 2)
def _exp_big(rng):
    a = boom(rng, 2.6, 35.0, 2400.0, 1.2)
    b = delay(boom(rng, 1.2, 50.0, 2000.0, 0.7), 0.4)
    c = delay(boom(rng, 1.0, 60.0, 1600.0, 0.5), 0.9)
    return mix(a, gain(b, 0.7), gain(c, 0.5))


@recipe("sfx_explosion_organic_burst", 2)
def _exp_org(rng):
    return mix(boom(rng, 1.0, 70.0, 1400.0, 0.8), wet(rng, 0.9, 2200.0))


# --- 3.7 alertas (stinger por facção) e energia
@recipe("sfx_alert_base_attack_sting_hum", 1)
def _sting_hum(rng):
    # Sirene de comando: duas notas de metal, repetidas
    a = beep(0.22, 660, "square", 0.6)
    b = beep(0.22, 494, "square", 0.6)
    return lowpass(seq(a, b, a, b), 3000.0)


@recipe("sfx_alert_base_attack_sting_rob", 1)
def _sting_rob(rng):
    notes = [880, 1175, 880, 659]
    return lowpass(crush(seq(*(beep(0.11, f, "square", 0.6) for f in notes)), 8), 4500.0)


@recipe("sfx_alert_base_attack_sting_ins", 1)
def _sting_ins(rng):
    growl = apply_env(lowpass(mix(osc(0.8, 70, 55, "saw"), gain(noise(0.8, rng), 0.4)), 500.0), env_ad(n_samples(0.8), 0.08, 1.2))
    chit = delay(apply_env(crush(osc(0.3, 2200, 1500, "square"), 4), env_ad(n_samples(0.3), 0.01, 1.5)), 0.4)
    return mix(growl, gain(lowpass(chit, 4000.0), 0.35))


@recipe("sfx_alert_low_power_pulse", 1)
def _low_power(rng):
    down = apply_env(osc(0.5, 220, 110, "saw"), env_ad(n_samples(0.5), 0.01, 1.0))
    return lowpass(seq(down, silence(0.08), down), 1200.0)


# --- 3.9 interface
@recipe("sfx_ui_click", 3)
def _click(rng):
    return mix(beep(0.04, rng.uniform(1900, 2100), "triangle"), gain(apply_env(highpass(noise(0.02, rng), 3000.0), env_ad(n_samples(0.02), 0.0005, 2.0)), 0.4))


@recipe("sfx_ui_hover", 2)
def _hover(rng):
    return beep(0.03, rng.uniform(2700, 2900), "sine", 0.5)


@recipe("sfx_ui_back", 1)
def _back(rng):
    return seq(beep(0.05, 1600, "triangle"), beep(0.06, 1100, "triangle"))


@recipe("sfx_ui_error", 1)
def _error(rng):
    return lowpass(seq(beep(0.09, 330, "square", 0.7), silence(0.03), beep(0.12, 247, "square", 0.7)), 2500.0)


@recipe("sfx_ui_selection_confirm", 3)
def _select(rng):
    return mix(beep(0.035, rng.uniform(1250, 1400), "square", 0.5), gain(apply_env(highpass(noise(0.015, rng), 4000.0), env_ad(n_samples(0.015), 0.0005, 2.0)), 0.5))


@recipe("sfx_ui_order_move_marker", 1)
def _move(rng):
    return seq(beep(0.04, 900, "triangle"), beep(0.06, 1350, "triangle"))


@recipe("sfx_ui_order_attack_marker", 1)
def _attack(rng):
    return lowpass(seq(beep(0.05, 520, "square", 0.7), beep(0.07, 390, "square", 0.7)), 3000.0)


@recipe("sfx_ui_build_queue_add", 1)
def _q_add(rng):
    return seq(beep(0.045, 880, "triangle"), beep(0.045, 1175, "triangle"), beep(0.07, 1568, "triangle"))


@recipe("sfx_ui_build_queue_cancel", 1)
def _q_cancel(rng):
    return seq(beep(0.05, 1175, "triangle"), beep(0.08, 784, "triangle"))


@recipe("sfx_ui_place_ok", 1)
def _place(rng):
    thunk = apply_env(osc(0.18, 160, 70, curve=2.0), env_ad(n_samples(0.18), 0.002, 2.0))
    return mix(thunk, gain(delay(beep(0.15, 1320, "sine"), 0.05), 0.5))


@recipe("sfx_ui_place_invalid", 1)
def _place_bad(rng):
    return lowpass(apply_env(osc(0.22, 140, shape="saw"), env_ad(n_samples(0.22), 0.005, 0.8)), 1500.0)


@recipe("sfx_ui_message_pop", 1)
def _pop(rng):
    return beep(0.08, 1047, "sine", 0.8)


@recipe("sfx_ui_countdown_tick", 1)
def _tick(rng):
    return beep(0.12, 880, "square", 0.6)


@recipe("sfx_ui_countdown_go", 1)
def _go(rng):
    return lowpass(mix(beep(0.4, 1320, "square", 0.6), beep(0.4, 660, "square", 0.4)), 4000.0)


@recipe("sfx_ui_minimap_ping", 1)
def _ping(rng):
    return mix(beep(0.35, 1760, "sine"), gain(beep(0.35, 2637, "sine"), 0.3))


def main():
    flt = sys.argv[1] if len(sys.argv) > 1 else ""
    total = 0
    for sound_id, (fn, variants) in RECIPES.items():
        if flt not in sound_id:
            continue
        for k in range(variants):
            rng = random.Random(f"{sound_id}:{k}")
            write(f"{sound_id}_{k + 1}", fn(rng))
            total += 1
    print(f"{total} arquivos em {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
