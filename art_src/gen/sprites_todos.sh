#!/bin/sh
# Renderiza no Blender e pixeliza no Godot as folhas de sprite dos modelos que casam com os
# filtros (ex.: sh art_src/gen/sprites_todos.sh rob_ _rob). Rodar na pasta do projeto.
BLENDER="/c/Program Files/Blender Foundation/Blender 5.2/blender.exe"
GODOT=/h/Jogos/Godot/Godot_v4.7.2-stable_win64_console.exe
"$BLENDER" -b --factory-startup --python art_src/blender/render_sprites.py -- models art_src/renders "$@" 2>&1 | grep -E "SPRITES|Error|Traceback"
for d in art_src/renders/*/; do
	n=$(basename "$d")
	for f in "$@"; do
		case "$n" in *"$f"*)
			"$GODOT" --headless --path . -s "$(pwd -W)/art_src/gen/pixelize.gd" -- "$n" 2>&1 | grep -E "pronta|SCRIPT ERROR"
			break;;
		esac
	done
done
echo "SPRITES OK"
