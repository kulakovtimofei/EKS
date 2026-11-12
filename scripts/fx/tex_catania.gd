class_name TexCatania
extends RefCounted
## Текстуры для Катании: чёрный лавовый камень, светлый известняк,
## барочные окна с наличниками, балконы, мостовая «базолато»,
## черепица, балюстрада, арки, сосны-«зонтики», пальмы, тенты рынка.
## Один тайл фасада = один пролёт окна (4 м) × один этаж (4.5 м).

const LAVA := Color("4a4c52")
const LAVA_DARK := Color("34363c")
const LIME := Color("d8d0bc")
const LIME_SHADE := Color("b0a890")
const CREAM := Color("dcc8a0")
const GLASS := Color("1a2230")
const IRON := Color("1c1c20")


static func make(tex_name: String) -> Image:
	match tex_name:
		"facade_dark": return _facade(LAVA, LIME, true)
		"facade_cream": return _facade(CREAM, Color("efe4cc"), false)
		"facade_grey": return _facade(Color("8a8680"), LIME, true)
		"facade_ground": return _ground_floor(Color("9a968c"))
		"facade_ground_dark": return _ground_floor(Color("5a5a5e"))
		"cathedral": return _cathedral_wall()
		"basolato": return _basolato()
		"slab": return _slab()
		"roof_tiles": return _roof_tiles()
		"balustrade": return _balustrade()
		"arches": return _arches()
		"pine": return _pine()
		"palm": return _palm()
		"awning": return _awning()
		"lime": return _stone(LIME, 3)
		"lava": return _stone(LAVA, 4)
	return null


static func _img(w: int, h: int, fill: Color) -> Image:
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(fill)
	return img



static func _rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for x in range(maxi(x0, 0), mini(x1, img.get_width())):
			img.set_pixel(x, y, c)


static func _speckle(img: Image, seed: int, amount: float) -> void:
	## Каменная «зернистость» поверх
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = 0.5
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			# Ступенчатый шум в пределах ±amount (раньше округление давало −25%)
			var v := roundf(n.get_noise_2d(x, y) * 2.0) / 2.0 * amount
			img.set_pixel(x, y, Color(clampf(c.r + v, 0, 1), clampf(c.g + v, 0, 1), clampf(c.b + v, 0, 1), c.a))


static func _stone(base: Color, seed: int) -> Image:
	var img := _img(32, 32, base)
	_speckle(img, seed, 0.04)
	return img


static func _facade(wall: Color, trim: Color, rusticated_pilaster: bool) -> Image:
	var img := _img(64, 64, wall)
	# Пилястра по краю пролёта (рустованная — с горизонтальными швами)
	_rect(img, 0, 0, 6, 64, trim)
	if rusticated_pilaster:
		for y in range(0, 64, 6):
			_rect(img, 0, y, 6, y + 1, LIME_SHADE)
	# Межэтажный карниз внизу тайла
	_rect(img, 0, 60, 64, 64, trim)
	_rect(img, 0, 63, 64, 64, LIME_SHADE)
	# Наличник окна
	_rect(img, 21, 12, 47, 52, trim)
	_rect(img, 18, 7, 50, 12, trim)            # сандрик
	_rect(img, 20, 4, 48, 7, trim)
	_rect(img, 31, 2, 37, 4, trim)             # завиток
	# Окно, переплёт
	_rect(img, 24, 15, 44, 50, GLASS)
	_rect(img, 33, 15, 35, 50, Color("6a6458"))
	_rect(img, 24, 30, 44, 31, Color("6a6458"))
	# Ставни, если фасад светлый
	if not rusticated_pilaster:
		_rect(img, 24, 15, 28, 50, Color("3a5a40"))
		_rect(img, 40, 15, 44, 50, Color("3a5a40"))
	# Балкон с коваными перилами
	_rect(img, 17, 50, 51, 53, trim)
	for x in range(18, 50, 3):
		_rect(img, x, 44, x + 1, 50, IRON)
	_rect(img, 18, 44, 50, 45, IRON)
	_speckle(img, 7, 0.04)
	return img


static func _ground_floor(stone: Color) -> Image:
	## Первый этаж: рустованный камень и арочный проём (магазин/подъезд)
	var img := _img(64, 64, stone)
	for y in range(0, 64, 8):
		_rect(img, 0, y, 64, y + 1, stone.darkened(0.3))
		var off := 0 if (y / 8) % 2 == 0 else 16
		for x in range(off, 64, 32):
			_rect(img, x, y, x + 1, y + 8, stone.darkened(0.3))
	# Арка
	var cx := 32.0
	for y in range(14, 64):
		for x in range(14, 50):
			var inside := y >= 28 or Vector2(x - cx, y - 28).length() < 18.0
			var frame := y >= 26 or Vector2(x - cx, y - 28).length() < 20.0
			if inside and x > 15 and x < 49:
				img.set_pixel(x, y, Color("141418"))
			elif frame:
				img.set_pixel(x, y, LIME)
	# Витрина/дверь внутри
	_rect(img, 20, 34, 44, 64, Color("2a3a48"))
	_rect(img, 31, 34, 33, 64, Color("101014"))
	_speckle(img, 9, 0.04)
	return img


static func _cathedral_wall() -> Image:
	var img := _img(64, 64, Color("e4d8b8"))
	for y in range(0, 64, 16):
		_rect(img, 0, y, 64, y + 1, Color("c4b898"))
	_rect(img, 0, 0, 8, 64, Color("f0e8d0"))
	_rect(img, 22, 10, 42, 46, Color("c4b898"))
	_rect(img, 24, 12, 40, 44, GLASS)
	_speckle(img, 13, 0.04)
	return img


static func _basolato() -> Image:
	## Мостовая из лавовых плит: ряды со смещением, чистые швы
	var size := 128
	var img := _img(size, size, Color(0.13, 0.13, 0.15))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for row in 4:
		var y0 := row * 32
		var off := 0 if row % 2 == 0 else 24
		var x := -off
		while x < size:
			var w := rng.randi_range(40, 56)
			var tint := rng.randf_range(-0.035, 0.035)
			for yy in range(y0 + 2, y0 + 32):
				for xx in range(x + 2, x + w):
					# Лёгкая фаска: края плиты чуть светлее
					var edge := 0.03 if (yy == y0 + 2 or xx == x + 2) else 0.0
					var c := 0.26 + tint + edge
					img.set_pixel(posmod(xx, size), yy, Color(c, c, c + 0.02))
			x += w
	return img


static func _slab() -> Image:
	var img := _img(32, 32, Color("6e6c6a"))
	_rect(img, 0, 0, 32, 1, Color("4a4846"))
	_rect(img, 0, 0, 1, 32, Color("4a4846"))
	_speckle(img, 23, 0.04)
	return img


static func _roof_tiles() -> Image:
	var img := _img(32, 32, Color("a8502c"))
	for y in range(0, 32, 8):
		_rect(img, 0, y, 32, y + 2, Color("7a3420"))
		for x in range(0, 32, 6):
			_rect(img, x, y + 2, x + 1, y + 8, Color("c06838"))
	_speckle(img, 24, 0.04)
	return img


static func _balustrade() -> Image:
	## Белая балюстрада с балясинами-«вазами», с прозрачностью
	var img := _img(64, 32, Color(0, 0, 0, 0))
	_rect(img, 0, 0, 64, 5, LIME)
	_rect(img, 0, 4, 64, 5, LIME_SHADE)
	_rect(img, 0, 27, 64, 32, LIME)
	for b in range(4, 64, 10):
		for y in range(5, 27):
			var t := float(y - 5) / 22.0
			var half := int(1.5 + 2.5 * sin(t * PI) + (1.5 if t > 0.6 else 0.0))
			_rect(img, b + 3 - half, y, b + 3 + half, y + 1, LIME if y % 7 else LIME_SHADE)
	return img


static func _arches() -> Image:
	## Арки старого виадука у набережной
	var img := _img(64, 64, Color("5a5856"))
	for y in range(0, 64, 6):
		_rect(img, 0, y, 64, y + 1, Color("44423f"))
	for y in range(16, 64):
		for x in range(10, 54):
			if y >= 32 or Vector2(x - 32, y - 32).length() < 22.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return img


static func _pine() -> Image:
	## Средиземноморская сосна-«зонтик»: высокий голый ствол, плоская крона
	var w := 64
	var h := 80
	var img := _img(w, h, Color(0, 0, 0, 0))
	var n := FastNoiseLite.new()
	n.seed = 31
	n.frequency = 0.15
	var pal := [Color("1e3a1a"), Color("2a4c20"), Color("3a6228"), Color("4a7a30")]
	for y in h:
		for x in w:
			var dx := (x - 32.0) / 32.0
			var dy := (y - 16.0) / 13.0
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			if dx * dx + dy * dy + (v - 0.5) * 0.6 < 1.0:
				img.set_pixel(x, y, pal[clampi(int((v - dy * 0.3) * 4.0), 0, 3)])
			elif y > 22 and absf(x - 32 + (y - 80) * 0.08) < 2.0:
				img.set_pixel(x, y, Color("5a4030") if x % 3 else Color("443024"))
	return img


static func _palm() -> Image:
	var w := 64
	var h := 96
	var img := _img(w, h, Color(0, 0, 0, 0))
	for y in range(20, h):
		var x := 32 + int(sin(y * 0.05) * 2.0)
		_rect(img, x - 2, y, x + 2, y + 1, Color("7a6040") if y % 4 else Color("5a4430"))
	for i in 9:
		var a := -PI * 0.95 + i * PI * 0.9 / 8.0
		for t in 26:
			var droop := t * t * 0.02
			var px := int(32 + cos(a) * t)
			var py := int(20 + sin(a) * t * 0.6 + droop)
			_rect(img, px - 1, py - 1, px + 2, py + 1, Color("3a7a30") if t % 3 else Color("2a5a24"))
	return img


static func _awning() -> Image:
	var img := _img(32, 32, Color("e8e0d0"))
	for x in range(0, 32, 8):
		_rect(img, x, 0, x + 4, 32, Color("c83030"))
	return img
