extends Node3D

@export var berry_scene: PackedScene
@export var grid_cols: int = 92
@export var grid_rows: int = 74
@export var spawn_half_extents: Vector3 = Vector3(22.0, 0.0, 28.0)
@export var layer_height_jitter: float = 0.06
@export var spawn_batch: int = 24

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	await get_tree().physics_frame
	var spawned := 0
	for row in grid_rows:
		for col in grid_cols:
			_spawn_at_grid(col, row)
			spawned += 1
			if spawned % spawn_batch == 0:
				await get_tree().physics_frame


func _spawn_at_grid(col: int, row: int) -> void:
	if berry_scene == null:
		return
	var fx := float(col) / maxf(1.0, float(grid_cols - 1))
	var fz := float(row) / maxf(1.0, float(grid_rows - 1))
	var x := lerpf(-spawn_half_extents.x, spawn_half_extents.x, fx)
	var z := lerpf(-spawn_half_extents.z, spawn_half_extents.z, fz)
	x += _rng.randf_range(-0.08, 0.08)
	z += _rng.randf_range(-0.08, 0.08)
	var jitter := _rng.randf_range(0.0, layer_height_jitter)

	var world_x := global_position.x + x
	var world_z := global_position.z + z
	var pos := BerryField.ray_snap(get_world_3d(), world_x, world_z, jitter)

	var berry := berry_scene.instantiate() as Node3D
	add_child(berry)
	berry.global_position = pos
	if berry.has_method("settle_on_floor"):
		berry.settle_on_floor()