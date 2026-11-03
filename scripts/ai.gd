class_name EnemyAI
extends Node
## IA dos inimigos: mantém coletores, produz tropas, ataca em ondas cada vez maiores,
## reconstrói e conserta a base e a defende quando atacada. Uma instância por time inimigo.
## Spec: design/quick-specs/ia-inimiga-terceiro-time-2026-11-03.md

const PLAYER := 0
## Pesos na lista da facção: fuzileiro, submetralhadora, metralhadora, antitanque, atirador
const INF_WEIGHTS: Array = GameData.AI_WEIGHTS["infantry"]
## coletor (só pela regra da economia), batedor, tanque, pesado
const VEH_WEIGHTS: Array = GameData.AI_WEIGHTS["vehicles"]
## caça, nave pesada
const AIR_WEIGHTS: Array = GameData.AI_WEIGHTS["air"]
## Prédio atingido há menos que isto (ms) dispara a defesa
const HIT_RECENT_MS := 3000
## Busca de célula livre para reconstruir: raio máximo (células) em volta da original
const REBUILD_SEARCH := 6

## Time controlado por esta IA (1 ou 2)
var team := 1
## Parâmetros do nível (GameData.AI_DIFFICULTY)
var diff: Dictionary = GameData.AI_DIFFICULTY["medio"]
var think := 3.0
var wave_size := 8
var wave_timer := 180.0
var first_wave_sent := false
## Campanha: centro da base inimiga (alvo das ondas = prédio do jogador mais perto dele)
## e se a IA produz unidades (false = só ataca com o que já tem)
var home := Vector2(-1, -1)
var produce := true
## Base a reconstruir: [[tipo, célula]]. Vazia até remember_base() (escaramuça: aos
## AI_SKIRMISH_LAYOUT_AT s).
var layout: Array = []
var _layout_set := false
var _elapsed := 0.0
## Unidades já mandadas numa onda (não voltam para defender)
var _in_wave := {}
## Defesa: unidades chamadas e há quanto tempo a base está sem inimigos por perto
var _defenders: Array = []
var _calm := 0.0
## Célula onde o prédio em construção vai ser posto
var _rebuild_cell := Vector2i(-1, -1)


## Escolhe o nível de dificuldade (chave de GameData.AI_DIFFICULTY).
func set_difficulty(key: String) -> void:
	diff = GameData.AI_DIFFICULTY.get(key, GameData.AI_DIFFICULTY["medio"])
	Game.income_mult[team] = float(diff["income_mult"])


## Grava os prédios atuais como a base a reconstruir.
func remember_base() -> void:
	layout = []
	for e in Game.entities:
		if e is Building and e.team == team and not e.dead and e.type != "cy":
			layout.append([e.type, e.cell])
	_layout_set = true


func _base_pos() -> Vector2:
	if home.x >= 0.0:
		return home
	return Vector2(Map.fit(GameData.ENEMY_BASE, GameData.ENEMY_CORNER)) * Game.TILE


func _process(delta: float) -> void:
	if Game.game_over:
		return
	wave_timer -= delta
	_elapsed += delta
	if not _layout_set and _elapsed >= GameData.AI_SKIRMISH_LAYOUT_AT:
		remember_base()
	if diff["defend"]:
		_update_calm(delta)
	think -= delta
	if think > 0.0:
		return
	think = float(diff["think"])

	var fac := Game.faction(team)
	var harvesters := 0
	var army: Array = []
	var at_home: Array = []
	for e in Game.entities:
		if e.team == team and e is Unit and not e.dead:
			if e is Harvester:
				harvesters += 1
			else:
				army.append(e)
				if not _in_wave.has(e):
					at_home.append(e)

	if diff["rebuild"] and produce:
		_rebuild()
	if float(diff["repair_below"]) > 0.0:
		_repair()
	if diff["defend"]:
		_defend(at_home)

	var queue: Dictionary = Game.production[team] if produce else {"infantry": 1, "vehicle": 1, "air": 1}
	# Economia primeiro
	if harvesters < 2 and not queue.has("vehicle"):
		Game.start_production(team, fac["harvester"])
	# Exército: não acumula muito além do tamanho da próxima onda
	var army_full := army.size() >= wave_size + 4
	if not queue.has("infantry") and not army_full:
		Game.start_production(team, fac["infantry"][_pick(INF_WEIGHTS)])
	if not queue.has("vehicle") and harvesters >= 1 and not army_full:
		Game.start_production(team, fac["vehicles"][_pick(VEH_WEIGHTS)])
	if not queue.has("air") and harvesters >= 1 and not army_full:
		Game.start_production(team, fac["air"][_pick(AIR_WEIGHTS)])

	# Ataque: a primeira onda só sai pelo tempo, dando ao jogador tempo de montar a base.
	# Depois, ataca quando o exército em casa fica grande o bastante (ou depois de um tempo).
	var free: Array = at_home.filter(func(u): return not _defenders.has(u))
	var ready := first_wave_sent and free.size() >= wave_size
	if ready or (wave_timer <= 0.0 and free.size() >= 3):
		var goal = _player_target()
		if goal != null:
			for u in free.slice(0, wave_size):
				u.command_attack_move(goal.position)
				_in_wave[u] = true
			first_wave_sent = true
			wave_size = mini(wave_size + int(diff["wave_growth"]), int(diff["wave_max"]))
			wave_timer = float(diff["wave_interval"])
	for u in _in_wave.keys():
		if not is_instance_valid(u) or u.dead:
			_in_wave.erase(u)


func _player_target():
	var base := _base_pos()
	var best = null
	var best_d := INF
	for e in Game.entities:
		if e.team == PLAYER and e is Building:
			var d: float = base.distance_to(e.position)
			if d < best_d:
				best_d = d
				best = e
	return best


# ---------------------------------------------------------------- reconstrução

## Repõe um prédio da base gravada por vez, na ordem de GameData.BUILD_ORDER. Sem o centro
## de comando (produtor de prédios) a IA não constrói.
func _rebuild() -> void:
	if layout.is_empty():
		return
	var job: Dictionary = Game.production[team].get("building", {})
	if not job.is_empty():
		if job["done"]:
			_place(job["type"])
		return
	if Game.producer_for(team, "building") == null:
		return
	var missing := _missing()
	if missing.is_empty():
		return
	var type: String = missing[0]
	if Game.credits[team] < float(Game.item_data(type)["cost"]):
		return
	if Game.start_production(team, type):
		_rebuild_cell = missing[1]


## Primeiro prédio da base gravada que falta: [tipo, célula] ou [].
func _missing() -> Array:
	var have := {}
	for e in Game.entities:
		if e is Building and e.team == team and not e.dead:
			have[e.type] = int(have.get(e.type, 0)) + 1
	var want := {}
	var cells := {}
	for entry in layout:
		want[entry[0]] = int(want.get(entry[0], 0)) + 1
		if not cells.has(entry[0]):
			cells[entry[0]] = []
		cells[entry[0]].append(entry[1])
	var order: Array = GameData.BUILD_ORDER.duplicate()
	for t in want:
		if not order.has(t):
			order.append(t)
	for t in order:
		if int(have.get(t, 0)) < int(want.get(t, 0)):
			return [t, _free_layout_cell(t, cells[t])]
	return []


## Célula gravada de `type` sem prédio em cima (a primeira, se todas estiverem ocupadas).
func _free_layout_cell(type: String, cells: Array) -> Vector2i:
	for c in cells:
		var taken := false
		for e in Game.entities:
			if e is Building and e.team == team and e.type == type and e.cell == c:
				taken = true
				break
		if not taken:
			return c
	return cells[0]


## Posiciona o prédio pronto na célula gravada ou na livre mais próxima; se não couber em
## lugar nenhum, cancela e recebe o dinheiro de volta.
func _place(type: String) -> void:
	var origin := _rebuild_cell
	if origin.x < 0:
		origin = Vector2i(_base_pos() / Game.TILE)
	for r in REBUILD_SEARCH + 1:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := origin + Vector2i(dx, dy)
				if Game.can_place(type, team, c) and Game.place_building(type, team, c):
					_rebuild_cell = Vector2i(-1, -1)
					return
	Game.cancel_production(team, "building")
	_rebuild_cell = Vector2i(-1, -1)


func _repair() -> void:
	var below := float(diff["repair_below"])
	for e in Game.entities:
		if not (e is Building) or e.team != team or e.dead or not e.built or e.repairing:
			continue
		if e.hp < e.max_hp * below and Game.credits[team] > float(diff["repair_reserve"]):
			Game.request_repair(e, true)


# ---------------------------------------------------------------- defesa

## Inimigo mais perto da base dentro do raio de defesa, ou null.
func _intruder():
	var base := _base_pos()
	var radius := float(diff["defend_radius"]) * Game.TILE
	var best = null
	var best_d := radius
	for e in Game.entities:
		if e.dead or not Game.are_enemies(e.team, team):
			continue
		var d: float = base.distance_to(e.position)
		if d < best_d:
			best_d = d
			best = e
	return best


func _update_calm(delta: float) -> void:
	if _defenders.is_empty():
		return
	_calm = 0.0 if _intruder() != null else _calm + delta
	if _calm >= GameData.AI_DEFEND_CALM:
		for u in _defenders:
			if is_instance_valid(u) and not u.dead:
				u.command_move(_base_pos())
		_defenders = []
		_calm = 0.0


## Prédio atingido há pouco: chama as unidades em casa perto da base até o atacante.
func _defend(at_home: Array) -> void:
	_defenders = _defenders.filter(func(u): return is_instance_valid(u) and not u.dead)
	var now := Time.get_ticks_msec()
	var hit := false
	for e in Game.entities:
		if e is Building and e.team == team and not e.dead and now - e.hit_at < HIT_RECENT_MS:
			hit = true
			break
	if not hit:
		return
	var foe = _intruder()
	if foe == null:
		return
	var base := _base_pos()
	var radius := float(diff["defend_radius"]) * Game.TILE
	for u in at_home:
		if base.distance_to(u.position) <= radius:
			u.command_attack_move(foe.position)
			if not _defenders.has(u):
				_defenders.append(u)
	_calm = 0.0


func _pick(weights: Array) -> int:
	var total := 0
	for w in weights:
		total += w
	var r := randi_range(0, total - 1)
	for i in weights.size():
		r -= weights[i]
		if r < 0:
			return i
	return 0
