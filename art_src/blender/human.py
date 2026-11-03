"""Império da Cinza (humanos): armaduras escuras gastas, estandartes vermelhos com caveira,
pináculos góticos e luzes de brasa. Referência: pasta "referencia facções/imperio cinza".

Infantaria: Soldado, Fuzileiro Pesado, Engenheiro, Médico de Campanha, Comando de Elite.
Veículos: Coletor de Recursos (6 rodas), Transporte Blindado (6 rodas), Tanque de Batalha e
Artilharia Móvel (esteiras). Naves: Caça Interceptor e Cruzador de Batalha.
"""

import math
import random

from core import Model
from palettes import HUMAN as P


# ---------------------------------------------------------------- infantaria

def _legs(m, w=1.0, pad="hull"):
    """Pernas com joelho: coxa de pano, joelheira e caneleira blindadas, bota."""
    for side, g in ((1, "leg_l"), (-1, "leg_r")):
        y = side * 0.075 * w
        p = m.group(g, (0, y, 0.36))
        p.box((0, y, 0.285), (0.1 * w, 0.095 * w, 0.17), "cloth", bev=0.03)
        k = m.group("knee" + g[3:], (0.0, y, 0.205), parent=g)
        k.sphere((0.045 * w, y, 0.205), (0.05 * w, 0.055 * w, 0.05), pad)
        k.box((0.025, y, 0.13), (0.07 * w, 0.075 * w, 0.14), pad, bev=0.02)
        k.box((0.0, y, 0.12), (0.08 * w, 0.08 * w, 0.15), "cloth", bev=0.02)
        k.box((0.03, y, 0.035), (0.16 * w, 0.095 * w, 0.07), "dark", bev=0.02, taper=(0.85, 0.9))


def _body(m, w=1.0, pauldron="team", chest="hull", cloth="cloth", tabard="team"):
    """Tronco: cinto, tabardo rasgado, couraça, ombreiras, braços. Devolve o grupo torso."""
    t = m.group("torso", (0, 0, 0.36))
    t.box((0, 0, 0.4), (0.15 * w, 0.2 * w, 0.07), "accent", bev=0.015)                 # cinto
    if tabard:
        t.box((0.085 * w, 0, 0.3), (0.012, 0.09 * w, 0.17), tabard, taper=(1.0, 1.25))  # tabardo
        t.box((-0.085 * w, 0, 0.3), (0.012, 0.12 * w, 0.18), tabard, taper=(1.0, 1.2))
    t.box((0, 0, 0.47), (0.15 * w, 0.21 * w, 0.1), cloth, bev=0.03)
    t.box((0.005, 0, 0.56), (0.19 * w, 0.26 * w, 0.18), chest, bev=0.05, taper=(0.92, 0.88))
    t.box((0.09 * w, 0, 0.57), (0.03, 0.17 * w, 0.12), "hull", bev=0.015)
    t.box((0.107 * w, 0, 0.585), (0.008, 0.06, 0.035), "skull")                       # águia no peito
    t.cyl((0, 0, 0.665), 0.075 * w, 0.03, "hull", seg=14)                               # gorjal
    # ombreiras e braços (os braços seguram a arma à frente do peito)
    t.sym("sphere", (0.0, 0.16 * w, 0.63), (0.085 * w, 0.08 * w, 0.06), pauldron)
    t.sym("cyl", (0.0, 0.16 * w, 0.6), 0.085 * w, 0.012, "dark", seg=16)
    t.sym("box", (0.03, 0.165 * w, 0.52), (0.065, 0.06, 0.14), cloth, bev=0.02)
    t.sym("box", (0.1, 0.12 * w, 0.5), (0.13, 0.055, 0.055), "hull", bev=0.015)
    return t


def _gas_helmet(t, eyes="glow", helm="hull", hood=None, w=1.0):
    """Capacete arredondado com máscara de gás e olhos acesos."""
    if hood:
        t.sphere((-0.005, 0, 0.74), (0.095 * w, 0.09 * w, 0.1), hood, seg=18, rings=12)
        t.cone((-0.07, 0, 0.8), 0.04, 0.08, hood, rot=(0, -60, 0), seg=10)
    else:
        t.sphere((0.0, 0, 0.75), (0.085 * w, 0.085 * w, 0.075), helm, seg=20, rings=12)
        t.cyl((0.0, 0, 0.735), 0.1 * w, 0.012, "dark", seg=20)                         # aba
    t.sphere((0.045, 0, 0.715), (0.05, 0.06, 0.055), "dark", seg=14, rings=10)
    t.cyl((0.095, 0, 0.695), 0.026, 0.04, "metal", axis="x", seg=10)                   # filtro
    t.sym("cyl", (0.088, 0.027, 0.735), 0.017, 0.012, eyes, axis="x", seg=10)
    t.tube((0.1, 0.0, 0.69), (-0.05, -0.07, 0.62), 0.007, "dark")                       # mangueira


def _lasgun(t, y=-0.07, z=0.53):
    t.box((0.03, y, z), (0.1, 0.035, 0.05), "accent", bev=0.008)                        # coronha
    t.box((0.15, y, z + 0.005), (0.16, 0.04, 0.055), "hull", bev=0.01)
    t.box((0.13, y, z - 0.045), (0.035, 0.03, 0.06), "dark", rot=(0, 15, 0))
    t.cyl((0.27, y, z + 0.01), 0.018, 0.1, "dark", axis="x", seg=10)
    t.cyl((0.34, y, z + 0.01), 0.009, 0.06, "metal", axis="x", seg=8)
    t.box((0.16, y, z + 0.037), (0.04, 0.015, 0.008), "glow")
    return (0.37, y, z + 0.01)


def soldado(name):
    m = Model(name, P)
    _legs(m)
    t = _body(m)
    t.box((-0.12, 0, 0.55), (0.08, 0.19, 0.18), "accent", bev=0.025)                   # mochila
    t.cyl((-0.12, 0, 0.665), 0.035, 0.2, "cloth", axis="y", seg=12)                     # manta
    t.sym("sphere", (0.0, 0.205, 0.64), (0.012, 0.035, 0.035), "skull")                 # caveira na ombreira
    _gas_helmet(t)
    m.loc("muzzle", _lasgun(t), "torso")
    return m


def fuzileiro(name):
    """Fuzileiro Pesado: armadura larga, ombreiras enormes, metralhadora rotativa e tambor."""
    m = Model(name, P)
    w = 1.35
    _legs(m, w, pad="hull")
    t = _body(m, w, pauldron="hull", chest="hull")
    for s in (1, -1):
        t.cyl((0.0, 0.16 * w * s, 0.6), 0.088 * w, 0.025, "team", seg=18)               # borda vermelha
        t.box((0.0, 0.225 * w * s, 0.63), (0.05, 0.008, 0.04), "skull")
    t.cyl((-0.16, 0, 0.55), 0.1, 0.22, "metal", axis="y", seg=18)                       # tambor de munição
    t.cyl((-0.16, 0, 0.55), 0.105, 0.03, "dark", axis="y", seg=18)
    t.sphere((0.02, 0, 0.73), (0.09, 0.1, 0.08), "hull", seg=18, rings=10)              # elmo afundado
    t.box((0.085, 0, 0.72), (0.03, 0.11, 0.03), "glow")                                 # visor
    t.cyl((0.1, 0, 0.68), 0.022, 0.03, "metal", axis="x", seg=10)
    # metralhadora rotativa no quadril direito
    y, z = -0.1, 0.47
    t.box((0.1, y, z), (0.18, 0.09, 0.1), "hull", bev=0.02)
    t.box((0.1, y, z + 0.065), (0.08, 0.02, 0.03), "dark")                              # alça
    for a in range(6):
        dy = math.cos(a * math.pi / 3) * 0.024
        dz = math.sin(a * math.pi / 3) * 0.024
        t.cyl((0.31, y + dy, z + dz), 0.012, 0.24, "metal", axis="x", seg=8)
    for x in (0.22, 0.4):
        t.cyl((x, y, z), 0.045, 0.02, "dark", axis="x", seg=14)
    for i in range(6):                                                                  # fita de munição
        u = i / 5
        t.box((-0.12 + 0.2 * u, -0.06 - 0.06 * math.sin(u * math.pi), 0.47 - 0.04 * math.sin(u * math.pi)),
              (0.03, 0.025, 0.02), "accent")
    m.loc("muzzle", (0.44, y, z), "torso")
    return m


def engenheiro(name):
    """Engenheiro: óculos de visão noturna, braço mecânico sobre a cabeça, chave e tablet."""
    m = Model(name, P)
    _legs(m)
    t = _body(m, pauldron="hull")
    t.sphere((0.0, 0.17, 0.63), (0.09, 0.085, 0.065), "team")                            # ombreira com manto
    t.box((-0.1, 0.06, 0.45), (0.012, 0.16, 0.34), "team", taper=(1.0, 1.3))           # manto vermelho
    t.box((-0.13, 0, 0.56), (0.09, 0.18, 0.2), "metal", bev=0.02)                       # mochila de servo
    t.cyl((-0.14, -0.06, 0.56), 0.03, 0.16, "accent", seg=10)
    arm = [(-0.14, -0.05, 0.66), (-0.15, -0.05, 0.9), (0.05, -0.05, 0.95), (0.13, -0.05, 0.86)]
    for a, b in zip(arm, arm[1:]):
        t.tube(a, b, 0.016, "hull")
    for p in arm[1:3]:
        t.sphere(p, 0.025, "dark")
    for s in (1, -1):
        t.tube(arm[-1], (0.17, -0.05 + 0.025 * s, 0.81), 0.008, "metal")              # garra
    _gas_helmet(t, eyes="dark")
    t.sym("cyl", (0.1, 0.027, 0.745), 0.022, 0.05, "dark", axis="x", seg=10)            # óculos NV
    t.sym("cyl", (0.126, 0.027, 0.745), 0.018, 0.006, "glow", axis="x", seg=10)
    t.box((0.2, 0.1, 0.56), (0.008, 0.09, 0.07), "glass", rot=(0, -20, 0))             # tablet holográfico
    t.box((0.2, 0.1, 0.56), (0.004, 0.08, 0.06), "glow", rot=(0, -20, 0))
    t.cyl((0.24, -0.08, 0.5), 0.01, 0.16, "metal", axis="x", seg=8)                     # chave/maçarico
    t.box((0.33, -0.08, 0.5), (0.03, 0.035, 0.025), "metal")
    m.loc("muzzle", (0.35, -0.08, 0.5), "torso")
    return m


def medico(name):
    """Médico de Campanha: capuz e tabardo brancos sujos, cruz vermelha, maleta e injetor."""
    m = Model(name, P)
    _legs(m, pad="dark")
    t = _body(m, pauldron="white", tabard=None)
    t.box((0.095, 0, 0.36), (0.012, 0.16, 0.34), "white", taper=(1.0, 1.15))           # tabardo branco longo
    t.box((-0.095, 0, 0.38), (0.012, 0.18, 0.36), "white", taper=(1.0, 1.15))
    t.box((0.103, 0, 0.5), (0.006, 0.025, 0.09), "team")                               # cruz vermelha
    t.box((0.103, 0, 0.51), (0.006, 0.075, 0.025), "team")
    t.sym("box", (0.0, 0.2, 0.655), (0.025, 0.006, 0.07), "team", rot=(0, 0, 0))
    t.box((0.02, 0.15, 0.4), (0.09, 0.05, 0.08), "white", bev=0.01)                     # maleta
    t.box((0.02, 0.177, 0.4), (0.03, 0.004, 0.012), "team")
    t.box((0.02, 0.177, 0.4), (0.012, 0.004, 0.03), "team")
    t.cyl((0.12, 0.1, 0.42), 0.018, 0.05, "glow", seg=10)                               # frasco de soro
    _gas_helmet(t, hood="white")
    t.cyl((0.2, -0.08, 0.52), 0.016, 0.1, "metal", axis="x", seg=10)                    # injetor
    t.cyl((0.26, -0.08, 0.52), 0.004, 0.05, "metal", axis="x", seg=6)
    m.loc("muzzle", (0.29, -0.08, 0.52), "torso")
    return m


def comando(name):
    """Comando de Elite: ghillie de trapos, olhos vermelhos e fuzil de precisão longo."""
    m = Model(name, P)
    _legs(m, pad="ghillie")
    t = _body(m, pauldron="ghillie", chest="cloth", tabard=None)
    _gas_helmet(t, hood="ghillie")
    rnd = random.Random(7)
    for i in range(46):                                                                 # tiras de ghillie
        a = rnd.uniform(0, 2 * math.pi)
        top = rnd.uniform(0.42, 0.8)
        r = 0.12 if top < 0.68 else 0.08
        x, y = math.cos(a) * r * 0.8, math.sin(a) * r
        if x > 0.05 and y < 0 and top < 0.62:
            continue                                                                    # deixa a arma livre
        ln = rnd.uniform(0.08, 0.2)
        t.box((x, y, top - ln / 2), (0.012, 0.025, ln), "ghillie" if i % 3 else "cloth",
              rot=(rnd.uniform(-12, 12), rnd.uniform(-12, 12), math.degrees(a)))
    y, z = -0.07, 0.58
    t.box((0.02, y, z), (0.12, 0.03, 0.05), "accent", bev=0.008)
    t.box((0.15, y, z + 0.005), (0.16, 0.035, 0.045), "dark", bev=0.008)
    t.cyl((0.14, y, z + 0.05), 0.018, 0.13, "metal", axis="x", seg=10)                  # luneta
    t.cyl((0.075, y, z + 0.05), 0.012, 0.004, "glow", axis="x", seg=8)
    t.cyl((0.36, y, z + 0.01), 0.008, 0.28, "dark", axis="x", seg=8)
    t.cyl((0.49, y, z + 0.01), 0.014, 0.05, "metal", axis="x", seg=8)                    # supressor
    m.loc("muzzle", (0.52, y, z + 0.01), "torso")
    return m


# ---------------------------------------------------------------- veículos

## Espaçamento das sapatas da esteira (o jogo usa o mesmo valor para rolar as faixas)
TREAD = 0.07


def _tracks(m, x, y, length, h, w, mat="dark"):
    """Esteiras: rodas giratórias (wheel_<lado><i>) e duas faixas de sapatas na face de fora
    (treadf_* corre para frente em cima, treadb_* para trás embaixo)."""
    p = m.body
    for s in (1, -1):
        side = "l" if s > 0 else "r"
        yy = y * s
        p.box((x, yy, h / 2 + 0.01), (length, w, h), mat, bev=h * 0.4, seg=3)
        p.box((x, yy, h + 0.02), (length * 1.02, w * 1.15, 0.03), "hull", bev=0.01)
        for i in range(5):
            xx = x - length * 0.38 + i * length * 0.19
            wc = (xx, yy + (w / 2 + 0.008) * s, h / 2 + 0.01)
            g = m.group("wheel_%s%d" % (side, i), wc)
            g.cyl(wc, h * 0.36, 0.022, "metal", axis="y", seg=16)
            g.box((xx, wc[1] + 0.012 * s, wc[2]), (h * 0.62, 0.01, 0.03), "dark")
            g.box((xx, wc[1] + 0.012 * s, wc[2]), (0.03, 0.01, h * 0.62), "dark")
        n = int(length * 0.92 / TREAD)
        face = yy + (w / 2 + 0.004) * s
        for name, z in (("treadf", h * 0.93), ("treadb", h * 0.1)):
            g = m.group("%s_%s" % (name, side), (x, face, z))
            for k in range(n):
                xx = x - (n - 1) * TREAD / 2 + k * TREAD
                g.box((xx, face, z), (0.03, 0.014, h * 0.14), "metal", bev=0.004)


def _wheels6(m, xs, y, r, wid):
    """Seis rodas grossas de caminhão militar (as da frente, índice 0, esterçam)."""
    for i, sx in enumerate(xs):
        for s in (1, -1):
            wc = (sx, y * s, r)
            g = m.group("wheel_%s%d" % ("l" if s > 0 else "r", i), wc)
            g.cyl(wc, r, wid, "dark", axis="y", seg=18, bev=0.03)
            for k in range(8):                                                          # cravos
                a = k * math.pi / 4
                g.box((sx + math.cos(a) * r, y * s, r + math.sin(a) * r), (0.035, wid * 1.02, 0.035), "dark",
                      rot=(0, -math.degrees(a), 0))
            g.cyl((sx, (y + wid * 0.52) * s, r), r * 0.45, 0.02, "metal", axis="y", seg=12)


def _banner(b, x, y, z, w, h, axis="y", skull=True):
    """Estandarte vermelho com caveira de osso, pendurado numa face."""
    if axis == "y":   # face voltada para ±Y
        b.box((x, y, z), (w, 0.012, h), "team", taper=(1.0, 1.0))
        if skull:
            b.sphere((x, y + 0.008 * (1 if y > 0 else -1), z + h * 0.1), (w * 0.18, 0.006, w * 0.2), "skull")
    else:
        b.box((x, y, z), (0.012, w, h), "team")
        if skull:
            b.sphere((x + 0.008 * (1 if x > 0 else -1), y, z + h * 0.1), (0.006, w * 0.18, w * 0.2), "skull")


def coletor(name):
    """Coletor de Recursos: caminhão blindado de seis rodas com broca e caçamba de minério."""
    m = Model(name, P)
    b = m.body
    _wheels6(m, (0.42, 0.0, -0.4), 0.32, 0.15, 0.13)
    b.box((0.0, 0, 0.33), (1.2, 0.5, 0.14), "dark", bev=0.03)
    b.box((0.38, 0, 0.5), (0.36, 0.5, 0.24), "hull", bev=0.05, taper=(0.8, 0.9))        # cabine
    b.box((0.52, 0, 0.55), (0.06, 0.4, 0.08), "glass", rot=(0, 25, 0))
    b.sym("box", (0.57, 0.18, 0.43), (0.02, 0.05, 0.03), "glow")                         # faróis
    b.box((-0.25, 0, 0.52), (0.66, 0.56, 0.26), "hull", bev=0.04, taper=(1.05, 1.08))   # caçamba
    for i in range(5):
        rnd = random.Random(i)
        b.ico((-0.45 + i * 0.1, rnd.uniform(-0.15, 0.15), 0.67), 0.08, "glow", sub=1, rough=0.3, seed=i)
    _banner(b, -0.25, 0.285, 0.52, 0.22, 0.2)
    _banner(b, -0.25, -0.285, 0.52, 0.22, 0.2)
    b.box((0.64, 0, 0.3), (0.12, 0.42, 0.14), "dark", bev=0.03)                           # broca frontal
    b.cyl((0.74, 0, 0.26), 0.13, 0.12, "metal", axis="x", seg=14)
    for k in range(6):
        a = k * math.pi / 3
        b.box((0.82, math.cos(a) * 0.1, 0.26 + math.sin(a) * 0.1), (0.06, 0.03, 0.03), "metal",
              rot=(math.degrees(a), 0, 0))
    b.sym("cyl", (-0.5, 0.2, 0.75), 0.03, 0.2, "metal", seg=10)
    m.sym_loc("smoke", (-0.5, 0.2, 0.86))
    return m


def transporte(name):
    """Transporte Blindado: casco anguloso de seis rodas com torre de metralhadora."""
    m = Model(name, P)
    b = m.body
    _wheels6(m, (0.38, 0.02, -0.34), 0.3, 0.13, 0.12)
    b.box((0.0, 0, 0.38), (1.05, 0.52, 0.26), "hull", bev=0.05, taper=(0.9, 0.85))
    b.box((0.5, 0, 0.36), (0.16, 0.48, 0.2), "hull", bev=0.04, shift=(-0.06, 0), taper=(0.6, 0.9))
    b.box((0.47, 0, 0.29), (0.05, 0.3, 0.06), "dark")                                   # grade
    b.sym("box", (0.56, 0.18, 0.36), (0.02, 0.05, 0.035), "glow")                        # faróis
    b.box((0.3, 0, 0.5), (0.2, 0.36, 0.06), "glass", bev=0.015)
    b.sym("box", (0.0, 0.27, 0.38), (0.8, 0.02, 0.18), "dark", bev=0.01)                 # placas laterais
    _banner(b, -0.05, 0.285, 0.4, 0.2, 0.16)
    _banner(b, -0.05, -0.285, 0.4, 0.2, 0.16)
    b.box((-0.3, 0, 0.55), (0.3, 0.4, 0.08), "accent", bev=0.02)                         # bagagem
    t = m.group("turret", (0.02, 0, 0.52))
    t.cyl((0.02, 0, 0.55), 0.1, 0.06, "dark", seg=16)
    t.box((0.04, 0, 0.62), (0.16, 0.12, 0.08), "hull", bev=0.02)
    t.cyl((0.22, 0, 0.63), 0.014, 0.24, "metal", axis="x", seg=8)
    t.sym("box", (0.1, 0.05, 0.665), (0.03, 0.012, 0.012), "glow")
    t.cyl((-0.05, 0.05, 0.75), 0.004, 0.18, "metal", seg=6)                              # antena
    m.loc("muzzle", (0.35, 0, 0.63), "turret")
    return m


def tanque(name):
    """Tanque de Batalha: esteiras, casco largo e anguloso, torre com canhão longo."""
    m = Model(name, P)
    b = m.body
    _tracks(m, 0, 0.36, 1.35, 0.25, 0.2)
    b.box((0, 0, 0.38), (1.3, 0.62, 0.22), "hull", bev=0.06, taper=(0.93, 0.9))
    b.box((0.66, 0, 0.33), (0.18, 0.6, 0.14), "hull", bev=0.04, shift=(-0.07, 0))
    b.sym("box", (0, 0.46, 0.38), (1.25, 0.06, 0.18), "hull", bev=0.03, rot=(-12, 0, 0))   # saias
    b.sym("box", (0.25, 0.495, 0.38), (0.12, 0.012, 0.13), "team", rot=(-12, 0, 0))
    b.sym("box", (-0.2, 0.495, 0.38), (0.12, 0.012, 0.13), "team", rot=(-12, 0, 0))
    b.sym("box", (0.75, 0.2, 0.4), (0.02, 0.06, 0.035), "glow")
    b.box((-0.66, 0, 0.42), (0.1, 0.5, 0.14), "dark", bev=0.03)
    t = m.group("turret", (-0.05, 0, 0.5))
    t.box((-0.08, 0, 0.6), (0.68, 0.52, 0.2), "hull", bev=0.06, taper=(0.82, 0.82))
    t.box((0.18, 0, 0.71), (0.22, 0.24, 0.03), "team", bev=0.01)
    t.sphere((0.18, 0, 0.73), (0.05, 0.05, 0.012), "skull")
    t.box((-0.38, 0, 0.6), (0.12, 0.46, 0.15), "accent", bev=0.03)                      # cesto traseiro
    t.cyl((0.6, 0, 0.6), 0.045, 0.8, "dark", axis="x", seg=14, bev=0.01)
    t.cyl((0.98, 0, 0.6), 0.065, 0.1, "hull", axis="x", seg=14, bev=0.015)              # freio de boca
    t.cyl((0.28, 0, 0.6), 0.075, 0.14, "hull", axis="x", seg=14, bev=0.015)
    t.box((-0.15, 0.16, 0.74), (0.14, 0.12, 0.08), "hull", bev=0.02)                    # cúpula com metralhadora
    t.cyl((-0.02, 0.16, 0.76), 0.01, 0.16, "metal", axis="x", seg=8)
    t.sym("box", (0.12, 0.27, 0.62), (0.03, 0.01, 0.03), "glow")
    for dy in (0.12, -0.12):
        t.cyl((-0.3, dy, 0.85), 0.004, 0.3, "metal", seg=6)                              # antenas
    m.loc("muzzle", (1.04, 0, 0.6), "turret")
    return m


def artilharia(name):
    """Artilharia Móvel: chassi de esteiras com lançador de 2×3 mísseis que se ergue."""
    m = Model(name, P)
    b = m.body
    _tracks(m, 0, 0.38, 1.4, 0.25, 0.2)
    b.box((0, 0, 0.38), (1.35, 0.64, 0.22), "hull", bev=0.06, taper=(0.95, 0.92))
    b.box((0.55, 0, 0.55), (0.3, 0.5, 0.16), "hull", bev=0.04, taper=(0.8, 0.9))        # cabine
    b.box((0.69, 0, 0.56), (0.03, 0.36, 0.06), "glass")
    b.sym("box", (0.7, 0.22, 0.42), (0.02, 0.06, 0.035), "glow")
    _banner(b, 0.05, 0.33, 0.4, 0.2, 0.15)
    _banner(b, 0.05, -0.33, 0.4, 0.15, 0.15, skull=False)
    t = m.group("turret", (-0.2, 0, 0.52))
    t.box((-0.2, 0, 0.56), (0.3, 0.36, 0.1), "dark", bev=0.02)
    t.box((-0.12, 0, 0.75), (0.6, 0.46, 0.3), "hull", bev=0.04, rot=(0, -22, 0))        # caixa do lançador
    t.box((-0.12, 0, 0.75), (0.5, 0.48, 0.06), "team", rot=(0, -22, 0))
    for r in range(2):
        for c in range(3):
            y = (c - 1) * 0.13
            zz = 0.75 + (r - 0.5) * 0.13
            x = 0.18 + (zz - 0.75) * 0.4
            t.cyl((x, y, zz + 0.12), 0.05, 0.05, "dark", axis="x", seg=12, rot=(0, -22, 0))
            t.cyl((x + 0.03, y, zz + 0.13), 0.035, 0.01, "glow", axis="x", seg=12, rot=(0, -22, 0))
    m.loc("muzzle", (0.24, 0, 0.88), "turret")
    return m


# ---------------------------------------------------------------- naves

def caca(name):
    """Caça Interceptor: fuselagem blindada, asas em flecha com a borda vermelha e canhões."""
    m = Model(name, P)
    b = m.body
    b.box((0.05, 0, 0.0), (0.95, 0.2, 0.13), "hull", bev=0.04, taper=(0.9, 0.7))
    b.cone((0.66, 0, 0.0), 0.08, 0.3, "hull", axis="x", seg=12, rot=(0, 180, 0))
    b.sphere((0.3, 0, 0.075), (0.16, 0.06, 0.045), "glass")
    for s in (1, -1):
        b.wing((-0.05, 0.09 * s, -0.01), 0.52, 0.5, 0.12, 0.04, "hull", sweep=0.32, dihedral=-0.02, side=s)
        b.wing((-0.1, 0.32 * s, 0.005), 0.26, 0.2, 0.08, 0.012, "team", sweep=0.16, side=s)
        b.cyl((0.12, 0.2 * s, -0.05), 0.015, 0.34, "dark", axis="x", seg=8)            # canhões
    b.sym("box", (-0.38, 0.13, 0.12), (0.18, 0.015, 0.14), "hull", rot=(12, 0, 0))       # derivas
    b.sym("cyl", (-0.4, 0.09, 0.0), 0.065, 0.24, "dark", axis="x", seg=14, bev=0.015)
    b.sym("cyl", (-0.525, 0.09, 0.0), 0.05, 0.02, "engine", axis="x", seg=14)
    m.sym_loc("muzzle", (0.29, 0.2, -0.05))
    m.sym_loc("engine", (-0.54, 0.09, 0.0))
    return m


def nave(name):
    """Nave de Transporte: casco blindado em caixa, cabine na frente, rampa traseira e
    turbinas laterais; leva tropas e veículos leves."""
    m = Model(name, P)
    b = m.body
    b.box((0.0, 0, 0.0), (1.2, 0.5, 0.32), "hull", bev=0.06, taper=(0.92, 0.88))
    b.box((0.66, 0, -0.02), (0.26, 0.42, 0.26), "hull", bev=0.06, taper=(0.6, 0.8))      # nariz
    b.box((0.7, 0, 0.06), (0.1, 0.32, 0.1), "glass", rot=(0, 30, 0))
    b.box((-0.1, 0, 0.2), (0.7, 0.36, 0.1), "dark", bev=0.03)
    for s in (1, -1):
        _banner(b, 0.0, 0.255 * s, 0.0, 0.26, 0.24)
        b.cyl((-0.25, 0.37 * s, 0.02), 0.13, 0.42, "dark", axis="x", seg=16, bev=0.02)  # turbinas
        b.cyl((-0.47, 0.37 * s, 0.02), 0.1, 0.02, "engine", axis="x", seg=16)
        b.box((-0.25, 0.3 * s, 0.02), (0.2, 0.1, 0.08), "hull", bev=0.02)
        for i in range(4):
            b.box((0.35 - i * 0.22, 0.252 * s, 0.1), (0.08, 0.006, 0.03), "glow")
    b.box((-0.62, 0, -0.1), (0.1, 0.38, 0.22), "dark", rot=(0, -25, 0))                # rampa
    b.box((-0.64, 0, -0.08), (0.02, 0.3, 0.16), "glow", rot=(0, -25, 0))
    b.cyl((0.2, 0.1, 0.28), 0.005, 0.2, "metal", seg=6)
    t = m.group("turret", (0.45, 0, -0.17))
    t.sphere((0.45, 0, -0.18), (0.07, 0.07, 0.05), "dark")
    t.cyl((0.58, 0, -0.19), 0.012, 0.2, "metal", axis="x", seg=8)
    m.loc("muzzle", (0.68, 0, -0.19), "turret")
    m.sym_loc("engine", (-0.48, 0.37, 0.02))
    return m


def cruzador(name):
    """Cruzador de Batalha: casco longo blindado com cidadela gótica, torres e estandartes."""
    m = Model(name, P)
    b = m.body
    b.box((0, 0, 0.0), (2.0, 0.46, 0.26), "hull", bev=0.06, taper=(0.95, 0.85))
    b.box((1.08, 0, -0.02), (0.3, 0.36, 0.2), "hull", bev=0.05, taper=(0.5, 0.7))      # proa
    b.box((0.0, 0, -0.17), (1.6, 0.3, 0.1), "dark", bev=0.03)
    for i in range(7):                                                                  # quilhas penduradas
        b.cone((-0.6 + i * 0.2, 0, -0.27), 0.04, 0.16, "dark", seg=6, rot=(180, 0, 0))
    b.box((-0.35, 0, 0.22), (0.6, 0.3, 0.2), "hull", bev=0.04, taper=(0.85, 0.85))      # cidadela
    for x, h in ((-0.5, 0.42), (-0.35, 0.55), (-0.2, 0.4)):
        b.box((x, 0, 0.32 + h / 4), (0.08, 0.08, h / 2), "dark", bev=0.01)
        b.cone((x, 0, 0.32 + h / 2 + 0.06), 0.045, 0.16, "dark", seg=4)                # pináculos
    b.sym("box", (-0.35, 0.155, 0.24), (0.3, 0.005, 0.03), "glow")
    for s in (1, -1):
        _banner(b, 0.25, 0.235 * s, -0.05, 0.22, 0.3)
        _banner(b, -0.6, 0.235 * s, -0.05, 0.16, 0.24, skull=False)
        for i in range(5):
            b.box((0.6 - i * 0.35, 0.236 * s, 0.07), (0.1, 0.006, 0.025), "glow")         # vigias
    for s in (1, -1):                                                                   # motores
        b.cyl((-1.02, 0.14 * s, 0.0), 0.1, 0.16, "dark", axis="x", seg=16, bev=0.02)
        b.cyl((-1.1, 0.14 * s, 0.0), 0.08, 0.02, "engine", axis="x", seg=16)
    for x in (0.55, 0.25):                                                              # torres de convés
        b.box((x, 0, 0.17), (0.12, 0.12, 0.06), "dark", bev=0.015)
        b.sym("cyl", (x + 0.12, 0.025, 0.18), 0.012, 0.18, "metal", axis="x", seg=8)
    t = m.group("turret", (0.4, 0, -0.24))
    t.sphere((0.4, 0, -0.26), (0.11, 0.11, 0.07), "dark")
    t.box((0.48, 0, -0.28), (0.14, 0.12, 0.07), "hull", bev=0.02)
    for dy in (-0.035, 0.035):
        t.cyl((0.66, dy, -0.28), 0.02, 0.3, "metal", axis="x", seg=10)
    m.loc("muzzle", (0.82, 0, -0.28), "turret")
    m.sym_loc("engine", (-1.12, 0.14, 0.0))
    return m


# ---------------------------------------------------------------- prédios

def _pad(b, sx, sy, h=0.06):
    b.box((0, 0, h / 2), (sx, sy, h), "dark", bev=0.03)
    b.box((0, 0, h + 0.005), (sx - 0.12, sy - 0.12, 0.01), "hull")


def _windows(b, x, y, z, n, dx, w=0.1, h=0.05, axis="x", mat="glow"):
    for i in range(n):
        o = (i - (n - 1) / 2) * dx
        if axis == "x":
            b.box((x + o, y, z), (w, 0.012, h), mat)
        else:
            b.box((x, y + o, z), (0.012, w, h), mat)


def _spire(b, x, y, z, h, r=0.06):
    """Pináculo gótico: torre fina de base quadrada com ponta."""
    b.box((x, y, z + h * 0.35), (r * 2, r * 2, h * 0.7), "dark", bev=0.01)
    b.cone((x, y, z + h * 0.85), r * 1.1, h * 0.3, "dark", seg=4, rot=(0, 0, 45))
    b.box((x + r, y, z + h * 0.5), (0.01, r * 0.8, 0.04), "glow")


def _block(b, c, s, team_y=None):
    """Bloco blindado com cinta de placas escuras e janelas de brasa."""
    b.box(c, s, "hull", bev=0.06, taper=(0.94, 0.94))
    b.box((c[0], c[1], c[2] + s[2] * 0.3), (s[0] + 0.02, s[1] + 0.02, 0.05), "dark", bev=0.01)


def cy(name):
    """Base Principal: fortaleza com escadaria, pináculos, antena parabólica e estandarte."""
    m = Model(name, P)
    b = m.body
    _pad(b, 2.9, 2.9)
    _block(b, (0.1, 0.15, 0.42), (2.2, 1.9, 0.72))
    b.box((0.1, -1.0, 0.18), (0.9, 0.3, 0.24), "dark", bev=0.02, taper=(1.0, 0.4), shift=(0, 0.1))  # escadaria
    b.box((0.1, -0.85, 0.42), (0.6, 0.06, 0.45), "glow")                                # portão aceso
    _banner(b, 0.1, -0.81, 0.75, 0.45, 0.42)
    _block(b, (-0.25, 0.35, 1.0), (1.1, 1.0, 0.5))
    for x, y, h in ((-0.75, -0.15, 1.1), (0.25, -0.15, 1.0), (-0.75, 0.85, 1.2), (0.25, 0.85, 1.3),
                    (-0.25, 0.35, 1.5), (0.95, -0.7, 0.8), (0.95, 0.9, 0.9), (-0.9, -0.7, 0.7)):
        _spire(b, x, y, 0.78 if abs(x) < 0.8 else 0.78, h)
    b.cyl((0.85, 0.3, 0.85), 0.06, 0.2, "metal", seg=10)                                  # antena parabólica
    b.sphere((0.85, 0.3, 1.05), (0.28, 0.28, 0.1), "metal", rot=(0, 35, 0))
    b.cyl((0.95, 0.3, 1.12), 0.012, 0.25, "dark", seg=6, rot=(0, 35, 0))
    _windows(b, 0.1, -0.81, 0.62, 6, 0.28, mat="glow")
    _windows(b, -0.25, -0.16, 1.05, 3, 0.3)
    for s in (1, -1):
        _banner(b, 1.21 * s, 0.15, 0.5, 0.35, 0.4, axis="x")
    return m


def power(name):
    """Usina de Energia: dois reatores cilíndricos com faixas acesas, tubos e chaminés."""
    m = Model(name, P)
    b = m.body
    _pad(b, 1.9, 1.9)
    _block(b, (0.0, 0.25, 0.25), (1.6, 1.1, 0.4))
    for x in (-0.38, 0.38):
        b.cyl((x, 0.2, 0.75), 0.3, 0.75, "hull", seg=24, bev=0.03)
        for z in (0.55, 0.8, 1.05):
            b.cyl((x, 0.2, z), 0.305, 0.04, "glow", seg=24)
        b.cyl((x, 0.2, 1.16), 0.26, 0.06, "dark", seg=20)
        b.cyl((x, 0.2, 1.24), 0.08, 0.14, "metal", seg=12)
    b.tube((-0.38, -0.12, 0.55), (0.38, -0.12, 0.55), 0.04, "metal")
    b.box((0.0, -0.6, 0.35), (1.3, 0.2, 0.5), "hull", bev=0.04)
    _windows(b, 0.0, -0.71, 0.35, 5, 0.24, w=0.12)
    _banner(b, 0.0, -0.71, 0.75, 0.3, 0.3)
    _spire(b, 0.7, -0.6, 0.6, 0.6)
    _spire(b, -0.7, -0.6, 0.6, 0.6)
    m.loc("smoke", (-0.38, 0.2, 1.3))
    m.loc("smoke", (0.38, 0.2, 1.3))
    return m


def refinery(name):
    """Refinaria: silos vermelhos, tubulação e esteira com minério aceso até a doca."""
    m = Model(name, P)
    b = m.body
    _pad(b, 2.9, 1.9)
    _block(b, (-0.6, 0.25, 0.45), (1.4, 1.1, 0.8))
    _banner(b, -0.6, -0.31, 0.7, 0.35, 0.4)
    for x in (0.5, 1.05):
        b.cyl((x, 0.35, 0.55), 0.25, 0.9, "team", seg=24, bev=0.04)
        b.sphere((x, 0.35, 1.0), (0.25, 0.25, 0.12), "hull")
        for z in (0.25, 0.75):
            b.cyl((x, 0.35, z), 0.255, 0.04, "dark", seg=24)
        b.sphere((x, 0.1, 0.6), (0.06, 0.012, 0.07), "skull")
    b.tube((-0.0, 0.35, 0.85), (0.5, 0.35, 0.85), 0.05, "metal")
    b.tube((0.5, 0.35, 0.95), (1.05, 0.35, 0.95), 0.04, "metal")
    b.box((0.55, -0.45, 0.3), (1.0, 0.22, 0.06), "dark", rot=(0, 18, 0))               # esteira
    for i in range(7):
        b.ico((0.15 + i * 0.13, -0.45, 0.2 + i * 0.04), 0.045, "glow", sub=1, rough=0.3, seed=i)
    b.box((-0.6, -0.55, 0.22), (0.9, 0.3, 0.36), "dark", bev=0.03)                      # doca de descarga
    b.box((-0.6, -0.71, 0.22), (0.7, 0.02, 0.26), "glow")
    _spire(b, -1.1, 0.6, 0.85, 0.7)
    b.cyl((-0.2, 0.6, 1.1), 0.07, 0.5, "metal", seg=12)
    m.loc("smoke", (-0.2, 0.6, 1.38))
    return m


def barracks(name):
    """Alojamento: casamata com portão iluminado e estandarte."""
    m = Model(name, P)
    b = m.body
    _pad(b, 1.9, 1.9)
    _block(b, (0, 0.1, 0.38), (1.55, 1.3, 0.66))
    b.box((0, -0.58, 0.28), (0.6, 0.14, 0.46), "dark", bev=0.04)
    b.box((0, -0.66, 0.26), (0.46, 0.02, 0.36), "glow")
    _banner(b, 0, -0.67, 0.6, 0.3, 0.2)
    b.box((0, 0.2, 0.82), (1.0, 0.8, 0.22), "hull", bev=0.05, taper=(0.7, 0.7))
    _spire(b, 0.6, -0.45, 0.7, 0.7)
    _spire(b, -0.6, -0.45, 0.7, 0.7)
    _spire(b, 0.0, 0.3, 0.92, 0.6)
    _windows(b, -0.5, -0.56, 0.5, 2, 0.2)
    _windows(b, 0.5, -0.56, 0.5, 2, 0.2)
    return m


def factory(name):
    """Mecânica: oficina de blindados com portão grande e guindaste."""
    m = Model(name, P)
    b = m.body
    _pad(b, 2.9, 2.9)
    _block(b, (0, 0.25, 0.6), (2.4, 2.0, 1.1))
    b.box((0, -0.78, 0.42), (1.4, 0.16, 0.76), "dark", bev=0.05)                         # portão
    for i in range(5):
        b.box((0, -0.87, 0.12 + i * 0.13), (1.25, 0.02, 0.05), "metal")
    b.box((0, -0.88, 0.85), (1.4, 0.02, 0.06), "glow")
    _banner(b, 0.95, -0.76, 0.75, 0.35, 0.5)
    _banner(b, -0.95, -0.76, 0.75, 0.35, 0.5)
    for x in (-0.9, 0.9):
        _spire(b, x, 0.9, 1.15, 0.8)
    b.box((0.7, 0.6, 1.4), (0.1, 0.1, 0.55), "accent", bev=0.02)                         # guindaste
    b.box((0.4, 0.6, 1.68), (0.75, 0.08, 0.07), "accent", bev=0.02)
    b.cyl((0.1, 0.6, 1.5), 0.006, 0.3, "metal", seg=6)
    b.box((0.1, 0.6, 1.33), (0.12, 0.12, 0.08), "glow")
    b.cyl((-0.3, 0.9, 1.4), 0.09, 0.35, "metal", seg=12)
    m.loc("smoke", (-0.3, 0.9, 1.6))
    return m


def starport(name):
    """Hangar: galpão em arco com pista e pináculos."""
    m = Model(name, P)
    b = m.body
    _pad(b, 2.9, 2.9)
    b.box((0.0, 0.3, 0.45), (2.3, 1.6, 0.8), "hull", bev=0.25, taper=(0.75, 0.9))       # arco do galpão
    b.box((0.0, -0.52, 0.38), (1.6, 0.06, 0.6), "dark", bev=0.05)                        # boca do hangar
    b.box((0.0, -0.56, 0.34), (1.4, 0.02, 0.5), "glow")
    b.box((0.0, -1.05, 0.08), (1.6, 0.8, 0.02), "dark")                                  # pista
    for i in range(5):
        b.box((-0.6 + i * 0.3, -1.05, 0.095), (0.12, 0.04, 0.01), "glow")
    _banner(b, 1.0, -0.5, 0.6, 0.3, 0.45)
    _banner(b, -1.0, -0.5, 0.6, 0.3, 0.45)
    for x in (-1.0, -0.5, 0.5, 1.0):
        _spire(b, x, 0.95, 0.85, 0.75)
    b.box((1.15, 1.1, 0.5), (0.4, 0.4, 0.9), "hull", bev=0.04)                           # torre de controle
    b.box((1.15, 1.1, 1.0), (0.48, 0.48, 0.14), "glass", bev=0.03)
    return m


def turret(name):
    """Torre de Defesa: bunker com canhão duplo e sensores vermelhos."""
    m = Model(name, P)
    b = m.body
    b.box((0, 0, 0.12), (0.92, 0.92, 0.24), "hull", bev=0.05, taper=(0.82, 0.82))
    b.box((0, 0, 0.3), (0.62, 0.62, 0.16), "dark", bev=0.04, taper=(0.85, 0.85))
    for s in (1, -1):
        _banner(b, 0.0, 0.42 * s, 0.14, 0.22, 0.16)
    g = m.group("gun", (0, 0, 0.42))
    g.box((-0.02, 0, 0.48), (0.42, 0.34, 0.2), "hull", bev=0.05)
    g.box((0.17, 0, 0.5), (0.04, 0.26, 0.08), "dark")
    for dy in (-0.075, 0.075):
        g.cyl((0.42, dy, 0.5), 0.04, 0.5, "dark", axis="x", seg=12, bev=0.01)
        g.cyl((0.68, dy, 0.5), 0.05, 0.06, "hull", axis="x", seg=12)
    for dy in (-0.1, 0.0, 0.1):
        g.sphere((0.19, dy, 0.57), 0.025, "glow")                                         # sensores
    _spire(g, -0.15, 0.12, 0.58, 0.3, r=0.025)
    m.loc("muzzle", (0.72, 0, 0.5), "gun")
    return m


def medic(name):
    """Hospital de Campanha: bloco com cruz vermelha e emissor de cura giratório."""
    m = Model(name, P)
    b = m.body
    _pad(b, 1.9, 1.9)
    _block(b, (0, 0.25, 0.3), (1.5, 0.95, 0.5))
    b.box((0.0, -0.235, 0.36), (0.18, 0.02, 0.36), "white")
    b.box((0.0, -0.237, 0.38), (0.06, 0.02, 0.26), "team")                               # cruz
    b.box((0.0, -0.237, 0.42), (0.2, 0.02, 0.06), "team")
    _windows(b, -0.5, -0.235, 0.35, 2, 0.2)
    _windows(b, 0.5, -0.235, 0.35, 2, 0.2)
    _spire(b, 0.62, 0.55, 0.55, 0.6)
    _spire(b, -0.62, 0.55, 0.55, 0.6)
    b.cyl((0.0, -0.55, 0.06), 0.36, 0.06, "dark", seg=24)
    b.cyl((0.0, -0.55, 0.1), 0.34, 0.015, "glow", seg=24)
    b.cyl((0.0, -0.55, 0.38), 0.05, 0.56, "metal", seg=12)
    s = m.group("spin", (0.0, -0.55, 0.72))
    s.cyl((0.0, -0.55, 0.72), 0.15, 0.05, "hull", seg=18)
    s.box((0.0, -0.55, 0.72), (0.06, 0.58, 0.03), "accent")
    s.box((0.0, -0.55, 0.72), (0.58, 0.06, 0.03), "accent")
    s.sphere((0.0, -0.55, 0.79), 0.06, "glow")
    return m


def all_models():
    out = [soldado("hum_soldado"), fuzileiro("hum_fuzileiro"), engenheiro("hum_engenheiro"),
           medico("hum_medico"), comando("hum_comando")]
    out += [coletor("hum_coletor"), transporte("hum_transporte"), tanque("hum_tanque"),
            artilharia("hum_artilharia"), caca("hum_caca"), nave("hum_nave"), cruzador("hum_cruzador")]
    out += [cy("cy_hum"), power("power_hum"), refinery("refinery_hum"), barracks("barracks_hum"),
            factory("factory_hum"), starport("starport_hum"), turret("turret_hum"),
            medic("medic_hum")]
    return out
