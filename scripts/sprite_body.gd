class_name SpriteBody
extends Node3D
## Visual pré-renderizado de uma entidade (estilo RTS de guerra clássico): folhas de sprite
## geradas no Blender (art_src/blender) e pixelizadas (art_src/gen/pixelize.gd), desenhadas
## num plano voltado para a câmera ortográfica fixa, com os pés no ponto do chão.
##
## Folha: assets/sprites/<modelo>.png + .json (linhas = direções, colunas = animações em
## sequência; "origin" = pixel dos pés). Opcional: <modelo>_turret.png/.json, uma torre que
## gira à parte (veículos e torres de defesa), desenhada por cima do casco no mesmo ponto.
## O modelo 3D da entidade continua carregado, mas invisível (bocas de arma, chaminés, caixa).

const DIR := "res://assets/sprites/"
## Pixels do render por unidade do mundo (1 unidade = 1 célula do mapa). Igual nos scripts do Blender.
const PX_PER_UNIT := 48.0
## Ângulo da câmera, o mesmo dos renders: elevação de 30° e giro de 45° (vista isométrica,
## a câmera fica a sudeste olhando para noroeste; o mapa aparece como um losango).
const ELEVATION := deg_to_rad(30.0)
const YAW := deg_to_rad(45.0)
## Torre: desenhada logo depois do próprio casco (ordem pela distância à câmera, deslocada
## um pouco para a frente). Positivo = desenha depois; medido no Godot 4.7
## (tests/visual/sprites_ordem_teste.gd), a doc não fixa o sinal.
const TURRET_SORT_OFFSET := 0.05

static var _sheets := {}
static var _mats := {}

## Material dos sprites: sem luz (a luz já está no render), sem teste de profundidade (a
## sombra fica abaixo dos pés) e escurecido pela névoa de guerra no ponto dos pés. Sem
## profundidade, quem decide quem fica na frente é a ordenação de transparentes: cada
## Sprite3D ordena pela origem do nó (os pés), não pelo centro da imagem — um prédio alto
## teria o centro "mais perto" da câmera que uma unidade parada na frente dele.
const SHADER := """
shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_disabled, blend_mix;
uniform sampler2D tex : source_color, filter_nearest;
global uniform sampler2D fog_tex;
global uniform float fog_on;
global uniform vec2 fog_size;

void fragment() {
	vec4 c = texture(tex, UV) * COLOR;
	float f = 1.0;
	if (fog_on > 0.5) {
		vec2 fuv = MODEL_MATRIX[3].xz / fog_size;
		f = (fuv.x < 0.0 || fuv.y < 0.0 || fuv.x > 1.0 || fuv.y > 1.0) ? 0.0 : texture(fog_tex, fuv).r;
	}
	ALBEDO = c.rgb * f;
	ALPHA = c.a * smoothstep(0.0, 0.12, f);   // nunca visto: some (não entrega o mapa)
}
"""
static var _shader: Shader


## Um material por folha.
static func material_for(tex: Texture2D, prio := 0) -> ShaderMaterial:
	var key := "%d:%d" % [tex.get_rid().get_id(), prio]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tex", tex)
	m.render_priority = prio
	_mats[key] = m
	return m


## Sprite parado de cenário (rocha, cristal...): variação `row` da folha, pés no ponto do nó.
static func make_static(model_name: String, row: int) -> Sprite3D:
	var sh := _load(model_name)
	var info: Dictionary = sh["info"]
	var s := Sprite3D.new()
	s.texture = sh["tex"]
	s.material_override = material_for(sh["tex"])
	s.region_enabled = true
	s.pixel_size = 1.0 / PX_PER_UNIT
	s.rotation = Vector3(-ELEVATION, YAW, 0.0)   # plano perpendicular à câmera
	s.sorting_use_aabb_center = false            # ordena pelos pés (ver SHADER)
	var fw: float = info["frame_w"]
	var fh: float = info["frame_h"]
	var o: Array = info["origin"]
	s.offset = Vector2(fw / 2.0 - float(o[0]), float(o[1]) - fh / 2.0)
	s.region_rect = Rect2(0, posmod(row, int(sh["dirs"])) * fh, fw, fh)
	return s

var sheet: Dictionary
var turret_sheet: Dictionary
var spr: Sprite3D
var tur: Sprite3D
var anim := "idle"
var anim_t := 0.0
var once := false              # animação que para no último quadro (morte)
var reveal := 1.0              # construção: fração visível de baixo para cima


static func has_sheet(model_name: String) -> bool:
	return not _load(model_name).is_empty()


## Folha carregada uma vez: {tex, info, dirs}.
static func _load(model_name: String) -> Dictionary:
	if _sheets.has(model_name):
		return _sheets[model_name]
	var out := {}
	var jp := DIR + model_name + ".json"
	if FileAccess.file_exists(jp) and ResourceLoader.exists(DIR + model_name + ".png"):
		var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(jp))
		out = {"tex": load(DIR + model_name + ".png"), "info": info, "dirs": info["directions"].size()}
	_sheets[model_name] = out
	return out


static func make(model_name: String) -> SpriteBody:
	var b := SpriteBody.new()
	b.sheet = _load(model_name)
	b.turret_sheet = _load(model_name + "_turret")
	b.spr = b._new_sprite(b.sheet, 0)
	if not b.turret_sheet.is_empty():
		# Mesma prioridade do casco: render_priority vale para a cena inteira e poria toda
		# torre por cima de todos os prédios. A torre só precisa vir logo depois do casco.
		b.tur = b._new_sprite(b.turret_sheet, 0)
		b.tur.sorting_offset = TURRET_SORT_OFFSET
	b.set_frame(0.0, "idle", 0)
	return b


func _new_sprite(sh: Dictionary, prio: int) -> Sprite3D:
	var s := Sprite3D.new()
	var info: Dictionary = sh["info"]
	s.texture = sh["tex"]
	s.material_override = material_for(sh["tex"], prio)
	s.region_enabled = true
	s.pixel_size = 1.0 / PX_PER_UNIT
	s.rotation = Vector3(-ELEVATION, YAW, 0.0)   # plano perpendicular à câmera
	s.sorting_use_aabb_center = false            # ordena pelos pés (ver SHADER)
	var fw: float = info["frame_w"]
	var fh: float = info["frame_h"]
	var o: Array = info["origin"]
	s.offset = Vector2(fw / 2.0 - float(o[0]), float(o[1]) - fh / 2.0)
	add_child(s)
	return s


## Índice da direção (linhas S, SW, W, NW, N, NE, E, SE...) para um ângulo do chão
## (0 = leste, PI/2 = sul, como `facing`).
static func dir_index(angle: float, n: int) -> int:
	return posmod(roundi((angle - PI / 2.0) / (TAU / n)), n)


func has_anim(name: String) -> bool:
	return sheet["info"]["animations"].has(name)


## Começa uma animação (reinicia o tempo); `hold` para no último quadro.
func play(name: String, hold := false) -> void:
	if anim == name and not hold:
		return
	anim = name if has_anim(name) else "idle"
	anim_t = 0.0
	once = hold


## Avança a animação e escolhe o quadro pela direção do corpo (e da torre).
func update(delta: float, body_angle: float, turret_angle: float, fps := 8.0) -> void:
	anim_t += delta
	var a: Dictionary = sheet["info"]["animations"][anim]
	var n := int(a["frames"])
	var f := int(anim_t * fps)
	f = mini(f, n - 1) if once else f % n
	set_frame(body_angle, anim, f)
	if tur != null:
		_region(tur, turret_sheet, dir_index(turret_angle, turret_sheet["dirs"]), 0)


func set_frame(angle: float, name: String, f: int) -> void:
	var a: Dictionary = sheet["info"]["animations"].get(name, sheet["info"]["animations"]["idle"])
	_region(spr, sheet, dir_index(angle, sheet["dirs"]), int(a["col"]) + f)
	if tur != null:
		_region(tur, turret_sheet, dir_index(angle, turret_sheet["dirs"]), 0)


func _region(s: Sprite3D, sh: Dictionary, row: int, col: int) -> void:
	var fw: float = sh["info"]["frame_w"]
	var fh: float = sh["info"]["frame_h"]
	if reveal >= 1.0:
		s.region_rect = Rect2(col * fw, row * fh, fw, fh)
		return
	# Em construção: só a parte de baixo aparece, subindo
	var keep := fh * clampf(reveal, 0.02, 1.0)
	s.region_rect = Rect2(col * fw, row * fh + fh - keep, fw, keep)
	var o: Array = sh["info"]["origin"]
	s.offset = Vector2(fw / 2.0 - float(o[0]), float(o[1]) - fh + keep / 2.0)


## Fim da construção: volta o recorte e o deslocamento normais.
func finish_reveal() -> void:
	reveal = 1.0
	for pair in [[spr, sheet], [tur, turret_sheet]]:
		if pair[0] == null:
			continue
		var info: Dictionary = pair[1]["info"]
		var o: Array = info["origin"]
		pair[0].offset = Vector2(float(info["frame_w"]) / 2.0 - float(o[0]), float(o[1]) - float(info["frame_h"]) / 2.0)


## Clarão de dano e tinta (prédio sem energia, carcaça queimada...).
func set_tint(c: Color) -> void:
	spr.modulate = c
	if tur != null:
		tur.modulate = c
