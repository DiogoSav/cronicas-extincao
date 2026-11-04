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
## Cronômetro dos objetivos de tempo ("survive"): painel no topo, centrado na área de jogo
var _timer_panel: PanelContainer
var _timer_label: Label
var _timer_sec := -1
## Abaixo disto o cronômetro fica âmbar com "!"
const TIMER_WARN := 60.0
var _root: Control
var _obj_panel: PanelContainer
var _tx_bar: ColorRect
var _tx_total := 1.0
var _timer_icon: UiSkin.Glyph
var _timer_warn: Label
## Linhas no painel de objetivos (altura máx. ~220 lógicos)
const MAX_OBJ_LINES := 6
## Nos últimos segundos o cronômetro pulsa (1 Hz)
const TIMER_PULSE := 15.0


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
	_update_timer()
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
# Layout (production/ui/hud-e-menu/ux-spec.md, 3.2–3.5): objetivos no canto superior
# esquerdo, cronômetro compacto no topo do centro do campo, rádio no canto inferior
# esquerdo. Tudo ancorado (unidades lógicas), na skin da facção do jogador.

func _build_ui() -> void:
	UiSkin.install()
	var fkey := UiSkin.player_key()
	var title_col: Color = UiSkin.skin(fkey)["title"]
	_root = Control.new()
	_root.name = "MissaoRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiSkin.theme(fkey)
	add_child(_root)

	# Objetivos: canto superior esquerdo, 380 de largura
	_obj_panel = PanelContainer.new()
	_obj_panel.name = "Objetivos"
	_obj_panel.add_theme_stylebox_override("panel", UiSkin.frame(fkey, "n1"))
	_obj_panel.position = Vector2(12, 12)
	_obj_panel.custom_minimum_size = Vector2(380, 0)
	_root.add_child(_obj_panel)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 4)
	_obj_panel.add_child(ov)
	var oh := HBoxContainer.new()
	ov.add_child(oh)
	oh.add_child(UiSkin.label("OBJETIVOS", 15, title_col, true))
	var mt := UiSkin.label("%s · %s" % [Game.mission_id, String(data["title"])], 14, UiSkin.TEXT_MID)
	mt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mt.clip_text = true
	mt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	oh.add_child(mt)
	_obj_label = RichTextLabel.new()
	_obj_label.bbcode_enabled = true
	_obj_label.fit_content = true
	_obj_label.scroll_active = false
	_obj_label.custom_minimum_size = Vector2(360, 0)
	_obj_label.add_theme_font_size_override("normal_font_size", 15)
	_obj_label.add_theme_font_size_override("bold_font_size", 15)
	_obj_label.add_theme_constant_override("line_separation", 2)
	ov.add_child(_obj_label)

	# Cronômetro: 150×44 no topo, centrado no campo (fora da barra lateral)
	_timer_panel = PanelContainer.new()
	_timer_panel.name = "Cronometro"
	_timer_panel.add_theme_stylebox_override("panel", UiSkin.frame(fkey, "n2"))
	_timer_panel.anchor_left = 0.5
	_timer_panel.anchor_right = 0.5
	_timer_panel.offset_left = -HUD.SIDEBAR_W / 2 - 75
	_timer_panel.offset_right = -HUD.SIDEBAR_W / 2 + 75
	_timer_panel.offset_top = 12
	_timer_panel.offset_bottom = 56
	_timer_panel.visible = false
	_root.add_child(_timer_panel)
	var th := HBoxContainer.new()
	th.alignment = BoxContainer.ALIGNMENT_CENTER
	th.add_theme_constant_override("separation", 6)
	_timer_panel.add_child(th)
	_timer_icon = UiSkin.Glyph.new("clock", UiSkin.TEXT_HI, 22)
	_timer_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(_timer_icon)
	_timer_label = UiSkin.label("00:00", 28, UiSkin.TEXT_HI, true)
	th.add_child(_timer_label)
	_timer_warn = UiSkin.label("!", 28, UiSkin.WARN, true)
	_timer_warn.visible = false
	th.add_child(_timer_warn)

	# Rádio: canto inferior esquerdo, 720 de largura, cresce para cima
	_tx_panel = PanelContainer.new()
	_tx_panel.name = "Radio"
	_tx_panel.add_theme_stylebox_override("panel", UiSkin.frame(fkey, "n1"))
	_tx_panel.anchor_top = 1.0
	_tx_panel.anchor_bottom = 1.0
	_tx_panel.offset_left = 20
	_tx_panel.offset_right = 740
	_tx_panel.offset_top = -12
	_tx_panel.offset_bottom = -12
	_tx_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_tx_panel.visible = false
	_root.add_child(_tx_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_tx_panel.add_child(row)
	var portrait := PanelContainer.new()
	portrait.add_theme_stylebox_override("panel", UiSkin.frame(fkey, "n2"))
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	portrait.add_child(UiSkin.Glyph.new("radio", title_col, 40))
	row.add_child(portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 4)
	row.add_child(v)
	_tx_speaker = UiSkin.label("", 15, title_col, true)
	v.add_child(_tx_speaker)
	_tx_text = UiSkin.label("", 16, UiSkin.TEXT_HI)
	_tx_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tx_text.custom_minimum_size = Vector2(600, 0)
	v.add_child(_tx_text)
	# Barrinha do tempo restante da transmissão (o rádio avança sozinho)
	var bar_back := ColorRect.new()
	bar_back.color = Color(0, 0, 0, 0.6)
	bar_back.custom_minimum_size = Vector2(0, 4)
	v.add_child(bar_back)
	_tx_bar = ColorRect.new()
	_tx_bar.color = UiSkin.skin(fkey)["color"]
	_tx_bar.size = Vector2(0, 4)
	bar_back.add_child(_tx_bar)


## Objetivos: ◻ pendente, ◼ concluído (riscado); o de tempo traz o relógio "(MM:SS)".
## Até MAX_OBJ_LINES linhas; o excedente vira "+N".
func _refresh_objectives() -> void:
	var lines: Array = []
	var objs: Array = data["objectives"]
	for i in objs.size():
		var o: Dictionary = objs[i]
		if lines.size() >= MAX_OBJ_LINES - 1 and objs.size() > MAX_OBJ_LINES:
			lines.append("[color=#%s]+%d objetivos[/color]" % [UiSkin.TEXT_MID.to_html(false), objs.size() - i])
			break
		var txt := String(o["text"])
		if txt.length() > 90:
			txt = txt.left(88) + "…"
		if done.has(o["id"]):
			lines.append("[color=#%s]◼ [s]%s[/s][/color]" % [UiSkin.GOOD.to_html(false), txt])
		else:
			var left := ""
			if o["type"] == "survive":
				left = "[b](%s)[/b] " % _clock(float(o["t"]) - time)
			lines.append("◻ %s%s" % [left, txt])
	_obj_label.text = "\n".join(lines)


## mm:ss de um tempo em segundos (nunca negativo).
static func _clock(seconds: float) -> String:
	var s := maxi(0, ceili(seconds))
	return "%02d:%02d" % [s / 60, s % 60]


## Primeiro objetivo de tempo ainda não cumprido: mostra o cronômetro (ícone + MM:SS) e
## atualiza o tempo restante no painel de objetivos uma vez por segundo. Menos de 60 s:
## âmbar + "!"; menos de 15 s: pulsa a 1 Hz.
func _update_timer() -> void:
	var cur: Dictionary = {}
	for o in data["objectives"]:
		if o["type"] == "survive" and not done.has(o["id"]):
			cur = o
			break
	_timer_panel.visible = not cur.is_empty()
	if cur.is_empty():
		return
	var left := float(cur["t"]) - time
	_timer_panel.modulate.a = (0.8 + 0.2 * cos(time * TAU)) if left <= TIMER_PULSE else 1.0
	var sec := maxi(0, ceili(left))
	if sec == _timer_sec:
		return
	_timer_sec = sec
	_timer_label.text = _clock(left)
	var warn := left <= TIMER_WARN
	_timer_label.add_theme_color_override("font_color", UiSkin.WARN if warn else UiSkin.TEXT_HI)
	_timer_icon.color = UiSkin.WARN if warn else UiSkin.TEXT_HI
	_timer_icon.queue_redraw()
	_timer_warn.visible = warn
	_refresh_objectives()


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
	_tx_speaker.text = String(m[0]).to_upper()
	_tx_text.text = m[1]
	_tx_panel.visible = true
	_tx_t = 4.0 + m[1].length() * 0.045
	_tx_total = _tx_t


func _update_transmission(delta: float) -> void:
	if not _tx_panel.visible or get_tree().paused:
		return
	_tx_t -= delta
	_tx_bar.size = Vector2(_tx_bar.get_parent().size.x * clampf(_tx_t / maxf(_tx_total, 0.01), 0.0, 1.0), 4)
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
	], UiSkin.skin(UiSkin.player_key())["title"])


func _show_modal(title: String, text: String, buttons: Array, color: Color) -> void:
	_close_modal()
	_modal = ColorRect.new()
	_modal.color = Color(0, 0, 0, 0.55)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_modal)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_right = -HUD.SIDEBAR_W   # centrado no campo
	_modal.add_child(center)
	var p := PanelContainer.new()
	var sb: StyleBoxTexture = UiSkin.frame(UiSkin.player_key(), "n1").duplicate()
	sb.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", sb)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	p.add_child(v)
	var t := UiSkin.label(title, 36, color, true)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var body := UiSkin.label(text, 19, UiSkin.TEXT_HI)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(760, 0)
	v.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var first: Button = null
	for b in buttons:
		var btn := MainMenu.make_button(b[0])
		btn.custom_minimum_size = Vector2(250, 52)
		btn.pressed.connect(b[1])
		row.add_child(btn)
		if first == null:
			first = btn
	if first != null and first.focus_mode != Control.FOCUS_NONE:
		first.grab_focus.call_deferred()


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null
