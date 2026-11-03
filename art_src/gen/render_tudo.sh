#!/bin/sh
# Refaz TODAS as folhas de sprite do jogo (vista isométrica): a infantaria detalhada do
# Império (infantaria.py) e depois todos os modelos .glb (render_sprites.py). ~2 h.
# Rodar na pasta do projeto: sh art_src/gen/render_tudo.sh
BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
GODOT=/h/Jogos/Godot/Godot_v4.7.2-stable_win64_console.exe
ROOT=$(pwd -W)
for p in soldado:hum_soldado fuzileiro_pesado:hum_fuzileiro engenheiro:hum_engenheiro medico:hum_medico comando:hum_comando; do
	unit=${p%%:*}
	name=${p##*:}
	"$BLENDER" -b --factory-startup --python art_src/blender/infantaria.py -- "$ROOT/art_src/renders/$name" "$unit" real 2>&1 | grep -E "RENDER OK|Error|Traceback"
	"$GODOT" --headless --path . -s "$ROOT/art_src/gen/pixelize.gd" -- "$name" 2>&1 | grep -E "pronta|SCRIPT ERROR"
done
sh art_src/gen/sprites_todos.sh hum_ _hum rob_ _rob ins_ _ins prop_ ore_crystal
echo "TUDO OK"
