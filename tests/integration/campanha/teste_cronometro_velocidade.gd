extends SceneTree
## Teste do cronômetro de objetivos de tempo e da velocidade do jogo, na H04
## (objetivo "Sobreviver … (10 minutos)"):
##   1. o cronômetro aparece e mostra o tempo restante, que diminui;
##   2. a linha do objetivo no painel traz o mesmo tempo;
##   3. teclas + e − mudam a velocidade em 25% (100 → 125 → 150 → 175, sem passar disso, e
##      sem descer de 100), e o botão do painel mostra o nível;
##   4. o cronômetro anda mais rápido com o jogo acelerado (é tempo de jogo).
## Prints em production/qa/evidence/cronometro_*.png.
##
## Rodar: Godot_v4.7.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 -s res://tests/integration/campanha/teste_cronometro_velocidade.gd

const EVIDENCE := "res://production/qa/evidence/"

var game: Node
var main: Node
var failures: Array = []


func _initialize() -> void:
	game = root.get_node("Game")
	var m: Dictionary = load("res://data/campaign.gd").MISSIONS["H04"]
	game.mission_id = "H04"
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


func _key(code: Key) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.pressed = true
	root.push_input(e)
	await process_frame


func _shot(name: String) -> void:
	for i in 10:
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(EVIDENCE + name))


## Segundos de missão por segundo real, medidos em ~2 s reais de quadros.
func _rate(mission) -> float:
	var t0: float = mission.time
	var r0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - r0 < 2000:
		await process_frame
	return (mission.time - t0) / ((Time.get_ticks_msec() - r0) / 1000.0)


## Segundos que o cronômetro mostra (mm:ss)
func _shown(label: Label) -> int:
	var p := label.text.split(":")
	return int(p[0]) * 60 + int(p[1])


func _run() -> void:
	await process_frame
	await process_frame
	main = current_scene
	paused = false
	main.mission._close_modal()
	var mission = main.mission
	for i in 30:
		await process_frame

	# 1 e 2. cronômetro
	_check(mission._timer_panel.visible, "cronômetro visível na missão com objetivo de tempo")
	var t0 := _shown(mission._timer_label)
	_check(t0 > 590 and t0 <= 600, "cronômetro começa perto de 10:00 (%s)" % mission._timer_label.text)
	_check(mission._obj_label.text.contains(mission._timer_label.text), "painel de objetivos mostra o mesmo tempo")
	await create_timer(3.0, true, false, true).timeout
	var t1 := _shown(mission._timer_label)
	_check(t1 < t0, "cronômetro diminui (%d → %d)" % [t0, t1])
	await _shot("cronometro_normal.png")

	# 3. velocidade pelas teclas
	var seen: Array = []
	for i in 4:
		await _key(KEY_EQUAL)
		seen.append(Engine.time_scale)
	_check(seen == [1.25, 1.5, 1.75, 1.75], "+ sobe de 25%% em 25%% e para em 175%% (%s)" % [seen])
	var btn_ok := false
	for b in main.hud.find_children("*", "Button", true, false):
		if b.text.contains("175%"):
			btn_ok = true
	_check(btn_ok, "botão do painel mostra 175%")
	await _shot("cronometro_velocidade.png")

	# 4. cronômetro anda mais rápido a 175% (3 s reais ≈ 5,25 s de jogo)
	# Compara o ritmo (tempo de jogo / tempo real) a 175% com o ritmo a 100%, medidos do mesmo
	# jeito: a razão absoluta depende da suavização de delta da janela de teste.
	var fast: float = await _rate(mission)
	game.set_speed_level(0)
	var normal: float = await _rate(mission)
	game.set_speed_level(3)
	print("ritmo: %.2f a 175%%, %.2f a 100%%" % [fast, normal])
	_check(absf(fast / normal - 1.75) < 0.15, "o cronômetro anda 1,75× mais rápido a 175%% (medido %.2f×)" % (fast / normal))

	seen.clear()
	for i in 4:
		await _key(KEY_MINUS)
		seen.append(Engine.time_scale)
	_check(seen == [1.5, 1.25, 1.0, 1.0], "− desce e para em 100%% (%s)" % [seen])

	print("RESULTADO: %s (%d falhas)" % ["OK" if failures.is_empty() else "FALHOU", failures.size()])
	quit(0 if failures.is_empty() else 1)
