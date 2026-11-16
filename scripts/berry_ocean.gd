extends Node3D


@export var cols: int = 94
@export var rows: int = 76
@export var half_extents: Vector3 = Vector3(25.2, 0.0, 33.2)
@export var berry_radius: float = 0.24
@export var edge_extra_layers: int = 3600
@export var cell_size: float = 0.45
@export var settle_passes_on_load: int = 10
@export var settle_passes_on_collect: int = 14

var _positions: PackedVector3Array = PackedVector3Array()
var _yaws: PackedFloat32Array = PackedFloat32Array()
var _active: PackedByteArray = PackedByteArray()
var _multimesh: MultiMeshInstance3D
var _rng := RandomNumberGenerator.new()
var _grid_w: int = 0
var _grid_d: int = 0
var _grid_origin: Vector2 = Vector2.ZERO
var _cell_lists: Array = []


func _ready() -> void:
	_rng.randomize()
	_build_positions()
	_relax_all_active(settle_passes_on_load)
	_create_multimesh()
	add_to_group("berry_ocean")


func berry_count_active() -> int:
	var n := 0
	for i in _active.size():
		if _active[i] == 1:
			n += 1
	return n


func ray_pick(from: Vector3, dir: Vector3, max_dist: float) -> int:
	dir = dir.normalized()
	var best_i := -1
	var best_t := max_dist
	for i in _positions.size():
		if _active[i] == 0:
			continue
		var center := _global_center(i)
		var t := _ray_sphere_t(from, dir, center, berry_radius * 1.04)
		if t >= 0.0 and t < best_t:
			best_t = t
			best_i = i
	return best_i


func collect_from_ray(from: Vector3, dir: Vector3, max_dist: float) -> bool:
	var idx := ray_pick(from, dir, max_dist)
	if idx < 0:
		return false
	if not GameState.try_collect():
		return false
	_deactivate(idx)
	return true


func pull_in_radius(origin: Vector3, radius: float, strength: float) -> void:
	var r2 := radius * radius
	for i in _positions.size():
		if _active[i] == 0:
			continue
		var pos := _positions[i]
		var gpos := _global_center(i)
		var offset := origin - gpos
		var dist2 := offset.length_squared()
		if dist2 > r2 or dist2 < 0.0001:
			continue
		var dist := sqrt(dist2)
		offset.y = 0.0
		if offset.length_squared() < 0.0001:
			continue
		var step: float = clampf(strength * 0.035 * (1.0 - dist / radius), 0.01, 0.14)
		pos += global_basis.inverse() * (offset.normalized() * step)
		pos.x = clampf(pos.x, -half_extents.x, half_extents.x)
		pos.z = clampf(pos.z, -half_extents.z, half_extents.z)
		pos.y = _support_center_y(pos.x, pos.z, i)
		_positions[i] = pos
		_update_instance(i, pos)
	_rebuild_cell_lists()


func collect_nearest(origin: Vector3, radius: float) -> bool:
	var best_i := -1
	var best_d := radius * radius
	for i in _positions.size():
		if _active[i] == 0:
			continue
		var d2 := origin.distance_squared_to(_global_center(i))
		if d2 < best_d:
			best_d = d2
			best_i = i
	if best_i < 0:
		return false
	if not GameState.try_collect():
		return false
	_deactivate(best_i)
	return true


func _global_center(i: int) -> Vector3:
	return global_transform * _positions[i]


func _build_positions() -> void:
	_positions.clear()
	_yaws.clear()
	_active.clear()
	_init_spatial_grid()
	var xz_slots: Array[Vector2] = []
	for row in rows:
		for col in cols:
			var fx := float(col) / maxf(1.0, float(cols - 1))
			var fz := float(row) / maxf(1.0, float(rows - 1))
			var x := lerpf(-half_extents.x, half_extents.x, fx)
			var z := lerpf(-half_extents.z, half_extents.z, fz)
			x += _rng.randf_range(-0.08, 0.08)
			z += _rng.randf_range(-0.08, 0.08)
			xz_slots.append(Vector2(x, z))
	for _i in edge_extra_layers:
		var x := _rng.randf_range(-half_extents.x, half_extents.x)
		var z := _rng.randf_range(-half_extents.z, half_extents.z)
		var edge := maxf(absf(x) / half_extents.x, absf(z) / half_extents.z)
		if edge < 0.58:
			continue
		xz_slots.append(Vector2(x, z))
	_shuffle_xy(xz_slots)
	for xz in xz_slots:
		var y := _support_center_y(xz.x, xz.y, -1)
		_positions.append(Vector3(xz.x, y, xz.y))
		_yaws.append(_rng.randf_range(0.0, TAU))
		_active.append(1)
		var idx := _positions.size() - 1
		_cell_lists[_cell_index(_cell_coord(xz.x, xz.y))].append(idx)


func _support_center_y(x: float, z: float, skip_i: int) -> float:
	var min_center_y := BerryField.WAREHOUSE_FLOOR_Y + berry_radius
	var reach2 := pow(berry_radius * 2.0, 2.0)
	var ci := _cell_coord(x, z)
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			var cell := ci + Vector2i(dx, dz)
			if not _cell_in_bounds(cell):
				continue
			for idx in _cell_lists[_cell_index(cell)]:
				if idx == skip_i or _active[idx] == 0:
					continue
				var p := _positions[idx]
				var d2 := (p.x - x) * (p.x - x) + (p.z - z) * (p.z - z)
				if d2 >= reach2:
					continue
				var d := sqrt(d2)
				var stack_y: float = p.y + sqrt(maxf(0.0, 4.0 * berry_radius * berry_radius - d * d))
				min_center_y = maxf(min_center_y, stack_y)
	return min_center_y


func _relax_all_active(passes: int) -> void:
	for _p in passes:
		var changed := false
		var order: Array[int] = []
		for i in _positions.size():
			if _active[i] == 1:
				order.append(i)
		order.sort_custom(func(a: int, b: int) -> bool: return _positions[a].y < _positions[b].y)
		for i in order:
			var pos := _positions[i]
			var ny := _support_center_y(pos.x, pos.z, i)
			if absf(ny - pos.y) > 0.0008:
				pos.y = ny
				_positions[i] = pos
				changed = true
		if not changed:
			break
	_rebuild_cell_lists()


func _init_spatial_grid() -> void:
	_grid_origin = Vector2(-half_extents.x, -half_extents.z)
	_grid_w = int(ceil((half_extents.x * 2.0) / cell_size)) + 2
	_grid_d = int(ceil((half_extents.z * 2.0) / cell_size)) + 2
	_cell_lists.clear()
	_cell_lists.resize(_grid_w * _grid_d)
	for i in _cell_lists.size():
		_cell_lists[i] = []


func _rebuild_cell_lists() -> void:
	for i in _cell_lists.size():
		_cell_lists[i].clear()
	for i in _positions.size():
		if _active[i] == 0:
			continue
		var cell := _cell_coord(_positions[i].x, _positions[i].z)
		_cell_lists[_cell_index(cell)].append(i)


func _cell_coord(x: float, z: float) -> Vector2i:
	var lx := x - _grid_origin.x
	var lz := z - _grid_origin.y
	return Vector2i(
		clampi(int(floor(lx / cell_size)), 0, _grid_w - 1),
		clampi(int(floor(lz / cell_size)), 0, _grid_d - 1)
	)


func _cell_index(cell: Vector2i) -> int:
	return cell.y * _grid_w + cell.x


func _cell_in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _grid_w and cell.y < _grid_d


func _shuffle_xy(list: Array[Vector2]) -> void:
	for i in range(list.size() - 1, -1, -1):
		var j := _rng.randi_range(0, i)
		var tmp := list[i]
		list[i] = list[j]
		list[j] = tmp


func _create_multimesh() -> void:
	_multimesh = MultiMeshInstance3D.new()
	_multimesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_multimesh.material_override = BerryMultimeshMesh.body_material()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = _positions.size()
	mm.mesh = BerryMultimeshMesh.build(berry_radius)
	_multimesh.multimesh = mm
	add_child(_multimesh)
	for i in _positions.size():
		_update_instance(i, _positions[i])


func _update_instance(i: int, pos: Vector3) -> void:
	var yaw := _yaws[i] if i < _yaws.size() else 0.0
	var basis := Basis(Vector3.UP, yaw)
	var t := Transform3D(basis, pos)
	_multimesh.multimesh.set_instance_transform(i, t)


func _deactivate(i: int) -> void:
	_active[i] = 0
	var hidden := Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3(0.0, -200.0, 0.0))
	_multimesh.multimesh.set_instance_transform(i, hidden)
	_rebuild_cell_lists()
	_relax_all_active(settle_passes_on_collect)


func _ray_sphere_t(from: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var oc := from - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return -1.0
	var t := -b - sqrt(disc)
	return t if t >= 0.0 else -1.0