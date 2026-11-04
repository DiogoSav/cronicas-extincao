# Especificação de UX — HUD da partida e Tela Inicial/Menu

Projeto: Crônicas da Extinção (Godot 4.7.2, GDScript) · Autor: ux-designer · Data: 2026-11-03 · Revisão 2 (após revisão de UX)
Referência escolhida: Command & Conquer / Red Alert (barra lateral metálica à direita, painéis chanfrados, cor da facção, legibilidade de console militar).
Status: PROPOSTA. Nada foi implementado.

## DECISÕES DO USUÁRIO (confirmadas, não reabrir)

1. **InfoPanel (painel de seleção)** fica colado à barra lateral, no canto inferior direito do CAMPO (ver 3.2, dimensões baseadas no `scripts/info_panel.gd` real).
2. **Fonte Rajdhani (SIL OFL), pesos Medium e Bold**, confirmada. Antes de adotar: teste de acentos (ç ã õ é ê í ó ú â, mais Ç Ã Õ É Ê) renderizado em 14, 18 e 28 lógicos; reprovando, vale o fallback (fonte padrão do Godot, ver 1.1).

## 0. Premissas e lacunas

- **Acessibilidade: nível "Básico" por SUPOSIÇÃO** (não há documento de requisitos): contraste de texto >= 4,5:1 (>= 3:1 para ícones/bordas), cor nunca é o único indicador, **fonte mínima 14 unidades lógicas em TODAS as resoluções**, teclado+mouse (gamepad fora de escopo), nada piscando acima de 3 Hz. Validar com o accessibility-specialist.
- Não existem player-journey nem `design/ux/hud.md`; esta spec é a fonte (depois migrar para `design/ux/hud.md`). Sem biblioteca de padrões: ver seção 7.
- Código lido: `hud.gd`, `mission.gd`, `menu.gd`, `info_panel.gd`, `main.gd`, `game_data.gd`, `theme.gd`, `project.godot`.

## 1. Fundamentos (HUD e menu)

### 1.1 Tipografia
- **Rajdhani** Bold (títulos, números) e Medium (corpo). Embutida em `assets/fonts/` com a licença OFL ao lado. **Fallback**: fonte padrão do Godot, rótulos de seção/botões em CAIXA ALTA, `outline_size` 2 preto, `FontVariation.spacing_glyph = 1`.
- Escala (unidades LÓGICAS; mínimo absoluto 14): título do jogo 96 (menu, tamanho atual) / 18 (cabeçalho do HUD) · cabeçalho de seção 15 Bold CAIXA ALTA · número de recurso 24 Bold · corpo/tooltip 15 · rótulo de botão 14 (botões de menu seguem 18–24) · mensagem de jogo 20 · cronômetro 28 Bold. Os `font_size` 13 hoje existentes em `info_panel.gd` sobem para 14.
- Cores de texto: `TEXT_HI #EFE8DC` sobre painel `#0E0C0C` (15:1), `TEXT_MID #B8B0A4` (8:1), `TEXT_DIM #7E766C` só decoração (4,6:1).

### 1.2 Molduras (sem arte externa)
- `StyleBoxFlat` base: bg `#14100F` (alpha 0,96), borda 2 na cor escura da facção, `shadow_size` 6. Helper `Frame.chamfered(size, cut=8)` gera `Image` 32x32 com 2 cantos opostos cortados + realce 1 px no topo → `StyleBoxTexture` NinePatch (`texture_margin` 10), cache por (facção, variante): 3 facções x 3 variantes = 9 texturas pequenas no `_ready`.
- 3 níveis: **N1** barra/painéis-mãe (borda 2, chanfro 8), **N2** caixas internas (minimapa, recursos; borda 1, chanfro 4, fundo `#0A0808`), **N3** botões. Cabeçalho de seção: faixa de 22 com gradiente facção→transparente. Rebites 3x3 nos cantos da barra (opcional).

### 1.3 Escala e âncoras (regra única)
Fato do projeto: `window/stretch/mode="canvas_items"`, `aspect="expand"`, base 1920x1080. O Godot já escala o canvas inteiro por `min(w/1920, h/1080)`. **Não existe `ui_scale`**: nada é multiplicado em código.

- **Todas as dimensões desta spec são unidades LÓGICAS.** A fonte mínima de 14 lógicos permanece 14 lógicos em qualquer resolução (o Godot a escala junto com o resto). Em 1024x768 o fator é 0,533 e 14 lógicos viram ~7,5 px físicos: isso é decisão de escopo, ver PREOCUPAÇÕES (resolução mínima suportada).
- **Barra lateral = 340 lógicos sempre**, âncora direita, altura total (`anchor_top=0, anchor_bottom=1`).
- Área lógica visível (aspect `expand`): **16:9 = 1920x1080 · 4:3 = 1920x1440 · 16:10 = 1920x1200 · 21:9 (3440x1440) = 2580x1080.** Largura lógica nunca < 1920, altura lógica nunca < 1080 (logo o layout de 1920x1080 é o piso).
- Nenhuma posição absoluta em 1080. Cada elemento escolhe uma âncora de canto/borda e usa offsets. Bug atual a eliminar: a linha de ajuda do HUD em `Vector2(16, 1080-30)` (y=1050 fixo) fica no meio da tela quando a altura lógica é 1440; vira dica ancorada ao rodapé da barra (3.6).
- "Centro do campo" = (largura lógica − 340) / 2, nunca o centro da tela.
- **4:3 (1920x1440): a área extra é VERTICAL (+360).** Regras: (a) barra lateral: cabeçalho, controles, minimapa e economia ficam ancorados ao TOPO com os mesmos tamanhos; rodapé (F) ancorado à BASE; a seção de produção (E) ocupa o espaço entre eles e é a única que estica (ganha folga, sem rolagem); (b) objetivos, cronômetro e mensagens ancorados ao topo do campo (mesmos offsets); (c) rádio e InfoPanel ancorados à base do campo; (d) menu: conteúdo permanece centralizado verticalmente (`PRESET_FULL_RECT` + `ALIGNMENT_CENTER` já faz isso), largura inalterada; vinheta ancorada às bordas, com altura em proporção (ver 4.2).
- **21:9 (2580x1080): a área extra é HORIZONTAL (+660)** e vai toda para o CAMPO (a barra continua 340). Regras: objetivos no canto superior esquerdo, cronômetro/mensagens no centro do campo (2240/2), rádio inferior esquerdo, InfoPanel inferior direito do campo, tudo por âncora (nada se afasta do seu canto). Menu: blocos centralizados na largura de 1920 lógicos (as laterais mostram só o fundo 3D); o fundo e a vinheta ocupam a tela toda.
- Aceitar valores fracionários de offset é proibido; use inteiros lógicos.

## 2. Tratamento por facção

Cada facção define um `UiSkin` (dicionário em `data/theme.gd`, cor lida de `game_data.gd`).

| Elemento | Império da Cinza | Legião Sintética | Enxame Abissal |
|---|---|---|---|
| Cor primária (`COR`) | `#C71F14` | `#FF8014` | `#9EFF1F` (só detalhes) |
| Cor escura (bordas) | `#5E1510` | `#7A3C08` | `#2E4A0A` + acento violeta `#7B4DB8` |
| Fundo de painel | `#14100F` aço quente | `#0F1114` aço frio | `#0D120B` quitina |
| Moldura | chanfro 8, rebites, listras diagonais no cabeçalho | chanfro 4, traços de circuito 1 px, LEDs | chanfro 8 + entalhe arredondado, borda dupla fina |
| Emblema (cabeçalho, 28) | cruz/asa "†" em `_draw` | engrenagem 8 dentes | hexágono/olho composto |

Regras: (a) cor nunca é o único portador de significado; (b) texto sobre `COR`: `TEXT_HI` com contorno; texto colorido de facção só >= 18; no Império títulos usam `#FF5A47` (5,1:1) e `#C71F14` fica para bordas/faixas; (c) o menu usa as três skins ao mesmo tempo (um cartão cada).

## 3. HUD da partida

### 3.1 Hierarquia
1. Alertas e mensagens do jogo. 2. Recursos/energia/população. 3. Minimapa. 4. Seleção (InfoPanel) e produção. 5. Objetivos e cronômetro. 6. Ajuda (sob demanda, F1).

### 3.2 Layout (1920x1080 lógicos; âncoras conforme 1.3)

Barra lateral: x 1580–1920, altura total, N1, margem interna 10.

| Bloco | Âncora / posição | Tamanho | Conteúdo |
|---|---|---|---|
| A. Cabeçalho | topo, y 0–64 | 340x64 | Emblema 40x40 + nome da facção (`army`, ex. Império da Cinza, 18 Bold) + subtítulo `name` 14 `TEXT_MID`. O título do jogo sai do HUD. |
| B. Controles | topo, y 64–96 | 2 botões 156x28 | `VEL 100%` (cicla; teclas `+`/`−`, já existentes) e `MENU  P` (abre pausa; `P` e `Esc` já abrem). |
| C. Minimapa | topo, y 100–330 | 320x230 | Moldura N2, proporção do mapa, retângulo da câmera. |
| D. Economia | topo, y 336–400 | 3 colunas 100x56 | Recursos (ícone + número 24 Bold), Energia (usada/produzida), População (usada/limite), rótulo 14. Energia insuficiente: número `#FFB020` + "!" + barra riscada. |
| E. Produção | entre D e F; y 408–1000 em 1080; estica em alturas maiores | 320 de largura | Seções e grade (3.3). Sem rolagem. |
| F. Rodapé | base, 62 de altura | 320x62 | Dica contextual (3.6) + "F1  Atalhos". |

- **Seções (nomes reais de `game_data.gd`):** CONSTRUÇÕES · INFANTARIA · VEÍCULOS · **NAVES**. Cabeçalho 24: ícone de categoria 16 (casa, soldado, roda, asa), texto 15 Bold CAIXA ALTA. Recolhível ao clicar (só visual).
- **InfoPanel (decisão confirmada).** Dimensionado pelo conteúdo real de `info_panel.gd`: `custom_minimum_size` 600x150, ícone 160x120, barra de vida 220, linha de arma com ~70 caracteres, barra de comandos com até 7 botões (Mover, Atacar, Patrulha, Parar, Defender, Agressivo, Desembarcar) e grade multi-seleção de 5 colunas x 96 px. Proposta: painel N1 **600 de largura**, âncora inferior-direita do campo, x 980–1580, **colado à barra (sem vão)**, altura = conteúdo: seleção única ~190, multi-seleção até ~340 (grade de 3 linhas; acima disso agrupa o excedente em "+N"). Mudanças pedidas: fontes 13→14; a barra de comandos vira `HFlowContainer` (quebra em 2 linhas em vez de estourar os 580 internos); atalho exibido em cada botão como hoje ("Mover (M)"). Oculto sem seleção. Sem colisão: o rádio ocupa x 20–740, o InfoPanel começa em 980 (vão 240).
- **Objetivos** (`mission.gd`): canto superior esquerdo, x 12–392 (380 de largura; hoje 430), cabeçalho "OBJETIVOS" 15 Bold + até 4 linhas 15, marcadores por forma (◻ pendente, ◼ concluído riscado, "!" falhou), altura máx 220, excedente em "+N", textos longos truncados em 2 linhas.
- **Rádio** (`_tx_panel`): inferior esquerdo, x 20–740 (720, como hoje), retrato 64x64 + emissor 15 Bold + texto 16. **Correção desta revisão:** o rádio hoje avança sozinho (~9 s por mensagem, fila); NÃO existe tecla "continuar", e **Espaço já é "ir ao último alerta"** (`main.gd`). Portanto não mostrar "[ESPAÇO] continuar"; mostrar a barrinha de tempo restante de 4 px sob o texto.
- **Fim de partida:** `end_label` centralizado no campo (offset_right = −340). Teclas existentes: R (reiniciar, só sem multiplayer), M (menu); mostrar as duas no texto.

### 3.3 Botões de produção — solução e conta de altura

**Decisão: 4 colunas de 74x68, com ícone + nome curto + custo, tudo >= 14.** (3 colunas de ~100x64 foram descartadas: o Império, a maior lista, precisaria de ~560 de grade + 4 cabeçalhos e estouraria a faixa útil de 592.)

- Largura: 4x74 + 3x5 = 311 <= 320 (centralizado). Conteúdo: ícone 36x30 (topo, centralizado) · nome curto `short` 14 Medium, centralizado, truncado com "…" · custo 14 Bold com mini-ícone de cristal. 4 + 30 + 17 + 17 = 68. O nome completo vai só no tooltip (nome, custo, tempo, requisito, `desc`).
- **Maior lista (Império, de `game_data.gd`):** BUILD_ORDER = 7 prédios (power, refinery, barracks, factory, starport, turret, medic) · infantry 5 (hum_soldado, fuzileiro, engenheiro, médico, comando) · vehicles 4 (coletor, transporte, tanque, artilharia) · air 3 (caça, nave, cruzador) = 19 botões.
- Linhas: CONSTRUÇÕES ceil(7/4)=2 · INFANTARIA ceil(5/4)=2 · VEÍCULOS 1 · NAVES 1 = **6 linhas x (68+5) = 438**. Quatro cabeçalhos x 28 = 112. **Total 550 <= 592** (faixa 408–1000). Sobram 42; sem rolagem. Em 1440 de altura a faixa tem 952 e fica com folga.
- Enxame e Legião: mesmas contagens de itens por seção (infantaria 5, veículos 4, naves 3; prédios podem diferir, confira o `BUILD_ORDER` por facção): nunca maiores que o Império. Se alguma facção tiver mais de 8 prédios, a seção CONSTRUÇÕES passa a 3 linhas (+73 = 623) e excede 592; nesse caso recolher a seção NAVES automaticamente: registrar como risco de conteúdo.
- Nomes `short` que podem truncar a 14: "Nave Transp.", "Bombardeiro", "Assimilador", "Engenheiro". Verificar com o teste de fonte; se truncar mal, usar `short` mais curto (campo já existe).

Estados (N3):

| Estado | Visual | Não-cor |
|---|---|---|
| Normal | fundo `#1B1614`, borda 2 `COR_ESCURA` | — |
| Hover | borda `COR` clara, +8% luminosidade, tooltip em 0,3 s | cursor mão |
| Sem dinheiro | ícone 60%, custo `#FF6B5A` + "!" , clique emite mensagem "Recursos insuficientes" (usar `GameTheme.CURRENCY`) | "!" + texto |
| Bloqueado por requisito | ícone cinza + cadeado 16, borda tracejada, tooltip "Requer: …" | cadeado + tracejado |
| Em produção | barra 6 px na base em `COR`, % no tooltip, sem pulso | barra |
| Fila (n) | selo 20x20 canto sup. direito com "x2"/"x3" 14 Bold; "x1" não aparece | numeral |
| Pronto (prédio a posicionar) | borda 2 branca + "PRONTO" 14 sobre o ícone | texto |
| Desativado (pausa/fim) | opacidade 50%, sem hover | — |

Interação inalterada: clique esquerdo `item_pressed(t)`, direito cancela/reduz fila.

### 3.4 Cronômetro enxuto
Painel N2 150x44, topo do campo (centro do campo, y 12), `[relógio] MM:SS` 28 Bold, sem repetir o texto do objetivo (o objetivo de tempo ganha o relógio e "(MM:SS)" na lista). < 60 s: texto `#FFB020` + "!" ; < 15 s: pulsa alpha 1,0↔0,6 a 1 Hz + "!". Oculto sem objetivo de tempo.

### 3.5 Mensagens do jogo
Faixa centralizada no campo, y 64 (abaixo do cronômetro y 12–56), largura máx 640, texto 20 com contorno 4, fundo `#000000A0` 30 de altura. Nunca em x < 400 (reservado a objetivos). Pilha de até 3 (passo 24), 4 s; alertas (ataque à base, energia baixa) com "!" e 6 s; repetida em < 3 s só reinicia o contador. Vira `VBoxContainer` ancorado. z-order: campo < HUD < objetivos < mensagens < rádio < modais.

### 3.6 Ajuda: atalhos (F1) e dica contextual
Remover a linha longa fixa de ajuda. Duas peças:
1. **Painel de atalhos modal** (F1 ou botão "?" na barra): 640x420 centrado no campo, 15, duas colunas, tecla em caixa 28x24. **Conferência com `scripts/main.gd` (teclas já em uso):** R (reiniciar, fim de partida), M (menu no fim de partida / modo Mover em jogo), Esc (cancela ordem → cancela construção → limpa seleção → senão abre pausa), P (pausa), `+`/`−` (velocidade), K (consertar), 1–9 (grupos; Ctrl+n define), Espaço (ir ao último alerta), Delete (reciclar), Q (patrulha), X (parar), G (defender), H (agressivo), U (desembarcar), F11 (tela cheia). **F1 está livre**: sem colisão. Conteúdo do painel tira a lista desta frase, sem inventar teclas. Colisões tratadas: (a) Espaço não pode ser "continuar" do rádio (3.2); (b) **Esc com o painel F1 aberto** deve fechá-lo e consumir o evento (`set_input_as_handled`) ANTES de `main.gd` cancelar seleção/abrir pausa; (c) F1 em partida multiplayer não pausa (a pausa não é alterada).
2. **Dica contextual** (bloco F, 320x62, 14, máx 2 linhas): muda com a seleção ("Botão direito: mover / atacar", "Ctrl + botão direito: andar atacando"); vazia = "F1  Atalhos".
Primeira partida: o painel abre uma vez (flag em `user://config`).

## 4. Menu / Tela inicial

**O fluxo e os controles atuais de `scripts/menu.gd` são mantidos.** O menu tem 5 páginas separadas (`_show_page`); esta seção só define o tratamento visual. Nenhum botão é inventado e nenhum é movido de página.

### 4.1 Elementos comuns a todas as páginas
- **Fundo:** vitrine 3D existente (planeta, naves), inalterada.
- **Vinheta:** gradiente escuro nas bordas, ancorado às bordas da tela (topo 140 e base 260 lógicos, alpha 0,7; laterais 120 em 21:9), `mouse_filter=IGNORE`, atrás das páginas e à frente do 3D. Garante contraste >= 4,5:1 do texto sobre o planeta.
- **Título:** `GameTheme.TITLE`, 96, nas cores atuais com contorno, repetido em todas as páginas como já faz `_title()`; subtítulo 24 `TEXT_MID` (texto atual de cada página: "escolha a sua raça", "campanha", "multiplayer · 1 contra 1 pela internet"; a sala usa o título "SALA XXXXX"). Filete horizontal sob o título (cosmético).
- **Botões:** `make_button` passa a usar o estilo N3 (chanfro 4, borda 2, hover claro) e foco visível: hoje `focus_mode = FOCUS_NONE`; mudar para `FOCUS_ALL` com anel pontilhado 2 branco, para atender "usável só com teclado" (Tab/Enter/setas). Esc volta à página principal (já existe), F11 tela cheia (já existe).
- Cada página é centralizada na vertical e limitada a 1920 de largura lógica (21:9: laterais só com fundo).

### 4.2 Página principal (`title_page`, `_menu_button`)
Conteúdo atual: faixa de ícones da vitrine (`MENU_SHOWCASE`, 256x192) + coluna de botões 360 de largura: `CAMPANHA`, `JOGAR CONTRA A IA`, `MULTIPLAYER  (1 × 1)` (só se `Net.available()`), `SAIR` (omitido no Web). Tratamento: botões 360x54, rótulo 24 Bold, o primeiro com foco inicial; `CAMPANHA` com faixa de acento (primário), os demais neutros; `SAIR` separado por 14 a mais, borda mais discreta. Rodapé: versão à direita, 14 `TEXT_MID`.

### 4.3 Página de escaramuça (`faction_page`, subtítulo "escolha a sua raça")
Conteúdo atual, mantido: 3 cartões de facção (cada um com `COMANDAR`) · linha **Inimigo** (Aleatório + as 3 `army`) · linha **Mapa** (Pequeno/Médio/Grande com dimensões, de `Game.MAP_SIZES`) · linha **Dificuldade** (Fácil/Médio/Difícil, de `GameData.AI_DIFFICULTY_ORDER`) · texto de ajuda de controles · `VOLTAR`. **Os botões CAMPANHA/ESCARAMUÇA/SAIR inventados na versão anterior são removidos desta página**; a navegação é só `VOLTAR` (e Esc).
- **Cartão (largura ~580, altura pelo conteúdo ~520):** nome da facção em `army` CAIXA ALTA 32 Bold cor da facção (como hoje; o `name` "Facção …" 14 `TEXT_MID` abaixo), três linhas do desfile de tropas (infantaria 110x82, veículos, naves 150x100; é o "modelo em vitrine"), `desc` de `game_data` 15–16 (texto existente, sem lemas novos), botão `COMANDAR` 54 de altura em largura total, faixa inferior na cor da facção. Moldura/emblema pelo `UiSkin` (seção 2). Largura total: 3x580 + 2x26 = 1792 <= 1920. Estados: normal / hover (borda clara) / foco de teclado (anel 2 branco) / pressionado.
- **Linhas de configuração** (rótulo + botões de alternância exclusivos, como hoje): Inimigo 4 botões 210x44; Mapa 3 botões 210x44; Dificuldade 3 botões 210x44; rótulo 20 `TEXT_MID` à esquerda; botão ativo = borda 3 `COR` neutra (acento do menu) + marca "●" além da cor. Agrupadas num painel N1 neutro 1250 de largura (3 linhas empilhadas, separação 10) sob os cartões. Os seletores "◂ valor ▸" da versão anterior NÃO são usados: ficam os botões de alternância atuais (menos mudança, todos os valores visíveis ao mesmo tempo).
- Ajuda de controles (texto atual, 2 linhas, 16 `TEXT_MID`) fica entre o painel de configuração e `VOLTAR`; no Web troca "bordas" por "setas" como já faz. `VOLTAR` 240x46 centralizado.
- Altura total aproximada em 1080: título 140 + cartões 520 + config 190 + ajuda 50 + voltar 46 + separações = ~1020: cabe, folga justa; se faltar, reduzir a altura da tropa (fileiras 82→70). Em 4:3 sobra espaço vertical, centralizado.

### 4.4 Página de campanha (`campaign_page`, `_build_campaign_page`)
Mantida: para cada facção em `CampaignData.CAMPAIGNS`: cabeçalho `NOME DA FACÇÃO — nome da campanha` (30, cor da facção clarificada), `desc` da campanha (18), lista de missões (largura 620) e `VOLTAR`. Tratamento: três blocos lado a lado seria mudança de fluxo, então **permanecem empilhados como hoje**; cada bloco recebe faixa lateral de 4 px na cor da facção. Botão de missão 620x46, rótulo "H03  ·  Título" 20, estados por TEXTO e ícone, não só cor: concluída "✓" no fim, bloqueada "(bloqueada)" + cadeado + botão `disabled` com opacidade 50%, não produzida "(em produção)" + relógio. A próxima missão liberada tem borda de acento (foco inicial do teclado). Risco de altura: 3 facções x (30 + 18 + 7 missões x 54) = ~1260 > 1080 com 7 missões cada: **resolver com `ScrollContainer` vertical** na lista de blocos (única página com rolagem; título e `VOLTAR` fixos), ou colapsar as facções que não têm missão liberada. Escolher na implementação; registrado em PREOCUPAÇÕES.

### 4.5 Página multiplayer (`mp_page`, `_build_mp_page`)
Mantida: linha "Seu nome" (rótulo 22 + `LineEdit` 320x50, máx 16) · linha de ações: `CRIAR SALA` 260x54 · "ou" · `LineEdit` CÓDIGO 170x54 (5 letras, maiúsculas automáticas, Enter entra) · `ENTRAR` 200x54 · rótulo de status 22 (cor de acento, altura 70) · `VOLTAR`. Tratamento: a linha de nome e a de ações dentro de um painel N1 neutro de 900 de largura; `LineEdit` com estilo N3 e borda de acento no foco; placeholder 14+ com contraste >= 4,5:1; status com ícone "!" quando for erro ("Digite o código de 5 letras da sala") para não depender de cor. Foco inicial: campo Nome.

### 4.6 Sala de espera (`room_page`, `_build_room_page`)
Mantida: título "SALA XXXXX" 44 + dica 18 · 2 cartões de jogador 430x120 (nome 28 "(você)", raça 20 na cor da facção, estado 20) · linha Mapa (3 botões; só anfitrião) ou texto "Mapa: … escolhido pelo anfitrião" · linha "Sua raça:" 3 botões 240x46 (o da raça do outro jogador fica desabilitado) · chat (log 900x170, campo + `ENVIAR` 140x40) · contagem regressiva 26 · `PRONTO` 260x56 (alternância) e `SAIR DA SALA` 260x56. Tratamento: cartões de jogador N1 com borda na cor da facção do jogador (já existe) e emblema da facção; estado "PRONTO ✓" em verde **com o ✓** (não só cor) e "ainda não está pronto" em `TEXT_MID`; contagem regressiva em 26 com ícone de relógio; chat com fundo `#050A12` D9, 18; `PRONTO` primário (acento) e `SAIR DA SALA` neutro; botão desabilitado: opacidade 50% + texto, tooltip explicando ("espere o outro jogador / escolha uma raça"). Altura total ~ 1000 em 1080 (já é a página mais alta; manter separação 12).

## 5. Mockups ASCII

### 5.1 HUD (1920x1080 lógicos)
```
+-------------------------------------------------------+-------------------+
|[OBJETIVOS             ]      [!]  03:45          [ TOP |  [E] IMPERIO DA   |
|  [ ] Destruir antena  |       (cronometro 150x44)       |      CINZA        |
|  [x] Chegar ao ponto  |   +--- mensagens (y64) -----+  |  Facc. Humana     |
|                       |   | ! Base sob ataque        |  | [VEL 100%] [MENU] |
|                       |   +--------------------------+  | +---------------+ |
|                                                         | |  minimapa     | |
|                                                         | |  320x230      | |
|                        (campo de jogo)                  | [cristal][raio][pop]
|                                                         | == CONSTRUCOES == |
|                                                         | [74][74][74][74]  |
|                                                         | [74][74][74]      |
|                                                         | == INFANTARIA === |
|                                                         | [74][74][74][74]  |
|                                                         | [74]              |
|                                                         | == VEICULOS ===== |
|                                                         | [74][74][74][74]  |
|                                                         | == NAVES ======== |
| [radio 720 ..........]   [InfoPanel 600 x ~190, colado] | [74][74][74]      |
|                          [  na barra, base do campo   ] | Dica | F1 Atalhos |
+-------------------------------------------------------+-------------------+
```
Em 1920x1440 a coluna da direita ganha 360 lógicos entre a economia e o rodapé; em 2580x1080 o campo ganha 660 à esquerda do InfoPanel/centro.

### 5.2 Página de escaramuça
```
              CRONICAS DA EXTINCAO
                escolha a sua raca
 +-------------+  +-------------+  +-------------+
 | IMPERIO ... |  | LEGIAO ...  |  | ENXAME ...  |
 | Facc. Humana|  | Facc. Robot.|  | Facc. Inset.|
 | [tropa x3]  |  | [tropa x3]  |  | [tropa x3]  |
 | desc (game_data)             ...               |
 | [ COMANDAR ]|  | [ COMANDAR ]|  | [ COMANDAR ]|
 +-------------+  +-------------+  +-------------+
 Inimigo:  [Aleatorio][Imperio][Legiao][Enxame]
 Mapa:     [Pequeno][Medio][Grande]
 Dificuldade: [Facil][Medio][Dificil]
 Arrastar: selecionar · Botao dir.: mover/atacar ...
                    [ VOLTAR ]
```

## 6. Critérios de aceitação (testáveis)

Screenshots retidos em `production/qa/evidence/`, nas resoluções 1920x1080, 1440x1080 (4:3, lógico 1920x1440), 3440x1440 (21:9, lógico 2580x1080) e 1280x720, para as 3 facções:
1. Nenhum texto do HUD/menu cortado, sobreposto ou fora da tela; teste de `get_global_rect()` sem interseção entre objetivos, cronômetro, mensagens, rádio, InfoPanel e barra.
2. Mensagens nunca cobrem objetivos nem cronômetro (3 mensagens empilhadas, 4 objetivos).
3. Barra lateral tem **340 lógicos** de largura em todas as resoluções; minimapa mantém a proporção do mapa; sem rolagem horizontal.
4. Nenhum `font_size` < 14 no tema/HUD/menu (varredura do código); contraste de texto >= 4,5:1, ícones/bordas >= 3:1.
5. **Em 1920x1440 nenhum elemento fica em posição absoluta de 1080** (a dica de ajuda está no rodapé da barra, não no meio da tela); em 2580x1080 os elementos de canto continuam nos cantos.
6. A lista de produção do Império (19 botões) cabe em 1080 de altura sem rolagem, com nome, custo e ícone legíveis (print).
7. Estados do botão de produção distinguíveis em escala de cinza.
8. F1 abre/fecha o painel; Esc o fecha sem cancelar seleção nem abrir a pausa; as teclas existentes de `main.gd` seguem funcionando; a linha longa de ajuda não existe no HUD.
9. Cronômetro mostra só ícone + MM:SS; < 60 s muda por forma; sem piscar > 1 Hz.
10. Menu: as 5 páginas existem e se navegam como hoje (principal → escaramuça/campanha/multiplayer → sala; Esc/VOLTAR retornam); a página de escaramuça não tem botões CAMPANHA/ESCARAMUÇA/SAIR; tudo operável por Tab/setas/Enter.
11. Troca de facção muda cor/emblema/moldura sem alterar posições (diff de layout = 0 lógico).
12. A UI não altera estado do jogo: cada controle só emite sinal já existente ou novo.
13. Teste de acentos Rajdhani (ç ã õ é ê í ó ú â) aprovado, ou fallback ativo.

## 7. Padrões novos (para `design/ux/interaction-patterns.md`)

1. Skin de facção (`UiSkin`). 2. Moldura chanfrada N1/N2/N3 procedural. 3. Cabeçalho de seção recolhível. 4. Botão de produção 74x68 com 7 estados + selo de fila. 5. Pilha de mensagens ancorada. 6. Cronômetro compacto por forma. 7. Painel modal de atalhos (F1) + dica contextual. 8. Cartão de facção com foco de teclado. 9. Regra de escala única: unidades lógicas + âncoras (`canvas_items`/`expand`), sem `ui_scale`; "centro do campo" exclui a barra. 10. Vinheta de legibilidade sobre fundo 3D. 11. Botão de alternância exclusiva com marca "●" além da cor.

## 8. Esforço estimado (1–2 dias)

Dia 1: fonte/molduras (`Frame`), `UiSkin`, barra lateral (A–F), botões de produção, InfoPanel, mensagens e cronômetro. Dia 2: páginas do menu (cartões, estilos, foco), painel F1, verificação em 4 resoluções. Corte seguro: emblemas vetoriais, seções recolhíveis, rebites.
