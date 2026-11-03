# RTS Kit — mecânicas, multiplayer e como criar um jogo novo

Documento técnico do kit (Godot 4.7, GDScript). O kit é o motor do **Star-RTS**
separado do conteúdo: tudo o que muda de um jogo para outro fica em `data/` e nos modelos;
o resto (`scripts/`) é o motor e normalmente não precisa ser tocado.

## Sumário

1. [Criar um jogo novo (passo a passo)](#1-criar-um-jogo-novo)
2. [Estrutura do projeto](#2-estrutura-do-projeto)
3. [Conteúdo: `data/game_data.gd`](#3-conteúdo-datagame_datagd)
4. [Tema: `data/theme.gd`](#4-tema-datathemegd)
5. [Modelos 3D (Blender)](#5-modelos-3d-blender)
6. [Mecânicas](#6-mecânicas)
7. [Multiplayer](#7-multiplayer)
8. [Versão Web e publicação](#8-versão-web-e-publicação)
9. [Onde mexer para…](#9-onde-mexer-para)
10. [Testes automatizados](#10-testes-automatizados)

---

## 1. Criar um jogo novo

```
H:\Jogos\rts-kit\novo_jogo.bat medieval-rts "Reinos em Guerra"
```

Isso copia o kit para `H:\Jogos\medieval-rts` (sem `.godot`, `web`, `.git`), troca o nome do
projeto e o título do jogo. O jogo novo começa idêntico ao Star-RTS (exemplo) e você o
transforma em quatro passos:

1. **Raças, unidades, prédios e regras** → `data/game_data.gd` (seção 3).
2. **Nome, textos, cores, terreno, cenário, menu** → `data/theme.gd` (seção 4).
3. **Modelos 3D** → um arquivo Python por raça em `art_src/blender/` e `gerar_modelos.bat`
   (seção 5). Os nomes dos modelos seguem os ids de `game_data.gd`.
4. **Testar** → `jogar.bat` (ou F5 no editor). Para a Web: seção 8.

Regras de ouro: **ids de unidade são `<raça>_<função>`** (ex.: `kni_archer`); **cada raça
tem os mesmos tipos de prédio** (cy, power, refinery, barracks, factory, starport, turret ou
os que você definir); **um modelo por unidade e um por prédio×raça**.

## 2. Estrutura do projeto

```
data/
  game_data.gd      CONTEÚDO: raças, unidades, prédios, armas, população, IA, mapa
  theme.gd          TEMA: título, textos, cores, terreno, cenário, menu
scripts/            MOTOR (autoloads Game e Net + cenas)
  game_state.gd     autoload "Game": estado, produção, fila, população, energia, criação
  net.gd            autoload "Net": sala, WebRTC, ordens, snapshots
  mqtt_signal.gd    cliente MQTT mínimo (sinalização do multiplayer)
  main.gd           cena da partida: mundo, luz, bases, seleção, ordens, posicionamento
  entity.gd         base de unidade/prédio: vida, arma, tiro, dano, modelo
  unit.gd           movimento (A* / voo), combate, marcha procedural, veículos
  harvester.gd      coletor (máquina de estados)
  building.gd       prédio: construção animada, energia, torre, conserto, cura, reciclar, reunião, fogo
  projectile.gd     projéteis visíveis (dano no impacto)
  map.gd            grade (64×48, 86×65 ou 102×77), terreno procedural, recurso, pathfinding, cenário
  fog.gd            névoa de guerra (textura global fog_tex)
  models.gd         carrega .glb, converte materiais (shader PBR + névoa + cor do time)
  ai.gd             IA do modo contra o computador
  hud.gd, info_panel.gd, minimap.gd, overlay.gd, pause_menu.gd, menu.gd   interface
  fx3d.gd, explosion.gd, wreck.gd, tracers.gd, ambience.gd, camera.gd     efeitos/câmera
art_src/blender/    geradores de modelos (Python para Blender) + folha de contato
models/             .glb gerados (o jogo carrega por nome)
tools/              serve_web.js (servidor local), cache_bust.js (publicação Web)
```

Coordenadas: a lógica roda no **plano do chão em pixels** (`TILE = 32`, `Vector2`); no 3D,
1 célula = 1 unidade (`Game.to3d` / `Game.to_ground`). Tamanho do mapa em `Map.W` / `Map.H`,
definido por `Map.configure(escala)` antes de gerar o mapa.

## 3. Conteúdo: `data/game_data.gd`

`class_name GameData`. O motor expõe tudo como `Game.FACTIONS`, `Game.UNITS` etc.

### Raças (`FACTIONS`)

```gdscript
"hum": {
    "name": "Humanos", "army": "Legião Solar", "color": Color(0.3, 0.6, 1.0),
    "shot": Color(0.45, 0.8, 1.0),          # cor dos tiros e rastros de motor
    "organic": false,                        # true = materiais de carapaça (insetos)
    "desc": "texto do card no menu",
    "infantry": [5 ids],  "vehicles": [ids, coletor primeiro],  "air": [ids],
    "harvester": "hum_harvester", "starter_tank": "hum_tank",
    "buildings": {"cy": "Centro de Comando", "power": "Reator de Fusão", ...},  # nomes por raça
}
```

- As listas definem os **botões do HUD** (na ordem) e as posições usadas pela IA.
- A partida começa com o centro (`cy`), 3× `infantry[0]` e 1× `starter_tank`.
- `color` é a cor do time (anéis, minimapa, peças `team` dos modelos).

### Unidades (`UNITS`)

| Campo | Significado |
|---|---|
| `name`, `short`, `desc` | nome completo, nome curto do botão, descrição (dica) |
| `kind` | `inf` (infantaria), `veh` (veículo), `air` (voa) |
| `category` | `infantry`, `vehicle` ou `air` — qual prédio produz |
| `cost`, `time` | preço e segundos de produção |
| `requires` | prédios necessários (ex.: `["refinery"]`) |
| `hp`, `armor` | vida e blindagem: `light`, `medium`, `heavy` |
| `speed`, `radius`, `sight` | px/s, raio de colisão (px), visão (células) |
| `hover` | flutua (balanço e inclinação maiores) |
| `harvester` | é coletor (usa `harvester.gd`, desarmado) |
| `pop` | (opcional) população; senão vem de `POP_COST` pela função |
| `weapon` | `{damage, range (px), cooldown (s), type, air?, ground?}` |

Arma: `air: true` atinge unidades aéreas; `ground: false` não atinge o solo. Tipos com
projétil visível estão em `PROJECTILE_WEAPONS` (o resto é raio instantâneo).

### Dano (`ARMOR_MULT`)

`dano final = damage × ARMOR_MULT[tipo da arma][blindagem do alvo]`. Prédios usam a
blindagem `building`. Para um tipo de arma novo, adicione uma linha aqui, um nome em
`theme.WEAPON_NAMES` e (se for projétil) inclua em `PROJECTILE_WEAPONS` e em
`projectile.gd › SPEEDS`.

### Prédios (`BUILDINGS`)

| Campo | Significado |
|---|---|
| `category` | `building` para construíveis (`""` = só no início, ex.: `cy`) |
| `size` | `Vector2i` em células |
| `power` | + gera / − consome energia |
| `produces` | `building`, `infantry`, `vehicle`, `air` ou `""` |
| `weapon` | se tiver, vira torre (só atira com energia suficiente) |
| `cost` | preço; também é a base do conserto e da reciclagem (80%) |
| `heal` | `{"range": px, "rate": fração/s}`: cura as unidades do time em volta (precisa de energia) |

Papéis fixos no motor: `cy` (centro, produz construções), `power` (energia + população),
`refinery` (recebe o recurso e vem com um coletor). `BUILD_ORDER` é a ordem dos botões.

### Regras

- `START_CREDITS`, `AIR_HEIGHT`, `MAX_QUEUE` (fila por categoria).
- População: `POP_COST` (por função = sufixo do id), `POP_BASE`, `POP_PER_POWER`, `POP_MAX`.
- IA: `AI_WEIGHTS` (pesos por posição das listas da raça).
### Mapa e tamanhos

- `MAP_SIZES`: tamanhos oferecidos (Pequeno 1,0 = 64×48, Médio 1,35 = 86×65, Grande 1,6 =
  102×77). Escolha na tela de raça (individual) e na sala de espera (anfitrião escolhe; o
  convidado vê; mudar desmarca o PRONTO). O zoom máximo da câmera acompanha o tamanho.
- O **layout é desenhado em células do mapa pequeno** e cada posição tem um ponto de
  referência (anchor) que a prende ao canto ou ao centro nos mapas maiores (`Map.fit`):
  `PLAYER_CORNER` (0, 1) e `ENEMY_CORNER` (1, 0) para as bases.
- `PLAYER_BASE` / `ENEMY_BASE` (centro sem rochas), `PLAYER_START` / `ENEMY_START`
  (centro de comando, fila de soldados, tanque), `AI_BASE` e `AI_START_UNITS` (base pronta
  do inimigo contra a IA).
- `RESOURCE_FIELDS`: `[centro, raio, anchor, tamanhos]` — `[]` aparece em todos; os maiores
  ganham campos extras. Rochas: 26 aglomerados no pequeno, proporcional à área nos outros.

## 4. Tema: `data/theme.gd`

`class_name GameTheme`: `TITLE`, `SUBTITLE`, `CURRENCY` ("Créditos"), `RESOURCE`
("cristais"), `RESOURCE_MODEL` (modelo nos campos), cores da interface (`ACCENT`, `TEXT`,
`BORDER`, `PANEL`), cores do terreno (`GROUND_DARK/MID/LIGHT`, `RESOURCE_GROUND`,
`RESOURCE_GLOW`), minimapa, `PROPS` (cenário nas células bloqueadas, com pesos),
`WEAPON_NAMES`, `MENU_SHOWCASE` (3 modelos da tela de título) e `MENU_FLYBY` (modelos que
cruzam o fundo do menu).

O fundo do menu (céu estrelado e planeta) e a luz da partida estão em `menu.gd` e
`main.gd › _setup_lights` — troque se o jogo não for espacial.

## 5. Modelos 3D (Blender)

- `art_src/blender/core.py`: primitivas (caixa chanfrada, cilindro, esfera, toro, tubo,
  asa, prisma), grupos, localizadores e exportação glTF.
- `palettes.py`: paleta PBR por raça (papel → cor, metálico, rugosidade, emissão).
- **Um arquivo por raça** (`human.py`, `robot.py`, `insect.py`) com `all_models()`, e
  `props.py` para o cenário. O gerador acha sozinho todo `.py` com `all_models()`.
- `gerar_modelos.bat [filtro]` gera os `.glb` e reimporta no Godot;
  `preview.py` faz uma folha de contato PNG.

Convenções que o motor entende:

| No Blender | No jogo |
|---|---|
| X = frente, Z = cima, 1 unidade = 1 célula | o modelo anda para +X |
| grupo `turret` / `gun` | torre que mira (veículo / prédio) |
| `leg_l`/`leg_r` + `knee_l`/`knee_r` | pernas de bípede com joelho |
| `limb_<l\|r><i>` | patas independentes (marcha em tripé) |
| `wheel_<l\|r><i>` | rodas (índice 0 esterça, salvo esteiras) |
| `treadf_*` / `treadb_*` | sapatas de esteira (espaçamento `TREAD = 0.07`) |
| `seg_<i>` | segmentos que ondulam (larvas, cobras) |
| `wing_*` | asas que batem |
| `spin` | gira sem parar |
| `torso` | tronco (balança na marcha, coice ao atirar) |
| `loc_muzzle_*`, `loc_engine_*`, `loc_smoke_*` | boca da arma, motor (rastro), fumaça |
| material `team` | recebe a cor do time |
| `glow`, `engine`, `glass`, `crystal` | brilham (emissão) |
| `hull`, `dark`, `metal`, `accent` | linhas de painel (ou carapaça se a raça for `organic`) |
| `chitin`, `flesh`, `bone`, `rock`, `plant` | textura orgânica |

Nomes de arquivo: unidade `models/<id>.glb`, prédio `models/<tipo>_<raça>.glb`, cenário
como estiver em `theme.PROPS`.

## 6. Mecânicas

**Economia.** Coletores extraem 60/s até 500, voltam à refinaria e descarregam 250/s em
dinheiro. Cada coletor lembra o **campo de trabalho** (`Harvester.field`, definido ao mandá-lo
para um campo) e volta para perto dele; sem recurso ali, procura perto de si e depois no mapa
todo — funciona a qualquer distância da refinaria. Os campos (até 350 por célula) encolhem
visualmente e crescem de novo devagar.

**Energia.** Soma do `power` dos prédios prontos. Consumo maior que geração: produção pela
metade e torres desligadas; aviso piscando sobre os prédios.

**Produção e fila.** Uma produção ativa por categoria; unidades extras entram numa fila
(até `MAX_QUEUE`, pagas na hora). Botão direito cancela o último daquele tipo e devolve o
dinheiro. Prédios: um por vez; quando pronto, clicar no botão e posicionar perto da base
(até 4 células de um prédio seu). O prédio é "impresso" de baixo para cima em até 2,5 s.

**População.** Unidades vivas + produção ativa + fila. Limite `POP_BASE` + `POP_PER_POWER`
por gerador pronto, até `POP_MAX`. Sem espaço a produção é recusada sem cobrar.

**Combate.** Unidades atacam o inimigo mais próximo dentro da visão (respeitando
`air`/`ground` da arma), perseguem enquanto guardam posição e voltam depois. Ordens:
mover, atacar alvo, andar atacando (Ctrl + botão direito). Veículos com torre giram a
torre antes de atirar. Dano = arma × `ARMOR_MULT`.

**Comandos e posturas.** Barra no painel de seleção (`info_panel.gd › UNIT_COMMANDS`) e
teclas: Mover (M), Atacar andando (Ctrl + direito), Patrulha (Q), Parar (X), Defender (G),
Agressivo (H). M/Q esperam um clique no destino (`main.order_mode`; botão direito cancela).
Patrulha vai e volta entre a posição atual e o ponto atacando o que aparecer
(`Unit.command_patrol`). Postura `Unit.stance`: `aggressive` (padrão, persegue o que vê e
volta) ou `defend` (não sai do lugar; só atira no que estiver ao alcance da arma).

**Grupos.** Ctrl + 1..9 grava a seleção (`main.groups`), o número seleciona, duas vezes em
400 ms centraliza a câmera.

**Ponto de reunião.** Com prédio produtor (`produces` infantry/vehicle/air) selecionado e
nenhuma unidade, o botão direito marca `Building.rally` (bandeira visível com o prédio
selecionado). Unidades novas recebem `command_move(rally)` — um coletor adota o campo.

**Reciclar.** Botão no painel ou Delete, confirmado com um segundo pedido em 3 s:
devolve `RECYCLE_REFUND` (80%) do `cost` e o prédio some com faíscas, sem explosão. O `cy`
não pode ser reciclado.

**Alerta de base.** Prédio do jogador perdendo vida grava `hit_at` (pisca vermelho no
minimapa por 4 s) e chama `Game.building_attacked`: mensagem "ALERTA: … sob ataque!" no
máximo a cada `BASE_ALERT_COOLDOWN` (12 s) e `Game.last_alert_pos` (Espaço leva a câmera).
O kit **não tem sons**: cada jogo liga os seus nos sinais/pontos de entrada — por exemplo
`Game.base_alert.connect(func(b): tocar_alerta())` para o alerta de base.

**Cura.** Prédio com `heal` (ex.: `medic`) cura a cada 1 s as unidades do time no alcance
(soldados, veículos e naves) em `rate` × vida máxima; sem energia não cura e várias
estações não somam (`Unit.healed_at`). Um anel verde mostra o alcance ao posicionar e com o
prédio selecionado.

**Unidades de suporte.** Uma unidade com `"heal": {range, rate, targets}` cura a cada 1 s os
aliados em volta (`unit.gd › _heal_nearby`): `targets` "bio" = soldados (e qualquer unidade de
raça `organic`), "mech" = veículos, naves e prédios prontos (conserto). Ex.: Médico e Engenheiro.

**Transporte.** Unidade com `"transport": {capacity, carries ["inf", "veh"], max_pop}` leva outras:
botão direito num transporte aliado com unidades selecionadas = embarcar (`Unit.command_board`;
andam até ele e entram). Os passageiros saem de `Game.entities` e da árvore, mas continuam
contando na população. Desembarcar: botão no painel ou tecla U (`Unit.unload`, saem em anel em
células livres). Transporte destruído mata quem está dentro. Ordens de rede `board`/`unload`.

**Sprites pré-renderizados.** Se existe `assets/sprites/<modelo>.png/.json`, a entidade é
desenhada por `SpriteBody` (Sprite3D voltado para a câmera, pés no ponto do chão) e o modelo 3D
fica carregado mas invisível (bocas de arma, chaminés, caixa). A câmera é ortográfica, fixa a
30° (`SpriteBody.ELEVATION`), sem girar — o mesmo ângulo dos renders. Animações da folha:
`idle`, `walk`, `attack`, `death`, `death_fwd`, `death_blast` (escolhida pela arma e pela
direção do tiro, em `Corpse`); `<modelo>_turret` é a torre que gira à parte. Pipeline:
`art_src/blender/render_sprites.py` (qualquer .glb; 16 direções, caminhada das patas, asas,
desgaste procedural nos materiais) ou `infantaria.py` (soldados detalhados), depois
`art_src/gen/pixelize.gd`; tudo junto: `sh art_src/gen/sprites_todos.sh <filtros>`.

**Campanha.** `data/campaign.gd` descreve as missões (mapa desenhado, bases e unidades
iniciais, objetivos, eventos com hora marcada, ondas, textos). `scripts/mission.gd` monta a
missão, mostra briefing, objetivos e transmissões e decide vitória/derrota (o fim padrão
"sem prédios" fica desligado em `Game.remove_entity`). Progresso em `user://campanha.cfg`.
Objetivos suportados: `build`, `army`, `destroy_tag`, `destroy_all`, `survive`.

**Naves.** Voam em linha reta a `AIR_HEIGHT`, ignoram terreno e prédios, inclinam nas
curvas e caem girando ao ser abatidas. Só armas com `air: true` as atingem.

**Conserto.** Pedido prédio a prédio (botão no painel ou K): 5% da vida por segundo, custo
por ponto = `cost / 2 / hp`. Para se o dinheiro acabar; nunca é automático.

**Névoa de guerra.** Preto onde nunca foi visto, penumbra onde já foi explorado. Inimigos
só aparecem na área visível (prédios ficam visíveis depois de explorados).

**IA.** Mantém 2 coletores, produz infantaria/veículos/naves pelos pesos, e ataca em ondas
(a primeira aos 3 min; depois a cada exército completo ou 2 min).

**Fim de jogo.** Perde quem fica sem prédios.

**Animação.** Marcha procedural dirigida pela distância andada (pés não deslizam), rodas,
esteiras, larvas, carroceria que empina e inclina, asas e anéis giratórios — tudo pelos
nomes dos grupos do modelo (seção 5).

## 7. Multiplayer

1 contra 1 pela internet, **anfitrião autoritativo** (`scripts/net.gd`).

**Conexão.** Quem cria a sala gera um código de 5 letras. O aperto de mão do WebRTC
(oferta, resposta, candidatos ICE) passa por um broker MQTT público
(`wss://broker.emqx.io:8084/mqtt`, tópicos `starrts/v1/<código>/...`); conectados, o broker
é fechado e o jogo flui P2P (`WebRTCMultiplayerPeer`, anfitrião = peer 1). STUN do Google.
Limites: redes muito restritas podem exigir TURN; o broker público vê os endereços no
aperto de mão. O prefixo dos tópicos vem de `GameData.NET_GAME_ID` (o `novo_jogo.bat` usa o
nome da pasta), para salas de jogos diferentes não se cruzarem.

**Sala de espera.** O anfitrião guarda `Net.room` (`[{name, race, ready}, {...}]`) e o
repassa ao convidado. Raça do outro bloqueada, chat, PRONTO dos dois → contagem de 3 s →
`_start` (semente do mapa, raças, nomes). Cada lado avisa quando carregou (`_loaded_in`);
o jogo fica congelado até os dois terminarem (`_go`).

**Partida.** O anfitrião roda tudo, como no modo contra a IA. O convidado:
- envia **ordens** com `Net.order(tipo, args)`: `move`, `attack_move`, `attack`, `produce`,
  `cancel`, `place`, `repair`, `patrol`, `stop`, `stance`, `rally`, `recycle`. Os pontos de
  entrada (`Game.start_production`, `place_building`, `request_repair`, `main._command`,
  `main.unit_order`, `main.recycle_selected`, `main._set_rally`) já desviam para a rede;
  reciclagem confirmada volta ao convidado por `Net.send_recycled`;
- recebe **snapshots** 15×/s (`_snap`, não confiável e ordenado): por entidade 12 floats
  (id, tipo, time, x, y, vida, direção, flags, extra, alvo, mira), mais dinheiro, produção e
  fila do convidado, e o recurso do mapa 1×/s. Aplica em **entidades-espelho** que só
  interpolam (`Unit._follow_net`) e mostram tiros (`mirror_fire`);
- nunca simula: guardas `Net.is_client()` em unit, building, harvester, map e entity.

**IDs e times.** Toda entidade tem `net_id` (`Game.by_id`). `Game.local_team` = 0 no
anfitrião, 1 no convidado; o HUD, a névoa e a seleção usam o time local. Mensagens para o
convidado vão por `Game.notify` → `Net.send_message`. Fim de partida leva o retrato final;
se alguém sai, o outro vence. No multiplayer a pausa não congela o jogo.

**Plataformas.** O botão aparece só na Web (o navegador traz WebRTC). No PC precisa da
extensão `webrtc-native` em `addons/` e o argumento `-- --mp-test` para testes.

**Custo de rede.** ~48 bytes por entidade por snapshot: 200 entidades ≈ 10 KB ≈ 1,2 Mbps
de upload do anfitrião. Acima de ~16 KB por snapshot o WebRTC fragmenta e perde mais
pacotes — por isso a população máxima de 100 por jogador.

## 8. Versão Web e publicação

- Renderizador: Forward+ no PC, **Compatibility** na Web (`rendering_method.web`).
  Não use `instance uniform` em shaders (estoura o limite do WebGL).
- Exportar: `Godot_console --headless --path . --export-release "Web" web/index.html`.
- `node tools/cache_bust.js` carimba uma versão nos arquivos (o GitHub Pages guarda por
  10 min e os navegadores usariam a cópia antiga).
- Testar: `node tools/serve_web.js 8060` e abrir `http://localhost:8060`.
- Publicar: conteúdo de `web/` numa branch `gh-pages` (GitHub Pages) ou num .zip no itch.io.
- Templates de exportação Web do Godot 4.7.2 em `%APPDATA%\Godot\export_templates\4.7.2.stable`.

## 9. Onde mexer para…

| Quero… | Onde |
|---|---|
| nova raça | `FACTIONS` + unidades em `UNITS` + nomes de prédios + `art_src/blender/<raça>.py` |
| nova unidade | `UNITS` + id numa lista da raça + modelo `<id>.glb` (+ peso em `AI_WEIGHTS`) |
| novo prédio produtor | `BUILDINGS` (com `produces`) + `BUILD_ORDER` + modelo por raça |
| novo tipo de arma | `ARMOR_MULT`, `theme.WEAPON_NAMES`, talvez `PROJECTILE_WEAPONS` + `SPEEDS` |
| balanceamento | `UNITS`, `BUILDINGS`, `ARMOR_MULT`, população, `START_CREDITS` |
| mapa e tamanhos | `MAP_SIZES`, bases, `*_START`, `AI_BASE`, `RESOURCE_FIELDS` (com anchor) |
| visual do chão | `theme.GROUND_*` e `map.gd › TERRAIN_SHADER` |
| luz e pós-processamento | `main.gd › _setup_lights`, `ambience.gd` |
| velocidade/regras da IA | `ai.gd` (`wave_timer`, `wave_size`) e `AI_WEIGHTS` |
| controles e câmera | `main.gd › _unhandled_input`, `camera.gd` |
| taxas de coleta | `harvester.gd` (`CAPACITY`, `HARVEST_RATE`, `UNLOAD_RATE`) |
| conserto | `building.gd › REPAIR_RATE`, `repair_cost_per_hp` |
| cura | `BUILDINGS[...]["heal"]`; tique em `building.gd › HEAL_TICK` |
| reciclagem | `building.gd › RECYCLE_REFUND`, `can_recycle` |
| alerta de base | `Game.BASE_ALERT_COOLDOWN`, sinal `Game.base_alert` (som do jogo) |
| comandos / teclas | `info_panel.gd › UNIT_COMMANDS`, `main.gd › _unhandled_input`, `hud.gd` (ajuda) |

## 10. Testes automatizados

Scripts `SceneTree` rodados com `Godot_console --path . -s teste.gd` (janela ou
`--headless`) permitem montar partidas, dar ordens e tirar prints. Cuidados:
- não use nomes de classe do projeto (`Unit`, `Building`) dentro do script de teste —
  use `root.get_node("Game")` e `e.has_method("command_move")`;
- para multiplayer, rode dois processos (anfitrião e convidado) numa cópia do projeto com
  a extensão `webrtc-native` e `-- --mp-test`, trocando o código da sala por um arquivo.
