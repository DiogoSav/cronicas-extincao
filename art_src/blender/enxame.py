"""Enxame Abissal (insetos): quitina roxa cheia de espinhos, mandíbulas de osso e sacos
biológicos verde-limão acesos. Referência: "referencia facções/enxame abissal".

Infantaria: Rasgador (batedor), Assimilador (foices), Espinhador (espinhos à distância),
Guardião (carapaça de linha de frente), Infestador (sacos de parasitas).
Veículos: Nexo Vital (suporte e cura), Demolidor (ataque pesado), Artilheiro (longo alcance).
Naves: Vespário (caça), Núcleo Aéreo (cura), Bombardeiro (ataque em área).
Patas são grupos limb_<lado><i>; asas, wing_l / wing_r (o render de sprites anima).
"""

import math
import random

from core import Model
from palettes import INSECT as P


def _legs(m, pairs, hip_z, reach, lift, r, body_y, claw=True):
    """Patas articuladas finas e pontudas, viradas para fora."""
    for i, x in enumerate(pairs):
        for s in (1, -1):
            hip = (x, body_y * s, hip_z)
            p = m.group("limb_%s%d" % ("l" if s > 0 else "r", i), hip)
            knee = (x * 1.2, (body_y + reach * 0.5) * s, hip_z + lift)
            foot = (x * 1.45 + (0.04 if x >= 0 else -0.04), (body_y + reach) * s, 0.0)
            p.sphere(hip, r * 1.4, "dark")
            p.tube(hip, knee, r * 1.2, "chitin")
            p.cone((knee[0], knee[1], knee[2] + r * 1.5), r * 0.7, r * 3.5, "bone", seg=6)   # espinho no joelho
            p.sphere(knee, r * 1.1, "chitin")
            p.tube(knee, foot, r, "chitin", r2=r * 0.25)


def _shell(b, c, s, spikes=8, seed=1, mat="chitin"):
    """Carapaça: domo de quitina com placas sobrepostas e espinhos curvos de osso."""
    rnd = random.Random(seed)
    b.sphere(c, s, mat, seg=18, rings=10)
    for i in range(3):
        k = 1.0 - i * 0.18
        b.sphere((c[0] - s[0] * 0.25 * i, c[1], c[2] + s[2] * 0.15 * i), (s[0] * 0.55 * k, s[1] * 0.92 * k, s[2] * 0.9 * k),
                 "hull", seg=14, rings=8)
    for i in range(spikes):
        u = (i + 0.5) / spikes
        x = c[0] + s[0] * (0.6 - 1.3 * u)
        side = 1 if i % 2 == 0 else -1
        y = c[1] + s[1] * 0.55 * side * rnd.uniform(0.6, 1.0)
        z = c[2] + s[2] * 0.75
        b.cone((x, y, z + s[2] * 0.2), s[2] * 0.12, s[2] * 0.6, "bone", seg=6,
               rot=(side * -35, -30 - rnd.uniform(0, 20), 0))


def _sacs(b, pts, r):
    """Sacos biológicos acesos com veias escuras."""
    for p in pts:
        b.sphere(p, r, "glow", seg=16, rings=10)
        b.torus(p, r * 0.95, r * 0.08, "dark", seg=16, seg2=4, rot=(90, 0, 0))


def _jaws(b, x, z, s=1.0):
    """Cabeça com olhos acesos e mandíbulas curvas."""
    b.sphere((x, 0, z), (0.07 * s, 0.07 * s, 0.055 * s), "chitin")
    b.sym("sphere", (x + 0.04 * s, 0.035 * s, z + 0.02 * s), (0.02 * s, 0.018 * s, 0.018 * s), "glow")
    b.sym("cone", (x + 0.09 * s, 0.035 * s, z - 0.025 * s), 0.016 * s, 0.1 * s, "bone", axis="x", seg=6,
          rot=(0, 15, -25))


# ---------------------------------------------------------------- infantaria

def rasgador(name):
    """Rasgador: batedor baixo e esguio, garras curvas para a frente."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.06, -0.04, -0.13], 0.17, 0.2, 0.09, 0.012, 0.05)
    _shell(b, (-0.04, 0, 0.18), (0.2, 0.08, 0.06), spikes=6, seed=2)
    _jaws(b, 0.17, 0.18)
    for s in (1, -1):
        b.tube((0.12, 0.05 * s, 0.2), (0.24, 0.09 * s, 0.26), 0.012, "chitin")
        b.cone((0.29, 0.08 * s, 0.22), 0.012, 0.12, "bone", axis="x", seg=6, rot=(0, 40, 0))
    m.loc("muzzle", (0.27, 0, 0.18))
    return m


def assimilador(name):
    """Assimilador: predador de foices erguidas, corpo inclinado para a frente."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.0, -0.12], 0.2, 0.22, 0.12, 0.014, 0.06)
    _shell(b, (-0.08, 0, 0.22), (0.17, 0.1, 0.08), spikes=6, seed=3)
    b.sphere((0.08, 0, 0.3), (0.08, 0.07, 0.09), "chitin", rot=(0, 30, 0))
    _jaws(b, 0.16, 0.38)
    for s in (1, -1):
        b.tube((0.1, 0.06 * s, 0.34), (0.2, 0.11 * s, 0.5), 0.016, "chitin")
        b.sphere((0.2, 0.11 * s, 0.5), 0.022, "dark")
        b.tube((0.2, 0.11 * s, 0.5), (0.34, 0.09 * s, 0.3), 0.014, "bone", r2=0.002)          # foice
    m.loc("muzzle", (0.3, 0, 0.32))
    return m


def espinhador(name):
    """Espinhador: corpo com três sacos acesos nas costas e lançador de espinhos na boca."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.08, -0.03, -0.14], 0.2, 0.21, 0.1, 0.014, 0.07)
    _shell(b, (-0.04, 0, 0.22), (0.2, 0.11, 0.09), spikes=8, seed=4)
    _sacs(b, [(-0.12, 0, 0.3), (-0.02, 0, 0.32), (0.07, 0, 0.3)], 0.045)
    _jaws(b, 0.18, 0.22)
    b.cone((0.28, 0, 0.22), 0.025, 0.1, "glow", axis="x", seg=8, rot=(0, 180, 0))
    m.loc("muzzle", (0.33, 0, 0.22))
    return m


def guardiao(name):
    """Guardião: escudo de carapaça grosso com chifre frontal; segura a linha de frente."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.12, 0.0, -0.13], 0.22, 0.2, 0.08, 0.02, 0.1)
    _shell(b, (-0.02, 0, 0.26), (0.26, 0.17, 0.14), spikes=12, seed=5)
    _sacs(b, [(-0.1, 0.12, 0.25), (-0.1, -0.12, 0.25)], 0.05)
    b.sphere((0.2, 0, 0.24), (0.09, 0.14, 0.1), "hull")                                   # placa frontal
    b.cone((0.3, 0, 0.32), 0.04, 0.18, "bone", axis="x", seg=8, rot=(0, -60, 0))           # chifre
    _jaws(b, 0.27, 0.2, 1.2)
    m.loc("muzzle", (0.36, 0, 0.22))
    return m


def infestador(name):
    """Infestador: abdômen inchado de sacos de parasitas acesos e cabeça pequena."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.08, -0.03, -0.14], 0.2, 0.2, 0.1, 0.014, 0.08)
    b.sphere((-0.06, 0, 0.26), (0.2, 0.15, 0.13), "chitin")
    _sacs(b, [(-0.08, 0.06, 0.34), (-0.08, -0.06, 0.34), (0.04, 0, 0.36), (-0.18, 0, 0.3)], 0.06)
    b.sym("cone", (-0.02, 0.15, 0.3), 0.025, 0.14, "bone", seg=6, rot=(-50, -20, 0))
    _jaws(b, 0.17, 0.24, 0.9)
    m.loc("muzzle", (0.24, 0, 0.26))
    return m


# ---------------------------------------------------------------- veículos

def nexo(name):
    """Nexo Vital: grande organismo de suporte, olhos-saco enormes e braços em arco."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.22, 0.05, -0.12, -0.28], 0.34, 0.32, 0.14, 0.026, 0.16)
    _shell(b, (-0.05, 0, 0.42), (0.38, 0.3, 0.2), spikes=12, seed=6)
    _sacs(b, [(0.22, 0.12, 0.42), (0.22, -0.12, 0.42), (0.1, 0, 0.55), (-0.1, 0.18, 0.46), (-0.1, -0.18, 0.46)], 0.08)
    for s in (1, -1):
        b.tube((0.0, 0.28 * s, 0.55), (0.1, 0.5 * s, 0.85), 0.03, "chitin")
        b.tube((0.1, 0.5 * s, 0.85), (0.35, 0.42 * s, 0.75), 0.022, "bone", r2=0.004)       # garra em arco
    b.sphere((0.36, 0, 0.36), (0.08, 0.1, 0.07), "chitin")
    m.loc("muzzle", (0.4, 0, 0.4))
    return m


def demolidor(name):
    """Demolidor: criatura colossal de carapaça reforçada com presas gigantes curvas."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.3, 0.08, -0.14, -0.34], 0.36, 0.34, 0.12, 0.035, 0.22)
    _shell(b, (-0.08, 0, 0.42), (0.5, 0.34, 0.24), spikes=16, seed=7)
    _sacs(b, [(-0.1, 0.3, 0.4), (-0.1, -0.3, 0.4), (0.12, 0.28, 0.38), (0.12, -0.28, 0.38)], 0.06)
    b.sphere((0.42, 0, 0.36), (0.14, 0.18, 0.12), "chitin")
    b.sym("sphere", (0.5, 0.08, 0.42), (0.03, 0.03, 0.03), "glow")
    for s in (1, -1):                                                                       # presas em foice
        pts = [(0.48, 0.12 * s, 0.32), (0.62, 0.24 * s, 0.4), (0.78, 0.2 * s, 0.5), (0.86, 0.06 * s, 0.46)]
        for a, c in zip(pts, pts[1:]):
            b.tube(a, c, 0.035, "bone", r2=0.022)
        b.cone((0.88, 0.04 * s, 0.44), 0.022, 0.08, "bone", axis="x", seg=6, rot=(0, 30, 0))
    m.loc("muzzle", (0.6, 0, 0.36))
    return m


def artilheiro(name):
    """Artilheiro: dorso alto e arqueado de espinhos e pescoço-canhão que cospe ácido."""
    m = Model(name, P)
    b = m.body
    _legs(m, [0.28, 0.06, -0.16, -0.36], 0.34, 0.32, 0.14, 0.03, 0.18)
    _shell(b, (-0.12, 0, 0.44), (0.48, 0.24, 0.2), spikes=14, seed=8)
    for i in range(6):                                                                      # crista de espinhos
        x = -0.4 + i * 0.12
        b.cone((x, 0, 0.66 + math.sin(i / 5 * math.pi) * 0.12), 0.04, 0.22, "bone", seg=6, rot=(0, -35, 0))
    _sacs(b, [(-0.2, 0.16, 0.5), (-0.2, -0.16, 0.5), (0.02, 0.17, 0.48), (0.02, -0.17, 0.48)], 0.07)
    t = m.group("turret", (0.25, 0, 0.5))
    t.tube((0.25, 0, 0.5), (0.48, 0, 0.62), 0.07, "chitin", r2=0.05)
    t.sphere((0.52, 0, 0.62), (0.08, 0.07, 0.06), "chitin")
    t.cone((0.6, 0, 0.63), 0.04, 0.08, "glow", axis="x", seg=10, rot=(0, 180, 0))
    t.sym("sphere", (0.55, 0.04, 0.66), 0.02, "glow")
    m.loc("muzzle", (0.66, 0, 0.63), "turret")
    return m


# ---------------------------------------------------------------- naves

def _wings(m, root_x, root_z, span, chord, mat="team"):
    """Asas membranosas (grupos wing_l / wing_r) com nervuras de quitina e borda serrilhada."""
    for g, s in (("wing_l", 1), ("wing_r", -1)):
        w = m.group(g, (root_x, 0.08 * s, root_z))
        w.wing((root_x, 0.08 * s, root_z), span, chord, chord * 0.25, 0.01, mat, sweep=chord * 0.9,
               dihedral=0.12, side=s)
        for k in range(4):
            u = (k + 1) / 5
            w.tube((root_x, 0.08 * s, root_z + 0.01),
                   (root_x - chord * 0.9 * u, (0.08 + span * u) * s, root_z + 0.12 * u + 0.01),
                   0.008, "chitin", r2=0.003)
        w.cone((root_x - chord * 0.9, (0.08 + span) * s, root_z + 0.12), 0.012, 0.12, "bone", axis="x",
               seg=6, rot=(0, 160, 0))


def vespario(name):
    """Vespário: predador aéreo esguio, garras dianteiras e asas largas acesas."""
    m = Model(name, P)
    b = m.body
    b.sphere((0.0, 0, 0.0), (0.32, 0.08, 0.07), "chitin")
    _shell(b, (-0.05, 0, 0.02), (0.22, 0.07, 0.05), spikes=6, seed=9)
    _jaws(b, 0.3, 0.0, 0.9)
    for s in (1, -1):
        b.tube((0.15, 0.05 * s, -0.04), (0.3, 0.1 * s, -0.12), 0.014, "chitin")
        b.cone((0.34, 0.09 * s, -0.1), 0.012, 0.1, "bone", axis="x", seg=6, rot=(0, -20, 0))
    b.cone((-0.38, 0, -0.02), 0.03, 0.14, "glow", axis="x", seg=8)                            # ferrão
    _wings(m, 0.02, 0.04, 0.55, 0.3)
    m.loc("muzzle", (0.36, 0, 0.0))
    return m


def nucleo(name):
    """Núcleo Aéreo: organismo de corpo redondo com sacos de esporos pendurados e acesos."""
    m = Model(name, P)
    b = m.body
    _shell(b, (0.0, 0, 0.05), (0.3, 0.22, 0.14), spikes=10, seed=10)
    _sacs(b, [(0.08, 0.1, -0.08), (0.08, -0.1, -0.08), (-0.1, 0.0, -0.1), (0.15, 0, 0.12)], 0.08)
    for i in range(5):
        a = i / 5 * math.tau
        b.tube((math.cos(a) * 0.12, math.sin(a) * 0.12, -0.08), (math.cos(a) * 0.16, math.sin(a) * 0.16, -0.32),
               0.008, "flesh", r2=0.003)
    _jaws(b, 0.3, 0.02, 0.9)
    _wings(m, 0.0, 0.12, 0.62, 0.34)
    m.loc("muzzle", (0.0, 0, -0.2))
    return m


def bombardeiro(name):
    """Bombardeiro: criatura de grande porte, asas enormes e saco ventral de carga corrosiva."""
    m = Model(name, P)
    b = m.body
    b.sphere((0.0, 0, 0.0), (0.55, 0.16, 0.12), "chitin")
    _shell(b, (-0.05, 0, 0.06), (0.42, 0.14, 0.09), spikes=10, seed=11)
    _sacs(b, [(0.0, 0, -0.14), (-0.18, 0, -0.12), (0.17, 0, -0.12)], 0.09)
    _jaws(b, 0.55, 0.0, 1.3)
    b.cone((-0.62, 0, 0.0), 0.05, 0.22, "chitin", axis="x", seg=8)
    _wings(m, 0.05, 0.08, 0.95, 0.5)
    m.loc("muzzle", (0.0, 0, -0.24))
    return m


def all_models():
    return [rasgador("ins_rifle"), assimilador("ins_smg"), espinhador("ins_sniper"), guardiao("ins_mg"),
            infestador("ins_at"), nexo("ins_scout"), demolidor("ins_tank"), artilheiro("ins_heavy"),
            vespario("ins_fighter"), nucleo("ins_nucleo"), bombardeiro("ins_gunship")]
