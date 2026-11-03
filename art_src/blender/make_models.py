"""Gera todos os modelos .glb do jogo (raças e cenário).

Uso (na pasta do projeto):
  blender -b --factory-startup --python art_src/blender/make_models.py -- models [filtro]

Rodar de novo sobrescreve os .glb (edições feitas à mão no Blender se perdem).
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import core  # noqa: E402

# Todo arquivo .py desta pasta (fora os do motor) com uma função all_models() é um módulo de
# modelos: uma raça (human.py, robot.py...) ou o cenário (props.py). Para criar uma raça nova
# basta copiar um deles com outro nome.
SKIP = {"core", "palettes", "make_models", "preview", "render_sprites", "infantaria"}
MODULES = []
for fname in sorted(os.listdir(os.path.dirname(os.path.abspath(__file__)))):
    name, ext = os.path.splitext(fname)
    if ext == ".py" and name not in SKIP:
        mod = __import__(name)
        if hasattr(mod, "all_models"):
            MODULES.append(mod)

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
out_dir = os.path.abspath(args[0] if args else "models")
flt = args[1] if len(args) > 1 else ""
os.makedirs(out_dir, exist_ok=True)

count = 0
for mod in MODULES:
    for model in mod.all_models():
        if flt and flt not in model.name:
            continue
        core.build(model, out_dir)
        count += 1
        print("modelo:", model.name)
print("total:", count)
