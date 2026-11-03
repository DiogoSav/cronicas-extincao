extends SceneTree
## Teste de integração do áudio, passo 1 (design/audio/audio-sonoplastia-geral.md):
##   1. barramentos criados e todos os eventos com arquivo carregável;
##   2. combate real dispara sons de arma, impacto e morte;
##   3. os quatro avisos visuais de acessibilidade (unidade pronta, coletor atacado,
##      prédio perdido, campo esgotado) aparecem como mensagem e pisca no minimapa.
## Tira print em production/qa/evidence/audio_avisos.png.
##
## Rodar: Godot_v4.7.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 -s res://tests/integration/audio/teste_sons.gd
## Sai com 0 se tudo passou, 1 se algo falhou.

const EVIDENCE := "res://production/qa/evidence/"

var game: Node
var sfx: Node
var main: Node
var failures: Array = []
var messages: Array = []
var played: Array = []


func _initialize() -> void:
	game = root.get_node("Game")
	sfx = root.get_node("Sfx")
	var m: Dictionary = load("res://data/campaign.gd").MISSIONS["H01"]
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


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _got(text: String) -> bool:
	return messages.any(func(t): return text in t)


func _run() -> void:
	await _frames(2)
	main = current_scene
	paused = false
	main.mission._close_modal()
	game.message.connect(func(t): messages.append(t))
	# Registra cada evento que de fato tocou
	var orig_last: Dictionary = sfx._last
	await _frames(10)

	# 1. barramentos e arquivos
	for b in ["Musica", "Efeitos", "Combate", "Ambiente", "Interface", "Vozes"]:
		_check(AudioServer.get_bus_index(b) >= 0, "barramento %s existe" % b)
	var missing: Array = []
	for id in sfx.EVENTS:
		for k in int(sfx.EVENTS[id]["files"]):
			if not ResourceLoader.exists("%s%s_%d.wav" % [AudioData.DIR, id, k + 1]):
				missing.append("%s_%d" % [id, k + 1])
	_check(missing.is_empty(), "todos os arquivos dos eventos existem (faltam: %s)" % [missing])

	# 2. combate: um tanque humano contra um inseto, na frente da câmera
	var spot: Vector2 = main.map.cell_center(Vector2i(14, 24))
	main.cam.set_process(false)   # sem rolagem pela borda (o mouse pode estar lá)
	main.cam.focus(spot)
	var tank = game.spawn_unit("hum_tanque", 0, spot)
	var bug = game.spawn_unit("ins_rifle", 1, spot + Vector2(3, 0) * game.TILE)
	sfx._last = {}
	for i in 240:
		await process_frame
		if not is_instance_valid(bug) or bug.dead:
			break
	var heard: Array = sfx._last.keys()
	print("sons de combate: ", heard)
	_check(heard.has("sfx_weapon_cannon_fire"), "tiro de canhão tocou")
	_check(heard.has("sfx_impact_cannon"), "impacto de canhão tocou")
	_check(heard.has("sfx_death_insect") or heard.has("sfx_weapon_acid_spit_fire"), "som do Enxame tocou (cuspe ou morte)")

	# 3a. unidade pronta: produção acelerada de um soldado
	messages.clear()
	game.credits[0] = 9000.0
	game.spawn_building("barracks", 0, Vector2i(10, 30))
	await _frames(5)
	game.start_production(0, "hum_soldado")
	game.production[0]["infantry"]["progress"] = 0.99
	await _frames(30)
	_check(_got("Unidade pronta"), "aviso visual: unidade pronta")

	# 3b. coletor atacado
	messages.clear()
	var h = game.spawn_unit("hum_coletor", 0, main.map.cell_center(Vector2i(20, 30)))
	h.take_damage(1.0, "rifle")
	await _frames(3)
	_check(_got("sob ataque") and not game.pings.is_empty(), "aviso visual: coletor atacado (mensagem + pisca)")

	# 3c. prédio perdido
	messages.clear()
	var n_pings: int = game.pings.size()
	var power = game.entities.filter(func(e): return e.team == 0 and e.has_method("start_construction") and e.type == "power")
	if not power.is_empty():
		# A câmera pode ter rolado (mouse na borda da janela): o som só toca perto dela
		main.cam.focus(power[0].position)
		power[0].take_damage(1e9, "cannon")
	await _frames(3)
	_check(_got("Prédio perdido") and game.pings.size() > n_pings, "aviso visual: prédio perdido (mensagem + pisca)")
	_check(sfx._last.has("sfx_explosion_building_small"), "explosão de prédio tocou")

	# 3d. campo esgotado: coletor com campo de trabalho num lugar sem minério
	messages.clear()
	h.field = main.map.cell_center(Vector2i(3, 3))
	h._find_ore()
	await _frames(3)
	_check(_got("esgotado"), "aviso visual: campo de minério esgotado")

	# Print: mensagens e o pisca no minimapa
	main.cam.focus(main.map.cell_center(Vector2i(12, 26)))
	game.ping(main.map.cell_center(Vector2i(40, 12)))
	await _frames(20)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(EVIDENCE + "audio_avisos.png"))

	print("RESULTADO: %s (%d falhas)" % ["OK" if failures.is_empty() else "FALHOU", failures.size()])
	quit(0 if failures.is_empty() else 1)
