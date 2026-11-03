extends Node
## Estado global do jogo. Registrado como autoload com o nome "Game".
## Guarda raças, dados de unidades/prédios, créditos, produção e a lista de entidades.

signal message(text: String)
signal game_ended(player_won: bool)
## Prédio do jogador local sofreu dano (já filtrado pelo intervalo de alerta). Ligue aqui o
## som de alerta do seu jogo.
signal base_alert(building)

const TILE := 32
const PLAYER := 0
const ENEMY := 1
## Segundo inimigo: só na campanha, em missões com "enemy2" (o multiplayer tem 2 times)
const ENEMY2 := 2
## Conteúdo do jogo (raças, unidades, prédios e regras): vem de data/game_data.gd
const START_CREDITS := GameData.START_CREDITS

## A lógica (posições, alcance, caminhos) continua no plano do chão, em "pixels de chão"
## com TILE = 32. No mundo 3D, 1 célula = 1 unidade: x do chão -> X, y do chão -> Z.
const UNIT := 1.0 / TILE
const AIR_HEIGHT := GameData.AIR_HEIGHT
const ARMOR_MULT := GameData.ARMOR_MULT
const PROJECTILE_WEAPONS := GameData.PROJECTILE_WEAPONS
const FACTIONS := GameData.FACTIONS
const UNITS := GameData.UNITS
const BUILDINGS := GameData.BUILDINGS
const MAX_QUEUE := GameData.MAX_QUEUE
const POP_COST := GameData.POP_COST
const POP_BASE := GameData.POP_BASE
const POP_PER_POWER := GameData.POP_PER_POWER
const POP_MAX := GameData.POP_MAX
const BUILD_ORDER := GameData.BUILD_ORDER
const CATEGORY_NAMES := GameData.CATEGORY_NAMES
const MAP_SIZES := GameData.MAP_SIZES

## Raça escolhida no menu (persiste entre partidas). enemy_choice "" = aleatória.
var player_faction: String = FACTIONS.keys()[0]
## Nome do jogador no multiplayer (persiste entre partidas)
var player_name := ""
## Tamanho do mapa escolhido (MAP_SIZES); no multiplayer quem escolhe é o anfitrião
var map_size := "small"
## Missão de campanha em andamento (CampaignData.MISSIONS[mission_id]); vazio = partida livre
var mission_id := ""
var mission: Dictionary = {}
## Time controlado por este computador (no multiplayer o convidado é o time 1)
var local_team := PLAYER
## Raças da partida multiplayer: [anfitrião, convidado]
var net_factions: Array = []
## IDs de rede de todas as entidades (iguais no anfitrião e no convidado)
var _ids := {}
var _next_id := 1
var _types: Array = []
var enemy_choice := ""
## Dificuldade da IA na escaramuça (GameData.AI_DIFFICULTY; persiste entre partidas)
var ai_difficulty := "medio"
## Times em uso: 2 normalmente, 3 em missões com segundo inimigo
var team_count := 2
## Missão com dois inimigos: true = aliados entre si; false = brigam entre si
var enemies_allied := false
## Raça de cada time: [jogador, inimigo, segundo inimigo?]
var factions: Array = [FACTIONS.keys()[0], FACTIONS.keys()[-1]]
var credits: Array = [START_CREDITS, START_CREDITS]
## Multiplicador do minério descarregado, por time (a IA usa income_mult da dificuldade)
var income_mult: Array = [1.0, 1.0]
var map: Map = null
var world: Node3D = null
var fog: Fog = null
var entities: Array = []
## Uma fila por time: categoria -> {"type", "progress", "done"}
var production: Array = [{}, {}]
## Fila de espera (já paga) depois do trabalho ativo: categoria -> [tipos]. Prédios não têm fila.
var queues: Array = [{}, {}]
var game_over := false
## Ícones dos modelos 3D, renderizados uma vez em SubViewports: nome do modelo -> textura
var _icons := {}


func _ready() -> void:
	# Renderiza todos os ícones logo no início, antes de a névoa de guerra existir
	for f in FACTIONS:
		for id in FACTIONS[f]["infantry"] + FACTIONS[f]["vehicles"] + FACTIONS[f]["air"]:
			icon(id)
		for b in BUILDINGS:
			icon(b + "_" + f)


func _exit_tree() -> void:
	Models.clear_cache()


## Ponto do chão (pixels de chão) no mundo 3D, a `h` unidades de altura.
static func to3d(p: Vector2, h := 0.0) -> Vector3:
	return Vector3(p.x * UNIT, h, p.y * UNIT)


static func to_ground(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z) / UNIT


## Ícone de um modelo 3D (vista 3/4) para botões e menus.
func icon(model_name: String) -> Texture2D:
	if _icons.has(model_name):
		return _icons[model_name]
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 120)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# Renderiza alguns quadros (texturas e shaders prontos) e depois congela a imagem
	get_tree().create_timer(0.6).timeout.connect(
			func(): vp.render_target_update_mode = SubViewport.UPDATE_DISABLED)
	add_child(vp)

	var model := Models.instantiate(model_name)
	vp.add_child(model)
	Models.set_tint(model, Color.WHITE, true)   # ícones ignoram a névoa de guerra
	var fkey := model_name.get_slice("_", 0) if UNITS.has(model_name) else model_name.get_slice("_", 1)
	if FACTIONS.has(fkey):
		Models.set_team(model, FACTIONS[fkey]["color"])
	var box := Models.aabb(model_name)
	var center := box.get_center()
	var building := not UNITS.has(model_name)
	var infantry: bool = UNITS.has(model_name) and UNITS[model_name]["kind"] == "inf"
	var dir := Vector3(0.75, 0.75, 1.0)    # veículos e naves: de lado, um pouco de frente
	if building:
		dir = Vector3(0.45, 0.9, 1.0)      # prédios: como na partida, de frente e de cima
	elif infantry:
		dir = Vector3(1.0, 0.45, 0.8)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = box.size.length() * (0.62 if infantry else 0.55)
	vp.add_child(cam)
	cam.look_at_from_position(center + dir.normalized() * 8.0, center)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.85)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	cam.environment = env
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.95, 0.9)
	sun.light_energy = 1.3
	vp.add_child(sun)
	sun.look_at_from_position(Vector3.ZERO, Vector3(-0.3, -1.0, -0.7))
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.7, 1.0)
	rim.light_energy = 0.8
	vp.add_child(rim)
	rim.look_at_from_position(Vector3.ZERO, Vector3(0.6, -0.3, 0.8))
	var tex := vp.get_texture()
	_icons[model_name] = tex
	return tex


func reset() -> void:
	var enemy := enemy_choice
	if enemy == "" or enemy == player_faction:
		var others: Array = FACTIONS.keys().filter(func(k): return k != player_faction)
		enemy = others.pick_random()
	factions = [player_faction, enemy]
	if Net.active:
		factions = net_factions.duplicate()
	elif mission.has("enemy2"):
		factions.append(mission["enemy2"])
	team_count = factions.size()
	enemies_allied = mission.get("enemies_allied", false)
	_ids = {}
	_next_id = 1
	credits = []
	income_mult = []
	production = []
	queues = []
	for t in team_count:
		credits.append(START_CREDITS)
		income_mult.append(1.0)
		production.append({})
		queues.append({})
	entities = []
	game_over = false
	map = null
	world = null
	fog = null


func faction(team: int) -> Dictionary:
	return FACTIONS[factions[team]]


func team_color(team: int) -> Color:
	var c: Color = faction(team)["color"]
	# Dois inimigos da mesma raça: o segundo fica mais escuro, para o mapa distinguir
	if team == ENEMY2 and factions[ENEMY2] == factions[ENEMY]:
		c = c.darkened(0.45)
	return c


## Os times `a` e `b` se atacam? O jogador é inimigo de todos; os dois inimigos de uma
## missão só se atacam quando a missão não os declara aliados ("enemies_allied").
func are_enemies(a: int, b: int) -> bool:
	if a == b:
		return false
	if a != PLAYER and b != PLAYER:
		return not enemies_allied
	return true


## Times controlados pela IA / inimigos do jogador (1, ou 1 e 2).
func enemy_teams() -> Array:
	return range(1, team_count)


func item_data(type: String) -> Dictionary:
	if UNITS.has(type):
		return UNITS[type]
	return BUILDINGS[type]


## Nome de uma unidade ou prédio (prédios têm nome próprio em cada raça).
func item_name(type: String, team := -1) -> String:
	if BUILDINGS.has(type):
		return faction(local_team if team < 0 else team)["buildings"].get(type, BUILDINGS[type]["name"])
	return UNITS[type]["name"]


# ---------------------------------------------------------------- consultas

func has_building(team: int, type: String) -> bool:
	for e in entities:
		if e is Building and e.team == team and e.type == type and e.built:
			return true
	return false


func building_count(team: int) -> int:
	var n := 0
	for e in entities:
		if e is Building and e.team == team:
			n += 1
	return n


func producer_for(team: int, category: String) -> Building:
	for e in entities:
		if e is Building and e.team == team and e.data["produces"] == category and e.built:
			return e
	return null


func nearest_building(team: int, type: String, pos: Vector2) -> Building:
	var best: Building = null
	var best_d := INF
	for e in entities:
		if e is Building and e.team == team and e.type == type and e.built:
			var d: float = pos.distance_to(e.position)
			if d < best_d:
				best_d = d
				best = e
	return best


## Inimigo mais próximo que `attacker` consegue atingir (naves só com armas antiaéreas).
func nearest_enemy(pos: Vector2, team: int, max_dist: float, attacker: Entity = null) -> Entity:
	var best: Entity = null
	var best_d := max_dist
	for e in entities:
		if not are_enemies(e.team, team) or e.dead:
			continue
		if attacker != null and not attacker.can_hit(e):
			continue
		var d: float = pos.distance_to(e.position) - e.radius
		if d < best_d:
			best_d = d
			best = e
	return best


## x = energia gerada, y = energia consumida
func get_power(team: int) -> Vector2i:
	var made := 0
	var used := 0
	for e in entities:
		if e is Building and e.team == team and e.built:
			var p: int = e.data["power"]
			if p > 0:
				made += p
			else:
				used -= p
	return Vector2i(made, used)


func low_power(team: int) -> bool:
	var p := get_power(team)
	return p.y > p.x


func requirements_met(team: int, type: String) -> bool:
	for r in item_data(type)["requires"]:
		if not has_building(team, r):
			return false
	return true


func can_produce(team: int, type: String) -> bool:
	var cat: String = item_data(type)["category"]
	return producer_for(team, cat) != null and requirements_met(team, type)


# ---------------------------------------------------------------- população

## Campo "pop" da unidade, ou pela função (sufixo do id) em POP_COST.
func pop_cost(type: String) -> int:
	if not UNITS.has(type):
		return 0
	return int(UNITS[type].get("pop", POP_COST.get(type.get_slice("_", 1), 1)))


## População em uso: unidades vivas mais as que estão sendo produzidas ou na fila
## (a fila já reserva o espaço).
func pop_used(team: int) -> int:
	var n := 0
	for e in entities:
		if e is Unit and e.team == team and not e.dead:
			n += pop_cost(e.type)
			if e.is_transport():
				n += e.cargo_used()   # passageiros continuam ocupando população
	return n + pop_reserved(team)


func pop_reserved(team: int) -> int:
	var n := 0
	for cat in ["infantry", "vehicle", "air"]:
		if production[team].has(cat):
			n += pop_cost(production[team][cat]["type"])
		for t in queued(team, cat):
			n += pop_cost(t)
	return n


func pop_cap(team: int) -> int:
	var powers := 0
	for e in entities:
		if e is Building and e.team == team and e.type == "power" and e.built:
			powers += 1
	return mini(POP_MAX, POP_BASE + powers * POP_PER_POWER)


## Cabe mais um `type` na população?
func pop_room(team: int, type: String) -> bool:
	return pop_used(team) + pop_cost(type) <= pop_cap(team)


# ---------------------------------------------------------------- produção

## Começa a produzir `type` ou, se a categoria já está ocupada, põe na fila (paga na hora).
func start_production(team: int, type: String) -> bool:
	if UNITS.has(type) and not pop_room(team, type):
		var msg := "Limite de população: %d / %d" % [pop_used(team), pop_cap(team)]
		if pop_cap(team) < POP_MAX:
			msg += " — construa mais %s (+%d cada)" % [item_name("power", team), POP_PER_POWER]
		notify(team, msg)
		return false
	if Net.is_client():
		Net.order("produce", [type])
		return true
	var data := item_data(type)
	var cat: String = data["category"]
	if not can_produce(team, type):
		return false
	var busy: bool = production[team].has(cat)
	if busy and (cat == "building" or queued(team, cat).size() + 1 >= MAX_QUEUE):
		if cat != "building":
			notify(team, "Fila de produção cheia (máximo %d)" % MAX_QUEUE)
		return false
	if credits[team] < data["cost"]:
		notify(team, "%s insuficientes" % GameTheme.CURRENCY)
		return false
	credits[team] -= data["cost"]
	if busy:
		queued(team, cat).append(type)
	else:
		production[team][cat] = {"type": type, "progress": 0.0, "done": false}
	return true


func queued(team: int, cat: String) -> Array:
	if not queues[team].has(cat):
		queues[team][cat] = []
	return queues[team][cat]


## Quantos itens de `type` estão na produção (o ativo mais os da fila).
func count_in_production(team: int, type: String) -> int:
	var cat: String = item_data(type)["category"]
	var n := queued(team, cat).count(type)
	if production[team].has(cat) and production[team][cat]["type"] == type:
		n += 1
	return n


## Cancela um `type` (o último da fila; se não houver na fila, o que está sendo produzido)
## e devolve os créditos.
func cancel_production(team: int, cat: String, type := "") -> void:
	if Net.is_client():
		Net.order("cancel", [cat, type])
		return
	var q := queued(team, cat)
	var i := q.rfind(type) if type != "" else -1
	if i >= 0:
		q.remove_at(i)
		credits[team] += item_data(type)["cost"]
	elif production[team].has(cat) and (type == "" or production[team][cat]["type"] == type):
		credits[team] += item_data(production[team][cat]["type"])["cost"]
		production[team].erase(cat)
		_next_job(team, cat)
	else:
		return
	notify(team, "Produção cancelada")


## Passa o próximo da fila para a produção.
func _next_job(team: int, cat: String) -> void:
	var q := queued(team, cat)
	if not q.is_empty() and not production[team].has(cat):
		production[team][cat] = {"type": q.pop_front(), "progress": 0.0, "done": false}


func _process(delta: float) -> void:
	if game_over or map == null or Net.is_client():
		return
	for team in team_count:
		var mult := 0.5 if low_power(team) else 1.0
		for cat in production[team].keys():
			var job: Dictionary = production[team][cat]
			if job["done"]:
				continue
			var producer := producer_for(team, cat)
			if producer == null:
				continue # produção pausada sem o prédio produtor
			job["progress"] += delta / float(item_data(job["type"])["time"]) * mult
			if job["progress"] >= 1.0:
				job["progress"] = 1.0
				if cat == "building":
					job["done"] = true
					notify(team, "Construção pronta: clique no botão e posicione no mapa")
				else:
					var pos := producer.position if cat == "air" else producer.exit_position()
					var u := spawn_unit(job["type"], team, pos)
					if producer.has_rally:
						u.command_move(producer.rally)   # coletor: o ponto vira o campo de trabalho
					production[team].erase(cat)
					_next_job(team, cat)


# ---------------------------------------------------------------- criação

func spawn_unit(type: String, team: int, pos: Vector2) -> Unit:
	var u: Unit
	if UNITS[type].get("harvester", false):
		u = Harvester.new()
	else:
		u = Unit.new()
	u.setup(type, team)
	u.position = pos
	world.add_child(u)
	entities.append(u)
	set_net_id(u, _next_id)
	return u


## Com `animate`, o prédio sobe do chão e só funciona quando termina (ver Building).
func spawn_building(type: String, team: int, cell: Vector2i, animate := false) -> Building:
	var b := Building.new()
	b.setup(type, team, cell)
	world.add_child(b)
	entities.append(b)
	set_net_id(b, _next_id)
	map.set_cells_blocked(b.cell, b.size, true)
	for e in entities:
		if e is Unit:
			e.repath()
	if animate:
		b.start_construction()
	else:
		b.finish_construction()
	return b


func can_place(type: String, team: int, cell: Vector2i) -> bool:
	var size: Vector2i = BUILDINGS[type]["size"]
	for x in size.x:
		for y in size.y:
			if not map.is_buildable(cell + Vector2i(x, y)):
				return false
	var rect := Rect2(Vector2(cell) * TILE, Vector2(size) * TILE).grow(4.0)
	var area := Rect2i(cell, size)
	var near_base := false
	for e in entities:
		if e is Unit and not e.flying and rect.has_point(e.position):
			return false
		if e is Building and e.team == team and Rect2i(e.cell, e.size).grow(4).intersects(area):
			near_base = true
	return near_base


func place_building(type: String, team: int, cell: Vector2i) -> bool:
	if Net.is_client():
		if not can_place(type, team, cell):
			return false
		Net.order("place", [type, cell])
		return true
	var job: Dictionary = production[team].get("building", {})
	if job.is_empty() or not job["done"] or job["type"] != type:
		return false
	if not can_place(type, team, cell):
		return false
	spawn_building(type, team, cell, true)
	production[team].erase("building")
	return true


func remove_entity(e) -> void:
	entities.erase(e)
	_ids.erase(e.net_id)
	if game_over or not (e is Building) or Net.is_client():
		return # no convidado quem decide o fim da partida é o anfitrião
	if not mission.is_empty():
		return # na campanha quem decide vitória e derrota são os objetivos (Mission)
	var team: int = e.team
	if building_count(team) == 0:
		game_over = true
		game_ended.emit(team != local_team)
		Net.send_game_over(team)


## Alerta de base: intervalo mínimo entre alertas (s) e a posição do último prédio atacado
## (a tecla Espaço leva a câmera até lá).
const BASE_ALERT_COOLDOWN := 12.0
var last_alert_pos := Vector2(-1, -1)
var _base_alert_t := -100.0


## Chamado pelo prédio do jogador local quando a vida dele cai.
func building_attacked(b) -> void:
	last_alert_pos = b.position
	var now := Time.get_ticks_msec() / 1000.0
	if now - _base_alert_t < BASE_ALERT_COOLDOWN:
		return
	_base_alert_t = now
	message.emit("ALERTA: %s sob ataque!  (Espaço: ir até lá)" % item_name(b.type, b.team))
	base_alert.emit(b)


## Mensagem para o dono do time: aparece aqui se for o jogador local; no multiplayer, o
## anfitrião repassa as do time do convidado.
func notify(team: int, text: String) -> void:
	if team == local_team:
		message.emit(text)
	elif Net.is_host():
		Net.send_message(text)


## Liga/desliga o conserto de um prédio (o convidado pede ao anfitrião).
func request_repair(b: Building, on: bool) -> void:
	if Net.is_client():
		Net.order("repair", [b.net_id, on])
	else:
		b.set_repairing(on)


func set_net_id(e, id: int) -> void:
	_ids.erase(e.net_id)
	e.net_id = id
	_ids[id] = e
	_next_id = maxi(_next_id, id + 1)


func by_id(id: int):
	var e = _ids.get(id)
	return e if is_instance_valid(e) and not e.dead else null


## Índice compacto de cada tipo de unidade/prédio (igual nos dois computadores).
func type_index(type: String) -> int:
	if _types.is_empty():
		_types = UNITS.keys() + BUILDINGS.keys()
		_types.sort()
	return _types.find(type)


func type_name(i: int) -> String:
	type_index("")
	return _types[i] if i >= 0 and i < _types.size() else ""


func spawn_explosion(pos: Vector2, size: float, height := 0.0, color := Color(1.0, 0.55, 0.2)) -> void:
	if world == null:
		return
	var fx := Explosion.new()
	fx.position = to3d(pos, height)
	fx.size = size
	fx.color = color
	fx.visible = fog == null or fog.is_visible_at(pos)  # não revela combates na névoa
	world.add_child(fx)
