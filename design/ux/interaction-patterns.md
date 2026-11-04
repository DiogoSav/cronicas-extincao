# Padrões de interação — Crônicas da Extinção

Fonte: `production/ui/hud-e-menu/ux-spec.md` (seção 7). Implementação: `scripts/ui_skin.gd`
(UiSkin), `scripts/hud.gd`, `scripts/info_panel.gd`, `scripts/mission.gd`, `scripts/menu.gd`.

1. **Skin de facção (UiSkin).** Cor primária de `data/game_data.gd` (`color`); cor escura,
   fundo, cor de título, chanfro e borda dupla em `data/theme.gd` (`FACTION_SKINS`); logo em
   `assets/ui/logo_<facção>.png`. A chave `""` é a skin neutra do menu. Trocar de facção muda
   cor, logo e moldura, nunca posições.
2. **Moldura chanfrada N1/N2/N3.** `UiSkin.frame(facção, nível, estado)`: imagem 32×32 gerada
   em código (cantos superior-esquerdo e inferior-direito cortados, realce de 1 px no topo),
   usada como nine-patch e guardada em cache. N1 = painel-mãe (borda 2), N2 = caixa interna
   (borda 1, fundo `#0A0808`), N3 = botão (estados normal, hover, active, disabled, primary).
3. **Cabeçalho de seção recolhível.** Faixa de 24 com gradiente facção→transparente, ícone de
   16 e texto 15 Bold em caixa alta; o clique recolhe a grade (só visual).
4. **Botão de produção 74×68.** Ícone, nome curto 14 e custo 14 Bold com cristal. Estados por
   forma ou texto, não só cor: sem dinheiro (custo + "!"), sem população ("POP!"), bloqueado
   (borda tracejada + cadeado), produzindo (barra de 6 px), fila (selo "x2"), pronto (borda
   branca + "PRONTO"), desativado (50%).
5. **Pilha de mensagens ancorada.** No máximo 3, no topo do centro do campo (y 64), largura
   máxima 640; 4 s, e alertas 6 s com "!" em âmbar. A repetida em menos de 3 s só reinicia o
   contador.
6. **Cronômetro compacto.** Caixa N2 150×44 com relógio e MM:SS. Abaixo de 60 s: âmbar + "!";
   abaixo de 15 s pulsa a 1 Hz. O objetivo de tempo mostra "(MM:SS)" na lista.
7. **Atalhos (F1) + dica contextual.** Painel modal 640×420 centrado no campo, com só as teclas
   que `main.gd` já trata. F1 ou o botão do rodapé abre e fecha; Esc fecha antes de qualquer
   outra ação de Esc. Não pausa. O rodapé da barra mostra uma dica que muda com a seleção.
8. **Cartão de facção com foco de teclado.** Logo, nome, desfile de tropas, descrição e
   COMANDAR (primário). Todo botão do menu aceita foco (anel branco de 2 px); cada página
   define o foco inicial.
9. **Regra de escala única.** Unidades lógicas + âncoras (`canvas_items` / `expand`, base
   1920×1080); nada de `ui_scale`. "Centro do campo" = (largura − 340) / 2.
10. **Vinheta de legibilidade.** Gradiente escuro nas bordas do menu (topo 140, base 260,
    laterais 120 em telas mais largas que 16:9), à frente do fundo 3D e atrás das páginas.
11. **Alternância exclusiva com "●".** Os botões de escolha (inimigo, mapa, dificuldade, raça,
    aba da campanha) marcam o ativo com borda de acento e o prefixo "●".
