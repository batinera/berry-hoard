extends StaticBody3D

@export var collect_force: float = 14.0

var _collected: bool = false
var _pull_speed: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 0


func settle_on_floor() -> void:
	global_position = BerryField.ray_snap(get_world_3d(), global_position.x, global_position.z)


func apply_pull(origin: Vector3, strength: float, force: float = -1.0) -> void:
	if _collected:
		return
	var offset := origin - global_position
	var dist := offset.length()
	if dist < 0.08:
		return
	var mult := force if force > 0.0 else collect_force
	var step: float = clampf(mult * 0.0045 * clampf(1.0 - dist / strength, 0.0, 1.0), 0.01, 0.14)
	global_position += offset.normalized() * step


func try_collect_at_player(player: Node3D) -> bool:
	if _collected:
		return false
	if global_position.distance_to(player.global_position) > GameState.reach_radius:
		return false
	return _collect_into_bag()


func try_collect_from_aim() -> bool:
	if _collected:
		return false
	return _collect_into_bag()


func _collect_into_bag() -> bool:
	if not GameState.try_collect():
		return false
	_collected = true
	queue_free()
	return true