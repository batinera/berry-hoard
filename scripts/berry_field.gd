extends Node
## Alturas do canteiro (topo da terra em y ≈ 0.40).

const DIRT_SURFACE_Y := 0.40
const WAREHOUSE_FLOOR_Y := 0.0
const BERRY_RADIUS := 0.26
const FLOOR_COLLISION_MASK := 1


func berry_center_on_surface(world_x: float, world_z: float, height_jitter: float = 0.0) -> Vector3:
	var y: float = DIRT_SURFACE_Y + BERRY_RADIUS + height_jitter
	return Vector3(world_x, y, world_z)


func ray_snap(world: World3D, world_x: float, world_z: float, height_jitter: float = 0.0) -> Vector3:
	var space := world.direct_space_state
	var from := Vector3(world_x, 8.0, world_z)
	var to := Vector3(world_x, -2.0, world_z)
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = FLOOR_COLLISION_MASK
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return berry_center_on_surface(world_x, world_z, height_jitter)
	var y: float = hit.position.y + BERRY_RADIUS + height_jitter
	return Vector3(world_x, y, world_z)