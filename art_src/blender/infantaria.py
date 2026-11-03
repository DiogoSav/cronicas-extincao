"""Unidades do Império da Cinza modeladas no Blender e renderizadas em 8 direções.

blender -b --factory-startup --python art_src/blender/infantaria.py -- <pasta_saida_abs> <unidade> [real] [test]

unidade: soldado, fuzileiro_pesado, engenheiro, medico, comando
Gera <pasta_saida>/<DIR>_<anim>_<f>.png (fundo transparente) e meta.json com a posição
(em pixels do quadro final) da boca da arma, dos pés, da poça de sangue e o tipo de clarão.
O art_src/gen/pixelize.gd transforma isso em pixel art (.pxo + folha PNG).
"test" renderiza só alguns quadros, para conferir o modelo.

Estilo "real" (referência: RTS de guerra pré-renderizados, tipo Sudden Strike): soldado
pequeno (~34 px), cores foscas, luz fixa da esquerda com sombra projetada de verdade no
chão (Cycles + shadow catcher), tronco inclinado ao andar. Quadro final 96x96 (folga
para o corpo deitado e o arremesso da explosão).

Mortes: death (tiro de frente, cai de costas), death_fwd (atingido fugindo, cai de
cara para a frente) e death_blast (explosão: arremessado para trás e para cima, gira e
cai largado). O meta.json traz "pool" (sangue) de cada quadro.

Modelo: peças arredondadas presas a juntas (empties). Frente = -Y, direita = -X, cima = +Z.
Todas as unidades usam o mesmo esqueleto; cada build_<unidade>() só troca as peças.
"""

import json
import math
import os
import random
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
OUT = ARGS[0]
UNIT = ARGS[1] if len(ARGS) > 1 and ARGS[1] not in ("real", "test") else "soldado"
REAL = "real" in ARGS[1:]
TEST = "test" in ARGS[1:]
os.makedirs(OUT, exist_ok=True)
RES = 384 if REAL else 512
FRAME = 96 if REAL else 128
PX_PER_M = 21.8 if REAL else 43.6   # ~34 / ~68 px de altura para 1,8 m
FEET_Y = 58 if REAL else 100        # linha dos pés no quadro final
DIRS = ["S", "SW", "W", "NW", "N", "NE", "E", "SE"]
ANIMS = [("idle", 4), ("walk", 6), ("attack", 3), ("death", 5), ("death_fwd", 5), ("death_blast", 7)]
TEST_KEYS = {"S_idle_0", "SW_idle_0", "SW_walk_1", "NE_idle_0", "E_attack_0", "SW_death_blast_2"}

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


# ------------------------------------------------------------------ materiais

def lin(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c) + (1.0,)


def mat(name, hexc, rough=0.7, metal=0.0, emit=0.0, wear=None, wear_at=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = lin(hexc)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = lin(hexc)
        b.inputs["Emission Strength"].default_value = emit
    if wear: # manchas de desgaste/ferrugem/sangue por ruído
        tex = nt.nodes.new("ShaderNodeTexNoise")
        tex.inputs["Scale"].default_value = 14.0
        tex.inputs["Detail"].default_value = 6.0
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        e0, e1 = ramp.color_ramp.elements
        e0.position, e0.color = wear_at, lin(hexc)
        e1.position, e1.color = wear_at + 0.08, lin(wear)
        nt.links.new(tex.outputs["Fac"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], b.inputs["Base Color"])
    return m


if REAL: # tudo fosco e menos saturado: o volume vem da luz, não do brilho
    ARMOR = mat("armor", "#4a463f", 0.75, 0.1, wear="#6b5440")
    ARMOR_L = mat("armor_l", "#625c52", 0.7, 0.15, wear="#8a8274")
    CLOTH = mat("cloth", "#4c4834", 0.95)
    RED = mat("red", "#7a2a21", 0.9)
else:
    ARMOR = mat("armor", "#504a43", 0.45, 0.3, wear="#7d5a3a")
    ARMOR_L = mat("armor_l", "#6e675d", 0.4, 0.35, wear="#a39b8c")
    CLOTH = mat("cloth", "#4f4a39", 0.9)
    RED = mat("red", "#a8261e", 0.75)
RED_D = mat("red_d", "#5e1511", 0.85)
LEATHER = mat("leather", "#62432a", 0.75)
BLACK = mat("black", "#2b2826", 0.6)
STEEL = mat("steel", "#77746c", 0.35, 0.7)
BRASS = mat("brass", "#b48c3e", 0.35, 0.8)
BONE = mat("bone", "#ddd2b6", 0.6)
EYE = mat("eye", "#ff3b1f", 0.5, emit=8.0)
AMBER = mat("amber", "#ffa22a", 0.5, emit=6.0)
HOLO = mat("holo", "#ffc95a", 0.5, emit=3.0)
WHITE = mat("white", "#c8c1b2", 0.9, wear="#6e1a12", wear_at=0.62)   # branco sujo com sangue
GHILLIE = [mat("gh%d" % i, c, 0.95) for i, c in enumerate(("#5d5638", "#6d6442", "#4a4430", "#787050", "#3b3726"))]


# ------------------------------------------------------------------ juntas e peças

JW = {}      # posição de repouso (mundo) de cada junta
REST = {}    # location local de repouso


def joint(name, pos, parent=None):
    e = bpy.data.objects.new(name, None)
    scene.collection.objects.link(e)
    e.parent = parent
    e.location = Vector(pos) - (JW[parent.name] if parent else Vector())
    JW[name] = Vector(pos)
    REST[name] = e.location.copy()
    return e


def _finish(o, m, parent, loc, bevel, smooth):
    o.data.materials.append(m)
    if bevel > 0:
        md = o.modifiers.new("bev", "BEVEL")
        md.width = bevel
        md.segments = 3
        md.limit_method = "ANGLE"
    if smooth:
        bpy.ops.object.shade_smooth()
    o.parent = parent
    o.location = Vector(loc) - JW[parent.name]
    return o


def part(kind, loc, size, m, parent, rot=(0, 0, 0), bevel=0.0, verts=20):
    if kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=0.5, depth=1)
    elif kind == "sph":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=verts, ring_count=max(8, verts // 2), radius=0.5)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=0.5, radius2=0.3, depth=1)
    o = bpy.context.object
    o.scale = size
    o.rotation_euler = rot
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, m, parent, loc, bevel, kind != "cube" or bevel > 0)


def limb(a, b, r1, r2, m, parent, caps=True):
    """Segmento cônico arredondado de a até b (braços, pernas, mangueiras)."""
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cone_add(vertices=16, radius1=r1, radius2=r2, depth=d.length)
    o = bpy.context.object
    o.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    _finish(o, m, parent, (a + b) / 2, 0, True)
    if caps: # tampas esféricas nas pontas deixam as juntas redondas
        for p, r in ((a, r1), (b, r2)):
            part("sph", p, (r * 2, r * 2, r * 2), m, parent, verts=12)
    return o


def chain(points, r, m, parent):
    """Mangueira/fita: segmentos finos ligando os pontos."""
    for a, b in zip(points, points[1:]):
        limb(a, b, r, r, m, parent)


TABARDS = []   # panos que balançam na animação: (objeto, sinal)


def tattered(name, x0, x1, ytop, z0, z1, m, parent, seed, back=False, cols=6, ragged=0.12):
    """Pano pendurado com a barra rasgada (tiras de comprimentos diferentes)."""
    rnd = random.Random(seed)
    verts, faces = [], []
    for i in range(cols + 1):
        x = x0 + (x1 - x0) * i / cols
        cut = z1 + rnd.uniform(-0.04, ragged) * (1 if i % 2 else 0.4)
        bulge = 0.012 * math.sin(i / cols * math.pi) * (1 if back else -1)
        verts.append((x, ytop + bulge, z0))
        verts.append((x, ytop + bulge + (0.03 if back else -0.03), cut))
    for i in range(cols):
        a = i * 2
        faces.append((a, a + 2, a + 3, a + 1))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    sol = o.modifiers.new("solid", "SOLIDIFY")
    sol.thickness = 0.018
    me.materials.append(m)
    o.parent = parent
    o.location = -JW[parent.name]
    TABARDS.append((o, 1 if back else -1))
    return o


def strips(parent, center, rx, ry, ztop, lens, n, seed, mats, skip=None):
    """Tiras de ghillie/trapos penduradas em volta de um ponto (anel elíptico)."""
    rnd = random.Random(seed)
    for i in range(n):
        ang = rnd.uniform(0, math.tau)
        x = center[0] + math.cos(ang) * rx
        y = center[1] + math.sin(ang) * ry
        if skip and skip(x, y):
            continue
        top = ztop + rnd.uniform(-0.05, 0.05)
        ln = rnd.uniform(*lens)
        w = rnd.uniform(0.035, 0.07)
        out = Vector((math.cos(ang), math.sin(ang), 0)) * rnd.uniform(0.02, 0.07)
        verts = [(x - w / 2 * math.sin(ang), y + w / 2 * math.cos(ang), top),
                 (x + w / 2 * math.sin(ang), y - w / 2 * math.cos(ang), top),
                 (x + out.x, y + out.y, top - ln)]
        me = bpy.data.meshes.new("strip")
        me.from_pydata(verts, [], [(0, 1, 2)])
        o = bpy.data.objects.new("strip", me)
        scene.collection.objects.link(o)
        o.modifiers.new("solid", "SOLIDIFY").thickness = 0.012
        me.materials.append(mats[i % len(mats)])
        o.parent = parent
        o.location = -JW[parent.name]


# ------------------------------------------------------------------ esqueleto

root = joint("root", (0, 0, 0))
tilt = joint("tilt", (0, 0, 0), root)
pelvis = joint("pelvis", (0, 0, 0.95), tilt)
hip = {s: joint("hip_%d" % s, (s * 0.12, 0, 0.93), pelvis) for s in (1, -1)}
knee = {s: joint("knee_%d" % s, (s * 0.12, -0.01, 0.52), hip[s]) for s in (1, -1)}
torso = joint("torso", (0, 0, 1.0), pelvis)
neck = joint("neck", (0, 0, 1.5), torso)
# arma/ferramenta e boca: cada unidade reposiciona com set_gun()
gun = joint("gun", (-0.11, -0.16, 1.13), torso)
muzzle = joint("muzzle", (-0.09, -0.69, 1.2), gun)
FLASH = "fire"   # tipo de clarão no ataque: fire, spark, heal


def set_gun(pos, tip):
    """Move a junta da arma e a boca para a pose de empunhar desta unidade."""
    gun.location = Vector(pos) - JW["torso"]
    JW["gun"] = Vector(pos)
    REST["gun"] = gun.location.copy()
    muzzle.location = Vector(tip) - Vector(pos)
    JW["muzzle"] = Vector(tip)
    REST["muzzle"] = muzzle.location.copy()


def legs(thigh=(0.105, 0.085), shin=(0.085, 0.075), pad=ARMOR, boot=(0.17, 0.31, 0.15), shin_m=ARMOR, wide=1.0):
    for s in (1, -1):
        x = s * 0.12
        limb((x, 0, 0.93), (x, -0.01, 0.55), thigh[0], thigh[1], CLOTH, hip[s])
        part("sph", (x, -0.07, 0.53), (0.15 * wide, 0.12 * wide, 0.15 * wide), pad, knee[s])   # joelheira
        limb((x, -0.01, 0.52), (x, 0, 0.14), shin[0], shin[1], CLOTH, knee[s])
        part("cube", (x, -0.07, 0.33), (0.16 * wide, 0.06 * wide, 0.3), shin_m, knee[s], bevel=0.02)  # caneleira
        part("cube", (x, -0.05, boot[2] / 2), boot, BLACK, knee[s], bevel=0.04)                   # bota


def belt(pouches=(0.12, -0.12, 0.17)):
    part("cube", (0, 0, 0.95), (0.4, 0.24, 0.17), CLOTH, pelvis, bevel=0.05)
    part("cube", (0, 0, 1.0), (0.43, 0.27, 0.07), LEATHER, pelvis, bevel=0.018)
    part("cube", (0, -0.12, 1.0), (0.05, 0.02, 0.05), BRASS, pelvis, bevel=0.008)   # fivela
    for px in pouches:
        part("cube", (px, -0.11 if px != 0.17 else 0.0, 0.97), (0.07, 0.06, 0.08), LEATHER, pelvis, bevel=0.012)


def gas_mask(z=1.61, eyes=EYE, hose=True):
    part("cyl", (0, 0, 1.52), (0.12, 0.12, 0.08), BLACK, neck)
    part("sph", (0, -0.09, z), (0.2, 0.19, 0.2), BLACK, neck)
    part("cone", (0, -0.2, z - 0.045), (0.1, 0.1, 0.09), BLACK, neck, rot=(math.pi / 2, 0, 0))
    part("cyl", (0, -0.26, z - 0.05), (0.11, 0.11, 0.055), STEEL, neck, rot=(math.pi / 2, 0, 0))
    for s in (1, -1):
        part("cyl", (s * 0.062, -0.17, z + 0.045), (0.068, 0.068, 0.03), eyes, neck, rot=(math.pi / 2, 0, 0), verts=12)
    if hose:
        limb((0.03, -0.22, z - 0.08), (0.15, 0.16, z - 0.19), 0.018, 0.018, BLACK, neck)


def helmet():
    part("sph", (0, 0.01, 1.68), (0.3, 0.32, 0.28), ARMOR, neck, verts=24)
    part("cyl", (0, 0.015, 1.715), (0.36, 0.38, 0.035), ARMOR_L, neck, verts=24)   # aba


def torso_armor(w=0.48, d=0.31, plate=ARMOR_L):
    part("cyl", (0, 0, 1.1), (0.38, 0.26, 0.2), CLOTH, torso)
    part("cube", (0, 0, 1.3), (w, d, 0.32), ARMOR, torso, bevel=0.07)
    if plate:
        part("cube", (0, -0.135, 1.31), (w - 0.1, 0.07, 0.26), plate, torso, bevel=0.03)   # peitoral
    part("cyl", (0, 0, 1.465), (0.22, 0.2, 0.06), ARMOR, torso)                          # gorjal


def arms_rifle(upper=CLOTH, fore=ARMOR, r=1.0, hand_r=(-0.115, -0.165, 1.125), hand_l=(-0.06, -0.42, 1.17), sh=0.3):
    """Dois braços segurando uma arma longa à direita (mão direita no punho, esquerda à frente)."""
    hr, hl = Vector(hand_r), Vector(hand_l)
    el_r = Vector((-sh + 0.01, 0.04, 1.17))
    el_l = Vector((sh - 0.07, -0.13, 1.19))
    limb((-sh, 0, 1.4), el_r, 0.075 * r, 0.065 * r, upper, torso)
    limb(el_r, hr, 0.068 * r, 0.058 * r, fore, torso)
    part("sph", hr, (0.11 * r,) * 3, BLACK, torso)
    limb((sh, 0, 1.4), el_l, 0.075 * r, 0.065 * r, upper, torso)
    limb(el_l, hl, 0.068 * r, 0.058 * r, fore, torso)
    part("sph", hl, (0.11 * r,) * 3, BLACK, torso)


# ------------------------------------------------------------------ modelos

def build_soldado():
    legs()
    belt()
    tattered("tabard_f", -0.09, 0.09, -0.125, 0.99, 0.55, RED, pelvis, 3)
    tattered("tabard_b", -0.12, 0.12, 0.125, 0.99, 0.5, RED, pelvis, 8, back=True)
    torso_armor()
    part("cube", (0, -0.175, 1.34), (0.14, 0.02, 0.08), BONE, torso, bevel=0.01)     # águia no peito
    part("cube", (0, 0.2, 1.28), (0.3, 0.15, 0.34), LEATHER, torso, bevel=0.035)     # mochila
    part("cyl", (0, 0.2, 1.49), (0.1, 0.1, 0.34), CLOTH, torso, rot=(0, math.pi / 2, 0))  # manta enrolada
    part("cyl", (0.13, 0.22, 1.2), (0.07, 0.07, 0.16), STEEL, torso)                 # cantil
    for s in (1, -1): # ombreiras vermelhas com caveira
        part("sph", (s * 0.3, 0, 1.44), (0.25, 0.3, 0.21), RED, torso, verts=24)
        part("cyl", (s * 0.3, 0, 1.385), (0.265, 0.315, 0.04), ARMOR, torso, verts=24)
        part("sph", (s * 0.42, 0, 1.46), (0.04, 0.1, 0.1), BONE, torso, verts=12)
    arms_rifle()
    helmet()
    gas_mask()
    # fuzil laser
    part("cube", (-0.1, 0.03, 1.17), (0.05, 0.18, 0.09), LEATHER, gun, bevel=0.012)
    part("cube", (-0.09, -0.22, 1.18), (0.07, 0.3, 0.1), ARMOR_L, gun, bevel=0.014)
    part("cube", (-0.09, -0.25, 1.09), (0.05, 0.07, 0.11), BLACK, gun, rot=(0.25, 0, 0), bevel=0.008)
    part("cube", (-0.09, -0.2, 1.25), (0.03, 0.09, 0.04), BLACK, gun, bevel=0.008)   # mira
    part("cyl", (-0.09, -0.45, 1.2), (0.055, 0.055, 0.19), BLACK, gun, rot=(math.pi / 2, 0, 0))
    part("cyl", (-0.09, -0.61, 1.2), (0.026, 0.026, 0.15), STEEL, gun, rot=(math.pi / 2, 0, 0))
    part("cube", (-0.09, -0.36, 1.235), (0.02, 0.04, 0.012), EYE, gun)               # célula de energia


def build_fuzileiro_pesado():
    """Armadura pesada, ombreiras enormes, metralhadora rotativa no quadril com fita até o tambor."""
    legs(thigh=(0.13, 0.11), shin=(0.105, 0.095), boot=(0.21, 0.36, 0.17), wide=1.3)
    part("cube", (0, 0, 0.95), (0.5, 0.3, 0.2), ARMOR, pelvis, bevel=0.05)
    part("cube", (0, 0, 1.02), (0.53, 0.33, 0.07), LEATHER, pelvis, bevel=0.018)
    for s in (1, -1): # placas da coxa
        part("cube", (s * 0.2, -0.04, 0.82), (0.12, 0.2, 0.22), ARMOR_L, pelvis, bevel=0.03)
    tattered("tabard_f", -0.11, 0.11, -0.16, 1.0, 0.55, RED, pelvis, 5)
    tattered("tabard_b", -0.14, 0.14, 0.16, 1.0, 0.52, RED, pelvis, 9, back=True)
    # tronco largo e alto
    part("cyl", (0, 0, 1.12), (0.48, 0.34, 0.2), ARMOR, torso)
    part("cube", (0, 0, 1.33), (0.62, 0.42, 0.42), ARMOR, torso, bevel=0.09)
    part("cube", (0, -0.19, 1.35), (0.48, 0.08, 0.32), ARMOR_L, torso, bevel=0.035)
    part("cube", (0, -0.24, 1.4), (0.18, 0.02, 0.1), BONE, torso, bevel=0.01)
    part("cube", (0, -0.235, 1.28), (0.06, 0.02, 0.12), RED, torso)
    # tambor de munição nas costas
    part("cyl", (0, 0.32, 1.3), (0.38, 0.38, 0.46), STEEL, torso, rot=(0, math.pi / 2, 0), verts=24)
    part("cyl", (0, 0.32, 1.3), (0.4, 0.4, 0.06), BLACK, torso, rot=(0, math.pi / 2, 0), verts=24)
    # ombreiras gigantes com borda vermelha (a cor do time)
    for s in (1, -1):
        part("sph", (s * 0.4, 0, 1.5), (0.36, 0.42, 0.3), ARMOR, torso, verts=24)
        part("cyl", (s * 0.4, 0, 1.43), (0.38, 0.44, 0.06), RED, torso, verts=24)
        part("cube", (s * 0.57, 0, 1.5), (0.02, 0.14, 0.12), BONE, torso, bevel=0.01)
    # braços grossos: direito no punho da arma, esquerdo na alça
    limb((-0.4, 0, 1.38), (-0.36, 0.02, 1.12), 0.1, 0.09, ARMOR, torso)
    limb((-0.36, 0.02, 1.12), (-0.2, -0.2, 1.04), 0.09, 0.08, ARMOR_L, torso)
    part("sph", (-0.2, -0.22, 1.04), (0.15,) * 3, BLACK, torso)
    limb((0.4, 0, 1.38), (0.32, -0.12, 1.16), 0.1, 0.09, ARMOR, torso)
    limb((0.32, -0.12, 1.16), (-0.08, -0.36, 1.18), 0.09, 0.08, ARMOR_L, torso)
    part("sph", (-0.1, -0.37, 1.18), (0.15,) * 3, BLACK, torso)
    # cabeça afundada: elmo com visor
    part("cyl", (0, -0.02, 1.56), (0.2, 0.2, 0.1), BLACK, neck)
    part("sph", (0, -0.03, 1.66), (0.3, 0.32, 0.3), ARMOR, neck, verts=24)
    part("cube", (0, -0.17, 1.64), (0.2, 0.06, 0.13), BLACK, neck, bevel=0.02)
    part("cube", (0, -0.2, 1.665), (0.16, 0.02, 0.03), EYE, neck)
    part("cyl", (0, -0.2, 1.585), (0.07, 0.07, 0.05), STEEL, neck, rot=(math.pi / 2, 0, 0))
    # metralhadora rotativa
    set_gun((-0.17, -0.2, 1.06), (-0.17, -0.95, 1.06))
    part("cube", (-0.17, -0.3, 1.06), (0.16, 0.34, 0.18), ARMOR_L, gun, bevel=0.025)
    part("cube", (-0.17, -0.3, 1.19), (0.04, 0.2, 0.06), BLACK, gun, bevel=0.01)      # alça
    for i in range(6):
        a = i / 6 * math.tau
        part("cyl", (-0.17 + math.cos(a) * 0.055, -0.68, 1.06 + math.sin(a) * 0.055),
             (0.04, 0.04, 0.5), STEEL, gun, rot=(math.pi / 2, 0, 0), verts=8)
    for yy in (-0.52, -0.88):
        part("cyl", (-0.17, yy, 1.06), (0.15, 0.15, 0.04), BLACK, gun, rot=(math.pi / 2, 0, 0))
    # fita de munição do tambor até a arma, passando pelo quadril direito
    pts = [(-0.18, 0.2, 1.12), (-0.33, 0.05, 0.98), (-0.32, -0.12, 0.95), (-0.22, -0.2, 1.0)]
    for a, b in zip(pts, pts[1:]):
        a, b = Vector(a), Vector(b)
        for k in range(4):
            p = a.lerp(b, (k + 0.5) / 4)
            part("cube", p, (0.06, 0.035, 0.035), BRASS, torso, bevel=0.006)


def build_engenheiro():
    """Óculos de visão noturna, braço mecânico na mochila, chave na mão e tablet holográfico."""
    legs()
    belt(pouches=(0.12, -0.12, -0.17, 0.17))
    part("cyl", (-0.17, -0.06, 0.92), (0.06, 0.06, 0.14), BRASS, pelvis)            # cilindro de ferramenta
    tattered("tabard_f", -0.08, 0.08, -0.125, 0.99, 0.6, RED, pelvis, 4)
    torso_armor(w=0.46, plate=None)
    part("cube", (0, -0.14, 1.3), (0.34, 0.06, 0.24), LEATHER, torso, bevel=0.02)    # colete de bolsos
    for px in (-0.1, 0.1):
        part("cube", (px, -0.18, 1.28), (0.1, 0.04, 0.1), CLOTH, torso, bevel=0.01)
    part("cyl", (0.08, -0.2, 1.4), (0.07, 0.07, 0.02), BRASS, torso, rot=(math.pi / 2, 0, 0))  # manômetro
    # manto vermelho caindo do ombro esquerdo pelas costas
    tattered("cape", -0.2, 0.24, 0.17, 1.45, 0.62, RED, torso, 11, back=True, cols=8, ragged=0.16)
    part("sph", (0.3, 0, 1.44), (0.27, 0.32, 0.22), RED, torso, verts=24)           # ombreira com o manto
    part("sph", (-0.29, 0, 1.43), (0.2, 0.24, 0.16), ARMOR_L, torso, verts=20)
    # mochila de servo e braço mecânico sobre a cabeça
    part("cube", (0, 0.21, 1.28), (0.32, 0.16, 0.36), STEEL, torso, bevel=0.03)
    part("cyl", (0.12, 0.3, 1.3), (0.08, 0.08, 0.3), BRASS, torso)
    j = [(-0.12, 0.25, 1.46), (-0.14, 0.22, 1.92), (-0.14, -0.12, 2.02), (-0.14, -0.28, 1.86)]
    for a, b in zip(j, j[1:]):
        limb(a, b, 0.035, 0.03, ARMOR_L, torso)
    for a in j[1:3]:
        part("sph", a, (0.08,) * 3, BLACK, torso)
    for s in (1, -1): # garra
        limb((-0.14, -0.28, 1.86), (-0.14 + s * 0.05, -0.33, 1.78), 0.015, 0.012, STEEL, torso)
    chain([(0.06, 0.24, 1.12), (-0.25, 0.1, 1.0), (-0.32, -0.08, 1.06)], 0.016, BLACK, torso)   # mangueira
    # braços: direita segura a chave à frente, esquerda ergue o tablet
    limb((-0.29, 0, 1.4), (-0.3, -0.02, 1.16), 0.075, 0.065, CLOTH, torso)
    limb((-0.3, -0.02, 1.16), (-0.24, -0.26, 1.12), 0.068, 0.058, ARMOR, torso)
    part("sph", (-0.24, -0.28, 1.12), (0.11,) * 3, BLACK, torso)
    limb((0.29, 0, 1.4), (0.32, -0.1, 1.2), 0.075, 0.065, CLOTH, torso)
    limb((0.32, -0.1, 1.2), (0.26, -0.34, 1.34), 0.068, 0.058, ARMOR, torso)
    part("sph", (0.26, -0.36, 1.34), (0.11,) * 3, BLACK, torso)
    part("cube", (0.27, -0.45, 1.44), (0.26, 0.015, 0.19), HOLO, torso, rot=(0.35, 0, -0.25))   # tablet
    set_gun((-0.24, -0.28, 1.12), (-0.24, -0.62, 1.04))
    part("cyl", (-0.24, -0.43, 1.09), (0.04, 0.04, 0.3), STEEL, gun, rot=(math.pi / 2 - 0.25, 0, 0))
    part("cube", (-0.24, -0.6, 1.05), (0.09, 0.07, 0.05), STEEL, gun, bevel=0.01)   # cabeça da chave
    # cabeça: capacete, máscara e óculos de visão noturna laranja
    helmet()
    gas_mask(eyes=BLACK, hose=False)
    for s in (1, -1):
        part("cyl", (s * 0.065, -0.21, 1.665), (0.075, 0.075, 0.1), BLACK, neck, rot=(math.pi / 2, 0, 0), verts=12)
        part("cyl", (s * 0.065, -0.265, 1.665), (0.06, 0.06, 0.012), AMBER, neck, rot=(math.pi / 2, 0, 0), verts=12)
    part("cube", (0, -0.12, 1.73), (0.2, 0.06, 0.04), BLACK, neck)                  # suporte dos óculos


def build_medico():
    """Capuz e tabardo brancos manchados de sangue, cruz vermelha, maleta e frasco de soro."""
    legs(pad=ARMOR_L)
    belt(pouches=(0.12, -0.12))
    torso_armor(w=0.46, plate=None)
    # tabardo branco comprido na frente e atrás
    tattered("tabard_f", -0.17, 0.17, -0.16, 1.2, 0.45, WHITE, torso, 6, cols=8, ragged=0.15)
    tattered("tabard_b", -0.2, 0.2, 0.16, 1.3, 0.42, WHITE, torso, 12, back=True, cols=8, ragged=0.15)
    part("cube", (0, -0.165, 1.32), (0.2, 0.05, 0.24), WHITE, torso, bevel=0.01)     # peito do tabardo
    part("cube", (0, -0.192, 1.32), (0.05, 0.01, 0.17), RED, torso)                 # cruz
    part("cube", (0, -0.192, 1.34), (0.14, 0.01, 0.05), RED, torso)
    # manto nos ombros e capuz
    part("sph", (0, 0.01, 1.43), (0.62, 0.42, 0.24), WHITE, torso, verts=24)
    for s in (1, -1): # cruz nas ombreiras
        part("cube", (s * 0.3, -0.02, 1.53), (0.04, 0.12, 0.012), RED, torso)
        part("cube", (s * 0.3, -0.02, 1.535), (0.12, 0.04, 0.012), RED, torso)
    part("sph", (0, 0.03, 1.67), (0.36, 0.38, 0.4), WHITE, neck, verts=24)
    part("cone", (0, 0.2, 1.74), (0.16, 0.16, 0.18), WHITE, neck, rot=(-1.1, 0, 0))   # ponta do capuz
    gas_mask(z=1.6, hose=False)
    # maleta médica no quadril esquerdo
    part("cube", (0.27, -0.02, 0.92), (0.1, 0.26, 0.2), WHITE, pelvis, bevel=0.02)
    part("cube", (0.325, -0.02, 0.93), (0.01, 0.05, 0.14), RED, pelvis)
    part("cube", (0.325, -0.02, 0.94), (0.01, 0.14, 0.05), RED, pelvis)
    limb((0.27, -0.02, 1.02), (-0.2, -0.1, 1.42), 0.015, 0.015, LEATHER, torso, caps=False)   # alça
    # braços: direita com o injetor à frente, esquerda segura o frasco de soro
    limb((-0.29, 0, 1.4), (-0.3, -0.02, 1.16), 0.075, 0.065, WHITE, torso)
    limb((-0.3, -0.02, 1.16), (-0.22, -0.28, 1.16), 0.068, 0.058, ARMOR, torso)
    part("sph", (-0.22, -0.3, 1.16), (0.11,) * 3, BLACK, torso)
    limb((0.29, 0, 1.4), (0.33, -0.02, 1.15), 0.075, 0.065, WHITE, torso)
    limb((0.33, -0.02, 1.15), (0.3, -0.12, 0.92), 0.068, 0.058, ARMOR, torso)
    part("sph", (0.3, -0.13, 0.9), (0.11,) * 3, BLACK, torso)
    part("cyl", (0.3, -0.14, 0.8), (0.07, 0.07, 0.13), AMBER, torso)               # frasco brilhante
    part("cyl", (0.3, -0.14, 0.875), (0.08, 0.08, 0.02), BRASS, torso)
    set_gun((-0.22, -0.3, 1.16), (-0.22, -0.56, 1.18))
    part("cyl", (-0.22, -0.4, 1.17), (0.05, 0.05, 0.16), STEEL, gun, rot=(math.pi / 2, 0, 0))
    part("cyl", (-0.22, -0.42, 1.17), (0.035, 0.035, 0.1), mat("soro", "#7fd06a", 0.4, emit=2.5), gun,
         rot=(math.pi / 2, 0, 0))
    part("cyl", (-0.22, -0.52, 1.18), (0.012, 0.012, 0.1), STEEL, gun, rot=(math.pi / 2, 0, 0))   # agulha


def build_comando():
    """Roupa ghillie em trapos, capuz com olhos vermelhos e fuzil de precisão com luneta no ombro."""
    legs(pad=GHILLIE[2], shin_m=GHILLIE[4])
    belt(pouches=(0.12, 0.17))
    torso_armor(w=0.44, plate=None)
    part("cube", (0, 0.19, 1.28), (0.26, 0.13, 0.3), GHILLIE[2], torso, bevel=0.035)  # mochila
    for s in (1, -1):
        part("sph", (s * 0.28, 0, 1.43), (0.2, 0.25, 0.17), GHILLIE[1], torso, verts=16)
    # fuzil apoiado no ombro direito, mira alta
    set_gun((-0.12, -0.12, 1.3), (-0.1, -1.08, 1.33))
    arms_rifle(upper=GHILLIE[0], fore=GHILLIE[4], hand_r=(-0.13, -0.2, 1.24), hand_l=(-0.09, -0.52, 1.28), sh=0.28)
    part("cube", (-0.12, 0.0, 1.29), (0.05, 0.2, 0.09), LEATHER, gun, bevel=0.012)    # coronha
    part("cube", (-0.11, -0.27, 1.31), (0.06, 0.34, 0.08), BLACK, gun, bevel=0.012)
    part("cube", (-0.11, -0.3, 1.25), (0.04, 0.05, 0.08), BLACK, gun, rot=(0.25, 0, 0))   # carregador
    part("cyl", (-0.11, -0.25, 1.39), (0.045, 0.045, 0.28), STEEL, gun, rot=(math.pi / 2, 0, 0))   # luneta
    part("cyl", (-0.11, -0.4, 1.39), (0.035, 0.035, 0.012), EYE, gun, rot=(math.pi / 2, 0, 0))
    part("cyl", (-0.1, -0.75, 1.33), (0.022, 0.022, 0.5), BLACK, gun, rot=(math.pi / 2, 0, 0))
    part("cyl", (-0.1, -1.0, 1.33), (0.04, 0.04, 0.12), STEEL, gun, rot=(math.pi / 2, 0, 0))     # supressor
    # capuz ghillie com a máscara e olhos vermelhos à mostra
    part("cyl", (0, 0, 1.52), (0.12, 0.12, 0.08), BLACK, neck)
    part("sph", (0, 0.02, 1.66), (0.34, 0.36, 0.34), GHILLIE[3], neck, verts=20)
    part("sph", (0, -0.12, 1.62), (0.18, 0.12, 0.16), BLACK, neck)
    for s in (1, -1):
        part("cyl", (s * 0.055, -0.175, 1.655), (0.05, 0.05, 0.02), EYE, neck, rot=(math.pi / 2, 0, 0), verts=12)
    # trapos pendurados: capuz, ombros/tronco e quadril (deixam a arma livre)
    front_right = lambda x, y: x < -0.02 and y < -0.05
    strips(neck, (0, 0.02), 0.17, 0.18, 1.78, (0.12, 0.3), 30, 1, GHILLIE, skip=lambda x, y: y < -0.12)
    strips(torso, (0, 0), 0.32, 0.22, 1.5, (0.25, 0.55), 70, 2, GHILLIE, skip=front_right)
    strips(pelvis, (0, 0), 0.24, 0.17, 1.02, (0.2, 0.5), 40, 3, GHILLIE)


BUILD = {"soldado": build_soldado, "fuzileiro_pesado": build_fuzileiro_pesado,
         "engenheiro": build_engenheiro, "medico": build_medico, "comando": build_comando}
FLASH = {"engenheiro": "spark", "medico": "heal"}.get(UNIT, "fire")
BUILD[UNIT]()


# ------------------------------------------------------------------ câmera, luz, render

cam_data = bpy.data.cameras.new("cam")
cam_data.type = "ORTHO"
cam_data.ortho_scale = FRAME / PX_PER_M
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
elev = math.radians(30)
YAW = math.radians(45)   # vista isométrica (igual a SpriteBody.YAW no jogo)


def yawed(v):
    """Gira um vetor (x, y, z) em YAW em torno do eixo vertical (câmera e luzes)."""
    c, s = math.cos(YAW), math.sin(YAW)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c, v[2])
# alvo deslocado para os pés caírem em FEET_Y
target = Vector((0, 0, (FEET_Y - FRAME / 2) / PX_PER_M / math.cos(elev)))
d = Vector(yawed((0, -math.cos(elev), math.sin(elev))))
cam.location = target + d * 20
cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
scene.camera = cam


def sun(name, direction, energy, color):
    ld = bpy.data.lights.new(name, "SUN")
    ld.energy = energy
    ld.color = color
    ld.angle = math.radians(3)
    o = bpy.data.objects.new(name, ld)
    scene.collection.objects.link(o)
    o.rotation_euler = Vector(yawed(direction)).normalized().to_track_quat("Z", "Y").to_euler()


if REAL:
    # sol alto vindo da esquerda (um pouco de trás): a sombra cai para a direita/baixo
    sun("key", (-0.75, 0.25, 1.15), 4.2, (1.0, 0.95, 0.86))
    sun("fill", (0.5, -0.8, 0.4), 0.9, (0.7, 0.78, 0.9))   # céu frio, sem sombra
    bpy.data.lights["fill"].use_shadow = False
    bpy.ops.mesh.primitive_plane_add(size=12)
    bpy.context.object.is_shadow_catcher = True
else:
    sun("key", (-0.65, -0.55, 0.8), 6.5, (1.0, 0.96, 0.9))     # luz principal: cima-esquerda
    sun("rim", (0.8, 0.9, 0.35), 5.0, (1.0, 0.55, 0.35))       # contraluz de fogo
    sun("fill", (0.6, -0.8, 0.2), 1.4, (0.6, 0.7, 0.9))        # preenchimento frio

world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.14, 0.13, 0.13, 1)
scene.world = world

if REAL:
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.3, 0.32, 0.34, 1)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 24
    scene.cycles.use_denoising = True
    scene.cycles.max_bounces = 3
    scene.render.filter_size = 1.0
else:
    scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = RES
scene.render.resolution_y = RES
scene.render.film_transparent = True
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "AgX" if REAL else "Standard"
try:
    scene.eevee.taa_render_samples = 16
except AttributeError:
    pass


# ------------------------------------------------------------------ animação

JOINTS = [o for o in scene.objects if o.type == "EMPTY" and o.name != "root"]
POOL = {"death": (0, 0.75, 0), "death_fwd": (0, -0.8, 0), "death_blast": (0, 0.95, 0)}
HEAVY = UNIT == "fuzileiro_pesado"


def drop_gun(k, to, spin):
    """A arma escapa das mãos e cai deitada em `to` (coordenadas locais do root)."""
    gun.parent = root
    rest = JW["gun"]
    gun.location = rest.lerp(Vector(to), k)
    gun.rotation_euler.z = spin * k


def swing(f_ang):
    """Balanço dos panos: o da frente vai para um lado, o de trás para o outro."""
    for t, sgn in TABARDS:
        t.rotation_euler.x = f_ang * sgn


def reset():
    for j in JOINTS:
        j.rotation_euler = (0, 0, 0)
        j.location = REST[j.name].copy()
    gun.parent = torso
    gun.location = REST["gun"].copy()
    for t, _ in TABARDS:
        t.rotation_euler = (0, 0, 0)
    # pernas um pouco mais curtas: proporção mais robusta
    for s in (1, -1):
        hip[s].scale = (1.0, 1.0, 0.88)
    pelvis.location.z -= 0.11


def pose(anim, f):
    if anim == "idle":
        p = f / 4 * math.tau
        torso.location.z += 0.008 * math.sin(p)
        neck.rotation_euler.x = 0.03 * math.sin(p)
        for t, _ in TABARDS:
            t.rotation_euler.x = 0.03 * math.sin(p)
    elif anim == "walk":
        p = f / 6 * math.tau
        stride = 0.42 if HEAVY else 0.5
        hip[1].rotation_euler.x = -stride * math.sin(p)
        hip[-1].rotation_euler.x = stride * math.sin(p)
        knee[1].rotation_euler.x = 0.1 + 0.7 * max(0.0, math.cos(p))
        knee[-1].rotation_euler.x = 0.1 + 0.7 * max(0.0, -math.cos(p))
        pelvis.location.z -= (0.05 if HEAVY else 0.035) * abs(math.sin(p))
        torso.rotation_euler.z = 0.07 * math.sin(p)
        swing(0.11 * abs(math.sin(p)))
        if REAL: # inclinado para a frente, passada mais aberta: lê "andando" mesmo pequeno
            torso.rotation_euler.x = 0.08 if HEAVY else 0.16
            neck.rotation_euler.x = -0.08
            hip[1].rotation_euler.x *= 1.25
            hip[-1].rotation_euler.x *= 1.25
    elif anim == "attack":
        if HEAVY: # rajada: tremor curto em vez de um coice só
            torso.location.y += [0.02, 0.01, 0.02][f]
            gun.location.z += [0.01, -0.01, 0.0][f]
        else:
            torso.location.y += [0.035, 0.015, 0.0][f]
            torso.rotation_euler.x = [-0.05, -0.02, 0.0][f]
    elif anim == "death":
        a = math.radians([10, 30, 60, 84, 90][f])
        tilt.rotation_euler.x = -a
        tilt.location.z = math.sin(a) * 0.17
        for s in (1, -1):
            knee[s].rotation_euler.x = [0.1, 0.4, 0.5, 0.3, 0.2][f]
        neck.rotation_euler.x = [0, 0, -0.2, -0.45, -0.5][f]
        for t, _ in TABARDS:
            t.rotation_euler.x = [0, 0.05, 0.1, 0.12, 0.12][f]
        # a arma escapa das mãos e cai deitada à frente
        r = JW["gun"]
        drop_gun([0.0, 0.25, 0.7, 1.0, 1.0][f], (r.x - 0.08, r.y - 0.25, 0.1), 0.5)
    elif anim == "death_fwd":
        # atingido pelas costas: joelhos cedem, tomba de cara, rosto virado de lado
        a = math.radians([12, 32, 62, 86, 90][f])
        tilt.rotation_euler.x = a
        tilt.location.z = math.sin(a) * 0.2
        tilt.location.y = -[0.0, 0.05, 0.1, 0.12, 0.12][f]
        for s in (1, -1):
            knee[s].rotation_euler.x = [0.5, 0.8, 0.6, 0.35, 0.3][f] * (1.0 if s > 0 else 0.7)
            hip[s].rotation_euler.x = [-0.25, -0.4, -0.2, 0.0, 0.0][f]
        neck.rotation_euler.x = [0.1, 0.0, -0.3, -0.5, -0.55][f]
        neck.rotation_euler.z = [0, 0.1, 0.35, 0.6, 0.6][f]
        torso.rotation_euler.y = [0, 0.05, 0.12, 0.15, 0.15][f]
        for t, _ in TABARDS:
            t.rotation_euler.x = [0, -0.1, -0.2, -0.1, -0.08][f]
        r = JW["gun"]
        drop_gun([0.0, 0.3, 0.75, 1.0, 1.0][f], (r.x + 0.25, r.y - 1.2, 0.08), -0.9)
    elif anim == "death_blast":
        # explosão: arremessado para trás e para cima, gira além do chão e assenta largado
        up = [0.12, 0.42, 0.55, 0.38, 0.12, 0.0, 0.0][f]
        back = [0.05, 0.15, 0.25, 0.32, 0.36, 0.38, 0.38][f]
        if HEAVY: # armadura pesada voa menos
            up *= 0.6
            back *= 0.7
        a = math.radians([18, 52, 88, 112, 100, 92, 90][f])
        tilt.rotation_euler.x = -a
        tilt.rotation_euler.y = [0, 0.15, 0.3, 0.35, 0.3, 0.25, 0.25][f]
        tilt.location = Vector((0, back, up + math.sin(a) * 0.17))
        for s in (1, -1): # pernas e braços soltos, abertos
            hip[s].rotation_euler.x = s * [0.3, 0.6, -0.4, 0.3, 0.2, 0.15, 0.15][f]
            hip[s].rotation_euler.y = s * [0.1, 0.3, 0.35, 0.25, 0.2, 0.2, 0.2][f]
            knee[s].rotation_euler.x = [0.6, 1.0, 0.7, 0.4, 0.5, 0.3, 0.3][f] * (1 if s > 0 else 0.6)
        neck.rotation_euler.x = [-0.3, -0.6, -0.5, -0.2, -0.4, -0.5, -0.5][f]
        neck.rotation_euler.z = [0, 0.2, 0.4, 0.3, 0.4, 0.5, 0.5][f]
        torso.rotation_euler.y = [0, 0.15, 0.3, 0.2, 0.15, 0.15, 0.15][f]
        for t, _ in TABARDS:
            t.rotation_euler.x = [0.4, 0.8, 0.6, 0.3, 0.15, 0.12, 0.12][f]
        r = JW["gun"]
        k = [0.1, 0.35, 0.6, 0.8, 0.95, 1.0, 1.0][f]
        drop_gun(k, (r.x + 0.55, r.y + 0.3, 0.08), 2.2)
        gun.location.z += [0.1, 0.5, 0.7, 0.5, 0.15, 0, 0][f]


def px(world_pos):
    co = world_to_camera_view(scene, cam, world_pos)
    return [round(co.x * FRAME, 2), round((1 - co.y) * FRAME, 2)]


meta = {"frame": FRAME, "dirs": DIRS, "anims": ANIMS, "style": "real" if REAL else "hd",
        "unit": UNIT, "flash": FLASH, "frames": {}}
for di, dn in enumerate(DIRS):
    root.rotation_euler.z = math.radians(-45 * di)
    for anim, n in ANIMS:
        for f in range(n):
            key = "%s_%s_%d" % (dn, anim, f)
            if TEST and key not in TEST_KEYS:
                continue
            reset()
            pose(anim, f)
            bpy.context.view_layer.update()
            meta["frames"][key] = {
                "muzzle": px(muzzle.matrix_world.translation),
                "feet": px(root.matrix_world.translation),
                "pool": px(root.matrix_world @ Vector(POOL.get(anim, (0, 0.75, 0)))),
            }
            scene.render.filepath = os.path.join(OUT, key + ".png")
            bpy.ops.render.render(write_still=True)

if not TEST:
    with open(os.path.join(OUT, "meta.json"), "w") as fh:
        json.dump(meta, fh, indent=1)
print("RENDER OK", len(meta["frames"]))
