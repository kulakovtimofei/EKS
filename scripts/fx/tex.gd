class_name Tex
extends RefCounted
## Процедурные текстуры низкого разрешения с ограниченной палитрой —
## как в играх конца 90-х. Потом можно заменить на нарисованные PNG,
## имена оставить те же.

static var _cache := {}


static func get_tex(tex_name: String) -> Texture2D:
	if _cache.has(tex_name):
		return _cache[tex_name]
	var img: Image
	match tex_name:
		"grass": img = _grass()
		"dirt": img = _dirt()
		"concrete": img = _concrete()
		"asphalt": img = _asphalt()
		"wood": img = _wood()
		"wood_red": img = _wood(Color("7a2a1c"), Color("b5462c"))
		"metal": img = _metal()
		"roof": img = _metal(Color("5a2420"), Color("8c3a30"))
		"brick": img = _brick()
		"grip": img = _grip()
		"canopy": img = _canopy()
		"bush": img = _canopy(7)
		"mountains": img = _mountains()
		"graffiti": img = _graffiti()
		_:
			img = TexCatania.make(tex_name)
	if img == null:
		push_warning("Tex: неизвестная текстура %s" % tex_name)
		img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.MAGENTA)
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[tex_name] = t
	return t


# ---------- Утилиты ----------

static func _noise(seed: int, freq: float, octaves := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = octaves
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	return n


static func _seamless(n: FastNoiseLite, size: int) -> Image:
	return n.get_seamless_image(size, size, false, false, 0.2, true)


## Раскраска серой карты в палитру из нескольких ступеней (постеризация)
static func _ramp(v: float, colors: Array) -> Color:
	v = clampf(v, 0.0, 0.999)
	var i := int(v * colors.size())
	return colors[i]


static func _shade(c: Color, f: float) -> Color:
	return Color(c.r * f, c.g * f, c.b * f, c.a)


# ---------- Текстуры ----------

static func _grass() -> Image:
	var s := 64
	var a := _seamless(_noise(11, 0.06), s)
	var b := _seamless(_noise(12, 0.35, 1), s)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var pal := [Color("2f5a1c"), Color("3d6e22"), Color("4f8a2a"), Color("63a032"), Color("7cb83c")]
	for y in s:
		for x in s:
			var v := a.get_pixel(x, y).r * 0.6 + b.get_pixel(x, y).r * 0.4
			img.set_pixel(x, y, _ramp(v, pal))
	return img


static func _dirt() -> Image:
	var s := 64
	var a := _seamless(_noise(21, 0.08), s)
	var b := _seamless(_noise(22, 0.4, 1), s)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var pal := [Color("5a4026"), Color("6e5030"), Color("85633c"), Color("9c7a4c")]
	for y in s:
		for x in s:
			var v := a.get_pixel(x, y).r * 0.5 + b.get_pixel(x, y).r * 0.5
			img.set_pixel(x, y, _ramp(v, pal))
	return img


static func _concrete() -> Image:
	var s := 64
	var a := _seamless(_noise(31, 0.05), s)
	var b := _seamless(_noise(32, 0.5, 1), s)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var pal := [Color("8a8a86"), Color("9b9b96"), Color("aaa9a3"), Color("b8b7b0")]
	for y in s:
		for x in s:
			var v := a.get_pixel(x, y).r * 0.6 + b.get_pixel(x, y).r * 0.4
			var c := _ramp(v, pal)
			if x == 0 or y == 0:
				c = Color("6a6a66")   # шов плиты
			img.set_pixel(x, y, c)
	# Трещина
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var px := 20
	var py := 8
	for i in 40:
		img.set_pixel(posmod(px, s), posmod(py, s), Color("5e5e5a"))
		px += rng.randi_range(-1, 1)
		py += 1
	return img


static func _asphalt() -> Image:
	var s := 64
	var b := _seamless(_noise(41, 0.6, 1), s)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var pal := [Color("34343a"), Color("3e3e44"), Color("48484e"), Color("55555a")]
	for y in s:
		for x in s:
			img.set_pixel(x, y, _ramp(b.get_pixel(x, y).r, pal))
	return img


static func _wood(dark := Color("5c3d22"), light := Color("8e6438")) -> Image:
	var s := 64
	var n := _noise(51, 0.04, 2)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var plank := y / 16
			var v := n.get_noise_2d(x * 0.15 + plank * 37.0, y * 3.0) * 0.5 + 0.5
			var c := dark.lerp(light, floor(v * 4.0) / 4.0)
			if y % 16 == 0:
				c = _shade(dark, 0.6)
			elif (x + plank * 23) % 64 == 0:
				c = _shade(dark, 0.7)
			img.set_pixel(x, y, c)
	return img


static func _metal(dark := Color("8c9096"), light := Color("c4c8cc")) -> Image:
	var s := 64
	var b := _seamless(_noise(61, 0.3, 1), s)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var ridge := 0.5 + 0.5 * sin(x / 8.0 * TAU)
			var v := ridge * 0.7 + b.get_pixel(x, y).r * 0.3
			img.set_pixel(x, y, dark.lerp(light, floor(v * 4.0) / 4.0))
	return img


static func _brick() -> Image:
	var s := 64
	var b := _seamless(_noise(71, 0.4, 1), s)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var pal := [Color("7a3020"), Color("8e3a26"), Color("a0462e")]
	for y in s:
		for x in s:
			var row := y / 8
			var off := 8 if row % 2 == 1 else 0
			var mortar := y % 8 == 0 or (x + off) % 16 == 0
			var c := Color("b0a898") if mortar else _ramp(b.get_pixel(x, y).r, pal)
			img.set_pixel(x, y, c)
	return img


static func _grip() -> Image:
	var s := 32
	var b := _seamless(_noise(81, 0.9, 1), s)
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			img.set_pixel(x, y, _ramp(b.get_pixel(x, y).r, [Color("1a1a1e"), Color("242428"), Color("303036")]))
	return img


static func _canopy(seed := 91) -> Image:
	## Крона дерева со стволом, с прозрачностью — для спрайтов-«крестов»
	var w := 64
	var h := 80
	var n := _noise(seed, 0.12, 2)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var pal := [Color("1f4416"), Color("2c5a1c"), Color("3c7424"), Color("52902e")]
	var trunk := seed == 91
	for y in h:
		for x in w:
			var dx := (x - w * 0.5) / (w * 0.5)
			var dy := (y - 30.0) / 30.0
			var d := sqrt(dx * dx + dy * dy)
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			if d + (v - 0.5) * 0.5 < 0.9:
				var light := clampf(v - dy * 0.25 - dx * 0.1, 0.0, 1.0)
				img.set_pixel(x, y, _ramp(light, pal))
			elif trunk and absf(x - w * 0.5) < 3.0 + (y - 50) * 0.05 and y > 45:
				img.set_pixel(x, y, Color("4a3220") if x % 3 else Color("3a2618"))
	return img


static func _mountains() -> Image:
	## Панорама гор для фона: два слоя силуэтов, дымка, прозрачное небо
	var w := 512
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var far := _noise(101, 0.012, 3)
	var near := _noise(102, 0.02, 3)
	var tex := _noise(103, 0.15, 1)
	for x in w:
		# Бесшовность по горизонтали: сэмплируем по кругу
		var ang := float(x) / w * TAU
		var fx := cos(ang) * 80.0
		var fy := sin(ang) * 80.0
		var h_far := int(h * (0.25 + 0.35 * (far.get_noise_2d(fx, fy) * 0.5 + 0.5)))
		var h_near := int(h * (0.1 + 0.25 * (near.get_noise_2d(fx + 300.0, fy) * 0.5 + 0.5)))
		for y in h:
			var from_bottom := h - 1 - y
			var t := tex.get_noise_2d(x, y) * 0.5 + 0.5
			if from_bottom < h_near:
				var c := Color("2a3f2a").lerp(Color("3d5a34"), floor(t * 3.0) / 3.0)
				img.set_pixel(x, y, c)
			elif from_bottom < h_far:
				var k := float(from_bottom) / h_far
				var c2 := Color("4a5a9a").lerp(Color("6a78b8"), floor((t * 0.5 + k * 0.5) * 3.0) / 3.0)
				img.set_pixel(x, y, c2)
	return img


static func _graffiti() -> Image:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	var n := _noise(111, 0.08, 2)
	var cols := [Color("ff2bd6"), Color("00e5ff"), Color("ffe600"), Color("39ff14")]
	for y in s:
		for x in s:
			var v := n.get_noise_2d(x, y) * 0.5 + 0.5
			var base := Color("9a4030") if (y % 8 == 0 or (x + (8 if (y / 8) % 2 else 0)) % 16 == 0) else Color("b05a3a")
			if v > 0.55:
				base = cols[int(v * 17.0) % cols.size()]
			if v > 0.53 and v < 0.56:
				base = Color.BLACK
			img.set_pixel(x, y, base)
	return img
