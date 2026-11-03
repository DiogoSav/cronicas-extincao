extends SceneTree
## Converte os renders do Blender (art_src/renders/<unidade>/) em pixel art:
## reduz 4x, limita a uma paleta própria da unidade (median cut), põe contorno,
## sombra, clarão do tiro e poça de sangue. Escreve:
##   art_src/<unidade>_hd.pxo, assets/sprites/<unidade>_hd.png e <unidade>_hd.json
##
## Uso (na pasta do projeto):
##   Godot_console --headless --path . -s <abs>/art_src/gen/pixelize.gd -- soldado
##
## Renders com meta "style": "real" (soldado_real) seguem o visual de RTS de guerra
## pré-renderizado: sem contorno, sem paleta reduzida (degradê do render) e com a
## sombra projetada que veio do shadow catcher no lugar da elipse.

const PALETTE_SIZE := 44
## cores que não podem se perder na paleta (brilhos pequenos)
const KEEP := ["#ff3b1f", "#ff8a5c", "#ffd2b0"]

var root_dir := ""
var outline_col := Color("#0e0c0b")
var pal: Array[Color] = []
var pal_cache := {}
var real := false


func _initialize() -> void:
	root_dir = ProjectSettings.globalize_path("res://")
	var args := OS.get_cmdline_user_args()
	var unit: String = args[0] if args.size() > 0 else "soldado"
	var src := root_dir + "art_src/renders/" + unit + "/"
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(src + "meta.json"))
	var fw: int = meta["frame"]
	var dirs: Array = meta["dirs"]
	var anims: Array = meta["anims"]
	real = meta.get("style", "hd") == "real"
	var out_name := unit if real else unit + "_hd"

	# 1) reduz cada render para o tamanho do quadro
	var keys: Array[String] = []
	var small := {}
	var samples: Array[Color] = []
	for d in dirs:
		for a in anims:
			for f in int(a[1]):
				var key := "%s_%s_%d" % [d, a[0], f]
				keys.append(key)
				var img := downsample(Image.load_from_file(src + key + ".png"), fw)
				small[key] = img
				for y in range(0, fw, 2):
					for x in range((y / 2) % 2, fw, 2):
						var c := img.get_pixel(x, y)
						if c.a > 0.5:
							samples.append(c)
	if not real:
		pal = median_cut(samples, PALETTE_SIZE)
	for k in KEEP:
		pal.append(Color(k))
	print("paleta: %d cores, %d amostras" % [pal.size(), samples.size()])

	# 2) quantiza e acabamento de cada quadro
	var frames: Array[Image] = []
	var tags: Array = []
	var info := {"frame_w": fw, "frame_h": fw, "directions": dirs, "animations": {}, "muzzle": {}}
	var col := 0
	for a in anims:
		info["animations"][a[0]] = {"col": col, "frames": a[1]}
		col += int(a[1])
	for d in dirs:
		for a in anims:
			var start := frames.size() + 1
			for f in int(a[1]):
				var key := "%s_%s_%d" % [d, a[0], f]
				var m: Dictionary = meta["frames"][key]
				var img: Image = small[key]
				var k := float(fw) / 128.0
				if not real:
					quantize(img)
					add_outline(img)
				var feet := Vector2(m["feet"][0], m["feet"][1])
				var n := int(a[1])
				if a[0] == "death_blast":
					scorch(img, feet, 13.0 * k, f)
				if a[0].begins_with("death") and f >= n - 3:
					var big := 1.3 if a[0] == "death_blast" else 1.0
					blood_pool(img, Vector2(m["pool"][0], m["pool"][1]), [7.0, 11.0, 14.0][f - (n - 3)] * k * big)
				if not real:
					add_shadow(img, feet)
				if a[0] == "attack" and f < 2:
					draw_flash(img, Vector2i(roundi(m["muzzle"][0]), roundi(m["muzzle"][1])), roundi((4 - f) * maxf(k, 0.6)), meta.get("flash", "fire"))
				if a[0] == "attack":
					info["muzzle"]["%s_%d" % [d, f]] = m["muzzle"]
				if not info.has("origin"):   # pés do primeiro quadro (o pivô não muda)
					info["origin"] = [roundi(feet.x), roundi(feet.y)]
				frames.append(img)
			tags.append(["%s_%s" % [a[0], d], start, frames.size()])

	var cols := frames.size() / dirs.size()
	var sheet := Image.create_empty(fw * cols, fw * dirs.size(), false, Image.FORMAT_RGBA8)
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(0, 0, fw, fw), Vector2i((i % cols) * fw, (i / cols) * fw))
	sheet.save_png(root_dir + "assets/sprites/" + out_name + ".png")
	var fh := FileAccess.open(root_dir + "assets/sprites/" + out_name + ".json", FileAccess.WRITE)
	fh.store_string(JSON.stringify(info, "\t"))
	fh.close()
	save_pxo(out_name, frames, tags, 10.0, fw)
	if real and meta.get("compare", true):
		compare_real(unit, frames, cols, fw)
	elif not real:
		compare(unit, frames, cols, fw)
	print("pixel art pronta: assets/sprites/%s.png" % out_name)
	quit()


# ================================================================ redução e paleta

## Média de blocos (o PNG do Blender tem cor zero onde é transparente, então
## dividir pela cobertura recupera a cor verdadeira da borda).
func downsample(src: Image, size: int) -> Image:
	src.convert(Image.FORMAT_RGBA8)
	var img: Image = src.duplicate()
	while img.get_width() > size:
		img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	for y in size:
		for x in size:
			var c := img.get_pixel(x, y)
			if real and c.a < 0.5:
				# shadow catcher: pixel quase preto e semitransparente = sombra no chão
				var lum := (c.r + c.g + c.b) / maxf(c.a, 0.001) / 3.0
				var sa := c.a * 0.85 if lum < 0.08 and c.a > 0.04 else 0.0
				img.set_pixel(x, y, Color(0.04, 0.035, 0.03, minf(sa * 0.7, 0.36)))
			elif c.a < 0.5:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				img.set_pixel(x, y, Color(minf(c.r / c.a, 1.0), minf(c.g / c.a, 1.0), minf(c.b / c.a, 1.0), 1.0))
	return img


func median_cut(cols: Array[Color], n: int) -> Array[Color]:
	var boxes: Array = [cols]
	while boxes.size() < n:
		var best := -1
		var best_score := 0.0
		var best_ch := 0
		for i in boxes.size():
			var box: Array = boxes[i]
			if box.size() < 2:
				continue
			var lo := Vector3(9, 9, 9)
			var hi := Vector3(-9, -9, -9)
			for c in box:
				var v := Vector3(c.r, c.g, c.b)
				lo = lo.min(v)
				hi = hi.max(v)
			var rng := hi - lo
			var ch := 0 if rng.x >= rng.y and rng.x >= rng.z else (1 if rng.y >= rng.z else 2)
			var score: float = rng[ch] * sqrt(float(box.size()))
			if score > best_score:
				best_score = score
				best = i
				best_ch = ch
		if best < 0:
			break
		var box: Array = boxes[best]
		var chn := best_ch
		box.sort_custom(func(p: Color, q: Color) -> bool: return p[chn] < q[chn])
		var mid := box.size() / 2
		boxes[best] = box.slice(0, mid)
		boxes.append(box.slice(mid))
	var out: Array[Color] = []
	for box in boxes:
		var s := Vector3.ZERO
		for c in box:
			s += Vector3(c.r, c.g, c.b)
		s /= float(box.size())
		out.append(Color(s.x, s.y, s.z))
	return out


func nearest(c: Color) -> Color:
	var key := (int(c.r * 63) << 12) | (int(c.g * 63) << 6) | int(c.b * 63)
	if pal_cache.has(key):
		return pal_cache[key]
	var best := pal[0]
	var bd := 1e9
	for p in pal:
		var dr := c.r - p.r
		var dg := c.g - p.g
		var db := c.b - p.b
		var dist := 2.0 * dr * dr + 4.0 * dg * dg + 3.0 * db * db
		if dist < bd:
			bd = dist
			best = p
	pal_cache[key] = best
	return best


func quantize(img: Image) -> void:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				img.set_pixel(x, y, nearest(c))


# ================================================================ acabamento

func add_outline(img: Image) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var src: Image = img.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h and src.get_pixel(nx, ny).a > 0.5:
					img.set_pixel(x, y, outline_col)
					break


func add_shadow(img: Image, feet: Vector2) -> void:
	for y in range(-8, 9):
		for x in range(-20, 21):
			var e := pow(x / 20.0, 2) + pow(y / 8.0, 2)
			var ix := int(feet.x) + x
			var iy := int(feet.y) + y
			if e > 1.0 or ix < 0 or iy < 0 or ix >= img.get_width() or iy >= img.get_height():
				continue
			if img.get_pixel(ix, iy).a > 0.0:
				continue
			img.set_pixel(ix, iy, Color(0, 0, 0, 0.42 if e < 0.55 else 0.25))


func blood_pool(img: Image, c: Vector2, r: float) -> void:
	for y in range(-int(r), int(r) + 1):
		for x in range(-int(r * 1.7), int(r * 1.7) + 1):
			var e := pow(x / (r * 1.7), 2) + pow(y / (r * 0.85), 2)
			var n := sin(float(x / 3) * 12.9898 + float(y / 2) * 78.233 + r) * 43758.5453
			if e > 1.0 - (n - floor(n)) * 0.25:
				continue
			var ix := int(c.x) + x
			var iy := int(c.y) + y
			if ix < 0 or iy < 0 or ix >= img.get_width() or iy >= img.get_height():
				continue
			if img.get_pixel(ix, iy).a > 0.9:
				continue
			var bc := Color("#4a0d0b") if e > 0.5 else Color("#6a1410")
			if real: # sangue escuro e opaco, sem a sombra por baixo aparecer
				bc = Color("#3e100c") if e > 0.5 else Color("#55160f")
			img.set_pixel(ix, iy, bc)


## Chão chamuscado da explosão: mancha escura irregular com borda de terra queimada.
func scorch(img: Image, c: Vector2, r: float, f: int) -> void:
	var grow := minf(1.0, 0.55 + f * 0.15)
	r *= grow
	for y in range(-int(r), int(r) + 1):
		for x in range(-int(r * 1.8), int(r * 1.8) + 1):
			var e := pow(x / (r * 1.8), 2) + pow(y / r, 2)
			var n := sin(x * 7.13 + y * 3.71) * 9182.31
			n = n - floor(n)
			if e > 1.0 - n * 0.3:
				continue
			var ix := int(c.x) + x
			var iy := int(c.y) + y
			if ix < 0 or iy < 0 or ix >= img.get_width() or iy >= img.get_height():
				continue
			if img.get_pixel(ix, iy).a > 0.9:
				continue
			var col := Color(0.07, 0.06, 0.05, 0.85) if e < 0.45 else Color(0.2, 0.15, 0.1, 0.6)
			img.set_pixel(ix, iy, col)


func draw_flash(img: Image, c: Vector2i, size: int, kind := "fire") -> void:
	var cols := [Color("#fff6d8"), Color("#ffd75a"), Color("#ff8a24")]
	if kind == "spark": # solda/faísca do engenheiro
		cols = [Color("#ffffff"), Color("#bfe8ff"), Color("#ffb347")]
	elif kind == "heal": # injeção do médico
		cols = [Color("#eaffd8"), Color("#9be36a"), Color("#4fae3c")]
	for y in range(-size - 2, size + 3):
		for x in range(-size - 2, size + 3):
			var d := absi(x) + absi(y)
			var star := (x == 0 or y == 0) and d <= size + 2
			var ix := c.x + x
			var iy := c.y + y
			if ix < 0 or iy < 0 or ix >= img.get_width() or iy >= img.get_height():
				continue
			if d <= size / 2:
				img.set_pixel(ix, iy, cols[0])
			elif d <= size:
				img.set_pixel(ix, iy, cols[1])
			elif star:
				img.set_pixel(ix, iy, cols[2])


# ================================================================ saída

## .pxo = zip com data.json + RGBA8 cru por frame/camada (formato do Pixelorama 1.2.x).
func save_pxo(sheet_name: String, frames: Array[Image], tags: Array, fps: float, fw: int) -> void:
	var data := {
		"color_mode": 5, "current_frame": 0, "current_layer": 0, "fps": fps,
		"frames": [], "layers": [{
			"blend_mode": 0, "clipping_mask": false, "locked": false, "name": "Sprite",
			"new_cels_linked": false, "opacity": 1.0, "parent": -1, "type": 0, "visible": true,
		}],
		"pixelorama_version": "v1.2.3", "pxo_version": 7,
		"size_x": fw, "size_y": fw, "tags": [],
	}
	for i in frames.size():
		data["frames"].append({"cels": [{"opacity": 1.0, "z_index": 0}], "duration": 1.0})
	var tag_cols := {"idle": "#5a8fd0", "walk": "#6fb35a", "attack": "#d0503a", "death": "#8a8a8a"}
	for t in tags:
		data["tags"].append({"color": tag_cols[t[0].split("_")[0]], "from": t[1], "name": t[0], "to": t[2]})
	var zip := ZIPPacker.new()
	zip.open(root_dir + "art_src/" + sheet_name + ".pxo")
	_zip_put(zip, "data.json", JSON.stringify(data, "\t").to_utf8_buffer())
	_zip_put(zip, "mimetype", "application/x-pixelorama".to_utf8_buffer())
	_zip_put(zip, "preview.png", frames[0].save_png_to_buffer())
	for i in frames.size():
		var raw: PackedByteArray = frames[i].get_data()
		_zip_put(zip, "image_data/final_images/%d" % (i + 1), raw)
		_zip_put(zip, "image_data/frames/%d/layer_1" % (i + 1), raw)
	zip.close()


func _zip_put(zip: ZIPPacker, path: String, bytes: PackedByteArray) -> void:
	zip.start_file(path)
	zip.write_file(bytes)
	zip.close_file()


## Comparação lado a lado: versão antiga (caixas) x nova (Blender), mais o ciclo de andar.
func compare(unit: String, frames: Array[Image], cols: int, fw: int) -> void:
	var out := Image.create_empty(fw * 6, fw * 2, false, Image.FORMAT_RGBA8)
	for py in out.get_height():
		for px in out.get_width():
			var u := floori(px / 32.0 + py / 16.0)
			var v := floori(py / 16.0 - px / 32.0)
			out.set_pixel(px, py, Color("#2c2826") if posmod(u + v, 2) == 0 else Color("#342f2c"))
	var old_path := root_dir + "assets/sprites/" + unit + ".png"
	if FileAccess.file_exists(old_path):
		var old := Image.load_from_file(old_path)
		old.convert(Image.FORMAT_RGBA8)
		var fr := Image.create_empty(80, 80, false, Image.FORMAT_RGBA8)
		fr.blit_rect(old, Rect2i(0, 80, 80, 80), Vector2i.ZERO) # SW, parado
		out.blend_rect(fr, Rect2i(0, 0, 80, 80), Vector2i(24, 36))
	var walk_col := 4
	var pick := [[1, 0], [0, 0], [7, 10], [1, 17], [5, 0]] # [linha dir, coluna]
	for i in pick.size():
		out.blend_rect(frames[pick[i][0] * cols + pick[i][1]], Rect2i(0, 0, fw, fw), Vector2i((i + 1) * fw, 0))
	for i in 6:
		out.blend_rect(frames[1 * cols + walk_col + i], Rect2i(0, 0, fw, fw), Vector2i(i * fw, fw))
	out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
	out.save_png(root_dir + "assets/sprites/_compare_" + unit + ".png")


## Comparação do estilo real: as 3 mortes quadro a quadro (direção SW) num chão de
## grama, mais o Soldado parado e andando para dar a escala.
func compare_real(unit: String, frames: Array[Image], cols: int, fw: int) -> void:
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(root_dir + "assets/sprites/" + unit + ".json"))
	var an: Dictionary = meta["animations"]
	var rows := ["death", "death_fwd", "death_blast"]
	var step := 70
	var w := step * 7 + fw
	var h := 60 + rows.size() * 70 + 40
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	for py in h:
		for px in w:
			var n := sin(px * 12.9898 + py * 78.233) * 43758.5453
			n = n - floor(n)
			out.set_pixel(px, py, Color("#5d6b3a").lerp(Color("#6f7a44"), n * 0.6))
	var dir_row := 1 # SW
	out.blend_rect(frames[dir_row * cols + int(an["idle"]["col"])], Rect2i(0, 0, fw, fw), Vector2i(0, -20))
	for i in 3:
		out.blend_rect(frames[dir_row * cols + int(an["walk"]["col"]) + i * 2], Rect2i(0, 0, fw, fw), Vector2i(step * (i + 1), -20))
	for r in rows.size():
		var anim: Dictionary = an[rows[r]]
		for f in int(anim["frames"]):
			out.blend_rect(frames[dir_row * cols + int(anim["col"]) + f], Rect2i(0, 0, fw, fw), Vector2i(f * step, 30 + r * 70))
	out.resize(w * 2, h * 2, Image.INTERPOLATE_NEAREST)
	out.save_png(root_dir + "assets/sprites/_compare_" + unit + ".png")
