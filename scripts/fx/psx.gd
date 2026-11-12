class_name Psx
extends RefCounted
## Фабрика материалов. Стиль — Y2K: гладкие сглаженные текстуры,
## глянцевый пластик с бликом и ободком света (rim), хром, мягкое свечение.
## (Имя класса осталось с PS1-версии, чтобы не трогать весь код.)
## Мир текстурируется в мировых координатах (triplanar), развёртка не нужна.

static var _cache := {}


## tex_name — имя из Tex.get_tex() или "" для сплошного цвета
## scale — повторов текстуры на метр (для use_uv — множитель UV)
static func mat(tex_name: String, tint := Color.WHITE, scale := 0.25, use_uv := false, cutout := false, glow := 0.0, _jitter := true) -> StandardMaterial3D:
	var key := "m|%s|%s|%s|%s|%s|%s" % [tex_name, tint.to_html(), scale, use_uv, cutout, glow]
	if _cache.has(key):
		return _cache[key]
	var m := _base(tint)
	m.roughness = 0.55
	if tex_name != "":
		m.albedo_texture = Tex.get_tex(tex_name)
		if use_uv:
			m.uv1_scale = Vector3(scale, scale, 1.0)
		else:
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_triplanar_sharpness = 4.0
			m.uv1_scale = Vector3.ONE * scale
	if cutout:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.rim_enabled = false
	_glow(m, glow)
	_cache[key] = m
	return m


## Фасады: тайл текстуры = пролёт (tile.x м) × этаж (tile.y м)
static func wall(tex_name: String, tile: Vector2, tint := Color.WHITE, cutout := false) -> StandardMaterial3D:
	var key := "w|%s|%s|%s|%s" % [tex_name, tile, tint.to_html(), cutout]
	if _cache.has(key):
		return _cache[key]
	var m := _base(tint)
	m.roughness = 0.6
	m.albedo_texture = Tex.get_tex(tex_name)
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3(1.0 / tile.x, -1.0 / tile.y, 1.0 / tile.x)
	m.rim_enabled = false
	if cutout:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.alpha_scissor_threshold = 0.5
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache[key] = m
	return m


## Глянцевый пластик — для персонажей, самоката, мелочей
static func color(c: Color, glow := 0.0) -> StandardMaterial3D:
	var key := "c|%s|%s" % [c.to_html(), glow]
	if _cache.has(key):
		return _cache[key]
	var m := _base(c)
	m.roughness = 0.28
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	m.clearcoat_roughness = 0.15
	_glow(m, glow)
	_cache[key] = m
	return m


## Хром / зеркальный металл
static func chrome(c := Color("dfe6f0")) -> StandardMaterial3D:
	var key := "chrome|%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := _base(c)
	m.metallic = 1.0
	m.roughness = 0.12
	m.rim_enabled = false
	_cache[key] = m
	return m


## Перламутр / «голография»: металлик с ободком и лёгким свечением
static func pearl(c: Color, glow_tint := Color("7ff6ff")) -> StandardMaterial3D:
	var key := "pearl|%s|%s" % [c.to_html(), glow_tint.to_html()]
	if _cache.has(key):
		return _cache[key]
	var m := _base(c)
	m.metallic = 0.75
	m.roughness = 0.18
	m.rim = 1.0
	m.rim_tint = 0.0
	m.emission_enabled = true
	m.emission = glow_tint * 0.15
	m.clearcoat_enabled = true
	m.clearcoat = 1.0
	_cache[key] = m
	return m


static func _base(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.6
	return m


static func _glow(m: StandardMaterial3D, glow: float) -> void:
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = m.albedo_color
		m.emission_energy_multiplier = glow * 1.5
