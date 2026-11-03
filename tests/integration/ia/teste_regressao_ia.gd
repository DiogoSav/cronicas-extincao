extends SceneTree
## Regressão da IA (design/quick-specs/ia-inimiga-terceiro-time-2026-11-03.md): H01, H02 e a
## escaramuça (Difícil) continuam com 2 times, a IA produz e manda a primeira onda, e
## nenhuma partida gera erro de script.
##
## Rodar:
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/integration/ia/teste_regressao_ia.gd
## Sai com 0 se tudo passou, 1 se algo falhou.

const SPEED := 8.0

var game: Node
var failures: Array = []


func _initialize() -> void:
	game = root.get_node("Game")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASSOU  " if ok else "FALHOU  ") + what)
	if not ok:
		failures.append(what)


func _wait(seconds: float) -> void:
	await create_timer(seconds / SPEED, true, false, true).timeout


func _units(team: int) -> int:
	return game.entities.filter(func(e): return e.team == team and not e.dead \
			and e.has_method("command_move")).size()


## Abre uma partida (missão `id` ou escaramuça com `id` vazio) e devolve a cena.
func _open(id: String, difficulty := "medio") -> Node:
	if id == "":
		game.mission_id = ""
		game.mission = {}
		game.player_faction = "hum"
		game.enemy_choice = "ins"
		game.map_size = "small"
		game.ai_difficulty = difficulty
	else:
		var m: Dictionary = load("res://data/campaign.gd").MISSIONS[id]
		game.mission_id = id
		game.mission = m
		game.player_faction = m["player"]
		game.enemy_choice = m["enemy"]
		game.map_size = m["map"]["size"]
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var main: Node = current_scene
	paused = false
	if main.mission != null and main.mission._modal != null:
		main.mission._close_modal()
	return main


func _run() -> void:
	Engine.time_scale = SPEED
	for id in ["H01", "H02"]:
		var main := await _open(id)
		_check(game.team_count == 2 and main.ai2 == null, "%s: 2 times, sem segunda IA" % id)
		# A IA segura a produção enquanto o exército inicial já enche a onda (army_full):
		# só depois da primeira onda volta a produzir.
		var first: float = float(game.mission["ai"]["first_wave"])
		await _wait(first + 45.0)
		_check(not game.game_over, "%s: partida segue rodando após %d s" % [id, int(first + 45.0)])
		_check(main.ai.first_wave_sent, "%s: IA mandou a primeira onda" % id)
		var busy: bool = not game.production[1].is_empty() or game.credits[1] < float(game.mission["credits"][1])
		_check(busy, "%s: IA voltou a produzir depois da onda" % id)

	var sk := await _open("", "dificil")
	_check(game.team_count == 2 and sk.ai.diff["name"] == "Difícil", "escaramuça: 2 times e IA no Difícil")
	_check(is_equal_approx(game.income_mult[1], 1.25), "escaramuça: renda da IA ×1,25 no Difícil")
	await _wait(70.0)
	_check(sk.ai._layout_set and not sk.ai.layout.is_empty(), "escaramuça: IA gravou a base aos 60 s (%d prédios)" % sk.ai.layout.size())
	await _wait(200.0)
	_check(sk.ai.first_wave_sent, "escaramuça: IA mandou a primeira onda")

	Engine.time_scale = 1.0
	print("RESULTADO: %s (%d falhas)" % ["OK" if failures.is_empty() else "FALHOU", failures.size()])
	quit(0 if failures.is_empty() else 1)
