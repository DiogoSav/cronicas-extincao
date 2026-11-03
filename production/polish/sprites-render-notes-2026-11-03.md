# Sprites: ordem de desenho e névoa — diagnóstico (2026-11-03)

Nenhum arquivo do jogo foi editado. Escritos: este arquivo, `tests/visual/sprites_ordem_teste.gd` e os PNGs
`production/qa/evidence/sprites_antes_*.png` / `sprites_depois_*.png`.

Rodar: `Godot_v4.7.2-stable_win64_console.exe --path . --windowed --resolution 1280x720 -s res://tests/visual/sprites_ordem_teste.gd`
(depois da correção proposta, aplicada só em tempo de execução pelo teste: acrescentar `-- depois 0.05`).

## Resultado da reprodução (ANTES)

- `sprites_antes_frente_unidades.png`: o soldado encostado na borda sul do prédio (0,5 célula fora da base) tem
  o tronco cortado pela plataforma do prédio: o prédio é desenhado por cima de uma unidade que está na frente.
  Defeito 1 confirmado.
- `sprites_antes_atras_tanques.png`: dois tanques posicionados ATRÁS (noroeste) do prédio aparecem inteiros por
  cima do telhado, casco e torre. Confirma a hipótese 1 (o casco já passa por cima do prédio só pelo centro da AABB)
  e a hipótese 2 (a torre, prioridade 1, é desenhada depois de todo casco/prédio).
- `sprites_antes_predio_geral.png`: visão geral da cena.

## Verificação da correção (DEPOIS, aplicada em runtime)

- `sprites_depois_frente_unidades.png` / `_predio_geral.png`: soldados na frente aparecem inteiros sobre a
  plataforma; tanques atrás ficam escondidos pelo prédio (só sobra o que ultrapassa a silhueta do telhado).
- Sinal de `sorting_offset` medido na prática (Godot 4.7.2): valor POSITIVO = desenhado depois (na frente);
  negativo = antes. Com -0.05 a torre ficou embaixo do casco (escotilha vermelha sumiu); com +0.05 a torre fica
  sobre o casco e ainda atrás do prédio (a distância tanque-prédio é ~1,9 unidades de profundidade, muito maior
  que 0,05). A documentação em docs/engine-reference/ não cobre isso: o sinal é verificado só empiricamente.

## Correções propostas (não aplicadas)

### scripts/sprite_body.gd

1. `make_static` (rochas/cristais) — ordenar pelos pés:
```
-	s.rotation = Vector3(-ELEVATION, YAW, 0.0)   # plano perpendicular à câmera
-	var fw: float = info["frame_w"]
+	s.rotation = Vector3(-ELEVATION, YAW, 0.0)   # plano perpendicular à câmera
+	s.sorting_use_aabb_center = false   # ordena pela origem (pés), não pelo centro da imagem
+	var fw: float = info["frame_w"]
```
(o trecho `s.rotation = ...` aparece em `make_static` e em `_new_sprite`; aplicar nos dois.)

2. `_new_sprite` — mesma linha, e torre na mesma prioridade do casco, logo à frente dele:
```
-func _new_sprite(sh: Dictionary, prio: int) -> Sprite3D:
+func _new_sprite(sh: Dictionary, prio: int) -> Sprite3D:   # prio > 0 = torre
 ...
-	s.material_override = material_for(sh["tex"], prio)
+	s.material_override = material_for(sh["tex"])   # prioridade 0 para todos
+	s.sorting_use_aabb_center = false
+	if prio > 0:
+		s.sorting_offset = TURRET_SORT_OFFSET   # logo à frente do casco; positivo = desenha depois
```
e a constante (junto das demais):
```
+## Torre ordena à frente do próprio casco (não por prioridade global): positivo = depois.
+const TURRET_SORT_OFFSET := 0.05
```
`material_for(tex, prio)` pode manter o parâmetro (ninguém mais usa prio 1 depois disso; opcional removê-lo).

### scripts/corpse.gd

Cadáver de infantaria deve ficar atrás de unidades vivas no mesmo lugar (hoje ordena pelo centro da AABB e
fica por cima delas):
```
 	body = SpriteBody.make(model_name)
 	add_child(body)
+	if _infantry:
+		body.spr.sorting_offset = -0.4   # cadáver desenha antes (embaixo) de unidades vivas
```
Carcaça de veículo (ramo `else`) não precisa: é bloqueio sólido, ordena pelos pés como as unidades.

### scripts/building.gd, scripts/unit.gd, scripts/entity.gd, scripts/wreck.gd

Sem mudança necessária: todos criam o visual via `SpriteBody.make`, que passa a ordenar pelos pés. Pelos pés, o
prédio ordena pelo centro da base; uma unidade fora da base, em qualquer lado visível (sul/leste), tem x+z maior
que o centro por pelo menos 0,5 célula, logo sai na frente. Limitação: unidade com o centro dentro de ~0,5 célula
da parede da frente pode ainda sair atrás em prédios muito grandes; se aparecer, dar ao prédio
`sprite.spr.sorting_offset = -0.3` em `Building.setup` (desenha antes) em troca de unidades nos fundos até 0,5 célula.

## Outros achados (sem correção proposta aqui)

- Névoa: o shader usa `MODEL_MATRIX[3].xz` (um ponto, o centro do prédio). Prédio grande com uma parte
  explorada e outra não é escurecido por inteiro pelo valor do centro; também o sprite alto de uma unidade
  atrás da névoa não é recortado. Visual menor; corrigir exigiria amostrar a névoa por fragmento (posição de
  mundo reconstruída no plano do sprite não equivale ao chão), então ficou como nota.
- `Wreck` usa o modelo 3D com teste de profundidade, enquanto os sprites têm `depth_test_disabled` e passam no
  pass transparente: qualquer sprite é desenhado sobre uma carcaça 3D, mesmo estando atrás dela. Só afeta
  entidades sem folha de sprite (com sprite, `die()` usa `Corpse`).
- Torre alinhada ao casco: origem e offset usam o mesmo cálculo (`_new_sprite`), sem desalinhamento visto nos
  prints; ao fim da construção `finish_reveal` repõe offset do casco e da torre igualmente.
- Orçamentos: nenhuma das mudanças altera contagem de draw calls (mesmos materiais; a torre passa a reutilizar a
  chave de material por textura) nem memória de textura; custo da ordenação é o mesmo.
- O teste é um script de reprodução visual (conferência por olho nos PNGs), sem asserções automáticas.
