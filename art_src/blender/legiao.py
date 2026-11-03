"""Legião Sintética (robôs): andadores de grafite blindado com núcleos e frisos laranja.
Referência: "referencia facções/legião sintética" (infantaria, unidades terrestres e aéreas).

Infantaria: Rastejador (aranha batedora), Ceifador (quadrúpede com canhão), Arquiteto
(esteira com guindaste), Bastião (quadrúpede pesado), Vigia (drone flutuante).
Veículos: Vetor (caminhante de transporte, 6 patas), Aniquilador (tanque andador),
Devastador (artilharia andadora). Naves: Vespa, Colosso (transporte), Cruzador Sintético.
Patas são grupos limb_<lado><i> (o render de sprites gera a caminhada).
"""

import math

from core import Model
from palettes import ROBOT as P


def _plate(b, c, s, rot=(0, 0, 0), stripe=True):
    """Placa blindada hexagonal-chanfrada com friso aceso."""
    b.box(c, s, "hull", bev=min(s) * 0.3, rot=rot, taper=(0.9, 0.9))
    if stripe:
        b.box((c[0] + s[0] * 0.5, c[1], c[2]), (0.012, s[1] * 0.6, s[2] * 0.2), "glow", rot=rot)


def _emblem(b, c, w, axis="x"):
    """Emblema da Legião (triângulo invertido laranja)."""
    pts = [(0, w * 0.55), (-w * 0.5, -w * 0.35), (w * 0.5, -w * 0.35)]
    if axis == "x":
        b.prism(c, [(y, z) for y, z in pts], 0.01, "team", rot=(90, 0, 90))
    else:
        b.prism(c, [(y, z) for y, z in pts], 0.01, "team", rot=(90, 0, 0))


def _walker_legs(m, hips, hip_z, reach, knee_up, thick, foot_r=None, segs=2):
    """Patas mecânicas: coxa grossa blindada, joelho com núcleo aceso, canela fina e pé."""
    for i, (x, y) in enumerate(hips):
        for s in (1, -1):
            hip = (x, y * s, hip_z)
            p = m.group("limb_%s%d" % ("l" if s > 0 else "r", i), hip)
            knee = (x * 1.25, (y + reach * 0.55) * s, hip_z + knee_up)
            foot = (x * 1.45, (y + reach) * s, 0.02)
            p.sphere(hip, thick * 1.5, "dark")
            p.tube(hip, knee, thick, "hull")
            p.box(((hip[0] + knee[0]) / 2, (hip[1] + knee[1]) / 2, (hip[2] + knee[2]) / 2 + thick * 0.6),
                  (thick * 2.2, thick * 2.6, thick * 0.8), "hull", bev=thick * 0.3)
            p.sphere(knee, thick * 1.25, "dark")
            p.sphere((knee[0], knee[1] + thick * 0.9 * s, knee[2]), thick * 0.55, "glow")
            p.tube(knee, foot, thick * 0.75, "metal", r2=thick * 0.5)
            p.cyl(foot, foot_r or thick * 1.4, 0.03, "dark", seg=10)


# ---------------------------------------------------------------- infantaria

def rastejador(name):
    """Rastejador: aranha batedora baixa e rápida, olho de sensor e antenas."""
    m = Model(name, P)
    b = m.body
    _walker_legs(m, [(0.08, 0.07), (-0.08, 0.07)], 0.2, 0.2, 0.08, 0.018)
    b.box((0, 0, 0.21), (0.3, 0.18, 0.09), "hull", bev=0.03, taper=(0.85, 0.85))
    b.box((-0.02, 0, 0.27), (0.18, 0.12, 0.05), "dark", bev=0.015)
    b.sphere((0.15, 0, 0.21), (0.05, 0.06, 0.05), "dark")
    b.sphere((0.185, 0, 0.215), 0.03, "glow")                                           # olho
    b.sym("tube", (-0.08, 0.04, 0.29), (-0.14, 0.06, 0.45), 0.004, "metal")
    b.sym("box", (0.0, 0.092, 0.21), (0.16, 0.006, 0.02), "team")
    m.loc("muzzle", (0.21, 0, 0.215))
    return m


def ceifador(name):
    """Ceifador: quadrúpede de patas longas com canhão de assalto aceso na ponta."""
    m = Model(name, P)
    b = m.body
    _walker_legs(m, [(0.1, 0.09), (-0.1, 0.09)], 0.34, 0.24, 0.12, 0.022)
    b.box((0, 0, 0.36), (0.32, 0.22, 0.12), "hull", bev=0.035, taper=(0.85, 0.85))
    b.box((0.0, 0, 0.3), (0.24, 0.16, 0.05), "dark", bev=0.015)
    b.sym("box", (0.0, 0.112, 0.36), (0.18, 0.006, 0.025), "glow")
    t = m.group("turret", (0.0, 0, 0.42))
    t.box((0.0, 0, 0.45), (0.2, 0.14, 0.08), "hull", bev=0.025)
    t.cyl((0.24, 0, 0.46), 0.022, 0.34, "dark", axis="x", seg=12)
    for i in range(3):
        t.cyl((0.18 + i * 0.07, 0, 0.46), 0.026, 0.02, "glow", axis="x", seg=12)
    t.sphere((0.42, 0, 0.46), 0.022, "glow")
    _emblem(t, (0.0, 0.072, 0.46), 0.05, axis="y")
    m.loc("muzzle", (0.43, 0, 0.46), "turret")
    return m


def arquiteto(name):
    """Arquiteto: base de esteiras com faixas de advertência, cabine e braço-guindaste com garra."""
    m = Model(name, P)
    b = m.body
    for s in (1, -1):
        b.box((0, 0.12 * s, 0.07), (0.34, 0.07, 0.12), "dark", bev=0.04, seg=3)
        for i in range(4):
            b.box((-0.12 + i * 0.08, 0.157 * s, 0.07), (0.035, 0.004, 0.07), "team" if i % 2 else "dark")
    b.box((0, 0, 0.2), (0.28, 0.2, 0.16), "hull", bev=0.03)
    b.box((0.13, 0, 0.21), (0.02, 0.14, 0.05), "glow")
    for i in range(3):
        b.box((0.141, -0.045 + i * 0.045, 0.21), (0.004, 0.02, 0.04), "dark")
    _emblem(b, (0.0, 0.102, 0.22), 0.06, axis="y")
    arm = [(-0.05, 0.0, 0.3), (-0.02, 0.0, 0.5), (0.14, 0.0, 0.56), (0.24, 0.0, 0.44)]
    for a, c in zip(arm, arm[1:]):
        b.tube(a, c, 0.025, "hull")
    for p in arm[1:3]:
        b.sphere(p, 0.035, "dark")
    for s in (1, -1):
        b.tube(arm[-1], (0.28, 0.035 * s, 0.38), 0.01, "metal")
    m.loc("muzzle", (0.28, 0, 0.38))
    return m


def bastiao(name):
    """Bastião: quadrúpede pesado de linha de frente, blindagem grossa e canhões gêmeos."""
    m = Model(name, P)
    b = m.body
    _walker_legs(m, [(0.13, 0.12), (-0.13, 0.12)], 0.32, 0.18, 0.07, 0.035, foot_r=0.06)
    b.box((0, 0, 0.36), (0.38, 0.3, 0.2), "hull", bev=0.05, taper=(0.88, 0.85))
    b.sym("box", (0.0, 0.16, 0.36), (0.3, 0.03, 0.16), "hull", bev=0.015)
    for i in range(3):
        b.sym("box", (-0.08 + i * 0.07, 0.178, 0.37), (0.035, 0.006, 0.08), "glow")
    t = m.group("turret", (0.04, 0, 0.47))
    t.box((0.04, 0, 0.5), (0.22, 0.2, 0.1), "hull", bev=0.03)
    _emblem(t, (0.151, 0, 0.52), 0.06)
    for s in (1, -1):
        t.cyl((0.24, 0.065 * s, 0.5), 0.022, 0.24, "dark", axis="x", seg=12)
        t.cyl((0.36, 0.065 * s, 0.5), 0.024, 0.02, "glow", axis="x", seg=12)
    m.loc("muzzle", (0.37, 0, 0.5), "turret")
    return m


def vigia(name):
    """Vigia: drone flutuante com olho central, dois rotores e cone de varredura."""
    m = Model(name, P)
    b = m.body
    z = 0.5
    b.sphere((0, 0, z), (0.16, 0.13, 0.07), "hull")
    b.box((0.0, 0, z + 0.04), (0.18, 0.08, 0.04), "dark", bev=0.015)
    b.sphere((0.14, 0, z), (0.05, 0.06, 0.05), "dark")
    b.sphere((0.17, 0, z), 0.035, "glow")
    for s in (1, -1):
        b.wing((0.0, 0.1 * s, z), 0.14, 0.14, 0.06, 0.02, "hull", sweep=0.05, side=s)
        b.cyl((-0.02, 0.26 * s, z - 0.01), 0.07, 0.02, "dark", seg=16)
        b.cyl((-0.02, 0.26 * s, z - 0.02), 0.055, 0.005, "glow", seg=16)
    b.cone((0, 0, z - 0.1), 0.04, 0.06, "glow", seg=10, rot=(180, 0, 0))
    m.loc("muzzle", (0.2, 0, z))
    return m


# ---------------------------------------------------------------- veículos

def vetor(name):
    """Vetor: caminhante de transporte, casco comprido com compartimento aceso e 6 patas."""
    m = Model(name, P)
    b = m.body
    _walker_legs(m, [(0.32, 0.2), (0.0, 0.22), (-0.32, 0.2)], 0.42, 0.3, 0.1, 0.035, foot_r=0.06)
    b.box((0, 0, 0.5), (1.0, 0.44, 0.3), "hull", bev=0.07, taper=(0.92, 0.9))
    b.box((0.47, 0, 0.47), (0.12, 0.38, 0.22), "hull", bev=0.04, shift=(-0.05, 0))
    b.box((0.54, 0, 0.5), (0.02, 0.24, 0.05), "glow")
    for s in (1, -1):
        for i in range(3):
            b.box((-0.18 + i * 0.2, 0.222 * s, 0.5), (0.15, 0.006, 0.14), "glass")        # janelas da tropa
        _emblem(b, (0.32, 0.223 * s, 0.52), 0.12, axis="y")
    b.box((0, 0, 0.67), (0.7, 0.32, 0.05), "dark", bev=0.015)
    b.sym("cyl", (-0.3, 0.1, 0.78), 0.005, 0.22, "metal", seg=6)
    t = m.group("turret", (0.15, 0, 0.7))
    t.box((0.15, 0, 0.73), (0.14, 0.12, 0.06), "hull", bev=0.02)
    t.sym("cyl", (0.3, 0.03, 0.73), 0.012, 0.2, "dark", axis="x", seg=8)
    m.loc("muzzle", (0.4, 0, 0.73), "turret")
    return m


def aniquilador(name):
    """Aniquilador: tanque de assalto andador, quatro patas e canhão longo com bobinas acesas."""
    m = Model(name, P)
    b = m.body
    _walker_legs(m, [(0.28, 0.2), (-0.28, 0.2)], 0.42, 0.34, 0.14, 0.045, foot_r=0.08)
    b.box((0, 0, 0.48), (0.82, 0.5, 0.26), "hull", bev=0.07, taper=(0.9, 0.86))
    b.box((0.0, 0, 0.36), (0.6, 0.4, 0.08), "dark", bev=0.02)
    for s in (1, -1):
        for i in range(3):
            b.box((-0.2 + i * 0.16, 0.252 * s, 0.48), (0.1, 0.006, 0.03), "glow")
    t = m.group("turret", (0.0, 0, 0.6))
    t.box((-0.02, 0, 0.66), (0.46, 0.38, 0.16), "hull", bev=0.05, taper=(0.82, 0.82))
    t.box((0.05, 0, 0.745), (0.14, 0.14, 0.008), "team")
    t.cyl((0.5, 0, 0.66), 0.045, 0.62, "dark", axis="x", seg=14)
    for i in range(4):
        t.cyl((0.32 + i * 0.12, 0, 0.66), 0.05, 0.03, "glow", axis="x", seg=14)
    t.cyl((0.82, 0, 0.66), 0.055, 0.04, "hull", axis="x", seg=14)
    t.sym("box", (-0.18, 0.2, 0.7), (0.12, 0.02, 0.05), "glow")
    m.loc("muzzle", (0.85, 0, 0.66), "turret")
    return m


def devastador(name):
    """Devastador: artilharia andadora com caixa de 2×5 mísseis acesos que se ergue."""
    m = Model(name, P)
    b = m.body
    _walker_legs(m, [(0.28, 0.2), (-0.28, 0.2)], 0.4, 0.36, 0.14, 0.042, foot_r=0.08)
    b.box((0, 0, 0.46), (0.8, 0.48, 0.24), "hull", bev=0.07, taper=(0.9, 0.86))
    _emblem(b, (0.0, 0.243, 0.47), 0.12, axis="y")
    _emblem(b, (0.0, -0.243, 0.47), 0.12, axis="y")
    t = m.group("turret", (-0.05, 0, 0.6))
    t.box((-0.05, 0, 0.62), (0.3, 0.3, 0.08), "dark", bev=0.02)
    t.box((0.0, 0, 0.84), (0.66, 0.5, 0.26), "hull", bev=0.04, rot=(0, -18, 0))
    for r in range(2):
        for c in range(5):
            y = (c - 2) * 0.09
            zz = 0.84 + (r - 0.5) * 0.11
            x = 0.33 + (zz - 0.84) * 0.33
            t.box((x, y, zz + 0.1), (0.02, 0.07, 0.08), "glow", rot=(0, -18, 0))
    m.loc("muzzle", (0.36, 0, 0.98), "turret")
    return m


# ---------------------------------------------------------------- naves

def vespa(name):
    """Vespa: caça de asas em flecha com núcleo aceso e canhões gêmeos."""
    m = Model(name, P)
    b = m.body
    b.box((0.05, 0, 0.0), (0.7, 0.16, 0.1), "hull", bev=0.03, taper=(0.8, 0.7))
    b.cone((0.48, 0, 0.0), 0.06, 0.22, "hull", axis="x", seg=8, rot=(0, 180, 0))
    b.sphere((0.05, 0, 0.0), (0.08, 0.1, 0.08), "dark")
    b.cyl((0.12, 0, 0.0), 0.05, 0.02, "glow", axis="x", seg=14)
    for s in (1, -1):
        b.wing((-0.05, 0.08 * s, 0.0), 0.55, 0.42, 0.06, 0.035, "hull", sweep=0.42, dihedral=0.08, side=s)
        b.wing((-0.08, 0.2 * s, 0.02), 0.32, 0.12, 0.03, 0.01, "glow", sweep=0.25, dihedral=0.05, side=s)
        b.cyl((0.28, 0.07 * s, -0.06), 0.02, 0.4, "dark", axis="x", seg=8)
        b.box((-0.3, 0.35 * s, 0.12), (0.2, 0.02, 0.18), "hull", rot=(0, -20, 0))
    b.cyl((-0.33, 0, 0.0), 0.06, 0.14, "dark", axis="x", seg=12)
    b.cyl((-0.405, 0, 0.0), 0.045, 0.02, "engine", axis="x", seg=12)
    m.sym_loc("muzzle", (0.48, 0.07, -0.06))
    m.loc("engine", (-0.42, 0, 0.0))
    return m


def colosso(name):
    """Colosso: nave de transporte em blocos, quatro motores e rampa acesa."""
    m = Model(name, P)
    b = m.body
    b.box((0, 0, 0.0), (1.3, 0.5, 0.36), "hull", bev=0.07, taper=(0.92, 0.9))
    b.box((0.7, 0, -0.02), (0.18, 0.42, 0.28), "hull", bev=0.05, shift=(-0.04, 0))
    b.box((0.79, 0, 0.0), (0.02, 0.3, 0.06), "glow")
    for s in (1, -1):
        for x in (0.35, -0.35):
            b.box((x, 0.36 * s, 0.0), (0.42, 0.2, 0.26), "hull", bev=0.05)
            b.box((x - 0.22, 0.36 * s, 0.0), (0.02, 0.15, 0.16), "engine")
        for i in range(4):
            b.box((-0.45 + i * 0.3, 0.252 * s, 0.1), (0.14, 0.006, 0.05), "glow")
        _emblem(b, (0.15, 0.462 * s, 0.02), 0.14, axis="y")
    b.box((-0.68, 0, -0.12), (0.1, 0.34, 0.2), "dark", rot=(0, -25, 0))
    b.box((-0.69, 0, -0.1), (0.02, 0.28, 0.14), "glow", rot=(0, -25, 0))
    b.sym("cyl", (0.2, 0.1, 0.25), 0.005, 0.18, "metal", seg=6)
    m.sym_loc("engine", (-0.6, 0.36, 0.0))
    return m


def cruzador(name):
    """Cruzador Sintético: disco colossal com anéis acesos, canhões na borda e núcleo inferior."""
    m = Model(name, P)
    b = m.body
    R = 0.85
    b.cyl((0, 0, 0.0), R, 0.16, "hull", seg=32, r2=R * 0.82, bev=0.04)
    b.cyl((0, 0, -0.12), R * 0.8, 0.1, "dark", seg=32, r2=R * 0.55)
    b.cyl((0, 0, 0.12), R * 0.55, 0.1, "hull", seg=24, r2=R * 0.4, bev=0.02)
    for r in (0.3, 0.55):
        b.torus((0, 0, -0.17), r, 0.015, "glow", seg=40, seg2=6)
    b.cyl((0, 0, -0.26), 0.1, 0.16, "dark", seg=16)
    b.cyl((0, 0, -0.35), 0.06, 0.04, "glow", seg=16)
    for i in range(10):
        a = i * math.tau / 10
        x, y = math.cos(a) * R * 0.95, math.sin(a) * R * 0.95
        b.box((x, y, 0.0), (0.16, 0.1, 0.1), "hull", bev=0.02, rot=(0, 0, math.degrees(a)))
        b.box((x * 1.06, y * 1.06, 0.0), (0.012, 0.07, 0.03), "glow", rot=(0, 0, math.degrees(a)))
        b.cyl((math.cos(a) * (R + 0.08), math.sin(a) * (R + 0.08), 0.02), 0.014, 0.16, "dark", axis="x",
              seg=8, rot=(0, 0, math.degrees(a)))
    for x in (-0.12, 0.0, 0.12):
        b.cyl((x, 0.0, 0.3), 0.006, 0.22, "metal", seg=6)
    b.box((0.25, 0, 0.18), (0.22, 0.22, 0.06), "dark", bev=0.02)
    b.box((0.25, 0, 0.215), (0.1, 0.1, 0.006), "team")
    m.loc("muzzle", (0.0, 0.0, -0.35))
    return m


def all_models():
    return [rastejador("rob_rifle"), ceifador("rob_smg"), arquiteto("rob_at"), bastiao("rob_mg"),
            vigia("rob_sniper"), vetor("rob_scout"), aniquilador("rob_tank"), devastador("rob_heavy"),
            vespa("rob_fighter"), colosso("rob_colosso"), cruzador("rob_gunship")]
