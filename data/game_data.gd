class_name GameData
extends RefCounted
## CONTEÚDO DO JOGO: raças, unidades, prédios e regras de balanceamento.
##
## É o arquivo principal para criar um jogo novo com o kit. O motor (scripts/) lê tudo daqui
## por meio do autoload Game (Game.UNITS, Game.FACTIONS...). Convenções importantes:
##  - id de unidade = "<raça>_<função>" (ex.: hum_tank). A função define a população
##    (POP_COST) e o arquivo do modelo é models/<id>.glb.
##  - id de prédio genérico (power, refinery...) e modelo models/<prédio>_<raça>.glb.
##  - Cada raça tem as listas "infantry", "vehicles" e "air" na ordem dos botões do HUD; a IA
##    usa as mesmas posições com os pesos de AI_WEIGHTS.
##  - Tipos de prédio com papel fixo no motor: "cy" (centro, produz construções), "power"
##    (energia e população), "refinery" (recebe o recurso; vem com um coletor), produtores
##    com "produces" = infantry / vehicle / air, e qualquer prédio com "weapon" vira torre.
## Veja docs/MECANICAS.md para o que cada campo faz.

## Identificador do jogo na rede (salas do multiplayer). Jogos diferentes feitos com o kit
## precisam de identificadores diferentes para não se encontrarem no mesmo servidor de salas.
const NET_GAME_ID := "cronicasextincao"

const START_CREDITS := 5000.0
## Altura de voo das unidades aéreas (unidades do mundo; 1 = 1 célula)
const AIR_HEIGHT := 1.35

## Multiplicador de dano: tipo de arma -> tipo de blindagem.
const ARMOR_MULT := {
	"rifle": {"light": 1.0, "medium": 0.4, "heavy": 0.1, "building": 0.25},
	"smg": {"light": 1.2, "medium": 0.3, "heavy": 0.05, "building": 0.2},
	"mg": {"light": 1.1, "medium": 0.45, "heavy": 0.1, "building": 0.25},
	"sniper": {"light": 2.0, "medium": 0.2, "heavy": 0.05, "building": 0.1},
	"at": {"light": 0.3, "medium": 1.1, "heavy": 1.0, "building": 0.7},
	"cannon": {"light": 0.6, "medium": 1.0, "heavy": 1.0, "building": 0.9},
	"missile": {"light": 1.0, "medium": 1.1, "heavy": 0.6, "building": 0.4},
}
## Armas que disparam projéteis visíveis (o dano chega quando o projétil acerta)
const PROJECTILE_WEAPONS := ["at", "cannon", "missile"]

const FACTIONS := {
	"hum": {
		"name": "Império da Cinza", "army": "Facção Humana", "color": Color(0.78, 0.12, 0.08),
		"shot": Color(1.0, 0.62, 0.25),
		"desc": "Fé, disciplina e aço contra a extinção.\nInfantaria resistente, tanques pesados e artilharia.",
		"infantry": ["hum_soldado", "hum_fuzileiro", "hum_engenheiro", "hum_medico", "hum_comando"],
		"vehicles": ["hum_coletor", "hum_transporte", "hum_tanque", "hum_artilharia"],
		"air": ["hum_caca", "hum_nave", "hum_cruzador"],
		"harvester": "hum_coletor", "starter_tank": "hum_tanque",
		"buildings": {
			"cy": "Base Principal", "power": "Usina de Energia", "refinery": "Refinaria",
			"barracks": "Alojamento", "factory": "Mecânica", "starport": "Hangar",
			"turret": "Torre de Defesa", "medic": "Hospital de Campanha",
		},
	},
	"rob": {
		"name": "Legião Sintética", "army": "Facção Robótica", "color": Color(1.0, 0.5, 0.08),
		"shot": Color(1.0, 0.6, 0.15),
		"desc": "Máquinas caras, lentas de produzir e muito resistentes.\nAndadores Aniquilador e o Cruzador Sintético.",
		"infantry": ["rob_rifle", "rob_smg", "rob_at", "rob_mg", "rob_sniper"],
		"vehicles": ["rob_harvester", "rob_scout", "rob_tank", "rob_heavy"],
		"air": ["rob_fighter", "rob_colosso", "rob_gunship"],
		"harvester": "rob_harvester", "starter_tank": "rob_tank",
		"buildings": {
			"cy": "Núcleo da Legião", "power": "Núcleo de Energia", "refinery": "Processador de Minério",
			"barracks": "Montadora", "factory": "Forja de Andadores",
			"starport": "Plataforma Aérea", "turret": "Torre de Raios",
			"medic": "Doca de Reparo",
		},
	},
	"ins": {
		"name": "Enxame Abissal", "army": "Facção Insetoide", "color": Color(0.62, 1.0, 0.12),
		"organic": true,   # materiais com textura de carapaça em vez de linhas de painel
		"shot": Color(0.7, 1.0, 0.2),
		"desc": "Baratos, rápidos e numerosos.\nCarapaça quitinosa, ácido e esporos de cura.",
		"infantry": ["ins_rifle", "ins_smg", "ins_sniper", "ins_mg", "ins_at"],
		"vehicles": ["ins_harvester", "ins_scout", "ins_tank", "ins_heavy"],
		"air": ["ins_fighter", "ins_nucleo", "ins_gunship"],
		"harvester": "ins_harvester", "starter_tank": "ins_tank",
		"buildings": {
			"cy": "Colmeia-Mãe", "power": "Nódulo Vital", "refinery": "Digestor de Minério",
			"barracks": "Incubadora", "factory": "Casulo Profundo", "starport": "Ninho Aéreo",
			"turret": "Espinho Ácido", "medic": "Poço de Regeneração",
		},
	},
}

## Arma: "air" = pode atirar em naves; "ground" = false para naves que só atacam outras naves.
## "heal" numa unidade = suporte: {range (px), rate (fração da vida/s), targets "bio" ou "mech"}.
## "transport" = leva unidades: {capacity (vagas de população), carries ["inf", "veh"], max_pop}.
const UNITS := {
	# ---- Império da Cinza: infantaria resistente, blindados pesados
	"hum_soldado": {
		"name": "Soldado", "short": "Soldado", "kind": "inf", "category": "infantry", "pop": 1,
		"cost": 100, "time": 3.0, "requires": [], "hp": 60, "speed": 40.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Infantaria de linha com fuzil laser. A espinha dorsal do Império.",
		"weapon": {"damage": 11, "range": 120.0, "cooldown": 1.1, "type": "rifle"},
	},
	"hum_fuzileiro": {
		"name": "Fuzileiro Pesado", "short": "Fuzileiro", "kind": "inf", "category": "infantry", "pop": 2,
		"cost": 260, "time": 5.0, "requires": [], "hp": 110, "speed": 30.0, "radius": 7.0, "sight": 6,
		"armor": "medium", "desc": "Suporte de fogo: metralhadora rotativa contra infantaria e NAVES.",
		"weapon": {"damage": 5, "range": 145.0, "cooldown": 0.18, "type": "mg", "air": true},
	},
	"hum_engenheiro": {
		"name": "Engenheiro", "short": "Engenheiro", "kind": "inf", "category": "infantry", "pop": 1,
		"cost": 200, "time": 4.0, "requires": [], "hp": 55, "speed": 38.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Conserta veículos, naves e prédios em volta. Maçarico corta blindagem de perto.",
		"weapon": {"damage": 22, "range": 60.0, "cooldown": 1.6, "type": "at"},
		"heal": {"range": 110.0, "rate": 0.025, "targets": "mech"},
	},
	"hum_medico": {
		"name": "Médico de Campanha", "short": "Médico", "kind": "inf", "category": "infantry", "pop": 1,
		"cost": 220, "time": 4.0, "requires": [], "hp": 55, "speed": 40.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Cura os soldados em volta durante o combate. Pistola de defesa.",
		"weapon": {"damage": 6, "range": 90.0, "cooldown": 1.2, "type": "rifle"},
		"heal": {"range": 110.0, "rate": 0.04, "targets": "bio"},
	},
	"hum_comando": {
		"name": "Comando de Elite", "short": "Comando", "kind": "inf", "category": "infantry", "pop": 1,
		"cost": 400, "time": 6.0, "requires": ["refinery"], "hp": 45, "speed": 42.0, "radius": 6.0,
		"sight": 9, "armor": "light", "desc": "Infiltração e precisão: fuzil de longuíssimo alcance.",
		"weapon": {"damage": 55, "range": 230.0, "cooldown": 3.0, "type": "sniper"},
	},
	"hum_coletor": {
		"name": "Coletor de Recursos", "short": "Coletor", "kind": "veh", "category": "vehicle", "pop": 2,
		"cost": 900, "time": 9.0, "requires": ["refinery"], "hp": 520, "speed": 42.0, "radius": 13.0,
		"sight": 3, "armor": "medium", "harvester": true,
		"desc": "Caminhão de seis rodas com broca: extrai minério e leva à Refinaria.", "weapon": {},
	},
	"hum_transporte": {
		"name": "Transporte Blindado", "short": "Transporte", "kind": "veh", "category": "vehicle", "pop": 2,
		"cost": 500, "time": 6.5, "requires": [], "hp": 280, "speed": 68.0, "radius": 11.0, "sight": 7,
		"armor": "medium", "desc": "Leva 6 soldados com segurança ao campo de batalha. Torre de metralhadora (atinge naves).",
		"weapon": {"damage": 6, "range": 130.0, "cooldown": 0.25, "type": "mg", "air": true},
		"transport": {"capacity": 6, "carries": ["inf"]},
	},
	"hum_tanque": {
		"name": "Tanque de Batalha", "short": "Tanque", "kind": "veh", "category": "vehicle", "pop": 3,
		"cost": 900, "time": 10.0, "requires": [], "hp": 460, "speed": 48.0, "radius": 13.0, "sight": 6,
		"armor": "heavy", "desc": "Canhão de alto calibre: rompe defesas e destrói estruturas.",
		"weapon": {"damage": 40, "range": 155.0, "cooldown": 1.8, "type": "cannon"},
	},
	"hum_artilharia": {
		"name": "Artilharia Móvel", "short": "Artilharia", "kind": "veh", "category": "vehicle", "pop": 4,
		"cost": 1400, "time": 14.0, "requires": ["refinery"], "hp": 380, "speed": 36.0, "radius": 14.0,
		"sight": 6, "armor": "medium", "desc": "Salva de mísseis de longo alcance contra estruturas e tropas.",
		"weapon": {"damage": 70, "range": 260.0, "cooldown": 4.0, "type": "missile"},
	},
	"hum_caca": {
		"name": "Caça Interceptor", "short": "Caça", "kind": "air", "category": "air", "pop": 2,
		"cost": 700, "time": 8.0, "requires": [], "hp": 170, "speed": 110.0, "radius": 11.0, "sight": 7,
		"armor": "light", "desc": "Superioridade aérea: mísseis contra naves e alvos no solo.",
		"weapon": {"damage": 18, "range": 140.0, "cooldown": 1.0, "type": "missile", "air": true},
	},
	"hum_nave": {
		"name": "Nave de Transporte", "short": "Nave Transp.", "kind": "air", "category": "air", "pop": 3,
		"cost": 900, "time": 10.0, "requires": [], "hp": 420, "speed": 70.0, "radius": 15.0, "sight": 6,
		"armor": "heavy", "desc": "Robusta e blindada: leva 10 vagas de tropas e veículos leves (até Transporte).",
		"weapon": {"damage": 5, "range": 120.0, "cooldown": 0.3, "type": "mg"},
		"transport": {"capacity": 10, "carries": ["inf", "veh"], "max_pop": 2},
	},
	"hum_cruzador": {
		"name": "Cruzador de Batalha", "short": "Cruzador", "kind": "air", "category": "air", "pop": 5,
		"cost": 2000, "time": 18.0, "requires": ["refinery"], "hp": 900, "speed": 40.0, "radius": 20.0,
		"sight": 8, "armor": "heavy", "desc": "Nave capital: baterias pesadas contra o solo e grande resistência.",
		"weapon": {"damage": 55, "range": 170.0, "cooldown": 2.0, "type": "cannon"},
	},
	# ---- Legião Sintética: caro, lento de produzir, resistente
	"rob_rifle": {
		"name": "Rastejador", "short": "Rastejador", "kind": "inf", "category": "infantry",
		"cost": 120, "time": 3.5, "requires": [], "hp": 60, "speed": 52.0, "radius": 6.0, "sight": 8,
		"armor": "light", "desc": "Reconhecimento: leve, rápido e de visão longa.",
		"weapon": {"damage": 10, "range": 120.0, "cooldown": 1.1, "type": "rifle"},
	},
	"rob_smg": {
		"name": "Ceifador", "short": "Ceifador", "kind": "inf", "category": "infantry",
		"cost": 170, "time": 4.5, "requires": [], "hp": 80, "speed": 42.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Assalto: canhão rápido para pressão contínua.",
		"weapon": {"damage": 7, "range": 85.0, "cooldown": 0.3, "type": "smg"},
	},
	"rob_at": {
		"name": "Arquiteto", "short": "Arquiteto", "kind": "inf", "category": "infantry", "pop": 1,
		"cost": 220, "time": 5.0, "requires": [], "hp": 90, "speed": 32.0, "radius": 7.0, "sight": 5,
		"armor": "medium", "desc": "Suporte: conserta máquinas e estruturas da Legião. Garra de corte.",
		"weapon": {"damage": 24, "range": 60.0, "cooldown": 1.8, "type": "at"},
		"heal": {"range": 110.0, "rate": 0.03, "targets": "mech"},
	},
	"rob_mg": {
		"name": "Bastião", "short": "Bastião", "kind": "inf", "category": "infantry", "pop": 2,
		"cost": 300, "time": 6.0, "requires": [], "hp": 140, "speed": 28.0, "radius": 8.0, "sight": 6,
		"armor": "medium", "desc": "Linha de frente: alta resistência e canhão rápido (atinge naves).",
		"weapon": {"damage": 6, "range": 145.0, "cooldown": 0.22, "type": "mg", "air": true},
	},
	"rob_sniper": {
		"name": "Vigia", "short": "Vigia", "kind": "inf", "category": "infantry",
		"cost": 420, "time": 6.5, "requires": ["refinery"], "hp": 50, "speed": 40.0, "radius": 6.0,
		"sight": 10, "armor": "light", "desc": "Drone de sensores com disparo de alta precisão.",
		"weapon": {"damage": 55, "range": 230.0, "cooldown": 3.2, "type": "sniper"},
	},
	"rob_harvester": {
		"name": "Extrator", "short": "Extrator", "kind": "veh", "category": "vehicle",
		"cost": 1000, "time": 10.0, "requires": ["refinery"], "hp": 560, "speed": 44.0, "radius": 12.0,
		"sight": 3, "armor": "medium", "harvester": true, "hover": true,
		"desc": "Plataforma flutuante que extrai minério.", "weapon": {},
	},
	"rob_scout": {
		"name": "Vetor", "short": "Vetor", "kind": "veh", "category": "vehicle",
		"cost": 560, "time": 7.0, "requires": [], "hp": 320, "speed": 60.0, "radius": 12.0, "sight": 7,
		"armor": "medium", "desc": "Caminhante de transporte: leva 6 unidades de infantaria. Torre antiaérea.",
		"weapon": {"damage": 7, "range": 135.0, "cooldown": 0.25, "type": "mg", "air": true},
		"transport": {"capacity": 6, "carries": ["inf"]},
	},
	"rob_tank": {
		"name": "Aniquilador", "short": "Aniquilador", "kind": "veh", "category": "vehicle",
		"cost": 1000, "time": 11.0, "requires": [], "hp": 520, "speed": 46.0, "radius": 13.0, "sight": 6,
		"armor": "heavy", "desc": "Tanque de assalto andador com canhão de alto calibre.",
		"weapon": {"damage": 42, "range": 155.0, "cooldown": 1.8, "type": "cannon"},
	},
	"rob_heavy": {
		"name": "Devastador", "short": "Devastador", "kind": "veh", "category": "vehicle",
		"cost": 1500, "time": 15.0, "requires": ["refinery"], "hp": 450, "speed": 34.0, "radius": 15.0,
		"sight": 7, "armor": "medium", "desc": "Artilharia móvel: salva de mísseis em área.",
		"weapon": {"damage": 72, "range": 260.0, "cooldown": 4.0, "type": "missile"},
	},
	"rob_fighter": {
		"name": "Vespa", "short": "Vespa", "kind": "air", "category": "air",
		"cost": 800, "time": 9.0, "requires": [], "hp": 200, "speed": 105.0, "radius": 11.0, "sight": 7,
		"armor": "light", "desc": "Caça interceptor: patrulha e ataques rápidos.",
		"weapon": {"damage": 20, "range": 145.0, "cooldown": 1.1, "type": "missile", "air": true},
	},
	"rob_colosso": {
		"name": "Colosso", "short": "Colosso", "kind": "air", "category": "air", "pop": 3,
		"cost": 1000, "time": 11.0, "requires": [], "hp": 520, "speed": 60.0, "radius": 17.0, "sight": 6,
		"armor": "heavy", "desc": "Nave de transporte de grande capacidade: 12 vagas de tropas e veículos (até Vetor).",
		"weapon": {},
		"transport": {"capacity": 12, "carries": ["inf", "veh"], "max_pop": 2},
	},
	"rob_gunship": {
		"name": "Cruzador Sintético", "short": "Cruzador", "kind": "air", "category": "air",
		"cost": 2100, "time": 19.0, "requires": ["refinery"], "hp": 1000, "speed": 36.0, "radius": 20.0,
		"sight": 8, "armor": "heavy", "desc": "Nave de comando colossal com armamento integrado (só solo).",
		"weapon": {"damage": 60, "range": 170.0, "cooldown": 2.2, "type": "cannon"},
	},
	# ---- Enxame Abissal: barato, rápido e frágil
	"ins_rifle": {
		"name": "Rasgador", "short": "Rasgador", "kind": "inf", "category": "infantry",
		"cost": 80, "time": 2.4, "requires": [], "hp": 45, "speed": 56.0, "radius": 6.0, "sight": 7,
		"armor": "light", "desc": "Batedor: leve e rápido, vê o inimigo e ataca de oportunidade.",
		"weapon": {"damage": 9, "range": 100.0, "cooldown": 0.9, "type": "rifle"},
	},
	"ins_smg": {
		"name": "Assimilador", "short": "Assimilador", "kind": "inf", "category": "infantry",
		"cost": 110, "time": 2.8, "requires": [], "hp": 62, "speed": 52.0, "radius": 6.0, "sight": 5,
		"armor": "light", "desc": "Predador ágil: corpo a corpo veloz e pressão constante.",
		"weapon": {"damage": 8, "range": 45.0, "cooldown": 0.35, "type": "smg"},
	},
	"ins_sniper": {
		"name": "Espinhador", "short": "Espinhador", "kind": "inf", "category": "infantry",
		"cost": 200, "time": 3.8, "requires": [], "hp": 50, "speed": 40.0, "radius": 6.0, "sight": 7,
		"armor": "light", "desc": "Espinhos biológicos de longo alcance.",
		"weapon": {"damage": 30, "range": 190.0, "cooldown": 2.2, "type": "sniper"},
	},
	"ins_mg": {
		"name": "Guardião", "short": "Guardião", "kind": "inf", "category": "infantry", "pop": 2,
		"cost": 240, "time": 4.5, "requires": [], "hp": 130, "speed": 34.0, "radius": 8.0, "sight": 6,
		"armor": "medium", "desc": "Robusto, segura a linha de frente. Cospe ácido (atinge naves).",
		"weapon": {"damage": 5, "range": 135.0, "cooldown": 0.22, "type": "mg", "air": true},
	},
	"ins_at": {
		"name": "Infestador", "short": "Infestador", "kind": "inf", "category": "infantry",
		"cost": 260, "time": 4.5, "requires": ["refinery"], "hp": 60, "speed": 40.0, "radius": 6.0,
		"sight": 5, "armor": "light", "desc": "Parasitas que corroem blindados e estruturas.",
		"weapon": {"damage": 40, "range": 120.0, "cooldown": 2.2, "type": "at"},
	},
	"ins_harvester": {
		"name": "Larva Coletora", "short": "Larva", "kind": "veh", "category": "vehicle",
		"cost": 800, "time": 8.0, "requires": ["refinery"], "hp": 380, "speed": 48.0, "radius": 12.0,
		"sight": 3, "armor": "medium", "harvester": true,
		"desc": "Devora minério e o leva ao Digestor.", "weapon": {},
	},
	"ins_scout": {
		"name": "Nexo Vital", "short": "Nexo", "kind": "veh", "category": "vehicle",
		"cost": 600, "time": 7.0, "requires": [], "hp": 300, "speed": 58.0, "radius": 12.0, "sight": 7,
		"armor": "medium", "desc": "Suporte e cura: regenera as criaturas do Enxame em volta.",
		"weapon": {"damage": 6, "range": 120.0, "cooldown": 0.3, "type": "mg", "air": true},
		"heal": {"range": 140.0, "rate": 0.03, "targets": "bio"},
	},
	"ins_tank": {
		"name": "Demolidor", "short": "Demolidor", "kind": "veh", "category": "vehicle",
		"cost": 760, "time": 8.0, "requires": [], "hp": 420, "speed": 56.0, "radius": 14.0, "sight": 6,
		"armor": "heavy", "desc": "Criatura colossal de carapaça reforçada: rompe defesas.",
		"weapon": {"damage": 34, "range": 110.0, "cooldown": 1.4, "type": "cannon"},
	},
	"ins_heavy": {
		"name": "Artilheiro", "short": "Artilheiro", "kind": "veh", "category": "vehicle",
		"cost": 1300, "time": 13.0, "requires": ["refinery"], "hp": 420, "speed": 38.0, "radius": 15.0,
		"sight": 7, "armor": "medium", "desc": "Lança projéteis corrosivos a longa distância.",
		"weapon": {"damage": 64, "range": 250.0, "cooldown": 3.6, "type": "missile"},
	},
	"ins_fighter": {
		"name": "Vespário", "short": "Vespário", "kind": "air", "category": "air",
		"cost": 600, "time": 7.0, "requires": [], "hp": 130, "speed": 120.0, "radius": 11.0, "sight": 7,
		"armor": "light", "desc": "Predador aéreo veloz: controla o céu e caça unidades leves.",
		"weapon": {"damage": 16, "range": 130.0, "cooldown": 0.9, "type": "missile", "air": true},
	},
	"ins_nucleo": {
		"name": "Núcleo Aéreo", "short": "Núcleo", "kind": "air", "category": "air", "pop": 3,
		"cost": 900, "time": 10.0, "requires": [], "hp": 300, "speed": 70.0, "radius": 16.0, "sight": 7,
		"armor": "medium", "desc": "Organismo voador de suporte: regenera as criaturas do Enxame com esporos.",
		"weapon": {"damage": 6, "range": 110.0, "cooldown": 0.6, "type": "mg"},
		"heal": {"range": 160.0, "rate": 0.035, "targets": "bio"},
	},
	"ins_gunship": {
		"name": "Bombardeiro", "short": "Bombardeiro", "kind": "air", "category": "air",
		"cost": 1450, "time": 14.0, "requires": ["refinery"], "hp": 600, "speed": 50.0, "radius": 18.0,
		"sight": 7, "armor": "medium", "desc": "Lança cargas biológicas corrosivas (só solo).",
		"weapon": {"damage": 52, "range": 150.0, "cooldown": 2.0, "type": "cannon"},
	},
}

## Os nomes dos prédios mudam por raça (FACTIONS[...]["buildings"]); estes são os genéricos.
const BUILDINGS := {
	# "cost" do centro de comando só entra no cálculo do conserto (ele não é construível)
	"cy": {
		"name": "Centro de Comando", "category": "", "cost": 3000, "time": 0.0, "requires": [],
		"hp": 1500, "size": Vector2i(3, 3), "power": 10, "sight": 6, "produces": "building",
		"desc": "Centro de comando: constrói os outros prédios.",
	},
	"power": {
		"name": "Gerador", "category": "building", "cost": 300, "time": 6.0, "requires": [],
		"hp": 400, "size": Vector2i(2, 2), "power": 100, "sight": 4, "produces": "",
		"desc": "Gera energia para a base.",
	},
	"refinery": {
		"name": "Refinaria", "category": "building", "cost": 1000, "time": 10.0, "requires": ["power"],
		"hp": 900, "size": Vector2i(3, 2), "power": -40, "sight": 4, "produces": "",
		"desc": "Transforma minério em recursos. Vem com um coletor.",
	},
	"barracks": {
		"name": "Quartel", "category": "building", "cost": 300, "time": 6.0, "requires": ["power"],
		"hp": 600, "size": Vector2i(2, 2), "power": -20, "sight": 4, "produces": "infantry",
		"desc": "Treina infantaria.",
	},
	"factory": {
		"name": "Fábrica", "category": "building", "cost": 1200, "time": 12.0,
		"requires": ["refinery"], "hp": 1000, "size": Vector2i(3, 3), "power": -30, "sight": 4,
		"produces": "vehicle", "desc": "Monta coletores, batedores e tanques.",
	},
	"starport": {
		"name": "Hangar", "category": "building", "cost": 1500, "time": 13.0,
		"requires": ["factory"], "hp": 1000, "size": Vector2i(3, 3), "power": -40, "sight": 5,
		"produces": "air", "desc": "Constrói caças e naves de ataque.",
	},
	"turret": {
		"name": "Torre", "category": "building", "cost": 600, "time": 8.0, "requires": ["barracks"],
		"hp": 500, "size": Vector2i(1, 1), "power": -20, "sight": 6, "produces": "",
		"desc": "Defesa contra solo e naves. Precisa de energia.",
		"weapon": {"damage": 28, "range": 175.0, "cooldown": 1.3, "type": "cannon", "air": true},
	},
	## Cura: "range" em pixels de chão, "rate" = fração da vida máxima recuperada por segundo.
	## Qualquer prédio com a chave "heal" cura as unidades do time em volta.
	"medic": {
		"name": "Estação de Cura", "category": "building", "cost": 700, "time": 9.0,
		"requires": ["barracks"], "hp": 500, "size": Vector2i(2, 2), "power": -25, "sight": 5,
		"produces": "", "heal": {"range": 160.0, "rate": 0.03},
		"desc": "Recupera a vida das suas unidades em volta (soldados, veículos e naves). Precisa de energia.",
	},
}

## Itens por categoria de unidade na produção (o ativo + a fila de espera)
const MAX_QUEUE := 5
## População: quanto cada unidade ocupa, pela função (o sufixo do id: hum_tank -> "tank").
const POP_COST := {"rifle": 1, "smg": 1, "mg": 1, "at": 1, "sniper": 1,
		"harvester": 2, "scout": 2, "fighter": 2, "tank": 3, "heavy": 4, "gunship": 4}
## Limite inicial, quanto cada gerador de energia pronto acrescenta, e o máximo absoluto
const POP_BASE := 30
const POP_PER_POWER := 20
const POP_MAX := 100
const BUILD_ORDER := ["power", "refinery", "barracks", "factory", "starport", "turret", "medic"]
const CATEGORY_NAMES := {"building": "construções", "infantry": "infantaria",
		"vehicle": "veículos", "air": "naves"}

## IA: pesos de escolha para cada posição das listas da raça (infantry / vehicles / air).
## Coletores (posição 0 de vehicles) são produzidos à parte, pela regra de economia.
const AI_WEIGHTS := {
	"infantry": [4, 3, 1, 2, 1],
	"vehicles": [0, 2, 3, 1],
	"air": [3, 0, 2],
}

## Velocidade do jogo (Engine.time_scale): normal e três níveis acima, de 25% em 25%.
## Só fora do multiplayer. Teclas + e − na partida, ou o botão ao lado do MENU.
const SPEED_STEPS := [1.0, 1.25, 1.5, 1.75]

## IA: níveis de dificuldade. A missão escolhe com "ai": {"difficulty": ...}; a escaramuça,
## pelo seletor do menu. first_wave e wave_size da missão têm prioridade sobre estes valores.
## Spec: design/quick-specs/ia-inimiga-terceiro-time-2026-11-03.md (ponto de partida, sem
## balanceamento validado).
##   think          intervalo entre decisões (s)
##   income_mult    multiplica o minério que os coletores da IA descarregam
##   wave_growth    quanto cada onda cresce · wave_max: onda máxima
##   wave_interval  tempo máximo entre ondas (s)
##   rebuild        reconstrói prédios destruídos · defend: defende a base
##   defend_radius  alcance da defesa (células)
##   repair_below   conserta prédios abaixo desta fração da vida (0 = nunca)
##   repair_reserve dinheiro mínimo mantido ao consertar
const AI_DIFFICULTY_ORDER := ["facil", "medio", "dificil"]
const AI_DIFFICULTY := {
	"facil": {"name": "Fácil", "think": 2.5, "income_mult": 0.8, "wave_growth": 1,
		"wave_max": 12, "wave_interval": 150.0, "rebuild": false, "defend": true,
		"defend_radius": 10, "repair_below": 0.0, "repair_reserve": 0.0},
	"medio": {"name": "Médio", "think": 1.5, "income_mult": 1.0, "wave_growth": 2,
		"wave_max": 16, "wave_interval": 120.0, "rebuild": true, "defend": true,
		"defend_radius": 14, "repair_below": 0.5, "repair_reserve": 800.0},
	"dificil": {"name": "Difícil", "think": 1.0, "income_mult": 1.25, "wave_growth": 3,
		"wave_max": 22, "wave_interval": 90.0, "rebuild": true, "defend": true,
		"defend_radius": 18, "repair_below": 0.7, "repair_reserve": 400.0},
}
## A IA da escaramuça grava a base que tiver depois deste tempo (s) como base a reconstruir.
const AI_SKIRMISH_LAYOUT_AT := 60.0
## Fim da defesa: segundos sem inimigos perto da base.
const AI_DEFEND_CALM := 10.0

## Tamanhos de mapa: escala sobre o mapa pequeno (64×48 células). A ordem é a dos botões.
const MAP_SIZES := {
	"small": {"name": "Pequeno", "scale": 1.0},
	"medium": {"name": "Médio", "scale": 1.35},
	"large": {"name": "Grande", "scale": 1.6},
}

## Layout do mapa, desenhado em células do mapa PEQUENO (64×48). Nos maiores, cada posição
## fica presa a um ponto de referência (anchor): (0, 0) = canto superior esquerdo,
## (1, 1) = inferior direito, (0.5, 0.5) = centro (ver Map.fit).
## O jogador / anfitrião fica no canto inferior esquerdo; o inimigo / convidado no superior direito.
const PLAYER_CORNER := Vector2(0, 1)
const ENEMY_CORNER := Vector2(1, 0)
## Centros das bases (área sem rochas ao redor)
const PLAYER_BASE := Vector2i(8, 38)
const ENEMY_BASE := Vector2i(55, 10)
## Início de cada lado: centro de comando, primeira célula da fila de soldados e o tanque
const PLAYER_START := {"cy": Vector2i(6, 37), "infantry": Vector2i(10, 35), "tank": Vector2i(11, 37)}
const ENEMY_START := {"cy": Vector2i(52, 6), "infantry": Vector2i(50, 11), "tank": Vector2i(51, 9)}
## Modo contra a IA: o inimigo começa com esta base pronta [tipo, célula] e estes soldados
## (infantry[i] da raça em cada célula), tudo preso ao canto do inimigo
const AI_BASE := [
	["cy", Vector2i(52, 6)], ["power", Vector2i(56, 6)], ["power", Vector2i(59, 6)],
	["barracks", Vector2i(56, 9)], ["refinery", Vector2i(52, 10)], ["factory", Vector2i(58, 11)],
	["turret", Vector2i(49, 14)], ["turret", Vector2i(54, 14)], ["starport", Vector2i(48, 6)],
	["medic", Vector2i(49, 10)],
]
const AI_START_UNITS := [Vector2i(52, 15), Vector2i(53, 15)]
## Campos de recurso: [centro, raio, anchor, tamanhos em que aparece ([] = todos)].
## Os mapas maiores ganham campos extras para a economia acompanhar a área.
const RESOURCE_FIELDS := [
	[Vector2i(18, 35), 3, PLAYER_CORNER, []],             # perto das bases
	[Vector2i(45, 15), 3, ENEMY_CORNER, []],
	[Vector2i(32, 24), 4, Vector2(0.5, 0.5), []],         # centro, mais rico
	[Vector2i(13, 12), 3, Vector2(0, 0), []],             # cantos
	[Vector2i(51, 36), 3, Vector2(1, 1), []],
	[Vector2i(32, 9), 3, Vector2(0.5, 0), ["medium", "large"]],    # meio de cima e de baixo
	[Vector2i(32, 39), 3, Vector2(0.5, 1), ["medium", "large"]],
	[Vector2i(10, 22), 3, Vector2(0, 0.5), ["large"]],              # laterais
	[Vector2i(54, 26), 3, Vector2(1, 0.5), ["large"]],
]
