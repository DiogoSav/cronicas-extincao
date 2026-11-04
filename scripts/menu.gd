class_name MainMenu
extends Control
## Menu inicial: fundo 3D (céu estrelado, planeta e naves passando), tela de título
## (Jogar / Sair) e a escolha da raça do jogador e do inimigo. Visual: production/ui/hud-e-menu/ux-spec.md, seção 4.

const ACCENT := GameTheme.ACCENT

const SKY_SHADER := """
shader_type sky;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float n = fbm(d * 2.5 + vec3(TIME * 0.003, 0.0, 0.0));
	float n2 = fbm(d * 5.0 + vec3(3.1));
	vec3 neb = mix(vec3(0.20, 0.05, 0.30), vec3(0.02, 0.18, 0.32), n2);
	vec3 col = vec3(0.005, 0.008, 0.02) + neb * pow(smoothstep(0.35, 0.85, n), 2.0) * 0.9;
	vec3 q = d * 220.0;
	vec3 cell = floor(q);
	float h = hash(cell);
	float s = smoothstep(0.42, 0.0, length(fract(q) - 0.5)) * step(0.985, h);
	float tw = 0.6 + 0.4 * sin(TIME * (1.0 + h * 4.0) + h * 40.0);
	col += vec3(0.85, 0.9, 1.0) * s * tw * 2.5;
	vec3 q2 = d * 700.0;
	col += vec3(0.7, 0.75, 1.0) * step(0.993, hash(floor(q2))) * 0.6;
	COLOR = col;
}
"""

const PLANET_SHADER := """
shader_type spatial;
uniform sampler2D noise_tex : repeat_enable;
varying vec3 onrm;
void vertex() {
	onrm = NORMAL;
}
void fragment() {
	vec2 uv = vec2(atan(onrm.z, onrm.x) / 6.2831 + TIME * 0.002, acos(onrm.y) / 3.1416);
	float n = texture(noise_tex, uv * vec2(2.0, 1.0)).r;
	float n2 = texture(noise_tex, uv * vec2(8.0, 4.0)).r;
	vec3 a = vec3(0.32, 0.18, 0.16);
	vec3 b = vec3(0.12, 0.08, 0.16);
	vec3 c = mix(b, a, smoothstep(0.35, 0.7, n));
	c = mix(c, vec3(0.55, 0.42, 0.35), smoothstep(0.65, 0.85, n2) * 0.4);
	ALBEDO = c;
	ROUGHNESS = 0.9;
	// luzes de cidades no lado escuro
	EMISSION = vec3(0.4, 0.7, 1.0) * step(0.78, n2) * step(0.5, n) * 0.6;
}
"""

const ATMO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_front, depth_draw_never;
uniform vec4 color : source_color = vec4(0.35, 0.6, 1.0, 1.0);
void fragment() {
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	ALBEDO = color.rgb * rim * 2.5;
}
"""

var title_page: VBoxContainer
var faction_page: VBoxContainer
var mp_page: VBoxContainer
var room_page: VBoxContainer
var campaign_page: VBoxContainer
var _race_buttons := {}
var _name_edit: LineEdit
var _code_edit: LineEdit
var _mp_status: Label
var _room_title: Label
var _room_hint: Label
var _cards: Array = []
var _chat_log: RichTextLabel
var _chat_edit: LineEdit
var _countdown_label: Label
var _countdown_icon: Control
var _ready_button: Button
var _exit_room_button: Button
var _ships: Array = []
var _enemy_buttons := {}
var _solo_map_buttons := {}
var _diff_buttons := {}
var _room_map_buttons := {}
var _room_map_row: HBoxContainer
var _room_map_info: Label
## Campanha: abas por facção e o bloco da facção escolhida
var _camp_tabs := {}
var _camp_body: VBoxContainer
var _camp_strip: ColorRect
var _camp_tab := ""
var _camp_focus: Control
## Primeiro controle com foco de teclado em cada página
var _first_focus := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	UiSkin.install()
	theme = UiSkin.theme("")
	_build_space()
	# Vinheta de legibilidade: atrás das páginas, à frente do fundo 3D
	var vig := Vignette.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vig)

	title_page = _page()
	_title(title_page, GameTheme.SUBTITLE)
	var ships := HBoxContainer.new()
	ships.alignment = BoxContainer.ALIGNMENT_CENTER
	ships.add_theme_constant_override("separation", 30)
	title_page.add_child(ships)
	for id in GameTheme.MENU_SHOWCASE:
		ships.add_child(_pic(Game.icon(id), Vector2(256, 192)))
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons.custom_minimum_size = Vector2(360, 0)
	title_page.add_child(buttons)
	var camp := _menu_button("CAMPANHA", func(): _show_page(campaign_page))
	UiSkin.style_button(camp, "", true)   # botão principal: faixa de acento
	buttons.add_child(camp)
	_first_focus[title_page] = camp
	buttons.add_child(_menu_button("JOGAR CONTRA A IA", func(): _show_page(faction_page)))
	if Net.available():
		buttons.add_child(_menu_button("MULTIPLAYER  (1 × 1)", func(): _show_page(mp_page)))
	if not OS.has_feature("web"):   # no navegador o jogo não pode fechar a aba
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(0, 0)
		buttons.add_child(gap)
		var quit_b := _menu_button("SAIR", func(): get_tree().quit())
		quit_b.add_theme_stylebox_override("normal", UiSkin.frame("", "n3", "disabled"))
		quit_b.add_theme_color_override("font_color", UiSkin.TEXT_MID)
		buttons.add_child(quit_b)
	var version := String(ProjectSettings.get_setting("application/config/version", ""))
	if version != "":
		var vl := UiSkin.label("v" + version, 14, UiSkin.TEXT_MID)
		vl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		vl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		vl.grow_vertical = Control.GROW_DIRECTION_BEGIN
		vl.offset_right = -16
		vl.offset_bottom = -10
		add_child(vl)

	_build_mp_page()
	_build_campaign_page()

	faction_page = _page()
	faction_page.add_theme_constant_override("separation", 12)
	_title(faction_page, "escolha a sua raça")
	faction_page.visible = false

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	faction_page.add_child(row)
	for f in Game.FACTIONS:
		row.add_child(_faction_card(f))

	# Configuração da escaramuça num painel neutro: inimigo, mapa, dificuldade
	var cfg := PanelContainer.new()
	cfg.add_theme_stylebox_override("panel", UiSkin.frame("", "n1"))
	cfg.custom_minimum_size = Vector2(1250, 0)
	cfg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	faction_page.add_child(cfg)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 10)
	cfg.add_child(cv)
	var enemy_row := _option_row("Inimigo:", false)
	cv.add_child(enemy_row)
	for key in [""] + Game.FACTIONS.keys():
		var b := _toggle_button("Aleatório" if key == "" else Game.FACTIONS[key]["name"])
		b.pressed.connect(_set_enemy.bind(key))
		enemy_row.add_child(b)
		_enemy_buttons[key] = b
	_set_enemy(Game.enemy_choice)
	cv.add_child(_map_row(_solo_map_buttons, _set_solo_map, false))
	_set_solo_map(Game.map_size)
	cv.add_child(_difficulty_row())
	_set_difficulty(Game.ai_difficulty)

	var help := UiSkin.label("Arrastar: selecionar   ·   Botão direito: mover / atacar   ·   Ctrl + botão direito: andar atacando\nWASD / bordas: câmera   ·   Roda: zoom   ·   Clique no minimapa: ir para o local   ·   F11: tela cheia", 16, UiSkin.TEXT_MID)
	if OS.has_feature("web"):
		help.text = help.text.replace("WASD / bordas: câmera", "WASD / setas: câmera")
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 6)
	faction_page.add_child(help)
	var back := _menu_button("VOLTAR", func(): _show_page(title_page))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(240, 46)
	faction_page.add_child(back)

	add_child(Ambience.new())
	_focus_page.call_deferred(title_page)


# ---------------------------------------------------------------- fundo 3D

func _build_space() -> void:
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(svc)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	svc.add_child(vp)

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SKY_SHADER
	sm.shader = sh
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.32, 0.45)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_bloom = 0.05
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)

	var cam := Camera3D.new()
	cam.fov = 50.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.5, 9), Vector3(0, 0.2, 0))

	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.92, 0.82)
	sun.light_energy = 1.6
	vp.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-1.0, -0.35, -0.5))

	# Planeta com atmosfera
	var planet := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 9.0
	sphere.height = 18.0
	sphere.radial_segments = 96
	sphere.rings = 48
	planet.mesh = sphere
	var pm := ShaderMaterial.new()
	var psh := Shader.new()
	psh.code = PLANET_SHADER
	pm.shader = psh
	var nz := FastNoiseLite.new()
	nz.frequency = 0.012
	nz.fractal_octaves = 6
	var nt := NoiseTexture2D.new()
	nt.width = 1024
	nt.height = 512
	nt.seamless = true
	nt.noise = nz
	pm.set_shader_parameter("noise_tex", nt)
	planet.material_override = pm
	planet.position = Vector3(4.5, -9.8, -6.0)
	vp.add_child(planet)
	var atmo := MeshInstance3D.new()
	var s2 := SphereMesh.new()
	s2.radius = 9.5
	s2.height = 19.0
	s2.radial_segments = 96
	s2.rings = 48
	atmo.mesh = s2
	var am := ShaderMaterial.new()
	var ash := Shader.new()
	ash.code = ATMO_SHADER
	am.shader = ash
	atmo.material_override = am
	atmo.position = planet.position
	vp.add_child(atmo)

	# Naves cruzando a cena (data/theme.gd)
	for s in GameTheme.MENU_FLYBY:
		var m := Models.instantiate(s[0])
		m.scale = Vector3.ONE * float(s[3])
		m.position = s[1]
		m.rotation.y = -0.18
		vp.add_child(m)
		var key: String = String(s[0]).get_slice("_", 0)
		Models.set_team(m, Game.FACTIONS[key]["color"])
		for loc in Models.locators_named(m, "engine"):
			var tr := Fx3D.engine_trail(Game.FACTIONS[key]["shot"])
			tr.amount = 40
			tr.lifetime = 0.8
			loc.add_child(tr)
		_ships.append([m, float(s[2]), randf() * 10.0, s[1].y])


func _process(delta: float) -> void:
	for s in _ships:
		var m: Node3D = s[0]
		s[2] += delta
		m.position += Vector3(cos(m.rotation.y), 0, sin(m.rotation.y)) * s[1] * delta
		m.position.y = s[3] + sin(s[2] * 0.8) * 0.15
		m.rotation.x = sin(s[2] * 0.6) * 0.08
		if m.position.x > 14.0:
			m.position.x = -16.0
			m.position.z -= 0.0
		for wing in m.find_children("wing_*", "Node3D", true, false):
			wing.rotation.x = sin(s[2] * 30.0) * 0.4 * (1 if wing.name == "wing_l" else -1)
		for sp in m.find_children("spin", "Node3D", true, false):
			sp.rotation.y += delta


# ---------------------------------------------------------------- páginas

func _page() -> VBoxContainer:
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	add_child(col)
	return col


func _title(page: VBoxContainer, subtitle: String) -> void:
	var title := Label.new()
	title.text = GameTheme.TITLE
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", UiSkin.font(true))
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.92, 0.86, 0.8))
	title.add_theme_color_override("font_outline_color", Color(0.3, 0.05, 0.03))
	title.add_theme_constant_override("outline_size", 16)
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.35, 0.15, 0.45))
	title.add_theme_constant_override("shadow_outline_size", 30)
	page.add_child(title)
	# Filete sob o título (cosmético)
	var line := ColorRect.new()
	line.color = Color(GameTheme.ACCENT, 0.55)
	line.custom_minimum_size = Vector2(560, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	page.add_child(line)
	var sub := UiSkin.label(subtitle, 24, UiSkin.TEXT_MID)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page.add_child(sub)


## Campanha: ABAS por facção (Império / Legião / Enxame), 7 missões por vez, sem rolagem.
## Uma missão abre quando a anterior foi concluída (progresso em user://campanha.cfg).
func _build_campaign_page() -> void:
	campaign_page = _page()
	_title(campaign_page, "campanha")
	campaign_page.visible = false
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	campaign_page.add_child(tabs)
	for f in Game.FACTIONS:
		var fac: Dictionary = Game.FACTIONS[f]
		var b := _toggle_button(String(fac["name"]).to_upper())
		b.custom_minimum_size = Vector2(300, 52)
		b.add_theme_font_size_override("font_size", 20)
		b.icon = UiSkin.logo(f)
		b.add_theme_constant_override("icon_max_width", 30)
		UiSkin.style_button(b, f)
		b.pressed.connect(_show_campaign_tab.bind(f))
		tabs.add_child(b)
		_camp_tabs[f] = b
	var body := PanelContainer.new()
	body.add_theme_stylebox_override("panel", UiSkin.frame("", "n1"))
	body.custom_minimum_size = Vector2(780, 0)
	body.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	campaign_page.add_child(body)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	body.add_child(hb)
	_camp_strip = ColorRect.new()
	_camp_strip.custom_minimum_size = Vector2(4, 0)
	hb.add_child(_camp_strip)
	_camp_body = VBoxContainer.new()
	_camp_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_camp_body.add_theme_constant_override("separation", 8)
	hb.add_child(_camp_body)
	var back := _menu_button("VOLTAR", func(): _show_page(title_page))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(240, 46)
	campaign_page.add_child(back)
	# Aba inicial: a primeira facção com campanha
	var first: String = Game.FACTIONS.keys()[0]
	for f in Game.FACTIONS:
		if CampaignData.CAMPAIGNS.has(f):
			first = f
			break
	_show_campaign_tab(first)


## Mostra a campanha de uma facção na aba (cabeçalho, descrição e as missões).
func _show_campaign_tab(f: String) -> void:
	_camp_tab = f
	for k in _camp_tabs:
		_mark(_camp_tabs[k], k == f)
	var fac: Dictionary = Game.FACTIONS[f]
	var sk := UiSkin.skin(f)
	_camp_strip.color = fac["color"]
	for c in _camp_body.get_children():
		c.queue_free()
	_camp_focus = _camp_tabs[f]
	if not CampaignData.CAMPAIGNS.has(f):
		_camp_body.add_child(UiSkin.label(String(fac["name"]).to_upper(), 30, sk["title"], true))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var g := UiSkin.Glyph.new("clock", UiSkin.TEXT_MID, 22)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(g)
		row.add_child(UiSkin.label("Campanha em produção: as missões desta facção chegam numa próxima versão.", 18, UiSkin.TEXT_MID))
		_camp_body.add_child(row)
		if campaign_page != null and campaign_page.visible:
			_focus_page.call_deferred(campaign_page)
		return
	var camp: Dictionary = CampaignData.CAMPAIGNS[f]
	var head := UiSkin.label("%s  —  %s" % [String(fac["name"]).to_upper(), camp["name"]], 30, sk["title"], true)
	_camp_body.add_child(head)
	var desc := UiSkin.label(camp["desc"], 18, UiSkin.TEXT_HI)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(700, 0)
	_camp_body.add_child(desc)
	var done := Mission.completed()
	var unlocked := true
	var next_set := false
	for id in camp["missions"]:
		var ready: bool = CampaignData.MISSIONS.has(id)
		var title: String = CampaignData.MISSIONS[id]["title"] if ready else CampaignData.PLANNED.get(id, "?")
		var b := make_button("%s  ·  %s" % [id, title])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(620, 46)
		b.add_theme_font_size_override("font_size", 20)
		b.disabled = not (ready and unlocked)
		var glyph := ""
		var gcol := UiSkin.TEXT_MID
		if done.has(id):
			b.text += "   (concluída)"
			glyph = "check"
			gcol = UiSkin.GOOD
		elif not ready:
			b.text += "   (em produção)"
			glyph = "clock"
		elif not unlocked:
			b.text += "   (bloqueada)"
			glyph = "lock"
		elif not next_set:
			# Próxima missão liberada: borda de acento e foco inicial do teclado
			UiSkin.style_button(b, f, true)
			_camp_focus = b
			next_set = true
		if glyph != "":
			var g := UiSkin.Glyph.new(glyph, gcol, 20)
			g.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
			g.offset_left = -34
			g.offset_right = -14
			g.offset_top = -10
			g.offset_bottom = 10
			b.add_child(g)
		b.pressed.connect(func(): Mission.start(get_tree(), id))
		_camp_body.add_child(b)
		unlocked = unlocked and done.has(id)
	if _camp_focus is Button and (_camp_focus as Button).disabled:
		_camp_focus = _camp_tabs[f]
	if campaign_page.visible:
		_focus_page.call_deferred(campaign_page)


## Multiplayer, 1ª tela: nome do jogador, criar uma sala ou entrar com um código.
func _build_mp_page() -> void:
	mp_page = _page()
	_title(mp_page, "multiplayer  ·  1 contra 1 pela internet")
	mp_page.visible = false

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiSkin.frame("", "n1"))
	panel.custom_minimum_size = Vector2(900, 0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mp_page.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 16)
	panel.add_child(pv)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 12)
	pv.add_child(name_row)
	name_row.add_child(UiSkin.label("Seu nome", 22, UiSkin.TEXT_HI))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(320, 50)
	_name_edit.add_theme_font_size_override("font_size", 24)
	_name_edit.text = Game.player_name
	_name_edit.text_changed.connect(func(t): Game.player_name = t.strip_edges())
	name_row.add_child(_name_edit)
	_first_focus[mp_page] = _name_edit

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	pv.add_child(actions)
	var create := make_button("CRIAR SALA")
	create.custom_minimum_size = Vector2(260, 54)
	create.pressed.connect(_create_room)
	UiSkin.style_button(create, "", true)
	actions.add_child(create)
	actions.add_child(UiSkin.label("ou", 18, UiSkin.TEXT_MID))
	_code_edit = LineEdit.new()
	_code_edit.placeholder_text = "CÓDIGO"
	_code_edit.max_length = 5
	_code_edit.custom_minimum_size = Vector2(170, 54)
	_code_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_edit.add_theme_font_size_override("font_size", 26)
	_code_edit.text_changed.connect(func(t):
		var col := _code_edit.caret_column
		_code_edit.text = t.to_upper()
		_code_edit.caret_column = col)
	_code_edit.text_submitted.connect(func(_t): _join())
	actions.add_child(_code_edit)
	var join := make_button("ENTRAR")
	join.custom_minimum_size = Vector2(200, 54)
	join.pressed.connect(_join)
	actions.add_child(join)

	_mp_status = UiSkin.label("Um jogador cria a sala e passa o código; o outro digita o código e entra.", 22, ACCENT)
	_mp_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mp_status.add_theme_color_override("font_outline_color", Color.BLACK)
	_mp_status.add_theme_constant_override("outline_size", 6)
	_mp_status.custom_minimum_size = Vector2(0, 70)
	mp_page.add_child(_mp_status)

	var back := _menu_button("VOLTAR", func(): _show_page(title_page))
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.custom_minimum_size = Vector2(240, 46)
	mp_page.add_child(back)

	_build_room_page()
	Net.status.connect(_on_net_status)
	Net.room_changed.connect(_refresh_room)
	Net.chat.connect(_on_chat)
	Net.countdown.connect(_on_countdown)


## Multiplayer, 2ª tela: a sala de espera. Mostra os dois jogadores (nome, raça, pronto),
## a escolha de raça, o chat e o botão PRONTO.
func _build_room_page() -> void:
	room_page = _page()
	room_page.add_theme_constant_override("separation", 12)
	room_page.visible = false
	_room_title = UiSkin.label("", 44, Color(0.92, 0.86, 0.8), true)
	_room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_page.add_child(_room_title)
	_room_hint = UiSkin.label("", 18, UiSkin.TEXT_MID)
	_room_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_page.add_child(_room_hint)

	# Os dois jogadores
	var players := HBoxContainer.new()
	players.alignment = BoxContainer.ALIGNMENT_CENTER
	players.add_theme_constant_override("separation", 30)
	room_page.add_child(players)
	for i in 2:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(430, 120)
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(box)
		var n := UiSkin.label("", 28, UiSkin.TEXT_HI, true)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(n)
		var rr := HBoxContainer.new()
		rr.alignment = BoxContainer.ALIGNMENT_CENTER
		rr.add_theme_constant_override("separation", 8)
		box.add_child(rr)
		var lg := UiSkin.logo_rect("", 34)
		rr.add_child(lg)
		var r := UiSkin.label("", 20)
		rr.add_child(r)
		var s := UiSkin.label("", 20)
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(s)
		players.add_child(card)
		_cards.append({"panel": card, "name": n, "race": r, "state": s, "logo": lg})

	# Tamanho do mapa (só o anfitrião muda; o convidado vê a escolha)
	_room_map_row = _map_row(_room_map_buttons, func(k): Net.set_map(k), true)
	room_page.add_child(_room_map_row)
	_room_map_info = UiSkin.label("", 20, UiSkin.TEXT_HI)
	_room_map_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_page.add_child(_room_map_info)

	# Escolha de raça (do jogador local)
	var races := HBoxContainer.new()
	races.alignment = BoxContainer.ALIGNMENT_CENTER
	races.add_theme_constant_override("separation", 12)
	room_page.add_child(races)
	races.add_child(UiSkin.label("Sua raça:", 20, UiSkin.TEXT_MID))
	for f in Game.FACTIONS:
		var fac: Dictionary = Game.FACTIONS[f]
		var b := _toggle_button(fac["name"])
		b.custom_minimum_size = Vector2(250, 46)
		b.add_theme_font_size_override("font_size", 20)
		b.icon = UiSkin.logo(f)
		b.add_theme_constant_override("icon_max_width", 26)
		UiSkin.style_button(b, f)
		b.pressed.connect(func(): Net.set_race(f))
		races.add_child(b)
		_race_buttons[f] = b

	# Chat
	var chat_box := VBoxContainer.new()
	chat_box.custom_minimum_size = Vector2(900, 0)
	chat_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	room_page.add_child(chat_box)
	_chat_log = RichTextLabel.new()
	_chat_log.custom_minimum_size = Vector2(900, 170)
	_chat_log.scroll_following = true
	_chat_log.add_theme_font_size_override("normal_font_size", 18)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#050A12D9")
	sb.border_color = ACCENT.darkened(0.55)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	_chat_log.add_theme_stylebox_override("normal", sb)
	chat_box.add_child(_chat_log)
	var chat_row := HBoxContainer.new()
	chat_box.add_child(chat_row)
	_chat_edit = LineEdit.new()
	_chat_edit.placeholder_text = "Escreva uma mensagem e aperte Enter"
	_chat_edit.max_length = 200
	_chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_edit.add_theme_font_size_override("font_size", 18)
	_chat_edit.text_submitted.connect(func(_t): _send_chat())
	chat_row.add_child(_chat_edit)
	var send := make_button("ENVIAR")
	send.custom_minimum_size = Vector2(140, 40)
	send.add_theme_font_size_override("font_size", 18)
	send.pressed.connect(_send_chat)
	chat_row.add_child(send)

	var cd := HBoxContainer.new()
	cd.alignment = BoxContainer.ALIGNMENT_CENTER
	cd.add_theme_constant_override("separation", 8)
	room_page.add_child(cd)
	_countdown_icon = UiSkin.Glyph.new("clock", UiSkin.GOOD, 24)
	_countdown_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_countdown_icon.visible = false
	cd.add_child(_countdown_icon)
	_countdown_label = UiSkin.label("", 26, UiSkin.GOOD, true)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd.add_child(_countdown_label)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	room_page.add_child(buttons)
	_ready_button = make_button("PRONTO")
	_ready_button.toggle_mode = true
	_ready_button.custom_minimum_size = Vector2(260, 56)
	_ready_button.toggled.connect(func(on): Net.set_ready(on))
	UiSkin.style_button(_ready_button, "", true)
	buttons.add_child(_ready_button)
	_exit_room_button = make_button("SAIR DA SALA")
	_exit_room_button.custom_minimum_size = Vector2(260, 56)
	_exit_room_button.pressed.connect(func(): _show_page(mp_page))
	buttons.add_child(_exit_room_button)


func _create_room() -> void:
	Game.player_name = _player_name()
	_chat_log.clear()
	Net.host(Game.player_name, Game.player_faction)
	_show_page(room_page, false)


func _join() -> void:
	var c := _code_edit.text.strip_edges()
	if c.length() != 5:
		_mp_status.text = "!  Digite o código de 5 letras da sala"
		return
	Game.player_name = _player_name()
	_chat_log.clear()
	Net.join(c, Game.player_name)
	_show_page(room_page, false)
	_refresh_room()


func _player_name() -> String:
	var n := _name_edit.text.strip_edges()
	return n if n != "" else "Comandante %d" % (randi() % 900 + 100)


func _send_chat() -> void:
	Net.send_chat(_chat_edit.text)
	_chat_edit.text = ""


func _on_net_status(text: String) -> void:
	_mp_status.text = text
	_room_hint.text = text
	if Net.role == "" and room_page.visible:
		_show_page(mp_page, false)   # a sala fechou ou não foi encontrada


func _on_chat(line: String) -> void:
	_chat_log.append_text(line.replace("[", "[lb]") + "\n")


func _on_countdown(n: int) -> void:
	_countdown_label.text = "" if n < 0 else "Os dois estão prontos! Começando em %d…" % n
	_countdown_icon.visible = _countdown_label.text != ""


## Atualiza os cartões dos jogadores, as raças bloqueadas e o botão PRONTO.
func _refresh_room() -> void:
	if Net.role == "":
		return
	var me := Net.me()
	_room_title.text = "SALA  %s" % Net.code
	for i in 2:
		var p: Dictionary = Net.room[i]
		var c: Dictionary = _cards[i]
		var you := "  (você)" if i == me else ""
		var race := ""
		if p.is_empty():
			c["name"].text = "Aguardando jogador…" if i == 1 else "Anfitrião"
			c["race"].text = ""
			c["state"].text = ""
		else:
			race = String(p.get("race", ""))
			var fac: Dictionary = Game.FACTIONS.get(race, {})
			c["name"].text = String(p["name"]) + you
			c["race"].text = fac.get("name", "escolhendo raça…")
			c["race"].add_theme_color_override("font_color",
					UiSkin.skin(race)["title"] if fac.has("name") else UiSkin.TEXT_MID)
			c["state"].text = "PRONTO ✓" if p.get("ready", false) else "ainda não está pronto"
			c["state"].add_theme_color_override("font_color",
					UiSkin.GOOD if p.get("ready", false) else UiSkin.TEXT_MID)
		var has_race := Game.FACTIONS.has(race)
		c["panel"].add_theme_stylebox_override("panel", UiSkin.frame(race if has_race else "", "n1"))
		c["logo"].texture = UiSkin.logo(race) if has_race else null
		c["logo"].visible = has_race
	var mine: Dictionary = Net.room[me]
	var other: Dictionary = Net.room[1 - me]
	for f in _race_buttons:
		_mark(_race_buttons[f], mine.get("race", "") == f)
		_race_buttons[f].disabled = other.get("race", "") == f
		_race_buttons[f].tooltip_text = "O outro jogador já escolheu esta raça" if _race_buttons[f].disabled else ""
	# Mapa: o anfitrião escolhe nos botões; o convidado só vê a escolha, em texto
	var map_k := Net.room_map()
	for k in _room_map_buttons:
		_mark(_room_map_buttons[k], map_k == k)
	_room_map_row.visible = Net.role == "host"
	_room_map_info.visible = Net.role != "host"
	var mi: Dictionary = Game.MAP_SIZES.get(map_k, Game.MAP_SIZES["small"])
	_room_map_info.text = "Mapa:  %s  (%d×%d)   ·   escolhido pelo anfitrião" % [mi["name"],
			roundi(Map.BASE_W * mi["scale"]), roundi(Map.BASE_H * mi["scale"])]
	_ready_button.set_pressed_no_signal(mine.get("ready", false))
	_ready_button.disabled = other.is_empty() or not Game.FACTIONS.has(mine.get("race", ""))
	_ready_button.text = "PRONTO ✓" if mine.get("ready", false) else "PRONTO"
	_ready_button.tooltip_text = ""
	if other.is_empty():
		_ready_button.tooltip_text = "Espere o outro jogador entrar"
	elif not Game.FACTIONS.has(mine.get("race", "")):
		_ready_button.tooltip_text = "Escolha uma raça"
	if Net.role == "host" and other.is_empty():
		_room_hint.text = "Passe o código  %s  para o outro jogador e aguarde ele entrar." % Net.code


func _show_page(page: Control, leave := true) -> void:
	title_page.visible = page == title_page
	faction_page.visible = page == faction_page
	mp_page.visible = page == mp_page
	room_page.visible = page == room_page
	campaign_page.visible = page == campaign_page
	if leave and page != room_page:
		Net.leave()
	if page == room_page:
		_countdown_label.text = ""
		_countdown_icon.visible = false
		_refresh_room()
	_focus_page.call_deferred(page)


## Foco de teclado inicial de cada página (Tab / setas / Enter navegam a partir dele).
func _focus_page(page: Control) -> void:
	var target: Control = _first_focus.get(page)
	if page == campaign_page:
		target = _camp_focus
	elif page == room_page:
		target = _ready_button if not _ready_button.disabled else _exit_room_button
	if target != null and is_instance_valid(target) and target.is_visible_in_tree():
		target.grab_focus()


## Fileira de opções: rótulo à esquerda + botões de alternância.
func _option_row(text: String, centered: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER if centered else BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 10)
	var l := UiSkin.label(text, 20, UiSkin.TEXT_MID)
	if not centered:
		l.custom_minimum_size = Vector2(150, 0)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(l)
	return row


## Botão de alternância exclusiva (o ativo ganha borda de acento e a marca "●").
func _toggle_button(text: String) -> Button:
	var b := make_button(text)
	b.set_meta("base", text)
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(210, 44)
	b.add_theme_font_size_override("font_size", 18)
	return b


## Liga/desliga um botão de alternância sem emitir sinal (marca "●" além da cor).
func _mark(b: Button, on: bool) -> void:
	b.set_pressed_no_signal(on)
	b.text = ("●  " if on else "") + String(b.get_meta("base", b.text))


## Fileira "Mapa: Pequeno · Médio · Grande" (modo individual e sala de espera).
func _map_row(buttons: Dictionary, on_pick: Callable, centered: bool) -> HBoxContainer:
	var row := _option_row("Mapa:", centered)
	for k in Game.MAP_SIZES:
		var info: Dictionary = Game.MAP_SIZES[k]
		var b := _toggle_button("%s  (%d×%d)" % [info["name"], roundi(Map.BASE_W * info["scale"]),
				roundi(Map.BASE_H * info["scale"])])
		b.pressed.connect(func(): on_pick.call(k))
		row.add_child(b)
		buttons[k] = b
	return row


## Fileira "Dificuldade: Fácil · Médio · Difícil" (IA da escaramuça).
func _difficulty_row() -> HBoxContainer:
	var row := _option_row("Dificuldade:", false)
	for k in GameData.AI_DIFFICULTY_ORDER:
		var b := _toggle_button(GameData.AI_DIFFICULTY[k]["name"])
		b.pressed.connect(_set_difficulty.bind(k))
		row.add_child(b)
		_diff_buttons[k] = b
	return row


func _set_difficulty(k: String) -> void:
	Game.ai_difficulty = k
	for key in _diff_buttons:
		_mark(_diff_buttons[key], key == k)


func _set_solo_map(k: String) -> void:
	Game.map_size = k
	for key in _solo_map_buttons:
		_mark(_solo_map_buttons[key], key == k)


func _set_enemy(key: String) -> void:
	Game.enemy_choice = key
	for k in _enemy_buttons:
		_mark(_enemy_buttons[k], k == key)


## Botão grande no estilo do menu (também usado pelo menu de pausa e pelas janelas da
## missão): moldura chanfrada N3 neutra, rótulo Bold 24 e foco de teclado visível.
static func make_button(text: String) -> Button:
	UiSkin.install()
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 54)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", UiSkin.font(true))
	b.add_theme_font_size_override("font_size", 24)
	UiSkin.style_button(b, "")
	b.add_theme_color_override("font_color", UiSkin.TEXT_HI)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", UiSkin.TEXT_MID)
	return b


func _menu_button(text: String, action: Callable) -> Button:
	var b := make_button(text)
	b.pressed.connect(action)
	return b


## Cartão de facção da escaramuça: logo, nome, desfile de tropas, descrição e COMANDAR.
func _faction_card(f: String) -> Control:
	var fac: Dictionary = Game.FACTIONS[f]
	var col: Color = fac["color"]
	var sk := UiSkin.skin(f)
	var panel := PanelContainer.new()
	var sb: StyleBoxTexture = UiSkin.frame(f, "n1").duplicate()
	sb.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(560, 0)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var lg := UiSkin.logo_rect(f, 84)
	lg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(lg)
	var name_l := UiSkin.label(String(fac["name"]).to_upper(), 32, sk["title"], true)
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_l)
	var race := UiSkin.label(fac["army"], 15, UiSkin.TEXT_MID)
	race.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(race)

	# Desfile da tropa: soldados, veículos e naves da raça
	var sizes := [Vector2(96, 62), Vector2(112, 66), Vector2(132, 76)]
	var lists := [fac["infantry"], fac["vehicles"], fac["air"]]
	for i in lists.size():
		var r := HBoxContainer.new()
		r.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_child(r)
		for id in lists[i]:
			r.add_child(_pic(Game.icon(id), sizes[i]))

	var desc := UiSkin.label(fac["desc"], 16, UiSkin.TEXT_HI)
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(desc)

	var b := make_button("COMANDAR")
	UiSkin.style_button(b, f, true)
	b.pressed.connect(_start.bind(f))
	box.add_child(b)
	if not _first_focus.has(faction_page):
		_first_focus[faction_page] = b
	var strip := ColorRect.new()
	strip.color = col
	strip.custom_minimum_size = Vector2(0, 5)
	box.add_child(strip)
	return panel


func _pic(tex: Texture2D, pic_size: Vector2) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = pic_size
	return r


func _start(f: String) -> void:
	Net.leave()
	Game.mission_id = ""
	Game.mission = {}
	Game.player_faction = f
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F11:
		Ambience.toggle_fullscreen()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_show_page(title_page)


## Vinheta de legibilidade: gradiente escuro nas bordas (topo 140, base 260; laterais 120
## quando a tela é mais larga que 16:9), atrás das páginas e à frente do fundo 3D.
class Vignette extends Control:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _band(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color) -> void:
		# a,b no lado escuro; c,d no lado transparente
		draw_polygon(PackedVector2Array([a, b, c, d]), PackedColorArray([ca, ca, cb, cb]))

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var dark := Color(0, 0, 0, 0.7)
		var clear := Color(0, 0, 0, 0)
		_band(Vector2(0, 0), Vector2(w, 0), Vector2(w, 140), Vector2(0, 140), dark, clear)
		_band(Vector2(w, h), Vector2(0, h), Vector2(0, h - 260), Vector2(w, h - 260), dark, clear)
		if w / maxf(h, 1.0) > 1.8:
			_band(Vector2(0, h), Vector2(0, 0), Vector2(120, 0), Vector2(120, h), dark, clear)
			_band(Vector2(w, 0), Vector2(w, h), Vector2(w - 120, h), Vector2(w - 120, 0), dark, clear)
