class_name RTSCamera
extends Camera3D
## Câmera de RTS ortográfica e isométrica: elevação de 30°, a sudeste do foco olhando para
## noroeste (giro de 45°) — o mesmo ângulo em que unidades, prédios e cenário foram
## renderizados no Blender (sprites pré-renderizados, ver SpriteBody).
## WASD/setas ou mouse nas bordas (só no PC) movem o ponto de foco; a roda aproxima e afasta.
## `dist` é a altura da vista em unidades do mundo (tamanho ortográfico).

const SPEED := 16.0          # células por segundo (na distância padrão)
const EDGE := 12.0
const PITCH := SpriteBody.ELEVATION
const YAW := SpriteBody.YAW
const DIST_MIN := 7.0
const DIST_MAX := 30.0
const BACK := 60.0           # distância real da câmera ao foco (só para não cortar nada)

var target := Vector3(8, 0, 38)  # ponto do chão no centro da área de jogo (mundo 3D)
var dist := 17.0
var _dist_goal := 17.0


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	near = 1.0
	far = 200.0
	# Começa com 1 pixel do sprite = 1 pixel da tela (arte nítida)
	dist = clampf(get_viewport().get_visible_rect().size.y / SpriteBody.PX_PER_UNIT, DIST_MIN, DIST_MAX)
	_dist_goal = dist
	_apply()


func _process(delta: float) -> void:
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1

	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var vs := vp.get_visible_rect().size
	# Na Web a câmera só anda pelo teclado (o mouse sai do canvas toda hora no navegador)
	var edge_scroll := not OS.has_feature("web")
	if edge_scroll and DisplayServer.window_is_focused() and Rect2(Vector2.ZERO, vs).has_point(mp):
		if mp.x < EDGE:
			dir.x -= 1
		elif mp.x > vs.x - EDGE:
			dir.x += 1
		if mp.y < EDGE:
			dir.y -= 1
		elif mp.y > vs.y - EDGE:
			dir.y += 1

	if dir != Vector2.ZERO:
		# direções da tela no chão: direita = nordeste, cima = noroeste
		var d := dir.normalized() * SPEED * delta * (dist / 17.0) * Vector2(1.0, 1.6)
		var right := Vector3(cos(YAW), 0, -sin(YAW))
		var down := Vector3(sin(YAW), 0, cos(YAW))
		target += right * d.x + down * d.y
	dist = lerpf(dist, _dist_goal, minf(1.0, delta * 10.0))
	clamp_to_map()
	_apply()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist_goal = clampf(_dist_goal / 1.15, DIST_MIN, dist_max())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist_goal = clampf(_dist_goal * 1.15, DIST_MIN, dist_max())


## Afastamento máximo: cresce com o tamanho do mapa (médio e grande deixam ver mais).
func dist_max() -> float:
	return DIST_MAX * float(Map.W) / float(Map.BASE_W)


## Centraliza a área de jogo num ponto do chão (pixels de chão).
func focus(ground: Vector2) -> void:
	target = Game.to3d(ground)
	clamp_to_map()
	_apply()


func clamp_to_map() -> void:
	target.x = clampf(target.x, 0.0, Map.W)
	target.z = clampf(target.z, 0.0, Map.H + 2.0)


func _apply() -> void:
	var offset := Vector3(sin(YAW) * cos(PITCH), sin(PITCH), cos(YAW) * cos(PITCH)) * BACK
	position = target + offset
	basis = Basis.looking_at(-offset, Vector3.UP)
	size = dist
	# A barra lateral cobre a direita da tela: desloca a câmera para o foco ficar
	# no centro da parte livre.
	var vs := get_viewport().get_visible_rect().size
	var view_w := dist * vs.x / vs.y
	h_offset = HUD.SIDEBAR_W / 2.0 / vs.x * view_w


## Ponto do chão (mundo 3D) sob uma posição da tela, ou null.
func ground_at(screen: Vector2):
	var from := project_ray_origin(screen)
	var dir := project_ray_normal(screen)
	if dir.y > -0.001:
		return null
	return from + dir * (-from.y / dir.y)
