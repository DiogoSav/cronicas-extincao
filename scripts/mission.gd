class_name Mission
extends CanvasLayer
## Missão de campanha (data/campaign.gd): monta as bases e unidades iniciais, mostra o
## briefing, o painel de objetivos e as transmissões, dispara as ondas de ataque com hora
## marcada e decide vitória e derrota. Usa só os sistemas da partida normal (produção,
## combate, IA), sem regras novas de jogo.

const SAVE_PATH := "user://campanha.cfg"
const CHECK_EVERY := 0.5

var main: Node
var data: Dictionary
var time := 0.0
var done := {}                 # id do objetivo -> true
var _fired := {}               # índice do evento -> true
var _check_t := 0.0
var _ended := false
var _tags := {}                # tag -> prédio (ex.: "ninho1")
var _obj_label: RichTextLabel
var _tx_panel: PanelContainer
var _tx_speaker: Label
var _tx_text: Label
var _tx_queue: Array = []
var _tx_t := 0.0
var _modal: Control


## Lista de missões concluídas (salva no computador do jogador).
static func completed() -> Array:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) != OK:
		return []
	return cf.get_value("campanha", "concluidas", [])


static func _mark_completed(id: String) -> void:
	var list := completed()
	if not list.has(id):
		list.append(id)
	var cf := ConfigFile.new()
	cf.set_value("campanha", "concluidas", list)
	cf.save(SAVE_PATH)


## Prepara o Game para a missão e abre a cena da partida.
static func start(tree: SceneTree, id: String) -> void:
	var m: Dictionary = CampaignData.MISSIONS[id]
	Game.mission_id = id
	Game.mission = m
	Game.player_faction = m["player"]
	Game.enemy_choice = m["enemy"]
	Game.map_size = m["map"]["size"]
	tree.change_scene_to_file("res://scenes/main.tscn")


func _init(main_node: Node, mission: Dictionary) -> void:
	main = main_node
	data = mission
	layer = 6
	process_mode = Node.PROCESS_MODE_ALWAYS


## Bases, unidades e dinheiro iniciais; configura a IA. Chamado por main._setup_bases.
func spawn_start() -> void:
	for t in mini(data["credits"].size(), Game.team_count):
		Game.credits[t] = float(data["credits"][t])
	_spawn_side(Game.PLAYER, data["player_start"])
	_spawn_side(Game.ENEMY, data["enemy_start"])
	_setup_ai(main.ai, data.get("ai", {}), data["enemy_base"])
	if main.ai2 != null:
		_spawn_side(Game.ENEMY2, data.get("enemy2_start", {}))
		_setup_ai(main.ai2, data.get("ai2", {}), data["enemy2_base"])


## Configura a IA de um time inimigo: nível, base, primeira onda e tamanho das ondas
## (os valores da missão têm prioridade sobre os da dificuldade).
func _setup_ai(ai: EnemyAI, cfg: Dictionary, base: Vector2i) -> void:
	ai.set_difficulty(cfg.get("difficulty", "medio"))
	ai.home = main.map.cell_center(base)
	ai.wave_timer = float(cfg.get("first_wave", 300.0))
	ai.wave_size = int(cfg.get("wave_size", 6))
	ai.produce = cfg.get("produce", true)
	ai.remember_base()
	# Prédios com tag são alvos de objetivo: destruídos, não voltam
	var tagged := {}
	for b in _tags.values():
		tagged[b.cell] = true
	ai.layout = ai.layout.filter(func(entry): return not tagged.has(entry[1]))


func _spawn_side(team: int, side: Dictionary) -> void:
	for b in side.get("buildings", []):
		var e = Game.spawn_building(b[0], team, b[1])
		if b.size() > 2:
			_tags[b[2]] = e
	for u in side.get("units", []):
		for i in int(u[2]):
			var c: Vector2i = u[1] + Vector2i(i % 3, i / 3)
			Game.spawn_unit(u[0], team, main.map.cell_center(c))


func _ready() -> void:
	_build_ui()
	_refresh_objectives()
	_show_briefing()


# ---------------------------------------------------------------- lógica

func _process(delta: float) -> void:
	_update_transmission(delta)
	if _ended or get_tree().paused or Game.game_over:
		return
	time += delta
	_check_t -= delta
	if _check_t > 0.0:
		return
	_check_t = CHECK_EVERY
	var changed := false
	for o in data["objectives"]:
		if not done.has(o["id"]) and _objective_met(o):
			done[o["id"]] = true
			changed = true
	if changed:
		_refresh_objectives()
	_run_events()
	if _defeated():
		_finish(false)
	elif done.size() == data["objectives"].size():
		_finish(true)


func _objective_met(o: Dictionary) -> bool:
	match o["type"]:
		"build":
			return Game.has_building(Game.PLAYER, o["building"])
		"army":
			var n := 0
			for e in Game.entities:
				if e is Unit and e.team == Game.PLAYER and not e.dead and not e.data.get("harvester", false):
					n += 1
			return n >= int(o["count"])
		"destroy_tag":
			# "tag" (um alvo) ou "tags" (todos precisam cair)
			for tag in o.get("tags", [o.get("tag", "")]):
				var b = _tags.get(tag)
				if b != null and is_instance_valid(b) and not b.dead:
					return false
			return true
		"have":
			# possuir unidades: {unit (id), count}
			var n := 0
			for e in Game.entities:
				if e is Unit and e.team == Game.PLAYER and not e.dead and e.type == o["unit"]:
					n += 1
			return n >= int(o["count"])
		"destroy_all":
			# todos os inimigos sem prédios (com "enemy2", os dois)
			for t in Game.enemy_teams():
				if Game.building_count(t) > 0:
					return false
			return true
		"survive":
			return time >= float(o["t"])
	return false


func _defeated() -> bool:
	var d: Dictionary = data.get("defeat", {})
	if d.get("type", "") == "lose_building":
		return not Game.has_building(Game.PLAYER, d["building"])
	return Game.building_count(Game.PLAYER) == 0


func _run_events() -> void:
	var events: Array = data.get("events", [])
	for i in events.size():
		if _fired.has(i):
			continue
		var ev: Dictionary = events[i]
		var go := false
		match ev["at"]:
			"start":
				go = true
			"time":
				go = time >= float(ev["t"])
			"objective":
				go = done.has(ev["id"])
		if not go:
			continue
		_fired[i] = true
		if ev.has("text"):
			transmit(ev.get("speaker", ""), ev["text"])
		if ev.has("wave"):
			_send_wave(ev["wave"])


## Onda de ataque: as unidades surgem na borda indicada e andam atacando até o alvo.
func _send_wave(w: Dictionary) -> void:
	var target: Vector2
	if w.get("target", "player_base") is String:
		target = main.map.cell_center(data["player_base"])
	else:
		target = main.map.cell_center(w["target"])
	var k := 0
	for spec in w["units"]:
		for i in int(spec[1]):
			var c: Vector2i = w["from"] + Vector2i(-(k % 3), k / 3)
			var u = Game.spawn_unit(spec[0], int(w.get("team", Game.ENEMY)), main.map.cell_center(c))
			u.command_attack_move(target)
			k += 1


func _finish(won: bool) -> void:
	_ended = true
	Game.game_over = true
	Game.game_ended.emit(won)
	if won:
		_mark_completed(Game.mission_id)
	var text: String = data["ending"] if won else String(data.get("defeat", {}).get("text", "")) \
			+ "\n\nA missão falhou. Reorganize suas forças e tente de novo."
	_show_modal("MISSÃO CUMPRIDA" if won else "MISSÃO FRACASSADA", text, [
		["JOGAR DE NOVO", func(): Mission.start(get_tree(), Game.mission_id)],
		["MENU", func(): get_tree().change_scene_to_file("res://scenes/menu.tscn")],
	], Color(0.55, 0.9, 0.45) if won else Color(1.0, 0.35, 0.25))


# ---------------------------------------------------------------- interface

func _panel_style(alpha := 0.9) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(GameTheme.PANEL, alpha)
	sb.border_color = GameTheme.BORDER
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(12)
	return sb


func _build_ui() -> void:
	# Objetivos: canto superior esquerdo
	var obj := PanelContainer.new()
	obj.add_theme_stylebox_override("panel", _panel_style(0.82))
	obj.position = Vector2(12, 12)
	obj.custom_minimum_size = Vector2(430, 0)
	add_child(obj)
	_obj_label = RichTextLabel.new()
	_obj_label.bbcode_enabled = true
	_obj_label.fit_content = true
	_obj_label.scroll_active = false
	_obj_label.custom_minimum_size = Vector2(406, 0)
	_obj_label.add_theme_font_size_override("normal_font_size", 16)
	_obj_label.add_theme_font_size_override("bold_font_size", 17)
	obj.add_child(_obj_label)

	# Transmissões: faixa na parte de baixo, à esquerda do painel lateral
	_tx_panel = PanelContainer.new()
	_tx_panel.add_theme_stylebox_override("panel", _panel_style())
	_tx_panel.anchor_top = 1.0
	_tx_panel.anchor_bottom = 1.0
	_tx_panel.offset_left = 20
	_tx_panel.offset_top = -190
	_tx_panel.offset_bottom = -60
	_tx_panel.custom_minimum_size = Vector2(720, 0)
	_tx_panel.visible = false
	add_child(_tx_panel)
	var v := VBoxContainer.new()
	_tx_panel.add_child(v)
	_tx_speaker = Label.new()
	_tx_speaker.add_theme_font_size_override("font_size", 18)
	_tx_speaker.add_theme_color_override("font_color", GameTheme.ACCENT)
	v.add_child(_tx_speaker)
	_tx_text = Label.new()
	_tx_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tx_text.custom_minimum_size = Vector2(696, 0)
	_tx_text.add_theme_font_size_override("font_size", 17)
	_tx_text.add_theme_color_override("font_color", GameTheme.TEXT)
	v.add_child(_tx_text)


func _refresh_objectives() -> void:
	var t := "[b][color=#%s]%s — %s[/color][/b]\n" % [GameTheme.ACCENT.to_html(false), data["title"].to_upper(), data["map_name"]]
	for o in data["objectives"]:
		if done.has(o["id"]):
			t += "[color=#7fd36a]■ %s[/color]\n" % o["text"]
		else:
			t += "[color=#%s]□ %s[/color]\n" % [GameTheme.TEXT.to_html(false), o["text"]]
	_obj_label.text = t.strip_edges()


## Mensagem de rádio de um personagem (fila: uma de cada vez, ~9 s cada).
func transmit(speaker: String, text: String) -> void:
	_tx_queue.append([speaker, text])
	if not _tx_panel.visible:
		_next_transmission()


func _next_transmission() -> void:
	if _tx_queue.is_empty():
		_tx_panel.visible = false
		return
	var m: Array = _tx_queue.pop_front()
	_tx_speaker.text = "◆ " + String(m[0]).to_upper()
	_tx_text.text = m[1]
	_tx_panel.visible = true
	_tx_t = 4.0 + m[1].length() * 0.045


func _update_transmission(delta: float) -> void:
	if not _tx_panel.visible or get_tree().paused:
		return
	_tx_t -= delta
	if _tx_t <= 0.0:
		_next_transmission()


func _show_briefing() -> void:
	var objs := ""
	for o in data["objectives"]:
		objs += "•  " + o["text"] + "\n"
	var camp: Dictionary = CampaignData.CAMPAIGNS[data["player"]]
	var head := "%s  ·  %s  ·  Dificuldade: %s\n\n" % [camp["name"], data["map_name"], data["difficulty"]]
	get_tree().paused = true
	_show_modal("%s — %s" % [Game.mission_id, data["title"].to_upper()],
			head + data["briefing"] + "\n\nOBJETIVOS\n" + objs.strip_edges(), [
		["INICIAR MISSÃO", func():
			_close_modal()
			get_tree().paused = false],
		["MENU", func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/menu.tscn")],
	], GameTheme.ACCENT)


func _show_modal(title: String, text: String, buttons: Array, color: Color) -> void:
	_close_modal()
	_modal = ColorRect.new()
	_modal.color = Color(0, 0, 0, 0.55)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var p := PanelContainer.new()
	var sb := _panel_style(0.97)
	sb.border_color = color.darkened(0.3)
	sb.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", sb)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 36)
	t.add_theme_color_override("font_color", color)
	v.add_child(t)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(760, 0)
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", GameTheme.TEXT)
	v.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	for b in buttons:
		var btn := MainMenu.make_button(b[0])
		btn.custom_minimum_size = Vector2(250, 52)
		btn.pressed.connect(b[1])
		row.add_child(btn)


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null
