extends Node
## Áudio do jogo. Registrado como autoload com o nome "Sfx".
## Cria os barramentos (data/audio_data.gd), toca os eventos com variação de arquivo e de
## tom, limita quantos tocam ao mesmo tempo e atenua os posicionais pela distância à câmera.
## Também liga os sons de interface a todo botão que aparecer na árvore.
## Spec: design/audio/audio-sonoplastia-geral.md

const EVENTS := AudioData.EVENTS

var _streams := {}             # id -> [AudioStream]
var _pool: Array = []          # AudioStreamPlayer livres e ocupados
var _playing := {}             # id -> quantos tocando
var _last := {}                # id -> último disparo (s)
var _max_voices := AudioData.MAX_VOICES


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_max_voices = AudioData.MAX_VOICES_WEB
	_setup_buses()
	for i in _max_voices:
		var p := AudioStreamPlayer.new()
		p.finished.connect(_on_finished.bind(p))
		add_child(p)
		_pool.append(p)
	get_tree().node_added.connect(_on_node_added)
	Game.message.connect(_on_message)
	Net.countdown.connect(func(n: int): if n > 0: play("sfx_ui_countdown_tick"))
	Net.started.connect(func(): play("sfx_ui_countdown_go"))


var _low_power := false
var _low_power_t := 0.0
var _check_t := 0.0


## Energia baixa do jogador local: pulso e mensagem ao começar, pulso repetido a cada
## AudioData.LOW_POWER_REPEAT s enquanto durar.
func _process(delta: float) -> void:
	_check_t -= delta
	if _check_t > 0.0 or Game.map == null or Game.game_over or get_tree().paused:
		return
	_check_t = 1.0
	var low := Game.low_power(Game.local_team)
	var now := Time.get_ticks_msec() / 1000.0
	if low and not _low_power:
		Game.message.emit("Energia baixa: produção pela metade e torres desligadas")
		play("sfx_alert_low_power_pulse")
		_low_power_t = now
	elif low and now - _low_power_t >= AudioData.LOW_POWER_REPEAT:
		play("sfx_alert_low_power_pulse")
		_low_power_t = now
	elif not low and _low_power:
		Game.message.emit("Energia restabelecida")
	_low_power = low


## Mensagem na tela: um "pop" curto, a menos que um som de erro tenha acabado de tocar.
func _on_message(_text: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get("sfx_ui_error", -100.0)) < 0.2:
		return
	play("sfx_ui_message_pop")


func _setup_buses() -> void:
	for b in AudioData.BUSES:
		if AudioServer.get_bus_index(b[0]) >= 0:
			continue
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, b[0])
		AudioServer.set_bus_send(i, b[1])
		AudioServer.set_bus_volume_db(i, b[2])
	# Limitador no Master: batalhas grandes não estouram
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, lim)


func _stream(id: String, n: int) -> AudioStream:
	if not _streams.has(id):
		var list: Array = []
		for k in int(EVENTS[id]["files"]):
			var path := "%s%s_%d.wav" % [AudioData.DIR, id, k + 1]
			if ResourceLoader.exists(path):
				list.append(load(path))
		_streams[id] = list
	var l: Array = _streams[id]
	return l[n % l.size()] if not l.is_empty() else null


## Toca o evento `id`. Com `pos` (ponto do chão, em pixels) e evento posicional, o volume
## cai com a distância ao centro da câmera; longe demais não toca. Devolve se tocou.
func play(id: String, pos = null) -> bool:
	var ev: Dictionary = EVENTS.get(id, {})
	if ev.is_empty():
		push_warning("Sfx: evento desconhecido " + id)
		return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last.get(id, -100.0)) < float(ev["gap"]):
		return false
	if int(_playing.get(id, 0)) >= int(ev["voices"]):
		return false
	var db := float(ev["db"])
	if ev["pos"] and pos != null:
		var att = _attenuation(pos)
		if att == null:
			return false
		db += att
	var p := _free_player(int(ev["prio"]))
	if p == null:
		return false
	var s := _stream(id, randi())
	if s == null:
		return false
	_last[id] = now
	_playing[id] = int(_playing.get(id, 0)) + 1
	p.set_meta("id", id)
	p.set_meta("prio", int(ev["prio"]))
	p.stream = s
	p.bus = ev["bus"]
	p.volume_db = db
	p.pitch_scale = 1.0 + randf_range(-1.0, 1.0) * float(ev["pitch"])
	p.play()
	return true


## Som de uma entidade: só se o jogador local a enxerga (inimigo na névoa não denuncia).
func play_at(id: String, e) -> bool:
	if e == null or not is_instance_valid(e):
		return false
	if e.team != Game.local_team and not e.visible:
		return false
	return play(id, e.position)


## dB a somar pela distância do ponto ao centro da câmera; null = longe demais.
func _attenuation(pos: Vector2):
	var cam := get_viewport().get_camera_3d() as RTSCamera
	if cam == null:
		return 0.0
	var center: Vector2 = Game.to_ground(cam.target)
	var d := center.distance_to(pos) / Game.TILE / maxf(cam.dist, 1.0)
	if d <= AudioData.NEAR:
		return 0.0
	if d >= AudioData.FAR:
		return null
	return lerpf(0.0, AudioData.FAR_DB, (d - AudioData.NEAR) / (AudioData.FAR - AudioData.NEAR))


## Tocador livre; sem nenhum, rouba o de prioridade mais baixa (número maior) que `prio`.
func _free_player(prio: int) -> AudioStreamPlayer:
	var victim: AudioStreamPlayer = null
	for p in _pool:
		if not p.playing:
			return p
		if int(p.get_meta("prio", 1)) > prio and (victim == null or int(p.get_meta("prio")) > int(victim.get_meta("prio"))):
			victim = p
	if victim != null:
		victim.stop()
		_on_finished(victim)
	return victim


func _on_finished(p: AudioStreamPlayer) -> void:
	var id: String = p.get_meta("id", "")
	if id != "":
		_playing[id] = maxi(0, int(_playing.get(id, 0)) - 1)
		p.set_meta("id", "")


# ---------------------------------------------------------------- ganchos do jogo

## Disparo de arma: o som depende do tipo e da raça de quem atira.
func weapon_fired(shooter, wtype: String) -> void:
	var fac: String = Game.factions[shooter.team] if shooter.team < Game.factions.size() else ""
	var id: String = AudioData.FACTION_WEAPON.get(fac, {}).get(wtype, AudioData.WEAPON.get(wtype, ""))
	if id != "":
		play_at(id, shooter)


## Acerto: projéteis têm som próprio; raios instantâneos, um chiado (ácido no Enxame).
func weapon_hit(target, wtype: String, shooter_team: int) -> void:
	var id: String = AudioData.IMPACT.get(wtype, "")
	if id == "":
		var fac: String = Game.factions[shooter_team] if shooter_team < Game.factions.size() else ""
		id = "sfx_impact_acid" if fac == "ins" else "sfx_impact_beam"
	play_at(id, target)


func unit_died(u) -> void:
	var fac: String = Game.factions[u.team] if u.team < Game.factions.size() else ""
	var id := "sfx_explosion_vehicle"
	if u.is_infantry:
		if fac == "rob":
			id = "sfx_death_robot"
		elif fac == "ins":
			id = "sfx_death_insect"
		elif u.last_hit_type in ["at", "cannon", "missile"]:
			id = "sfx_death_infantry_explode"
		else:
			id = "sfx_death_infantry_human"
	play_at(id, u)


func building_died(b) -> void:
	var fac: String = Game.factions[b.team] if b.team < Game.factions.size() else ""
	if b.type == "cy":
		play("sfx_explosion_building_large")
	elif fac == "ins":
		play_at("sfx_explosion_organic_burst", b)
	else:
		play_at("sfx_explosion_building_small", b)


## Alerta de base atacada: stinger da facção do jogador.
func base_alert() -> void:
	var fac: String = Game.factions[Game.local_team]
	play("sfx_alert_base_attack_sting_" + fac)
	play("sfx_ui_minimap_ping")


# ---------------------------------------------------------------- interface

func _on_node_added(n: Node) -> void:
	if n is BaseButton:
		n.pressed.connect(_on_button.bind(n))
		n.mouse_entered.connect(func(): if not n.disabled: play("sfx_ui_hover"))


func _on_button(b: BaseButton) -> void:
	var t := String(b.get("text") if "text" in b else "").to_upper()
	play("sfx_ui_back" if t.contains("VOLTAR") or t.contains("CANCELAR") else "sfx_ui_click")
