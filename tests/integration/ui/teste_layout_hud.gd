extends SceneTree
## Teste de layout da HUD (production/ui/hud-e-menu/ux-spec.md, critérios 1, 2, 3, 5 e 8),
## na H04 (objetivo de tempo):
##   1. com 3 mensagens, uma transmissão de rádio e uma unidade selecionada, os retângulos
##      globais de objetivos, cronômetro, mensagens, rádio, InfoPanel e barra lateral não se
##      intersectam e estão dentro da tela;
##   2. a barra lateral tem 340 lógicos; a linha longa de ajuda não existe mais;
##   3. F1 abre/fecha o painel de atalhos; Esc o fecha sem limpar a seleção nem pausar.
## Print em production/qa/evidence/ui_hud_<largura>x<altura>_<facção>.png.
##
## Rodar (facção opcional: hum, rob, ins; padrão = a da missão):
##   Godot_v4.7.2-stable_win64_console.exe --path . --windowed -s res://tests/integration/ui/teste_layout_hud.gd -- rob 1920x1080
## (o projeto abre em tela cheia; o teste força a janela no tamanho pedido, padrão 1920x1080)
## Sai com 0 se tudo passou, 1 se algo falhou.

const EVIDENCE := "res://production/qa/evidence/"
const MISSION := "H04"

var game: Node
var main: Node
var fkey := ""
var win := Vector2i(1920, 1080)
var failures: Array = []


func _initialize() -> void:
	game = root.get_node("Game")
	var m: Dictionary = load("res://data/campaign.gd").MISSIONS[MISSION]
	game.mission_id = MISSION
	game.mission = m
	game.player_faction = m["player"]
	game.enemy_choice = m["enemy"]
	game.map_size = m["map"]["size"]
	for a in OS.get_cmdline_user_args():
		if a.contains("x"):
			win = Vector2i(int(a.get_slice("x", 0)), int(a.get_slice("x", 1)))
		else:
			game.player_faction = a
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(win)
	fkey = game.player_faction
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
	await process_frame


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(2)
	# A troca de tela cheia para janela é assíncrona: reaplica o tamanho até pegar
	for i in 30:
		if DisplayServer.window_get_size() == win:
			break
		DisplayServer.window_set_size(win)
		await _frames(3)
	main = current_scene
	paused = false
	main.mission._close_modal()
	main.cam.set_process(false)
	main.hud.close_help()   # a primeira partida abre o painel sozinho
	var mission = main.mission
	var hud = main.hud
	await _frames(30)

	# Situação de carga máxima: 3 mensagens, rádio com texto longo, uma unidade selecionada
	hud.show_message("ALERTA: Torre de Defesa sob ataque!  (Espaço: ir até lá)")
	hud.show_message("Unidade pronta: Tanque de Batalha")
	hud.show_message("Limite de população: 60 / 60 — construa mais Usina de Energia (+20 cada)")
	mission.transmit("Coronel Vega", "General, Bastião não pode cair. Máquinas ao norte, insetos ao sul. Fortaleça a posição e aguente até a chegada dos reforços do comando central.")
	var unit = null
	for e in game.entities:
		if e is Node and e.get("team") == game.local_team and e.has_method("command_move") and not e.dead:
			unit = e
			break
	_check(unit != null, "existe unidade do jogador para selecionar")
	if unit != null:
		main._set_selection([unit])
	await _frames(20)

	var vp: Rect2 = root.get_visible_rect()
	print("área lógica: %s" % vp.size)
	var rects := {
		"objetivos": mission._obj_panel.get_global_rect(),
		"cronômetro": mission._timer_panel.get_global_rect(),
		"mensagens": _msg_rect(hud),
		"rádio": mission._tx_panel.get_global_rect(),
		"InfoPanel": hud.info.get_global_rect(),
		"barra lateral": hud.sidebar.get_global_rect(),
	}
	_check(mission._timer_panel.visible and mission._tx_panel.visible and hud.info.visible,
			"cronômetro, rádio e InfoPanel visíveis")
	_check(hud._messages.size() == 3, "3 mensagens empilhadas (%d)" % hud._messages.size())
	var names: Array = rects.keys()
	for i in names.size():
		var r: Rect2 = rects[names[i]]
		print("  %-14s %s" % [names[i], r])
		var inside := vp.grow(0.5).encloses(r)
		_check(inside, "%s dentro da tela" % names[i])
		for j in range(i + 1, names.size()):
			var r2: Rect2 = rects[names[j]]
			_check(not r.intersects(r2), "%s não cobre %s" % [names[i], names[j]])
	_check(absf(rects["barra lateral"].size.x - 340.0) < 0.5, "barra lateral com 340 lógicos (%.1f)" % rects["barra lateral"].size.x)
	_check(absf(rects["InfoPanel"].end.x - rects["barra lateral"].position.x) < 0.5, "InfoPanel colado à barra")
	_check(absf(rects["barra lateral"].end.y - vp.end.y) < 0.5, "barra lateral ocupa a altura toda")

	# Nada da antiga linha longa de ajuda nem fonte abaixo de 14
	var long_help := false
	var small: Array = []
	for n in hud.find_children("*", "Label", true, false) + mission.find_children("*", "Label", true, false):
		if n.text.contains("Ctrl+1..9") or n.text.contains("Dir.: mover / atacar / ponto"):
			long_help = true
		if n.has_theme_font_size_override("font_size") and n.get_theme_font_size("font_size") < 14:
			small.append(n.text)
	_check(not long_help, "a linha longa de ajuda não existe mais na HUD")
	_check(small.is_empty(), "nenhum texto da HUD abaixo de 14 (%s)" % [small])

	var res := "%dx%d" % [win.x, win.y]
	_check(DisplayServer.window_get_size() == win, "janela no tamanho pedido (%s)" % [DisplayServer.window_get_size()])
	await _shot("ui_hud_%s_%s.png" % [res, fkey])

	# F1 abre/fecha; Esc fecha sem limpar a seleção nem pausar
	await _key(KEY_F1)
	_check(hud.help_open(), "F1 abre o painel de atalhos")
	_check(not paused, "F1 não pausa o jogo")
	if res == "1920x1080" and fkey == "hum":
		await _shot("ui_hud_f1_%s_%s.png" % [res, fkey])
	await _key(KEY_F1)
	_check(not hud.help_open(), "F1 fecha o painel")
	await _key(KEY_F1)
	await _key(KEY_ESCAPE)
	_check(not hud.help_open(), "Esc fecha o painel")
	_check(not main.selection.is_empty(), "Esc com o painel aberto não limpa a seleção")
	_check(not paused and not main.pause_menu.visible, "Esc com o painel aberto não abre a pausa")

	print("RESULTADO: %s (%d falhas)" % ["OK" if failures.is_empty() else "FALHOU", failures.size()])
	quit(0 if failures.is_empty() else 1)


## União dos retângulos das mensagens visíveis.
func _msg_rect(hud) -> Rect2:
	var r := Rect2()
	var first := true
	for m in hud._messages:
		var g: Rect2 = m["panel"].get_global_rect()
		r = g if first else r.merge(g)
		first = false
	return r


func _shot(name: String) -> void:
	await _frames(10)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(EVIDENCE + name))
	print("print: " + EVIDENCE + name)
