class_name UiSkin
extends RefCounted
## Skin da interface (production/ui/hud-e-menu/ux-spec.md): fontes Rajdhani com fallback
## para símbolos, cores de texto, molduras chanfradas procedurais (N1 painel-mãe, N2 caixa
## interna, N3 botão) por facção, logos, ícones vetoriais pequenos e o Theme da HUD e do menu.
## Tudo é gerado em código e guardado em cache; nada aqui altera o estado do jogo.

## Cores de texto (contraste sobre o painel #0E0C0C: 15:1, 8:1, 4,6:1)
const TEXT_HI := Color("#EFE8DC")
const TEXT_MID := Color("#B8B0A4")
const TEXT_DIM := Color("#7E766C")
## Avisos por cor (sempre acompanhados de "!" ou texto)
const WARN := Color("#FFB020")
const BAD := Color("#FF6B5A")
const GOOD := Color("#8FD46A")
const BTN_BG := Color("#1B1614")
const INNER_BG := Color("#0A0808")

const FONT_MEDIUM := "res://assets/fonts/Rajdhani-Medium.ttf"
const FONT_BOLD := "res://assets/fonts/Rajdhani-Bold.ttf"
## Fontes do sistema para os símbolos que a Rajdhani não tem (◂ ▸ ◻ ◼ ✓ ▶ ●)
const SYMBOL_FONTS := ["Segoe UI Symbol", "Segoe UI", "DejaVu Sans", "Noto Sans Symbols 2",
		"Noto Sans Symbols", "Noto Sans", "Arial Unicode MS"]

static var _installed := false
static var _fonts := {}
static var _frames := {}
static var _themes := {}
static var _logos := {}


## Carrega as fontes, liga os fallbacks e torna a Rajdhani a fonte padrão de toda a interface
## (inclusive de telas que não usam este tema, como o menu de pausa). Pode ser chamada várias vezes.
static func install() -> void:
	if _installed:
		return
	_installed = true
	var sym := SystemFont.new()
	sym.font_names = PackedStringArray(SYMBOL_FONTS)
	var base: Font = ThemeDB.fallback_font
	for bold in [false, true]:
		var f: Font = load(FONT_BOLD if bold else FONT_MEDIUM)
		if f == null:
			continue
		var fb: Array[Font] = [sym]
		if base != null:
			fb.append(base)
		f.fallbacks = fb
		_fonts[bold] = f
	if _fonts.has(false):
		ThemeDB.fallback_font = _fonts[false]
	ThemeDB.fallback_font_size = 16


## Rajdhani Medium (corpo) ou Bold (títulos, números).
static func font(bold := false) -> Font:
	install()
	return _fonts.get(bold, ThemeDB.fallback_font)


## Chave de facção do jogador local ("hum", "rob", "ins").
static func player_key() -> String:
	return String(Game.factions[Game.local_team]) if Game.factions.size() > Game.local_team else ""


## Skin de uma facção: cor primária (game_data), escura, fundo, título, chanfro e borda dupla.
## Chave "" = skin neutra do menu.
static func skin(fkey: String) -> Dictionary:
	var s: Dictionary = GameTheme.FACTION_SKINS.get(fkey, GameTheme.FACTION_SKINS[""]).duplicate()
	s["color"] = GameData.FACTIONS[fkey]["color"] if GameData.FACTIONS.has(fkey) else GameTheme.ACCENT
	return s


## Logo da facção (null se não houver arquivo).
static func logo(fkey: String) -> Texture2D:
	if not _logos.has(fkey):
		var path := GameTheme.FACTION_LOGO % fkey
		_logos[fkey] = load(path) if ResourceLoader.exists(path) else null
	return _logos[fkey]


## TextureRect com a logo da facção num quadrado de `side` lógicos (proporção mantida).
static func logo_rect(fkey: String, side: float) -> TextureRect:
	var r := TextureRect.new()
	r.texture = logo(fkey)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	r.custom_minimum_size = Vector2(side, side)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Label com fonte, tamanho e cor (tamanho mínimo 14).
static func label(text: String, size := 15, color := TEXT_HI, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(bold))
	l.add_theme_font_size_override("font_size", maxi(size, 14))
	l.add_theme_color_override("font_color", color)
	return l


# ---------------------------------------------------------------- molduras

## Moldura chanfrada procedural (StyleBoxTexture nine-patch, em cache).
## level: "n1" painel-mãe, "n2" caixa interna, "n3" botão.
## state (n3): "normal", "hover", "pressed", "disabled", "active" (alternância ligada), "primary".
static func frame(fkey: String, level := "n1", state := "normal") -> StyleBoxTexture:
	var key := "%s|%s|%s" % [fkey, level, state]
	if _frames.has(key):
		return _frames[key]
	var s := skin(fkey)
	var col: Color = s["color"]
	var dark: Color = s["dark"]
	var cut: int = s["cut"]
	var bw := 2
	var bg: Color = s["bg"]
	bg.a = 0.96
	var border := dark
	var double: bool = s["double"]
	var margin := 10
	match level:
		"n2":
			cut = 4
			bw = 1
			bg = Color(INNER_BG, 0.92)
			border = dark.lightened(0.15)
			double = false
			margin = 4
		"n3":
			cut = 4
			double = false
			margin = 6
			bg = BTN_BG
			match state:
				"hover":
					bg = BTN_BG.lightened(0.08)
					border = col.lightened(0.25)
				"pressed":
					bg = col.darkened(0.7)
					border = col
				"disabled":
					bg = BTN_BG.darkened(0.35)
					border = dark.darkened(0.35)
				"active":
					bg = col.darkened(0.75)
					border = col
					bw = 3
				"primary":
					bg = col.darkened(0.78)
					border = col.darkened(0.1)
	var sz := 32
	var img := Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	var hi := bg.lightened(0.18)
	for y in sz:
		for x in sz:
			var d := _edge_dist(x, y, sz, cut)
			var c := Color(0, 0, 0, 0)
			if d >= 0.0:
				if d < bw:
					c = border
				elif double and d >= bw + 1 and d < bw + 2:
					c = Color(border, 0.8)
				elif y == bw and d < bw + 1.5:
					c = hi   # realce de 1 px no topo
				else:
					c = bg
			img.set_pixel(x, y, c)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	var tm := cut + bw + 2
	sb.texture_margin_left = tm
	sb.texture_margin_right = tm
	sb.texture_margin_top = tm
	sb.texture_margin_bottom = tm
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin if level != "n3" else 3
	sb.content_margin_bottom = margin if level != "n3" else 3
	_frames[key] = sb
	return sb


## Distância (px) do pixel até o contorno do retângulo com os cantos superior-esquerdo e
## inferior-direito cortados em `cut`; negativa = fora.
static func _edge_dist(x: int, y: int, sz: int, cut: int) -> float:
	var d := float(mini(mini(x, y), mini(sz - 1 - x, sz - 1 - y)))
	d = minf(d, (x + y - cut) / 1.4142)
	d = minf(d, ((sz - 1 - x) + (sz - 1 - y) - cut) / 1.4142)
	return d


## Anel de foco de teclado: 2 px branco, fora do controle.
static func focus_ring() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color.WHITE
	sb.set_border_width_all(2)
	sb.set_expand_margin_all(3)
	return sb


## Faixa de cabeçalho de seção: gradiente da cor da facção para transparente.
static func header_strip(fkey: String) -> GradientTexture2D:
	var g := Gradient.new()
	var c: Color = skin(fkey)["color"]
	g.set_color(0, Color(c.darkened(0.35), 0.75))
	g.set_color(1, Color(c.darkened(0.35), 0.0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 4
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(1, 0)
	return t


## Aplica o estilo N3 da facção a um botão (todos os estados + foco).
## primary: borda de acento (botão principal da página).
static func style_button(b: Button, fkey: String, primary := false) -> void:
	b.add_theme_stylebox_override("normal", frame(fkey, "n3", "primary" if primary else "normal"))
	b.add_theme_stylebox_override("hover", frame(fkey, "n3", "hover"))
	b.add_theme_stylebox_override("pressed", frame(fkey, "n3", "active"))
	b.add_theme_stylebox_override("hover_pressed", frame(fkey, "n3", "active"))
	b.add_theme_stylebox_override("disabled", frame(fkey, "n3", "disabled"))
	b.add_theme_stylebox_override("focus", focus_ring())


# ---------------------------------------------------------------- tema

## Theme da HUD/menu na skin da facção: fonte, botões N3, painéis N1, tooltips, campos de texto.
static func theme(fkey: String) -> Theme:
	if _themes.has(fkey):
		return _themes[fkey]
	install()
	var th := Theme.new()
	th.default_font = font(false)
	th.default_font_size = 15
	var s := skin(fkey)
	th.set_stylebox("normal", "Button", frame(fkey, "n3", "normal"))
	th.set_stylebox("hover", "Button", frame(fkey, "n3", "hover"))
	th.set_stylebox("pressed", "Button", frame(fkey, "n3", "active"))
	th.set_stylebox("hover_pressed", "Button", frame(fkey, "n3", "active"))
	th.set_stylebox("disabled", "Button", frame(fkey, "n3", "disabled"))
	th.set_stylebox("focus", "Button", focus_ring())
	th.set_font("font", "Button", font(true))
	th.set_color("font_color", "Button", TEXT_HI)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_pressed_color", "Button", Color.WHITE)
	th.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", TEXT_MID)
	th.set_color("font_color", "Label", TEXT_HI)
	th.set_stylebox("panel", "PanelContainer", frame(fkey, "n1"))
	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(s["bg"], 0.97)
	tip.border_color = s["dark"].lightened(0.2)
	tip.set_border_width_all(1)
	tip.set_content_margin_all(8)
	th.set_stylebox("panel", "TooltipPanel", tip)
	th.set_color("font_color", "TooltipLabel", TEXT_HI)
	th.set_font_size("font_size", "TooltipLabel", 15)
	th.set_font("normal_font", "RichTextLabel", font(false))
	th.set_font("bold_font", "RichTextLabel", font(true))
	th.set_color("default_color", "RichTextLabel", TEXT_HI)
	th.set_stylebox("normal", "LineEdit", frame(fkey, "n3", "normal"))
	var fe := StyleBoxFlat.new()
	fe.draw_center = false
	fe.border_color = s["color"]
	fe.set_border_width_all(2)
	th.set_stylebox("focus", "LineEdit", fe)
	th.set_color("font_color", "LineEdit", TEXT_HI)
	th.set_color("font_placeholder_color", "LineEdit", TEXT_MID)
	th.set_color("caret_color", "LineEdit", Color.WHITE)
	_themes[fkey] = th
	return th


# ---------------------------------------------------------------- ícones

## Ícone vetorial pequeno desenhado em código (categoria, recurso, cadeado, relógio…).
## kind: "house", "soldier", "wheel", "wing", "crystal", "bolt", "pop", "lock", "clock",
## "check", "radio".
class Glyph extends Control:
	var kind := ""
	var color := Color.WHITE

	func _init(k := "", c := Color.WHITE, side := 16.0) -> void:
		kind = k
		color = c
		custom_minimum_size = Vector2(side, side)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) / 2.0
		var w := maxf(1.5, s / 10.0)
		var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
		match kind:
			"house":
				draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.08), p.call(0.95, 0.48),
						p.call(0.05, 0.48)]), color)
				draw_rect(Rect2(p.call(0.18, 0.46), Vector2(0.64, 0.46) * s), color)
			"soldier":
				draw_circle(p.call(0.5, 0.22), s * 0.16, color)
				draw_colored_polygon(PackedVector2Array([p.call(0.22, 0.45), p.call(0.78, 0.45),
						p.call(0.7, 0.95), p.call(0.3, 0.95)]), color)
			"wheel":
				draw_arc(p.call(0.5, 0.5), s * 0.38, 0, TAU, 20, color, w)
				draw_circle(p.call(0.5, 0.5), s * 0.12, color)
				for i in 4:
					var a := i * PI / 4.0
					draw_line(p.call(0.5, 0.5), p.call(0.5, 0.5) + Vector2(cos(a), sin(a)) * s * 0.38, color, w * 0.6)
					draw_line(p.call(0.5, 0.5), p.call(0.5, 0.5) - Vector2(cos(a), sin(a)) * s * 0.38, color, w * 0.6)
			"wing":
				draw_colored_polygon(PackedVector2Array([p.call(0.05, 0.62), p.call(0.5, 0.25),
						p.call(0.95, 0.62), p.call(0.5, 0.48)]), color)
				draw_colored_polygon(PackedVector2Array([p.call(0.42, 0.45), p.call(0.58, 0.45),
						p.call(0.55, 0.9), p.call(0.45, 0.9)]), color)
			"crystal":
				draw_colored_polygon(PackedVector2Array([p.call(0.5, 0.05), p.call(0.85, 0.4),
						p.call(0.5, 0.95), p.call(0.15, 0.4)]), color)
				draw_line(p.call(0.15, 0.4), p.call(0.85, 0.4), color.darkened(0.4), maxf(1.0, w * 0.5))
			"bolt":
				draw_colored_polygon(PackedVector2Array([p.call(0.62, 0.02), p.call(0.2, 0.55),
						p.call(0.48, 0.55), p.call(0.36, 0.98), p.call(0.82, 0.42), p.call(0.54, 0.42)]), color)
			"pop":
				draw_circle(p.call(0.33, 0.3), s * 0.13, color)
				draw_circle(p.call(0.7, 0.3), s * 0.13, color)
				draw_rect(Rect2(p.call(0.15, 0.5), Vector2(0.34, 0.42) * s), color)
				draw_rect(Rect2(p.call(0.53, 0.5), Vector2(0.34, 0.42) * s), color)
			"lock":
				draw_arc(p.call(0.5, 0.42), s * 0.22, PI, TAU, 12, color, w)
				draw_line(p.call(0.28, 0.42), p.call(0.28, 0.5), color, w)
				draw_line(p.call(0.72, 0.42), p.call(0.72, 0.5), color, w)
				draw_rect(Rect2(p.call(0.18, 0.48), Vector2(0.64, 0.46) * s), color)
			"clock":
				draw_arc(p.call(0.5, 0.5), s * 0.42, 0, TAU, 24, color, w)
				draw_line(p.call(0.5, 0.5), p.call(0.5, 0.2), color, w)
				draw_line(p.call(0.5, 0.5), p.call(0.72, 0.6), color, w)
			"check":
				draw_polyline(PackedVector2Array([p.call(0.12, 0.52), p.call(0.4, 0.8),
						p.call(0.9, 0.2)]), color, w * 1.4)
			"radio":
				draw_line(p.call(0.5, 0.95), p.call(0.5, 0.35), color, w)
				draw_circle(p.call(0.5, 0.3), s * 0.08, color)
				draw_arc(p.call(0.5, 0.3), s * 0.22, -PI * 0.85, -PI * 0.15, 10, color, w * 0.8)
				draw_arc(p.call(0.5, 0.3), s * 0.38, -PI * 0.85, -PI * 0.15, 14, color, w * 0.8)
