# Revisão de UX — HUD e Menu (Fase 4 do /team-ui)

Revisor: ux-designer · Data: 2026-11-03 · Base: `production/ui/hud-e-menu/ux-spec.md` (Revisão 2)
Método: leitura dos 15 prints em `production/qa/evidence/ui_*` e do código (`hud.gd`, `ui_skin.gd`,
`mission.gd`, `info_panel.gd`, `menu.gd`, `main.gd` só F1/Esc, `data/theme.gd` só `FACTION_SKINS`).
O jogo não foi executado.

## Veredito: APROVADO (sem bloqueantes; 8 avisos)

## Desvios conhecidos e aceitos (conferidos, fazem sentido)
- Logos PNG oficiais no lugar dos emblemas vetoriais: melhoram a identidade; legíveis a 48 (HUD) e 84 (cartões).
- Rebites, circuito e LEDs cortados: estavam no "corte seguro" da seção 8.
- Objetivos até 6 linhas (`MAX_OBJ_LINES`), com "+N objetivos": com 5 objetivos (H04) o painel termina em y~225 e não encosta nas mensagens (x >= ~470).
- Passo da pilha de mensagens 32 (painel 30 + separação 2): 3 mensagens ocupam y 64–160, sem cobrir cronômetro nem objetivos.
- Rádio com ícone de antena: retrato 64x64 coerente.
- Anel de foco contínuo (em vez de pontilhado): bem visível nos prints do menu (CAMPANHA, COMANDAR, H03, aba Legião).
- Campanha de Legião/Enxame "em produção": relógio + texto, não depende de cor.
- Sem print da sala de espera; MULTIPLAYER oculto sem `Net.available()` (código em `menu.gd` l.152).

## Conferência por item

### Hierarquia e layout por região (HUD)
Bate com 3.2: barra 340 à direita com A cabeçalho (logo + `name` + `army`), B VEL/MENU, C minimapa N2 na proporção do mapa, D economia em 3 colunas (número 24 Bold), E produção em 4 colunas 74x68 com as 4 seções e os 19 botões do Império cabendo sem rolagem em 1080 (folga de ~50), F rodapé com dica contextual + "F1 Atalhos". Objetivos no canto superior esquerdo (380), cronômetro 150x44 centrado no campo, mensagens abaixo dele, rádio inferior esquerdo (20–740), InfoPanel 600 colado à barra (980–1580). Linha longa de ajuda removida. Fim de partida mostra [R]/[M] (só [M] no multiplayer).

### Estados dos botões de produção sem cor (`hud.gd`, `ProdSlot`)
- Bloqueado: cadeado desenhado + borda tracejada + ícone cinza (visível nos prints: Hangar, veículos, naves). OK.
- Sem dinheiro: custo + "!" (texto). Sem população: "POP!" (texto). OK.
- Em produção: barra 6 px na base. Fila: selo "x2/x3" (só > 1). Pronto: borda branca + "PRONTO". Desativado: alpha 0,5. OK.
- Todos têm forma ou texto; em escala de cinza continuam distinguíveis pelo código. Só o estado "bloqueado" aparece nos prints (ver AVISO 2).

### Sobreposição e corte nas resoluções
- 1920x1080 (3 facções): sem sobreposição; posições idênticas entre facções (critério 11).
- 1440x1080 (lógico 1920x1440): barra com produção no topo e rodapé na base (a folga fica entre eles, como a regra 1.3a); objetivos/cronômetro no topo, rádio e InfoPanel na base. Nenhum elemento preso a y=1080. OK.
- 3440x1440 (lógico 2580x1080): elementos nos seus cantos; a área extra vai para o campo. OK.
- 1280x720: mesma composição de 1080 (fator 0,667). OK quanto a layout (ver AVISO 6 sobre tamanho físico).
- Menu de escaramuça nas 4 resoluções: cartões, painel de configuração, ajuda e VOLTAR cabem; em 1080 o VOLTAR fica a ~18 lógicos da base (folga justa, mas sem corte).
- Corte marginal: rótulos "Ninho Aéreo", "Plataforma", "Aniquilador", "Devastador" encostam na borda tracejada (AVISO 3).

### Navegação por teclado (código)
- Menu: `make_button` usa `FOCUS_ALL` + `focus_ring()`; `_focus_page` dá o foco inicial por página: principal → CAMPANHA; escaramuça → primeiro COMANDAR; campanha → próxima missão liberada (ou a aba); multiplayer → campo Nome; sala → PRONTO ou SAIR DA SALA. Tab/setas usam a vizinhança padrão do Godot; Enter aciona. Esc volta à principal; F11 tela cheia. OK.
- Alternâncias: `_mark` usa `set_pressed_no_signal` + "●" (não só cor). OK.
- HUD: F1 alterna o painel (não pausa); Esc com o painel aberto fecha e chama `set_input_as_handled()` ANTES de cancelar ordem/seleção/abrir pausa (`main.gd` l.258–264). Demais teclas inalteradas. OK. Botões do HUD ficam com `FOCUS_NONE` (correto: não roubam teclas de atalho do jogo).

### A UI não altera estado do jogo
Os controles só chamam ações que já existiam: `Game.start_production`, `cancel_production`, `set_speed_level`, `pause_requested`, `set_order_mode`, `unit_order`, `recycle_selected`, `Mission.start`, `_start`. Seções recolhíveis e painel F1 são só visuais. A única gravação nova é a flag `hud/atalhos_vistos` em `user://config.cfg` (preferência de interface, prevista na spec). OK.

### Textos >= 14 lógicos
`UiSkin.label` força `maxi(size, 14)`; todos os `font_size` explícitos em `hud.gd`, `info_panel.gd`, `mission.gd` e `menu.gd` são >= 14 (varredura sem ocorrências < 14). O único 10 é o glifo do cristal (ícone, não texto). OK.

### Contraste aparente (3 facções)
- Painéis: `TEXT_HI`/`TEXT_MID` sobre fundo escuro, legíveis nas três skins. Títulos em `#FF5A47` (Império), `#FF8C2A` (Legião), `#9EFF1F` (Enxame), todos >= 18 e claros sobre os fundos. OK.
- Problemas sobre o fundo 3D do menu: ver AVISO 4.

## Achados

### BLOQUEANTES
Nenhum.

### AVISOS
1. **Postura ativa só por cor** — `scripts/info_panel.gd` `refresh()` l.158–160 (região: barra de comandos do InfoPanel). "Agressivo (H)" ativo só fica verde (`modulate`). Viola a regra "cor nunca é o único indicador". Correção: usar `toggle_mode`/`button_pressed` com o estilo pressionado ou prefixar "●  " ao texto, como `_mark()` do menu.
2. **Evidência incompleta dos estados de produção** — `production/qa/evidence/` (região E da barra). Os prints só mostram normal e bloqueado; sem dinheiro, POP!, em produção, fila xN, PRONTO e desativado não aparecem (critério 7). Correção: um print com recursos baixos, fila x3, uma barra em andamento e um prédio PRONTO, de preferência também em escala de cinza.
3. **Nomes curtos encostando na borda tracejada** — `hud.gd` `ProdSlot.setup` (`_name` 70 de largura) e campo `short` em `data/game_data.gd`. "Ninho Aéreo", "Plataforma", "Aniquilador", "Devastador" tocam o tracejado/cadeado. Correção: `short` mais curto (ex.: "Ninho", "Platafor.", "Aniquil.", "Devast.") ou recuar o rótulo para 4–70 quando `locked`.
4. **Contraste de textos sobre o planeta no menu** — `menu.gd` (escaramuça: linha de ajuda l.209; multiplayer: rótulo de status laranja; subtítulos "escolha a sua raça"/"campanha" cruzados pelas naves da vitrine). Sobre os rastros claros do planeta, o texto `TEXT_MID` e o status laranja ficam abaixo do aparente 4,5:1. Correção: dar a esses rótulos uma faixa de fundo `#000000A0` (como as mensagens do HUD) ou reforçar a vinheta inferior; no status, usar `TEXT_HI` com "!" em vez de laranja.
5. **Print do F1 desatualizado** — `ui_hud_f1_1920x1080_hum.png` mostra "Cancela ordem / seleção; senão…" truncado, mas `HELP_KEYS` em `hud.gd` l.381 tem "Cancelar ordem · limpar · pausa". Correção: refazer o print para que a evidência corresponda ao código e confirmar que a linha não trunca.
6. **Tamanho físico em 1280x720** — por decisão de escopo da spec, 14 lógicos viram ~9 px físicos (InfoPanel, custos, rodapé quase ilegíveis no print). Não é falha desta implementação; registrar a resolução mínima suportada (sugestão: 1600x900) ou uma opção futura de escala de UI.
7. **Campanha em abas, não empilhada** — `menu.gd` `_build_campaign_page` (l.380–420). A spec mantinha os blocos empilhados (com rolagem ou colapso). As abas resolvem o risco de altura e têm "●" + foco, mas acrescentam um passo para trocar de facção. Correção: só confirmar com o usuário como desvio aceito.
8. **Objetivo falhado sem marcador "!"** — `mission.gd` `_refresh_objectives` só tem ◻/◼. Se houver objetivos que falham, acrescentar "!" + texto; senão, retirar da spec.

## Acessibilidade
**NÃO AVALIADA (nível Básico assumido).** Observações apenas: avisos 1 (cor como único indicador), 4 (contraste sobre fundo 3D) e 6 (tamanho físico em baixa resolução); pulso do cronômetro a 1 Hz entre alpha 0,6 e 1,0 (dentro do limite de 3 Hz); gamepad fora de escopo; o painel F1 abre sozinho na primeira partida e não pausa (bom para o multiplayer).
