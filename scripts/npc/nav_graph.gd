class_name NavGraph
extends RefCounted
## Граф маршрутов: тротуары для пешеходов или дороги для машин.
## Собирается из ломаных; точки ближе MERGE метров склеиваются в один узел,
## так получаются перекрёстки.
## Элемент ломаной — Vector3 или [Vector3, лимит_скорости, по_центру].
##   лимит_скорости > 0 — на подходе к узлу ехать не быстрее (шиканы)
##   по_центру = true — узел без смещения в полосу (объезд блоков)

const MERGE := 1.0

var points := PackedVector3Array()
var slow := PackedFloat32Array()
var center: Array[bool] = []
var links: Array[PackedInt32Array] = []


func add_polyline(pts: Array) -> void:
	var prev := -1
	for e in pts:
		var p: Vector3
		var s := 0.0
		var c := false
		if e is Array:
			p = e[0]
			if e.size() > 1:
				s = e[1]
			if e.size() > 2:
				c = e[2]
		else:
			p = e
		var i := _node(p, s, c)
		if prev >= 0 and prev != i:
			link(prev, i)
		prev = i


func add_grid(xs: Array, zs: Array, blocked_center := Vector3.INF, blocked_radius := 0.0) -> void:
	## Сетка дорожек по открытой площади; рёбра через круг blocked обходятся
	var idx := {}
	for xi in xs.size():
		for zi in zs.size():
			var p := Vector3(xs[xi], 0, zs[zi])
			if blocked_center != Vector3.INF and p.distance_to(blocked_center) < blocked_radius:
				continue
			idx[Vector2i(xi, zi)] = _node(p, 0.0, false)
	for key in idx:
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var other: Vector2i = key + d
			if idx.has(other):
				var a := points[idx[key]]
				var b := points[idx[other]]
				if blocked_center == Vector3.INF or _seg_dist(blocked_center, a, b) > blocked_radius:
					link(idx[key], idx[other])


func add_ring(c: Vector3, r: float, n: int) -> PackedInt32Array:
	var ids := PackedInt32Array()
	for i in n:
		var a := TAU * i / n
		ids.append(_node(c + Vector3(cos(a), 0, sin(a)) * r, 0.0, false))
	for i in n:
		link(ids[i], ids[(i + 1) % n])
	return ids


func connect_to_nearest(ids: PackedInt32Array, max_dist: float) -> void:
	## Соединяет узлы кольца с ближайшими узлами остального графа
	for i in ids:
		var best := -1
		var bd := max_dist
		for j in points.size():
			if ids.has(j):
				continue
			var d := points[i].distance_to(points[j])
			if d < bd:
				bd = d
				best = j
		if best >= 0:
			link(i, best)


func link(a: int, b: int) -> void:
	if not links[a].has(b):
		links[a].append(b)
	if not links[b].has(a):
		links[b].append(a)


func nearest(p: Vector3) -> int:
	var best := 0
	var bd := INF
	for i in points.size():
		var d := points[i].distance_squared_to(p)
		if d < bd:
			bd = d
			best = i
	return best


func terminals() -> PackedInt32Array:
	var out := PackedInt32Array()
	for i in points.size():
		if links[i].size() == 1:
			out.append(i)
	return out


func next_from(cur: int, prev: int, rng: RandomNumberGenerator) -> int:
	var opts := links[cur]
	if opts.is_empty():
		return cur
	if opts.size() == 1:
		return opts[0]          # тупик — разворот
	var choices: Array[int] = []
	for o in opts:
		if o != prev:
			choices.append(o)
	return choices[rng.randi() % choices.size()]


func random_route(start: int, rng: RandomNumberGenerator, max_steps := 60) -> PackedInt32Array:
	## Случайный маршрут от тупика до другого тупика без разворотов
	var route := PackedInt32Array([start])
	var prev := -1
	var cur := start
	for i in max_steps:
		var nxt := next_from(cur, prev, rng)
		if nxt == prev or nxt == cur:
			break
		route.append(nxt)
		prev = cur
		cur = nxt
		if links[cur].size() == 1:
			break
	return route


func route_points(route: PackedInt32Array, lane: float) -> Array[Dictionary]:
	## Точки маршрута со смещением в правую полосу
	var out: Array[Dictionary] = []
	for k in route.size():
		var i := route[k]
		var a := points[route[maxi(k - 1, 0)]]
		var b := points[route[mini(k + 1, route.size() - 1)]]
		var dir := b - a
		dir.y = 0.0
		var right := dir.normalized().cross(Vector3.UP) if dir.length() > 0.01 else Vector3.ZERO
		var off := 0.0 if center[i] else lane
		out.append({"pos": points[i] + right * off, "slow": slow[i]})
	return out


func _node(p: Vector3, s: float, c: bool) -> int:
	for i in points.size():
		if points[i].distance_to(p) < MERGE:
			if s > 0.0:
				slow[i] = s
			if c:
				center[i] = true
			return i
	points.append(p)
	slow.append(s)
	center.append(c)
	links.append(PackedInt32Array())
	return points.size() - 1


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)
