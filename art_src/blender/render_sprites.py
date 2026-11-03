"""Renderiza modelos .glb do jogo como sprites pré-renderizados (estilo RTS de guerra clássico).

blender -b --factory-startup --python art_src/blender/render_sprites.py -- <models> <renders> [filtro...]

Para cada models/<nome>.glb gera art_src/renders/<nome>/<DIR>_idle_0.png + meta.json; se o
modelo tem grupo "turret" ou "gun", a torre sai à parte em art_src/renders/<nome>_turret/.
Depois o art_src/gen/pixelize.gd transforma em assets/sprites/<nome>.png/.json.

Veículos e naves: 16 direções; prédios: 1 (de frente). Câmera ortográfica a 30°, a mesma do
jogo (SpriteBody.ELEVATION), PX_PER_UNIT pixels por célula. Sol alto da esquerda com sombra
projetada (shadow catcher) — naves não projetam (voam). Este arquivo não tem all_models():
o make_models.py o ignora.
"""

import json
import math
import os
import re
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
MODELS = os.path.abspath(ARGS[0])
OUT = os.path.abspath(ARGS[1])
FILTERS = ARGS[2:]
PX_PER_UNIT = 48.0
SS = 4                      # supersampling (o pixelize reduz)
ELEV = math.radians(30)
## Vista isométrica: câmera a sudeste olhando para noroeste (giro de 45°, igual a SpriteBody.YAW).
## As luzes giram junto, para a sombra cair sempre para a direita da tela.
YAW = math.radians(45)


def yawed(v):
    """Gira um vetor (x, y, z) em YAW em torno do eixo vertical."""
    c, s = math.cos(YAW), math.sin(YAW)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c, v[2])
DIRS16 = ["S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW", "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE"]
BUILDINGS = ("cy_", "power_", "refinery_", "barracks_", "factory_", "starport_", "turret_", "medic_")
## Folhas feitas à mão pelo infantaria.py (soldados detalhados): nunca sobrescrever daqui
MANUAL = {"hum_soldado", "hum_fuzileiro", "hum_engenheiro", "hum_medico", "hum_comando"}
AIR = ("_caca", "_cruzador", "_fighter", "_gunship", "_nave", "_colosso", "_nucleo")


def kind_of(name):
    if name.startswith("prop_") or name == "ore_crystal":
        return "prop"   # cenário: 8 variações (o modelo girado), sorteadas no mapa
    if name.startswith(BUILDINGS):
        return "bld"
    if name.endswith(AIR):
        return "air"
    return "veh"


def setup_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 12
    sc.cycles.use_denoising = True
    sc.cycles.max_bounces = 3
    sc.render.filter_size = 1.0
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"
    sc.view_settings.view_transform = "AgX"
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.3, 0.32, 0.34, 1)
    sc.world = w
    for name, d, e, col, shadow in (("key", (-0.75, 0.25, 1.15), 4.2, (1.0, 0.95, 0.86), True),
                                    ("fill", (0.5, -0.8, 0.4), 0.9, (0.7, 0.78, 0.9), False)):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = e
        ld.color = col
        ld.angle = math.radians(3)
        ld.use_shadow = shadow
        o = bpy.data.objects.new(name, ld)
        sc.collection.objects.link(o)
        o.rotation_euler = Vector(yawed(d)).normalized().to_track_quat("Z", "Y").to_euler()
    bpy.ops.mesh.primitive_plane_add(size=40)
    catcher = bpy.context.object
    catcher.is_shadow_catcher = True
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    sc.collection.objects.link(cam)
    sc.camera = cam
    return sc, cam, catcher


def matte(objs):
    """Materiais do kit são lisos e brilhantes; no estilo pré-renderizado ficam foscos e
    gastos: manchas de sujeira/ferrugem por ruído, relevo fino e cavidades escurecidas.
    Peças que brilham (emissão) ficam como estão."""
    done = set()
    for o in objs:
        for slot in getattr(o, "material_slots", []):
            m = slot.material
            if m is None or not m.use_nodes or m.name in done:
                continue
            done.add(m.name)
            nt = m.node_tree
            b = nt.nodes.get("Principled BSDF")
            if b is None:
                continue
            emit = b.inputs["Emission Color"].default_value
            if b.inputs["Emission Strength"].default_value > 0 and max(emit[:3]) > 0.05:
                # Partes acesas: o AgX lava cores fortes para o branco. Satura a cor (tira
                # parte do menor canal), escurece a base e mantém o brilho moderado.
                lo = min(emit[:3])
                sat = tuple(max(0.0, c - lo * 0.8) for c in emit[:3])
                b.inputs["Emission Color"].default_value = sat + (1,)
                b.inputs["Base Color"].default_value = tuple(c * 0.25 for c in sat) + (1,)
                b.inputs["Emission Strength"].default_value = 1.2
                continue
            b.inputs["Roughness"].default_value = max(b.inputs["Roughness"].default_value, 0.6)
            b.inputs["Metallic"].default_value = min(b.inputs["Metallic"].default_value, 0.4)
            base = tuple(b.inputs["Base Color"].default_value)
            coord = nt.nodes.new("ShaderNodeTexCoord")
            noise = nt.nodes.new("ShaderNodeTexNoise")
            noise.inputs["Scale"].default_value = 9.0
            noise.inputs["Detail"].default_value = 8.0
            nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
            ramp = nt.nodes.new("ShaderNodeValToRGB")
            e0, e1 = ramp.color_ramp.elements
            e0.position, e0.color = 0.35, tuple(c * 0.55 for c in base[:3]) + (1,)   # sujeira
            e1.position, e1.color = 0.7, base
            rust = ramp.color_ramp.elements.new(0.8)
            rust.color = (base[0] * 0.8 + 0.08, base[1] * 0.7 + 0.03, base[2] * 0.6, 1)
            nt.links.new(noise.outputs["Fac"], ramp.inputs["Fac"])
            ao = nt.nodes.new("ShaderNodeAmbientOcclusion")
            ao.inputs["Distance"].default_value = 0.08
            nt.links.new(ramp.outputs["Color"], ao.inputs["Color"])
            mix = nt.nodes.new("ShaderNodeMix")
            mix.data_type = "RGBA"
            mix.blend_type = "MULTIPLY"
            mix.inputs["Factor"].default_value = 0.6
            nt.links.new(ramp.outputs["Color"], mix.inputs["A"])
            nt.links.new(ao.outputs["AO"], mix.inputs["B"])
            nt.links.new(mix.outputs["Result"], b.inputs["Base Color"])
            fine = nt.nodes.new("ShaderNodeTexNoise")
            fine.inputs["Scale"].default_value = 60.0
            nt.links.new(coord.outputs["Object"], fine.inputs["Vector"])
            bump = nt.nodes.new("ShaderNodeBump")
            bump.inputs["Strength"].default_value = 0.25
            nt.links.new(fine.outputs["Fac"], bump.inputs["Height"])
            nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])


def render_model(name):
    sc, cam, catcher = setup_scene()
    kind = kind_of(name)
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(MODELS, name + ".glb"))
    objs = [o for o in bpy.data.objects if o not in before]
    tops = [o for o in objs if o.parent is None]
    root = bpy.data.objects.new("pivot", None)
    sc.collection.objects.link(root)
    for o in tops:
        o.parent = root
    matte(objs)
    turret = next((o for o in objs if o.name.split(".")[0] in ("turret", "gun")), None)
    tur_objs = set()
    if turret is not None:
        tur_objs = {turret} | set(turret.children_recursive)
    catcher.hide_render = kind == "air"

    # tamanho do quadro pelo maior alcance do modelo
    bpy.context.view_layer.update()
    pts = [o.matrix_world @ Vector(c) for o in objs if o.type == "MESH" for c in o.bound_box]
    rad = max(Vector((p.x, p.y, 0)).length for p in pts)
    top = max(p.z for p in pts)
    frame = int(math.ceil(max(rad * 2.0 * 1.35, rad * 1.3 + top * 1.2 + 0.4) * PX_PER_UNIT / 16.0) * 16)
    feet_y = int(frame * 0.62)
    cam.data.ortho_scale = frame / PX_PER_UNIT
    target = Vector((0, 0, (feet_y - frame / 2) / PX_PER_UNIT / math.cos(ELEV)))
    d = Vector(yawed((0, -math.cos(ELEV), math.sin(ELEV))))
    cam.location = target + d * 30
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    sc.render.resolution_x = sc.render.resolution_y = frame * SS

    dirs = ["S"] if kind == "bld" else DIRS16
    if kind == "prop":
        dirs = ["V%d" % i for i in range(8)]
    base = 0.0 if kind in ("bld", "prop") else -90.0   # glb olha para +X; a direção S olha para a câmera (-Y)

    def px(p):
        co = world_to_camera_view(sc, cam, p)
        return [round(co.x * frame, 2), round((1 - co.y) * frame, 2)]

    # Animações: patas (limb_*) ganham caminhada; asas (wing_*) batem em loop
    limbs, wings = [], []
    for o in objs:
        base_name = o.name.split(".")[0]
        # só o nó-pivô do grupo (o importador cria filhos como limb_l0_m com a malha)
        if not re.fullmatch(r"limb_[lr]\d+|wing_[lr]", base_name):
            continue
        o.rotation_mode = "XYZ"   # o importador glTF usa quaternion
        if base_name.startswith("limb_"):
            left = base_name[5] == "l"
            i = int(base_name[6:])
            group = i % 2 if left else (i + 1) % 2   # tripé alternado, como o jogo fazia
            limbs.append((o, 1.0 if left else -1.0, group * math.pi, o.rotation_euler.copy()))
        elif base_name.startswith("wing_"):
            wings.append((o, 1.0 if base_name.endswith("l") else -1.0, o.rotation_euler.copy()))
    small = rad < 0.45
    anims = [["idle", 1]]
    if limbs:
        anims.append(["walk", 6])
    if wings:
        anims = [["idle", 4]]

    def pose(anim, f):
        for o, side, ph, rest in limbs:
            o.rotation_euler = rest.copy()
            if anim == "walk":
                p = f / 6.0 * math.tau + ph
                o.rotation_euler.z += -side * math.sin(p) * (0.38 if small else 0.27)
                o.rotation_euler.x += side * max(0.0, math.cos(p)) ** 1.3 * (0.42 if small else 0.22)
        for o, side, rest in wings:
            o.rotation_euler = rest.copy()
            o.rotation_euler.x += side * math.sin(f / 4.0 * math.tau) * (0.5 if rad < 0.7 else 0.25)

    passes = [(name, None)]
    if turret is not None:
        passes.append((name + "_turret", "turret"))
    for out_name, part in passes:
        if part == "turret":   # torre gira para mirar: sempre 16 direções, olhando para +X
            dirs, base = DIRS16, -90.0
        folder = os.path.join(OUT, out_name)
        os.makedirs(folder, exist_ok=True)
        for o in objs:
            if o.type == "MESH":
                is_tur = o in tur_objs
                o.hide_render = is_tur if part is None else not is_tur
        meta = {"frame": frame, "dirs": dirs, "anims": anims if part is None else [["idle", 1]], "style": "real",
                "unit": out_name, "flash": "fire", "compare": False, "frames": {}}
        for di, dn in enumerate(dirs):
            root.rotation_euler.z = math.radians(base - 360.0 / len(dirs) * di)
            for anim, n in meta["anims"]:
                for f in range(n):
                    pose(anim, f)
                    bpy.context.view_layer.update()
                    key = "%s_%s_%d" % (dn, anim, f)
                    meta["frames"][key] = {"feet": px(Vector((0, 0, 0))), "muzzle": px(Vector((0, 0, 0.5))),
                                           "pool": px(Vector((0, 0, 0)))}
                    sc.render.filepath = os.path.join(folder, key + ".png")
                    bpy.ops.render.render(write_still=True)
        pose("idle", 0)
        with open(os.path.join(folder, "meta.json"), "w") as fh:
            json.dump(meta, fh, indent=1)
        print("SPRITES", out_name, frame, len(dirs))


names = sorted(f[:-4] for f in os.listdir(MODELS) if f.endswith(".glb"))
for n in names:
    if n in MANUAL:
        continue
    if FILTERS and not any(f in n for f in FILTERS):
        continue
    render_model(n)
print("RENDER OK")
