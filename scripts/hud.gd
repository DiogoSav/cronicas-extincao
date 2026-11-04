class_name HUD
extends CanvasLayer
## HUD da partida no estilo Command & Conquer (production/ui/hud-e-menu/ux-spec.md, seção 3):
## barra lateral de 340 lógicos à direita (cabeçalho da facção, velocidade/menu, minimapa,
## economia, produção em grade 4×74 e rodapé com dica e F1), pilha de mensagens no topo do
## campo, painel de atalhos (F1) e o texto de fim de partida. Skin por facção (UiSkin).
## A HUD só mostra o estado e chama as ações que já existem (Game.start_production etc.).

signal place_requested(type: String)
signal minimap_clicked(ground_pos: Vector2)
signal pause_requested

## Largura da barra lateral em unidades lógicas (igual em qualquer resolução)
const SIDEBAR_W := 340
const ACCENT := GameTheme.ACCENT
const TEXT := GameTheme.TEXT
const BORDER := GameTheme.BORDER
const PANEL := GameTheme.PANEL
## Mensagens: quantas ao mesmo tempo, duração normal e de alerta, janela de repetição
const MSG_MAX := 3
const MSG_TIME := 4.0
const ALERT_TIME := 6.0
const MSG_REPEAT := 3.0
const MSG_W := 640
## Preferências da interface (o painel F1 abre sozinho só na primeira partida)
const CONFIG_PATH := "user://config.cfg"

var root: Control
var sidebar: PanelContainer
var credits_label: Label
var power_label: Label
var pop_label: Label
var end_label: Label
var minimap: Minimap
var info: InfoPanel
var buttons := {}
var hint_label: Label
var help_panel: PanelContainer
var speed_button: Button
var _fkey := ""
var _msg_box: VBoxContainer
var _messages: Array = []        # [{panel, label, text, t, born}]
var _power_warn: Label
var _pop_box: Control
var _hint_t := 0.0


func _ready() -> void:
	layer = 2
	UiSkin.install()
	_fkey = UiSkin.player_key()
	root = Control.new()
	root.name = "HudRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiSkin.theme(_fkey)
	add_child(root)

	_build_sidebar()

	# Painel de seleção: canto inferior direito do campo, colado à barra
	info = InfoPanel.new()
	root.add_child(info)
	info.anchor_left = 1.0
	info.anchor_right = 1.0
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_right = -SIDEBAR_W
	info.offset_left = -SIDEBAR_W - 600
	info.offset_top = 0
	info.offset_bottom = 0
	info.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	info.grow_vertical = Control.GROW_DIRECTION_BEGIN

	# Mensagens: faixa centrada no campo, logo abaixo do cronômetro
	_msg_box = VBoxContainer.new()
	_msg_box.name = "Mensagens"
	_msg_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_msg_box.anchor_left = 0.5
	_msg_box.anchor_right = 0.5
	_msg_box.offset_left = -SIDEBAR_W / 2 - MSG_W / 2
	_msg_box.offset_right = -SIDEBAR_W / 2 + MSG_W / 2
	_msg_box.offset_top = 64
	_msg_box.add_theme_constant_override("separation", 2)
	root.add_child(_msg_box)

	end_label = Label.new()
	end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	end_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_label.offset_right = -SIDEBAR_W
	end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	end_label.add_theme_font_override("font", UiSkin.font(true))
	end_label.add_theme_font_size_override("font_size", 64)
	end_label.add_theme_color_override("font_outline_color", Color.BLACK)
	end_label.add_theme_constant_override("outline_size", 12)
	root.add_child(end_label)

	_build_help()

	Game.message.connect(show_message)
	Game.game_ended.connect(_on_game_ended)

	# Primeira partida: o painel de atalhos abre uma vez
	var cf := ConfigFile.new()
	cf.load(CONFIG_PATH)
	if not cf.get_value("hud", "atalhos_vistos", false):
		cf.set_value("hud", "atalhos_vistos", true)
		cf.save(CONFIG_PATH)
		help_panel.visible = true


# ---------------------------------------------------------------- barra lateral

func _build_sidebar() -> void:
	var fac := Game.faction(Game.local_team)
	var sk := UiSkin.skin(_fkey)
	sidebar = PanelContainer.new()
	sidebar.name = "BarraLateral"
	sidebar.add_theme_stylebox_override("panel", UiSkin.frame(_fkey, "n1"))
	root.add_child(sidebar)
	sidebar.anchor_left = 1.0
	sidebar.anchor_right = 1.0
	sidebar.anchor_top = 0.0
	sidebar.anchor_bottom = 1.0
	sidebar.offset_left = -SIDEBAR_W
	sidebar.offset_right = 0
	sidebar.offset_top = 0
	sidebar.offset_bottom = 0

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	sidebar.add_child(box)

	# A. Cabeçalho: logo + nome da facção + subtítulo
	var head := HBoxContainer.new()
	head.custom_minimum_size = Vector2(0, 58)
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	head.add_child(UiSkin.logo_rect(_fkey, 48))
	var names := VBoxContainer.new()
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	names.add_theme_constant_override("separation", 0)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(names)
	var nl := UiSkin.label(String(fac["name"]).to_upper(), 20, sk["title"], true)
	nl.clip_text = true
	nl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(nl)
	var sub := String(fac["army"])
	if Net.active:
		sub = "%s  ×  %s" % [Net.names[Net.me()], Net.names[1 - Net.me()]]
	var sl := UiSkin.label(sub, 14, UiSkin.TEXT_MID)
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(sl)

	# B. Controles: velocidade (fora do multiplayer) e MENU
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	box.add_child(top)
	if not Net.active:
		speed_button = _small_button("VEL  100%", "Velocidade do jogo (+ acelera, − desacelera)")
		speed_button.pressed.connect(func():
			Game.set_speed_level((Game.speed_level + 1) % GameData.SPEED_STEPS.size()))
		Game.speed_changed.connect(func(lv: int):
			speed_button.text = "VEL  %d%%" % roundi(GameData.SPEED_STEPS[lv] * 100.0))
		top.add_child(speed_button)
	var menu_b := _small_button("MENU  (P)", "Pausa (Esc ou P)")
	menu_b.pressed.connect(func(): pause_requested.emit())
	top.add_child(menu_b)

	# C. Minimapa em moldura N2, na proporção do mapa (no máximo 320×230)
	var mm_frame := PanelContainer.new()
	mm_frame.add_theme_stylebox_override("panel", UiSkin.frame(_fkey, "n2"))
	mm_frame.custom_minimum_size = Vector2(0, 230)
	box.add_child(mm_frame)
	var center := CenterContainer.new()
	mm_frame.add_child(center)
	minimap = Minimap.new()
	var mw := 312.0
	var mh := mw * Map.H / float(Map.W)
	if mh > 222.0:
		mh = 222.0
		mw = mh * Map.W / float(Map.H)
	minimap.custom_minimum_size = Vector2(roundi(mw), roundi(mh))
	minimap.clicked.connect(func(p): minimap_clicked.emit(p))
	center.add_child(minimap)

	# D. Economia: recursos, energia (usada/produzida), população (usada/limite)
	var eco := HBoxContainer.new()
	eco.add_theme_constant_override("separation", 10)
	box.add_child(eco)
	credits_label = _eco_column(eco, "crystal", "RECURSOS", Color(0.45, 0.75, 1.0))
	power_label = _eco_column(eco, "bolt", "ENERGIA", UiSkin.WARN)
	_power_warn = UiSkin.label("!", 24, UiSkin.WARN, true)
	_power_warn.visible = false
	power_label.get_parent().add_child(_power_warn)
	pop_label = _eco_column(eco, "pop", "POPULAÇÃO", UiSkin.TEXT_MID)
	_pop_box = pop_label.get_parent().get_parent()
	_pop_box.mouse_filter = Control.MOUSE_FILTER_STOP

	# E. Produção: única faixa que estica (sem rolagem)
	var prod := VBoxContainer.new()
	prod.name = "Producao"
	prod.size_flags_vertical = Control.SIZE_EXPAND_FILL
	prod.add_theme_constant_override("separation", 4)
	box.add_child(prod)
	_section(prod, "CONSTRUÇÕES", "house", Game.BUILD_ORDER)
	_section(prod, "INFANTARIA", "soldier", fac["infantry"])
	_section(prod, "VEÍCULOS", "wheel", fac["vehicles"])
	_section(prod, "NAVES", "wing", fac["air"])

	# F. Rodapé: dica contextual + atalhos
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", UiSkin.frame(_fkey, "n2"))
	foot.custom_minimum_size = Vector2(0, 62)
	box.add_child(foot)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 6)
	foot.add_child(fr)
	hint_label = UiSkin.label("", 14, UiSkin.TEXT_MID)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_label.max_lines_visible = 2
	hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fr.add_child(hint_label)
	var hb := _small_button("F1\nAtalhos", "Atalhos do teclado (F1)")
	hb.custom_minimum_size = Vector2(76, 0)
	hb.size_flags_horizontal = Control.SIZE_SHRINK_END
	hb.pressed.connect(toggle_help)
	fr.add_child(hb)


func _small_button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 30)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 14)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


## Coluna da economia (caixa N2): ícone + rótulo 14 e número 24 Bold. Devolve o Label do número.
func _eco_column(row: HBoxContainer, glyph: String, title: String, gcol: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiSkin.frame(_fkey, "n2"))
	p.custom_minimum_size = Vector2(100, 58)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	p.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	v.add_child(h)
	h.add_child(UiSkin.Glyph.new(glyph, gcol, 14))
	h.add_child(UiSkin.label(title, 14, UiSkin.TEXT_MID))
	var vr := HBoxContainer.new()
	vr.add_theme_constant_override("separation", 2)
	v.add_child(vr)
	var n := UiSkin.label("0", 24, UiSkin.TEXT_HI, true)
	vr.add_child(n)
	return n


## Seção de produção: cabeçalho recolhível (ícone + nome) e grade 4 × (74×68).
func _section(box: VBoxContainer, title: String, glyph: String, list: Array) -> void:
	var head := Button.new()
	head.flat = true
	head.focus_mode = Control.FOCUS_NONE
	head.custom_minimum_size = Vector2(0, 24)
	head.tooltip_text = "Clique para recolher / mostrar"
	head.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	box.add_child(head)
	var strip := TextureRect.new()
	strip.texture = UiSkin.header_strip(_fkey)
	strip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	strip.stretch_mode = TextureRect.STRETCH_SCALE
	strip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(strip)
	var hr := HBoxContainer.new()
	hr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hr.offset_left = 6
	hr.add_theme_constant_override("separation", 6)
	hr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(hr)
	var g := UiSkin.Glyph.new(glyph, UiSkin.TEXT_HI, 16)
	g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hr.add_child(g)
	var t := UiSkin.label(title, 15, UiSkin.TEXT_HI, true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	t.size_flags_vertical = Control.SIZE_FILL
	hr.add_child(t)
	var arrow := UiSkin.label("▾", 14, UiSkin.TEXT_MID)
	arrow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	arrow.size_flags_vertical = Control.SIZE_FILL
	hr.add_child(arrow)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	head.pressed.connect(func():
		grid.visible = not grid.visible
		arrow.text = "▾" if grid.visible else "▸")
	var sk := UiSkin.skin(_fkey)
	for type in list:
		var b := ProdSlot.new()
		b.setup(type, _item_icon(type), _short_name(type), int(Game.item_data(type)["cost"]), sk["color"])
		b.tooltip_text = _tooltip(type)
		b.pressed.connect(_on_item_pressed.bind(type))
		b.gui_input.connect(_on_item_gui_input.bind(type))
		grid.add_child(b)
		buttons[type] = b


func _item_icon(t: String) -> Texture2D:
	if Game.BUILDINGS.has(t):
		return Game.icon(t + "_" + Game.factions[Game.local_team])
	return Game.icon(t)


func _tooltip(t: String) -> String:
	var d := Game.item_data(t)
	var s := "%s\n%s\nCusto: %d   Tempo: %ds" % [Game.item_name(t), d["desc"], d["cost"], int(d["time"])]
	if d.has("hp"):
		s += "   Vida: %d" % d["hp"]
	if Game.UNITS.has(t):
		s += "   População: %d" % Game.pop_cost(t)
	var req: Array = d["requires"]
	if not req.is_empty():
		var names := req.map(func(r): return Game.item_name(r))
		s += "\nRequer: " + ", ".join(names)
	if Game.UNITS.has(t):
		s += "\nClique: produzir (fila de até %d)   ·   Botão direito: cancelar um" % Game.MAX_QUEUE
	return s


func _short_name(t: String) -> String:
	var d := Game.item_data(t)
	if d.has("short"):
		return d["short"]
	var n := Game.item_name(t)
	return n if n.length() <= 12 else n.get_slice(" ", 0)


func _on_item_pressed(t: String) -> void:
	var cat: String = Game.item_data(t)["category"]
	var job: Dictionary = Game.production[Game.local_team].get(cat, {})
	# Prédios: um por vez (depois de pronto, o clique posiciona). Unidades entram na fila.
	if cat == "building" and not job.is_empty():
		if job["done"] and job["type"] == t:
			place_requested.emit(t)
		elif job["type"] != t:
			show_message("Já existe uma construção em andamento")
		return
	Game.start_production(Game.local_team, t)


func _on_item_gui_input(event: InputEvent, t: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		var cat: String = Game.item_data(t)["category"]
		Game.cancel_production(Game.local_team, cat, t)


# ---------------------------------------------------------------- atalhos (F1)

## Teclas que main.gd já trata (não inventar teclas novas aqui).
const HELP_KEYS := [
	[["M", "Mover (clique no destino)"], ["Q", "Patrulha"], ["X", "Parar"], ["G", "Postura: defender"],
	 ["H", "Postura: agressivo"], ["U", "Desembarcar"], ["K", "Consertar prédio"],
	 ["Delete", "Reciclar prédio"], ["Esc", "Cancelar ordem · limpar · pausa"]],
	[["1 – 9", "Selecionar grupo"], ["Ctrl + 1 – 9", "Definir grupo"], ["Espaço", "Ir ao último alerta"],
	 ["P", "Pausa"], ["+  /  −", "Velocidade do jogo"], ["F11", "Tela cheia"], ["F1", "Este painel"],
	 ["R", "Jogar de novo (fim de partida)"], ["M", "Menu (fim de partida)"]],
]


func _build_help() -> void:
	help_panel = PanelContainer.new()
	help_panel.name = "Atalhos"
	help_panel.add_theme_stylebox_override("panel", UiSkin.frame(_fkey, "n1"))
	help_panel.anchor_left = 0.5
	help_panel.anchor_right = 0.5
	help_panel.anchor_top = 0.5
	help_panel.anchor_bottom = 0.5
	help_panel.offset_left = -SIDEBAR_W / 2 - 320
	help_panel.offset_right = -SIDEBAR_W / 2 + 320
	help_panel.offset_top = -210
	help_panel.offset_bottom = 210
	help_panel.visible = false
	root.add_child(help_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	help_panel.add_child(v)
	var hr := HBoxContainer.new()
	v.add_child(hr)
	var t := UiSkin.label("ATALHOS DO TECLADO", 20, UiSkin.skin(_fkey)["title"], true)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(t)
	var close := _small_button("FECHAR  (F1 / Esc)", "Fecha este painel")
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.custom_minimum_size = Vector2(170, 30)
	close.pressed.connect(close_help)
	hr.add_child(close)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	v.add_child(cols)
	for col in HELP_KEYS:
		var c := VBoxContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_theme_constant_override("separation", 5)
		cols.add_child(c)
		for row in col:
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 8)
			c.add_child(r)
			var cap := PanelContainer.new()
			cap.add_theme_stylebox_override("panel", UiSkin.frame(_fkey, "n2"))
			cap.custom_minimum_size = Vector2(92, 26)
			r.add_child(cap)
			var k := UiSkin.label(row[0], 14, UiSkin.TEXT_HI, true)
			k.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cap.add_child(k)
			var d := UiSkin.label(row[1], 15, UiSkin.TEXT_HI)
			d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			d.clip_text = true
			d.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			r.add_child(d)
	var mouse := UiSkin.label("Mouse: arrastar seleciona · botão direito move / ataca / marca ponto de reunião · "
			+ "Ctrl + botão direito anda atacando · WASD ou bordas da tela movem a câmera", 14, UiSkin.TEXT_MID)
	mouse.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(mouse)


## Abre/fecha o painel de atalhos (F1 ou botão no rodapé). Não pausa o jogo.
func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func close_help() -> void:
	help_panel.visible = false


func help_open() -> bool:
	return help_panel != null and help_panel.visible


# ---------------------------------------------------------------- mensagens

## Aviso grande no centro do campo (multiplayer: esperando o outro jogador). Vazio esconde.
func set_waiting(text: String) -> void:
	end_label.text = text
	end_label.add_theme_color_override("font_color", UiSkin.skin(_fkey)["title"])
	end_label.add_theme_font_size_override("font_size", 40 if text != "" else 64)


static func _is_alert(text: String) -> bool:
	return text.begins_with("ALERTA") or text.begins_with("Energia baixa") or text.begins_with("Prédio perdido")


## Mensagem de jogo: pilha de até 3 no topo do campo (4 s; alertas 6 s com "!").
## A mesma mensagem repetida em menos de 3 s só reinicia o contador.
func show_message(text: String) -> void:
	if text == "":
		return
	var alert := _is_alert(text)
	var now := Time.get_ticks_msec() / 1000.0
	for m in _messages:
		if m["text"] == text and now - m["born"] < MSG_REPEAT:
			m["t"] = ALERT_TIME if alert else MSG_TIME
			m["born"] = now
			return
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.63)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.custom_minimum_size = Vector2(0, 30)
	var l := UiSkin.label(("!  " + text) if alert else text, 20, UiSkin.WARN if alert else UiSkin.TEXT_HI)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var w := UiSkin.font(false).get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 4
	l.custom_minimum_size = Vector2(minf(w, MSG_W - 24), 0)
	p.add_child(l)
	_msg_box.add_child(p)
	_messages.append({"panel": p, "label": l, "text": text, "t": ALERT_TIME if alert else MSG_TIME, "born": now})
	while _messages.size() > MSG_MAX:
		_messages.pop_front()["panel"].queue_free()


func _on_game_ended(player_won: bool) -> void:
	if not Game.mission.is_empty():
		return   # na campanha a janela de fim de missão (Mission) mostra o resultado
	end_label.text = ("VITÓRIA!" if player_won else "DERROTA") + (
			"\n[M] menu" if Net.active else "\n[R] jogar de novo    [M] menu")
	end_label.add_theme_color_override("font_color",
			Color(0.45, 0.9, 1.0) if player_won else Color(1.0, 0.3, 0.25))


# ---------------------------------------------------------------- atualização

func _process(delta: float) -> void:
	for m in _messages.duplicate():
		m["t"] -= delta
		if m["t"] <= 0.0:
			m["panel"].queue_free()
			_messages.erase(m)

	var T := Game.local_team
	credits_label.text = "%d" % int(Game.credits[T])
	var p := Game.get_power(T)
	power_label.text = "%d/%d" % [p.y, p.x]
	var low := p.y > p.x
	power_label.add_theme_color_override("font_color", UiSkin.WARN if low else UiSkin.TEXT_HI)
	_power_warn.visible = low
	_update_population()

	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint_t = 0.25
		hint_label.text = _context_hint()

	var sk_color: Color = UiSkin.skin(_fkey)["color"]
	for t in buttons:
		var b: ProdSlot = buttons[t]
		var data := Game.item_data(t)
		var cat: String = data["category"]
		var job: Dictionary = Game.production[T].get(cat, {})
		var mine: bool = not job.is_empty() and job["type"] == t
		var n := Game.count_in_production(T, t)
		var done_now: bool = mine and job["done"]
		# Bloqueado por requisito ou sem produtor (um prédio pronto continua posicionável)
		b.locked = not Game.can_produce(T, t) and not done_now
		b.no_pop = Game.UNITS.has(t) and not Game.pop_room(T, t) and n == 0
		b.poor = Game.credits[T] < data["cost"] and n == 0
		b.is_ready = done_now
		b.progress = float(job["progress"]) if mine else -1.0
		b.queue_n = n
		b.off = Game.game_over
		b.accent = sk_color
		b.disabled = b.locked or b.off
		b.refresh()


## "População 24/60": usada / limite; tooltip com o que está em campo.
func _update_population() -> void:
	var T := Game.local_team
	var used := Game.pop_used(T)
	var cap := Game.pop_cap(T)
	var free := maxi(cap - used, 0)
	pop_label.text = "%d/%d" % [used, cap]
	pop_label.add_theme_color_override("font_color", UiSkin.BAD if free == 0 else (UiSkin.WARN if free < 6 else UiSkin.TEXT_HI))
	if Engine.get_process_frames() % 30 != 0:
		return
	var counts := {"inf": 0, "veh": 0, "air": 0}
	for e in Game.entities:
		if e is Unit and e.team == T and not e.dead:
			counts[e.data["kind"]] += 1
	_pop_box.tooltip_text = ("População %d / %d · livre %d%s\nEm campo: soldados %d · veículos %d · naves %d\n"
			+ "Custo: soldado 1 · coletor, batedor e caça 2 · tanque 3 · pesado e nave pesada 4.\n"
			+ "Limite: %d no início, +%d por gerador de energia pronto, máximo %d.\n"
			+ "Unidades na fila já reservam o espaço.") % [used, cap, free, "  (LIMITE!)" if free == 0 else "",
			counts["inf"], counts["veh"], counts["air"], Game.POP_BASE, Game.POP_PER_POWER, Game.POP_MAX]


## Dica do rodapé conforme o que o jogador está fazendo.
func _context_hint() -> String:
	var m := get_parent()
	if m != null and String(m.get("placing")) != "" and m.get("placing") != null:
		return "Clique: posicionar o prédio · Botão direito: cancelar"
	if m != null and m.get("order_mode") != null and String(m.get("order_mode")) != "":
		return "Clique no mapa: destino · Botão direito: cancelar"
	var sel: Array = info.selection.filter(func(e): return is_instance_valid(e))
	if sel.any(func(e): return e is Unit):
		return "Botão direito: mover / atacar · Ctrl + direito: andar atacando"
	if sel.any(func(e): return e is Building and e.produces_units()):
		return "Botão direito no mapa: ponto de reunião"
	return "Arrastar: selecionar · WASD ou bordas: câmera"


## Botão de produção 74×68: ícone, nome curto e custo; estados sem dinheiro, bloqueado,
## em produção (barra), fila (selo ×n), pronto e desativado — cada um com forma ou texto,
## não só cor (spec 3.3).
class ProdSlot extends Button:
	var type := ""
	var progress := -1.0
	var is_ready := false
	var locked := false
	var poor := false
	var no_pop := false
	var queue_n := 0
	var off := false
	var accent := Color.WHITE
	var cost := 0
	var _pic: TextureRect
	var _name: Label
	var _cost: Label
	var _crystal: Control
	var _ready_l: Label
	var _state := ""

	func setup(t: String, tex: Texture2D, short_name: String, c: int, acc: Color) -> void:
		type = t
		cost = c
		accent = acc
		custom_minimum_size = Vector2(74, 68)
		focus_mode = Control.FOCUS_NONE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		clip_contents = true
		_pic = TextureRect.new()
		_pic.texture = tex
		_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_pic.position = Vector2(16, 3)
		_pic.size = Vector2(42, 32)
		_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_pic)
		_name = UiSkin.label(short_name, 14, UiSkin.TEXT_HI)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.clip_text = true
		_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_name.position = Vector2(2, 32)
		_name.size = Vector2(70, 18)
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_name)
		_cost = UiSkin.label(str(c), 14, UiSkin.TEXT_HI, true)
		_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cost.position = Vector2(10, 48)
		_cost.size = Vector2(62, 18)
		_cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_cost)
		_crystal = UiSkin.Glyph.new("crystal", Color(0.45, 0.75, 1.0), 10)
		_crystal.size = Vector2(10, 10)
		add_child(_crystal)
		_ready_l = UiSkin.label("PRONTO", 14, Color.WHITE, true)
		_ready_l.add_theme_color_override("font_outline_color", Color.BLACK)
		_ready_l.add_theme_constant_override("outline_size", 4)
		_ready_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ready_l.position = Vector2(0, 10)
		_ready_l.size = Vector2(74, 18)
		_ready_l.visible = false
		_ready_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_ready_l)
		_place_cost()

	func _place_cost() -> void:
		var w := UiSkin.font(true).get_string_size(_cost.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var x0 := 37.0 - (w + 13.0) / 2.0
		_crystal.position = Vector2(x0, 52)
		_cost.position = Vector2(x0 + 13.0, 48)
		_cost.size = Vector2(w + 4, 18)
		_cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT

	## Atualiza textos/cores conforme o estado (só redesenha quando algo muda).
	func refresh() -> void:
		var st := "%s|%s|%s|%s|%s|%d|%d|%s" % [locked, poor, no_pop, is_ready, off, queue_n, int(progress * 100.0), disabled]
		if st == _state:
			return
		_state = st
		modulate.a = 0.5 if off else 1.0
		_ready_l.visible = is_ready
		var ctext := str(cost)
		var ccol := UiSkin.TEXT_HI
		if poor and not is_ready:
			ctext += "!"
			ccol = UiSkin.BAD
		if no_pop and not is_ready:
			ctext = "POP!"
			ccol = UiSkin.WARN
		_cost.text = ctext
		_cost.add_theme_color_override("font_color", ccol)
		_place_cost()
		_crystal.visible = not (no_pop and not is_ready)
		_pic.modulate = Color(0.45, 0.45, 0.45, 0.8) if locked else (Color(1, 1, 1, 0.6) if (poor or no_pop) else Color.WHITE)
		_name.add_theme_color_override("font_color", UiSkin.TEXT_MID if locked else UiSkin.TEXT_HI)
		queue_redraw()

	func _draw() -> void:
		if locked:
			var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
			var c := UiSkin.TEXT_DIM
			draw_dashed_line(r.position, Vector2(r.end.x, r.position.y), c, 2.0, 5.0)
			draw_dashed_line(Vector2(r.end.x, r.position.y), r.end, c, 2.0, 5.0)
			draw_dashed_line(r.end, Vector2(r.position.x, r.end.y), c, 2.0, 5.0)
			draw_dashed_line(Vector2(r.position.x, r.end.y), r.position, c, 2.0, 5.0)
			# cadeado 16 no canto superior direito
			var o := Vector2(size.x - 20, 4)
			draw_rect(Rect2(o + Vector2(2, 7), Vector2(12, 9)), UiSkin.TEXT_HI)
			draw_arc(o + Vector2(8, 7), 4.0, PI, TAU, 10, UiSkin.TEXT_HI, 2.0)
		if progress >= 0.0 and not is_ready:
			draw_rect(Rect2(3, size.y - 8, size.x - 6, 6), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(3, size.y - 8, (size.x - 6) * clampf(progress, 0.0, 1.0), 6), accent)
		if is_ready:
			draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color.WHITE, false, 2.0)
		if queue_n > 1:
			var br := Rect2(size.x - 23, 1, 22, 20)
			draw_rect(br, Color(0.05, 0.04, 0.04, 0.95))
			draw_rect(br, accent, false, 1.0)
			draw_string(UiSkin.font(true), Vector2(br.position.x, br.position.y + 15), "x%d" % queue_n,
					HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 14, Color.WHITE)
