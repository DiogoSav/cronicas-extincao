extends SceneTree
## Teste de integração da IA inimiga com três times
## (design/quick-specs/ia-inimiga-terceiro-time-2026-11-03.md).
##
## Monta a H01 com um segundo inimigo (Legião Sintética), acelera o tempo e verifica:
##   1. três times com IA própria e cores distintas;
##   2. hostilidade entre os inimigos conforme "enemies_allied";
##   3. reconstrução de um quartel destruído (nível Médio);
##   4. defesa: unidades em casa vão até o prédio atacado;
##   5. destroy_all só se cumpre sem prédios nos dois inimigos.
## Tira prints em production/qa/evidence/.
##
## Rodar (com janela, para os prints):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/integration/ia/teste_tres_times.gd
## Sai com código 0 se tudo passou, 1 se algo falhou.

const EVIDENCE := "res://production/qa/evidence/"
const SPEED := 4.0

var game: Node
var main: Node
var failures: Array = []


func _initialize() -> void:
	game = root.get_node("Game")
	var m: Dictionary = load("res://data/campaign.gd").MISSIONS["H01"].duplicate(true)
	m["enemy2"] = "rob"
	m["enemies_allied"] = false
	m["credits"] = [4000.0, 6000.0, 6000.0]
	m["enemy2_base"] = Vector2i(54, 41)
	m["enemy2_start"] = {
		"buildings": [["cy", Vector2i(54, 40)], ["power", Vector2i(58, 43)], ["barracks", Vector2i(49, 42)]],
		"units": [["rob_rifle", Vector2i(52, 37), 3]],
	}
	m["ai"]["difficulty"] = "medio"
	m["ai2"] = {"first_wave": 600.0, "wave_size": 4, "produce": true, "difficulty": "medio"}
	game.mission_id = "H01"
	game.mission = m
	game.player_faction = m["player"]
	game.enemy_choice = m["enemy"]
	game.map_size = m["map"]["size"]
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASSOU  " if ok else "FALHOU  ") + what)
	if not ok:
		failures.append(what)


func _wait(seconds: float) -> void:
	await create_timer(seconds / SPEED, true, false, true).timeout


## Só para os prints: desliga a névoa de guerra e mostra todas as entidades.
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
	img.save_png(ProjectSettings.globalize_path(EVIDENCE + name))
	print("print: " + EVIDENCE + name)


func _buildings(team: int, type := "") -> Array:
	return game.entities.filter(func(e): return e.team == team and not e.dead \
			and e.has_method("start_construction") and (type == "" or e.type == type))


func _run() -> void:
	await process_frame
	await process_frame
	main = current_scene
	paused = false
	if main.mission != null and main.mission._modal != null:
		main.mission._close_modal()
	Engine.time_scale = SPEED

	# 1. três times
	_check(game.team_count == 3, "três times na partida (team_count = %d)" % game.team_count)
	_check(main.ai2 != null and main.ai2.team == 2, "IA própria para o time 2")
	_check(_buildings(2).size() == 3, "base do segundo inimigo criada (%d prédios)" % _buildings(2).size())
	_check(game.team_color(1) != game.team_color(2), "cores distintas para os dois inimigos")

	# 2. hostilidade
	_check(game.are_enemies(1, 2), "inimigos hostis entre si com enemies_allied = false")
	_check(game.are_enemies(0, 1) and game.are_enemies(0, 2), "jogador é inimigo dos dois")
	game.enemies_allied = true
	_check(not game.are_enemies(1, 2), "inimigos aliados com enemies_allied = true")
	game.enemies_allied = false

	main.cam.focus(main.map.cell_center(Vector2i(48, 32)))
	main.cam.dist = main.cam.DIST_MAX
	main.cam._dist_goal = main.cam.DIST_MAX
	await _wait(20.0)
	await _shot("ia_tres_times_inicio.png")

	# 3. reconstrução: destrói o quartel do time 2 e espera ele voltar
	var b: Array = _buildings(2, "barracks")
	_check(b.size() == 1, "quartel do time 2 existe antes do teste")
	if b.size() == 1:
		b[0].take_damage(1e9, "cannon")
		await _wait(4.0)
		_check(_buildings(2, "barracks").is_empty(), "quartel destruído")
		await _wait(60.0)
		_check(_buildings(2, "barracks").size() == 1, "quartel reconstruído pela IA (Médio)")

	# 4. defesa: dano num prédio do time 1 com um soldado do jogador perto
	var cy1: Array = _buildings(1, "cy")
	if cy1.size() == 1:
		var spot: Vector2 = cy1[0].position + Vector2(-3, 0) * game.TILE
		var intruder = game.spawn_unit("hum_soldado", 0, spot)
		# Resistente: se as torres o matarem antes de a IA pensar, não há quem defender
		intruder.max_hp = 1e6
		intruder.hp = 1e6
		cy1[0].take_damage(5.0, "rifle")
		main.cam.focus(cy1[0].position)
		await _wait(6.0)
		_check(main.ai._defenders.size() > 0, "IA chamou defensores (%d)" % main.ai._defenders.size())
		await _shot("ia_defesa.png")
		if is_instance_valid(intruder):
			intruder.take_damage(1e9, "cannon")

	# 5. destroy_all com dois inimigos
	var obj := {"type": "destroy_all"}
	_check(not main.mission._objective_met(obj), "destroy_all não cumprido com os dois inimigos de pé")
	for e in _buildings(1):
		e.take_damage(1e9, "cannon")
	await _wait(3.0)
	_check(not main.mission._objective_met(obj), "destroy_all não cumprido só com o time 1 destruído")

	Engine.time_scale = 1.0
	print("RESULTADO: %s (%d falhas)" % ["OK" if failures.is_empty() else "FALHOU", failures.size()])
	quit(0 if failures.is_empty() else 1)
