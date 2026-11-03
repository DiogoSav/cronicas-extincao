"""Cenário do planeta: rochas, pináculos, cristais (recurso), plantas alienígenas e destroços."""

import math
import random

from core import Model
from palettes import PROPS as P


def rock(name, seed, n=3, h=0.5):
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    for i in range(n):
        x, y = rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25)
        r = rnd.uniform(0.22, 0.38)
        b.ico((x, y, r * 0.35), (r, r * rnd.uniform(0.8, 1.1), r * rnd.uniform(0.7, 1.3) * h * 2),
              "rock" if i % 3 else "dark", sub=2, rough=0.22, seed=seed * 10 + i, rot=(0, 0, rnd.uniform(0, 360)))
    return m


def spire(name, seed):
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    b.ico((0, 0, 0.1), (0.42, 0.42, 0.22), "dark", sub=2, rough=0.2, seed=seed)
    for i in range(3):
        x, y = rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15)
        hh = rnd.uniform(0.7, 1.3)
        b.cone((x, y, hh / 2), rnd.uniform(0.12, 0.2), hh, "rock", seg=7,
               rot=(rnd.uniform(-10, 10), rnd.uniform(-10, 10), rnd.uniform(0, 60)))
    return m


def crystal(name, seed, n=5, big=1.0):
    """Aglomerado de cristais: usado nos campos de recurso (malha instanciada) e em enfeites."""
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    for i in range(n):
        a = rnd.uniform(0, 2 * math.pi)
        d = 0.0 if i == 0 else rnd.uniform(0.06, 0.2)
        x, y = math.cos(a) * d, math.sin(a) * d
        h = (0.55 if i == 0 else rnd.uniform(0.2, 0.4)) * big
        r = (0.08 if i == 0 else rnd.uniform(0.035, 0.06)) * big
        tilt = 0 if i == 0 else 25
        rot = (math.sin(a) * -tilt, math.cos(a) * tilt, rnd.uniform(0, 60))
        b.cyl((x, y, h * 0.4), r, h * 0.8, "crystal", seg=6, rot=rot)
        # ponta
        from mathutils import Euler, Vector
        e = Euler([math.radians(q) for q in rot], "XYZ")
        tip = Vector((0, 0, h * 0.4 + h * 0.1)) @ e.to_matrix().transposed()
        b.cone((x + tip.x, y + tip.y, h * 0.4 + tip.z), r, h * 0.2, "crystal", seg=6, rot=rot)
    return m


def plant(name, seed):
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    b.ico((0, 0, 0.05), (0.25, 0.25, 0.1), "dark", sub=1, rough=0.2, seed=seed)
    for i in range(5):
        a = rnd.uniform(0, 2 * math.pi)
        d = rnd.uniform(0.0, 0.18)
        x, y = math.cos(a) * d, math.sin(a) * d
        h = rnd.uniform(0.35, 0.8)
        top = (x + rnd.uniform(-0.1, 0.1), y + rnd.uniform(-0.1, 0.1), h)
        b.tube((x, y, 0.0), top, 0.025, "plant", r2=0.015)
        b.sphere(top, (0.06, 0.06, 0.05), "glow")
    return m


def debris(name, seed):
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    b.ico((0, 0, 0.0), (0.4, 0.35, 0.12), "rock", sub=2, rough=0.15, seed=seed)
    for i in range(4):
        b.box((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.2), 0.12), (rnd.uniform(0.2, 0.4), 0.08, 0.05),
              "hull" if i % 2 else "metal", bev=0.01,
              rot=(rnd.uniform(-30, 30), rnd.uniform(-30, 30), rnd.uniform(0, 180)))
    b.box((0.05, 0.0, 0.2), (0.5, 0.12, 0.04), "accent", bev=0.01, rot=(0, -25, 30))
    return m


def red_plant(name, seed):
    """Vegetação alienígena: folhas vermelhas pontudas abertas em leque, brasa nas pontas."""
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    b.ico((0, 0, 0.04), (0.22, 0.22, 0.08), "dark", sub=1, rough=0.2, seed=seed)
    for i in range(9):
        a = i / 9 * 2 * math.pi + rnd.uniform(-0.2, 0.2)
        h = rnd.uniform(0.35, 0.7)
        out = rnd.uniform(0.18, 0.32)
        top = (math.cos(a) * out, math.sin(a) * out, h)
        b.tube((math.cos(a) * 0.04, math.sin(a) * 0.04, 0.02), top, 0.035, "plant", r2=0.004)
        if i % 3 == 0:
            b.sphere(top, (0.025, 0.025, 0.025), "glow")
    return m


def dead_tree(name, seed):
    """Árvore morta e queimada: tronco torto com galhos secos."""
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    top = (rnd.uniform(-0.08, 0.08), rnd.uniform(-0.08, 0.08), 0.95)
    b.tube((0, 0, 0), top, 0.07, "wood", r2=0.03)
    for i in range(5):
        t = rnd.uniform(0.4, 0.9)
        base = (top[0] * t, top[1] * t, top[2] * t)
        a = rnd.uniform(0, 2 * math.pi)
        ln = rnd.uniform(0.2, 0.4)
        tip = (base[0] + math.cos(a) * ln, base[1] + math.sin(a) * ln, base[2] + rnd.uniform(0.05, 0.25))
        b.tube(base, tip, 0.025, "wood", r2=0.008)
    b.ico((0, 0, 0.02), (0.18, 0.18, 0.06), "dark", sub=1, rough=0.25, seed=seed)
    return m


def ruin(name, seed):
    """Ruína de bunker industrial: paredes quebradas, vigas tortas e entulho."""
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    b.box((0, 0, 0.03), (0.9, 0.9, 0.06), "dark", bev=0.02)
    for i, (x, y, sx, sy) in enumerate(((-0.3, 0, 0.12, 0.8), (0, 0.32, 0.7, 0.12), (0.3, -0.1, 0.12, 0.5))):
        h = rnd.uniform(0.35, 0.7)
        b.box((x, y, h / 2), (sx, sy, h), "hull", bev=0.02, taper=(rnd.uniform(0.6, 1.0), 1.0))
        b.box((x, y, h * 0.55), (sx * 1.05, sy * 0.4, 0.06), "glow" if i == 1 else "metal")   # fresta acesa
    for i in range(3):
        b.box((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.2, 0.1), 0.5), (0.04, 0.04, rnd.uniform(0.4, 0.7)), "rust",
              rot=(rnd.uniform(-35, 35), rnd.uniform(-35, 35), 0))
    for i in range(4):
        b.ico((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.35, 0.1), 0.05), 0.09, "rock", sub=1, rough=0.3, seed=seed + i)
    return m


def wreck(name, seed):
    """Carcaça de blindado queimado, com o canhão caído."""
    m = Model(name, P)
    b = m.body
    rnd = random.Random(seed)
    b.box((0, 0, 0.16), (0.8, 0.5, 0.2), "rust", bev=0.04, rot=(rnd.uniform(-8, 8), 6, 20))
    b.box((-0.05, 0.02, 0.32), (0.36, 0.3, 0.14), "hull", bev=0.04, rot=(0, 0, 35))
    b.cyl((0.28, 0.2, 0.3), 0.035, 0.5, "dark", axis="x", rot=(0, 18, 35))
    for s in (1, -1):
        b.box((0, 0.28 * s, 0.09), (0.84, 0.1, 0.16), "dark", bev=0.03, rot=(0, 0, 20))
    b.ico((0.3, -0.3, 0.03), (0.2, 0.15, 0.05), "rock", sub=1, rough=0.25, seed=seed)
    return m


def all_models():
    return [
        rock("prop_rock_a", 1), rock("prop_rock_b", 2, 4, 0.4), rock("prop_rock_c", 3, 2, 0.7),
        spire("prop_spire_a", 4), spire("prop_spire_b", 5),
        crystal("prop_crystal", 6, 5, 1.0), crystal("ore_crystal", 7, 4, 0.7),
        red_plant("prop_plant", 8), debris("prop_debris", 9), dead_tree("prop_deadtree", 10),
        ruin("prop_ruin", 11), wreck("prop_wreck", 12),
    ]
