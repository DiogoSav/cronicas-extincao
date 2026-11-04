extends SceneTree
## Teste do menu (production/ui/hud-e-menu/ux-spec.md, seção 4 e critérios 1, 4 e 10):
##   1. as páginas existem e se navegam (principal → escaramuça / campanha / multiplayer);
##   2. o conteúdo de cada página fica dentro da tela e nenhum texto está abaixo de 14;
##   3. a escaramuça não tem botões CAMPANHA / ESCARAMUÇA / SAIR; os botões aceitam foco
##      de teclado; a campanha tem uma aba por facção, com no máximo 7 missões por vez.
## Prints: production/qa/evidence/ui_menu_<página>_<LxA>.png.
##
## Rodar (resolução opcional; com "so-escaramuca" tira só o print da escaramuça):
##   Godot_v4.7.2-stable_win64_console.exe --path . --windowed -s res://tests/integration/ui/teste_menu.gd -- 1920x1080
## Sai com 0 se tudo passou, 1 se algo falhou.

const EVIDENCE := "res://production/qa/evidence/"

var win := Vector2i(1920, 1080)
var only_skirmish := false
var menu: Control
var failures: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "so-escaramuca":
			only_skirmish = true
		elif a.contains("x"):
			win = Vector2i(int(a.get_slice("x", 0)), int(a.get_slice("x", 1)))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(win)
	change_scene_to_file("res://scenes/menu.tscn")
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASSOU  " if ok else "FALHOU  ") + what)
	if not ok:
		failures.append(what)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	await _frames(2)
	for i in 30:
		if DisplayServer.window_get_size() == win:
			break
		DisplayServer.window_set_size(win)
		await _frames(3)
	menu = current_scene
	await _frames(40)   # ícones 3D renderizam e congelam
	var res := "%dx%d" % [win.x, win.y]
	_check(DisplayServer.window_get_size() == win, "janela no tamanho pedido (%s)" % [DisplayServer.window_get_size()])

	var pages := {"principal": menu.title_page, "escaramuca": menu.faction_page,
			"campanha": menu.campaign_page, "mp": menu.mp_page}
	for name in pages:
		if only_skirmish and name != "escaramuca":
			continue
		var page: Control = pages[name]
		menu._show_page(page, false)
		await _frames(8)
		_check(page.visible, "página %s aparece" % name)
		_check_page(page, name)
		if name == "campanha":
			_check(menu._camp_tabs.size() == 3, "campanha com 3 abas (%d)" % menu._camp_tabs.size())
			for f in menu._camp_tabs:
				menu._show_campaign_tab(f)
				await _frames(6)
				var missions := 0
				for b in menu._camp_body.get_children():
					if b is Button:
						missions += 1
				_check(missions <= 7, "aba %s com até 7 missões (%d)" % [f, missions])
				_check_page(page, "campanha_" + f)
				await _shot("ui_menu_campanha_%s_%s.png" % [f, res])
		else:
			await _shot("ui_menu_%s_%s.png" % [name, res])
		if name == "escaramuca":
			var bad: Array = []
			for b in page.find_children("*", "Button", true, false):
				if b.text in ["CAMPANHA", "ESCARAMUÇA", "SAIR"]:
					bad.append(b.text)
			_check(bad.is_empty(), "escaramuça sem CAMPANHA / ESCARAMUÇA / SAIR (%s)" % [bad])
		var focused: Control = menu.get_viewport().gui_get_focus_owner()
		_check(focused != null and page.is_ancestor_of(focused), "página %s com foco de teclado inicial" % name)

	print("RESULTADO: %s (%d falhas)" % ["OK" if failures.is_empty() else "FALHOU", failures.size()])
	quit(0 if failures.is_empty() else 1)


## Conteúdo visível dentro da tela; fontes >= 14; botões focáveis.
func _check_page(page: Control, name: String) -> void:
	var vp: Rect2 = root.get_visible_rect().grow(0.5)
	var out: Array = []
	var small: Array = []
	var nofocus: Array = []
	for c in page.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree():
			continue
		if (c is Label or c is Button) and not vp.encloses(c.get_global_rect()):
			out.append(c.get("text"))
		if c is Label and c.has_theme_font_size_override("font_size") and c.get_theme_font_size("font_size") < 14:
			small.append(c.text)
		if c is Button and c.focus_mode == Control.FOCUS_NONE:
			nofocus.append(c.text)
	_check(out.is_empty(), "%s: tudo dentro da tela (fora: %s)" % [name, out])
	_check(small.is_empty(), "%s: nenhum texto abaixo de 14 (%s)" % [name, small])
	_check(nofocus.is_empty(), "%s: botões aceitam foco de teclado (%s)" % [name, nofocus])


func _shot(name: String) -> void:
	await _frames(6)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(EVIDENCE + name))
	print("print: " + EVIDENCE + name)
