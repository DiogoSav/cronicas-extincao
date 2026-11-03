extends SceneTree
## Teste visual: ordem de desenho dos sprites (unidade na frente de prédio, torre de tanque
## atrás de prédio). Salva prints em production/qa/evidence/sprites_<prefixo>_*.png.
## Rodar (antes = comportamento atual; "-- depois [offset_torre]" aplica a correção proposta em tempo de execução):
##   Godot_v4.7.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 -s res://tests/visual/sprites_ordem_teste.gd [-- depois]

const EVIDENCE := "res://production/qa/evidence/"
var game: Node
var main: Node
var prefix := "antes"


func _initialize() -> void:
	if "depois" in OS.get_cmdline_user_args():
		prefix = "depois"
	elif not OS.get_cmdline_user_args().is_empty():
		prefix = OS.get_cmdline_user_args()[0]   # ex.: "-- corrigido" (código do jogo, sem correção em runtime)
	game = root.get_node("Game")
	var m: Dictionary = load("res://data/campaign.gd").MISSIONS["H01"].duplicate(true)
	game.mission_id = "H01"
	game.mission = m
	game.player_faction = m["player"]
	game.enemy_choice = m["enemy"]
	game.map_size = m["map"]["size"]
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _reveal() -> void:
	var fog = game.fog
	fog.set_process(false)
	fog.explored.fill(1)
	fog.visible_cells.fill(1)
	fog._level.fill(1.0)
	fog._bytes.fill(255)
	fog._img.set_data(fog._img.get_width(), fog._img.get_height(), false, Image.FORMAT_L8, fog._bytes)
	fog._tex.update(fog._img)
	for e in game.entities:
		e.visible = true


func _shot(name: String) -> void:
	_reveal()
	await process_frame
	await process_frame
	var img := root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	img.save_png(ProjectSettings.globalize_path(EVIDENCE + "sprites_%s_%s.png" % [prefix, name]))
	print("print: sprites_%s_%s.png" % [prefix, name])


func _run() -> void:
	await process_frame
	await process_frame
	main = current_scene
	paused = false
	if main.mission != null and main.mission._modal != null:
		main.mission._close_modal()
	# Limpa a área de teste: prédios e unidades de todos os times saem do caminho
	for e in game.entities.duplicate():
		if not e.has_method("start_construction"):
			e.position = Vector2(2, 2) * game.TILE
	var T: float = game.TILE
	# Prédio grande (quartel) no meio de uma área livre da base do jogador
	var cell := Vector2i(20, 30)
	var b = game.spawn_building("factory", 0, cell)
	var c: Vector2 = b.position
	var half: Vector2 = Vector2(b.size) / 2.0 * T
	print("prédio ", b.type, " size=", b.size, " pos=", c)
	# Frente (sudeste): soldado e um segundo logo encostado à borda sul e à leste
	game.spawn_unit("hum_soldado", 0, c + Vector2(half.x * 0.2, half.y + 0.5 * T))
	game.spawn_unit("hum_soldado", 0, c + Vector2(half.x + 0.5 * T, half.y * 0.2))
	game.spawn_unit("hum_soldado", 0, c + Vector2(half.x * 0.9, half.y + 0.9 * T))
	# Atrás (noroeste): tanques com torre, encostados à borda norte e oeste
	var t1 = game.spawn_unit("hum_tanque", 0, c + Vector2(-half.x - 0.1 * T, -half.y - 0.1 * T))
	var t2 = game.spawn_unit("hum_tanque", 0, c + Vector2(-half.x * 0.3, -half.y - 0.5 * T))
	for t in [t1, t2]:
		t.body_angle = PI / 2.0
	if prefix == "depois":
		_apply_fix(float(OS.get_cmdline_user_args()[-1]) if OS.get_cmdline_user_args().size() > 1 else 0.05)
	await create_timer(0.5).timeout
	main.cam.dist = 6.0
	main.cam._dist_goal = 6.0
	main.cam.focus(c + Vector2(0, 0))
	await _shot("predio_geral")
	main.cam.dist = 3.5
	main.cam._dist_goal = 3.5
	main.cam.focus(c + Vector2(half.x * 0.5, half.y))
	await _shot("frente_unidades")
	main.cam.focus(c + Vector2(-half.x * 0.6, -half.y * 0.6))
	await _shot("atras_tanques")
	quit(0)


## Aplica em tempo de execução a correção proposta (sem editar o jogo), só no modo "depois":
## ordenação pela origem (pés) e torre com a mesma prioridade do casco, logo à frente dele.
func _apply_fix(turret_offset: float) -> void:
	for n in game.world.find_children("*", "Sprite3D", true, false):
		n.sorting_use_aabb_center = false
		if n.material_override != null and n.material_override.render_priority == 1:
			n.material_override = load("res://scripts/sprite_body.gd").material_for(n.texture, 0)
			n.sorting_offset = turret_offset
