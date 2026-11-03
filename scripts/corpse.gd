class_name Corpse
extends Node3D
## O que sobra de uma unidade com sprite pré-renderizado.
## Soldados: toca a animação de morte e o corpo fica no chão (com a poça de sangue da folha):
##   death_blast = arma explosiva (canhão, míssil, antiblindagem): arremessado;
##   death_fwd = tiro pelas costas (fugindo): cai de cara; death = cai de costas.
## Veículos e naves: carcaça escurecida com fogo e fumaça (naves caem antes).
## Some devagar depois de LIFETIME.

const LIFETIME := 45.0
const BLAST := ["cannon", "missile", "at"]

var body: SpriteBody
var t := 0.0
var angle := 0.0
var _fall := 0.0
var _infantry := true
var _fire: CPUParticles3D


func setup(model_name: String, u) -> void:
	position = Game.to3d(u.position, u.altitude)
	_fall = u.altitude
	angle = u.body_angle
	_infantry = u.is_infantry
	visible = u.visible
	body = SpriteBody.make(model_name)
	add_child(body)
	if _infantry:
		body.spr.sorting_offset = -0.4   # cadáver desenha antes (embaixo) das unidades vivas
	if _infantry and body.has_anim("death"):
		var anim := "death"
		var from: Vector2 = u.last_hit_from - u.position
		if u.last_hit_type in BLAST and body.has_anim("death_blast"):
			anim = "death_blast"
		elif from.length() > 1.0 and absf(angle_difference(from.angle(), angle)) > PI * 0.6 \
				and body.has_anim("death_fwd"):
			anim = "death_fwd"   # o tiro veio de trás
		body.play(anim, true)
	else:
		body.set_tint(Color(0.3, 0.27, 0.25))
		var top: float = u.height()
		var smoke := Fx3D.smoke(true)
		smoke.position.y = top
		add_child(smoke)
		_fire = Fx3D.fire()
		_fire.position.y = top * 0.7
		add_child(_fire)
	body.update(0.0, angle, u.turret_angle)


func _process(delta: float) -> void:
	t += delta
	if _fall > 0.0:
		# Nave abatida: cai acelerando até o chão e explode
		_fall = maxf(0.0, _fall - delta * (1.0 + t * 5.0))
		position.y = _fall
		if _fall <= 0.0:
			Game.spawn_explosion(Game.to_ground(position), 18.0, 0.1)
	if _infantry:
		body.update(delta, angle, angle, 10.0)
	elif _fire != null and t > 12.0 and _fire.emitting:
		_fire.emitting = false
	if t > LIFETIME - 5.0:
		var a := clampf((LIFETIME - t) / 5.0, 0.0, 1.0)
		var c := body.spr.modulate
		body.set_tint(Color(c.r, c.g, c.b, a))
	if t > LIFETIME:
		queue_free()
