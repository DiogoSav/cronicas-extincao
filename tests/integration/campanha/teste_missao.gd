extends SceneTree
## Teste de integração de uma missão de campanha (data/campaign.gd). Verifica:
##   1. todas as tags dos objetivos existem (tag errada daria o objetivo como cumprido);
##   2. nenhum prédio inicial está sobre rocha nem sobreposto a outro;
##   3. há caminho por terra da base do jogador até cada base inimiga;
##   4. com segundo inimigo, os dois times e as duas IAs existem;
##   5. a missão roda RUN_TIME s de jogo sem erro e sem derrota, e os eventos com hora marcada
##      até lá disparam.
## Print do mapa revelado em production/qa/evidence/<id>_mapa.png.
##
## Rodar (uma missão por vez):
##   Godot_v4.7.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 -s res://tests/integration/campanha/teste_missao.gd -- H03
## Sai com 0 se tudo passou, 1 se algo falhou.

const EVIDENCE := "res://production/qa/evidence/"
const SPEED := 8.0
const RUN_TIME := 250.0

var game: Node
var main: Node
var id := "H03"
var failures: Array = []


func _initialize() -> void:
	if not OS.get_cmdline_user_args().is_empty():
		id = OS.get_cmdline_user_args()[0]
	game = root.get_node("Game")
	var m: Dictionary = load("res://data/campaign.gd").MISSIONS[id]
	game.mission_id = id
	game.mission = m
	game.player_faction = m["player"]
	game.enemy_choice = m["enemy"]
	game.map_size = m["map"]["size"]
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print("%s  %s: %s" % ["PASSOU" if ok else "FALHOU", id, what])
	if not ok:
		failures.append(what)


func _wait(seconds: float) -> void:
	await create_timer(seconds / SPEED, true, false, true).timeout


func _run() -> void:
	await process_frame
	await process_frame
	main = current_scene
	paused = false
	main.mission._close_modal()
	main.cam.set_process(false)
	var mission = main.mission
	var data: Dictionary = mission.data
	var map = main.map

	# 1. tags dos objetivos
	var missing: Array = []
	for o in data["objectives"]:
		if o["type"] == "destroy_tag":
			for tag in o.get("tags", [o.get("tag", "")]):
				if not mission._tags.has(tag):
					missing.append(tag)
	_check(missing.is_empty(), "tags dos objetivos existem (faltam: %s)" % [missing])

	# 2. prédios sobre rocha ou sobrepostos
	var bad: Array = []
	var used := {}
	for e in game.entities:
		if e.has_method("start_construction"):
			for x in e.size.x:
				for y in e.size.y:
					var c: Vector2i = e.cell + Vector2i(x, y)
					if not map.in_bounds(c):
						bad.append("%s fora do mapa em %s" % [e.type, c])
					elif map.tiles[map.idx(c)] == map.ROCK:
						bad.append("%s sobre rocha em %s" % [e.type, c])
					if used.has(c):
						bad.append("%s sobre %s em %s" % [e.type, used[c], c])
					used[c] = e.type
	_check(bad.is_empty(), "prédios no lugar (%s)" % [bad])

	# 3. caminho até cada base inimiga
	var bases := [data["enemy_base"]]
	if data.has("enemy2_base"):
		bases.append(data["enemy2_base"])
	for b in bases:
		var path: PackedVector2Array = map.find_path(map.cell_center(data["player_base"]), map.cell_center(b))
		_check(path.size() > 1, "caminho da base do jogador até %s (%d passos)" % [b, path.size()])

	# 4. segundo inimigo
	if data.has("enemy2"):
		_check(game.team_count == 3 and main.ai2 != null, "três times e duas IAs")
		_check(game.building_count(2) > 0, "base do segundo inimigo criada (%d prédios)" % game.building_count(2))

	# 5. roda RUN_TIME s
	Engine.time_scale = SPEED
	await _wait(RUN_TIME)
	Engine.time_scale = 1.0
	_check(not game.game_over, "segue rodando aos %d s, sem derrota" % int(RUN_TIME))
	var events: Array = data.get("events", [])
	var late: Array = []
	for i in events.size():
		var ev: Dictionary = events[i]
		if ev["at"] == "start" or (ev["at"] == "time" and float(ev["t"]) < RUN_TIME - 5.0):
			if not mission._fired.has(i):
				late.append(i)
	_check(late.is_empty(), "eventos até %d s dispararam (faltam índices %s)" % [int(RUN_TIME), late])

	# Print do mapa todo, sem névoa
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
	main.cam.focus(map.cell_center(Vector2i(map.W / 2, map.H / 2)))
	main.cam.dist = main.cam.DIST_MAX
	main.cam._dist_goal = main.cam.DIST_MAX
	for i in 20:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(EVIDENCE + id.to_lower() + "_mapa.png"))

	print("RESULTADO %s: %s (%d falhas)" % [id, "OK" if failures.is_empty() else "FALHOU", failures.size()])
	quit(0 if failures.is_empty() else 1)
