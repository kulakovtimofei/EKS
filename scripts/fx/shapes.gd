class_name Shapes
extends RefCounted
## Обтекаемые формы вместо коробок — для Y2K-стиля.
## rounded(size) по пропорциям выбирает:
##   тонкая пластина (одна сторона < 7 см) → коробка (деки, козырьки)
##   вытянутая деталь                     → капсула вдоль длинной оси
##   «кубик»                              → эллипсоид
## Поворот и масштаб запекаются в меш, чтобы снаружи всё работало как с BoxMesh.

static var _cache := {}


static func rounded(size: Vector3) -> Mesh:
	var key := "%.3f|%.3f|%.3f" % [size.x, size.y, size.z]
	if _cache.has(key):
		return _cache[key]
	var dims := [size.x, size.y, size.z]
	var smallest: float = dims.min()
	var longest: float = dims.max()
	var axis := dims.find(longest)
	var others: Array = dims.duplicate()
	others.remove_at(axis)
	var mid: float = others.max()
	var mesh: Mesh
	if smallest < 0.07:
		var b := BoxMesh.new()
		b.size = size
		mesh = b
	elif longest / mid > 1.6:
		var cap := CapsuleMesh.new()
		var r: float = (others[0] + others[1]) * 0.25
		cap.radius = r
		cap.height = maxf(longest, r * 2.0 + 0.01)
		cap.radial_segments = 14
		cap.rings = 4
		# Сплющиваем поперечное сечение под пропорции детали
		var sx: float = others[0] / (r * 2.0)
		var sz: float = others[1] / (r * 2.0)
		var basis := Basis.from_scale(Vector3(sx, 1.0, sz))
		match axis:
			0: basis = Basis(Vector3.BACK, PI * 0.5) * Basis.from_scale(Vector3(others[0] / (r * 2.0), 1.0, others[1] / (r * 2.0)))
			2: basis = Basis(Vector3.RIGHT, PI * 0.5) * Basis.from_scale(Vector3(others[0] / (r * 2.0), 1.0, others[1] / (r * 2.0)))
		mesh = _bake(cap, basis)
	else:
		var sp := SphereMesh.new()
		sp.radius = 0.5
		sp.height = 1.0
		sp.radial_segments = 16
		sp.rings = 10
		mesh = _bake(sp, Basis.from_scale(size))
	_cache[key] = mesh
	return mesh


static func _bake(src: Mesh, basis: Basis) -> Mesh:
	var st := SurfaceTool.new()
	st.append_from(src, 0, Transform3D(basis, Vector3.ZERO))
	st.generate_normals()
	return st.commit()
