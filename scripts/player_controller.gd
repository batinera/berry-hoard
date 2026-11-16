extends CharacterBody3D

const SPEED := 8.5
const HAND_REACH := 6.5
const JUMP_VELOCITY := 4.5
const MOUSE_SENS := 0.003
const BASE_COLLECT_FORCE := 14.0

@onready var camera: Camera3D = $Camera3D
@onready var fp_tools: Node3D = $Camera3D/FPTools
@onready var reach_area: Area3D = $ReachArea
@onready var reach_shape: CollisionShape3D = $ReachArea/CollisionShape3D

var _pulling: bool = false
var _physics_tick: int = 0
var _harvester_timer: float = 0.0
var _look_enabled: bool = true
var _hand_cd: float = 0.0
var _ocean: Node = null


func _ready() -> void:
	add_to_group("player")
	call_deferred("_capture_mouse")
	call_deferred("_find_ocean")
	GameState.tool_changed.connect(_on_tool_changed)
	GameState.proficiencies_changed.connect(_refresh_reach_radius)
	_refresh_reach_radius()


func _find_ocean() -> void:
	_ocean = get_tree().get_first_node_in_group("berry_ocean")


func _capture_mouse() -> void:
	if _look_enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		call_deferred("_capture_mouse")


func set_look_enabled(enabled: bool) -> void:
	_look_enabled = enabled
	if enabled:
		_capture_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _refresh_reach_radius() -> void:
	if reach_shape and reach_shape.shape is SphereShape3D:
		(reach_shape.shape as SphereShape3D).radius = GameState.reach_radius


func _on_tool_changed(_tool: GameState.Tool) -> void:
	_pulling = false
	if fp_tools and fp_tools.has_method("set_magnet_pulling"):
		fp_tools.set_magnet_pulling(false)


func _input(event: InputEvent) -> void:
	if not _look_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera.rotate_x(-event.relative.y * MOUSE_SENS)
		camera.rotation.x = clampf(camera.rotation.x, -1.45, 1.45)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		set_look_enabled(false)
	if event.is_action_pressed("tool_hand"):
		GameState.set_tool(GameState.Tool.HAND)
	if event.is_action_pressed("tool_harvester") and GameState.harvester_unlocked:
		GameState.set_tool(GameState.Tool.HARVESTER)
	if event.is_action_pressed("tool_magnet") and GameState.magnet_unlocked:
		GameState.set_tool(GameState.Tool.MAGNET)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_tool(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_tool(1)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			_capture_mouse()
		elif GameState.active_tool == GameState.Tool.HAND:
			_try_click_collect()
			if fp_tools and fp_tools.has_method("play_grab"):
				fp_tools.play_grab()
		elif GameState.active_tool == GameState.Tool.MAGNET:
			_pulling = true
			if fp_tools and fp_tools.has_method("set_magnet_pulling"):
				fp_tools.set_magnet_pulling(true)
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if GameState.active_tool == GameState.Tool.MAGNET:
			_pulling = false
			if fp_tools and fp_tools.has_method("set_magnet_pulling"):
				fp_tools.set_magnet_pulling(false)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)
	move_and_slide()
	_hand_cd = maxf(0.0, _hand_cd - delta)
	if _ocean == null:
		_find_ocean()

	_physics_tick += 1
	match GameState.active_tool:
		GameState.Tool.MAGNET:
			if _pulling:
				_pull_berries()
		GameState.Tool.HARVESTER:
			_harvester_timer -= delta
			if _harvester_timer <= 0.0:
				_harvester_timer = GameState.harvester_cooldown
				_harvester_tick()
				if fp_tools and fp_tools.has_method("play_grab"):
					fp_tools.play_grab()

	if _physics_tick % 4 == 0:
		_update_interact_hint()


func _try_click_collect() -> void:
	if _hand_cd > 0.0:
		return
	if _ocean:
		var from := camera.global_position
		var dir := -camera.global_basis.z
		if _ocean.collect_from_ray(from, dir, HAND_REACH):
			_hand_cd = GameState.hand_click_cooldown
		return
	var hit := _aim_raycast_physics()
	if hit.is_empty():
		return
	var collider := hit.collider as Node
	if collider and collider.has_method("try_collect_from_aim"):
		if collider.call("try_collect_from_aim"):
			_hand_cd = GameState.hand_click_cooldown


func _pull_berries() -> void:
	var origin := _interaction_origin()
	var strength := GameState.reach_radius * 1.8
	if _ocean:
		_ocean.pull_in_radius(origin, strength, BASE_COLLECT_FORCE * GameState.magnet_force_mult)
		return
	var force := BASE_COLLECT_FORCE * GameState.magnet_force_mult
	for body in reach_area.get_overlapping_bodies():
		if body is StaticBody3D and body.has_method("apply_pull"):
			body.apply_pull(origin, strength, force)


func _harvester_tick() -> void:
	if _ocean:
		var origin := _interaction_origin()
		_ocean.pull_in_radius(origin, GameState.reach_radius * 1.1, BASE_COLLECT_FORCE * 0.9)
		_ocean.collect_nearest(origin, GameState.reach_radius)
		return
	var closest: Node3D = null
	var closest_dist := INF
	for body in reach_area.get_overlapping_bodies():
		if not body.has_method("try_collect_at_player"):
			continue
		var dist := global_position.distance_squared_to(body.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = body
	if closest and closest.has_method("try_collect_at_player"):
		if closest.has_method("apply_pull"):
			closest.apply_pull(_interaction_origin(), GameState.reach_radius * 1.2, BASE_COLLECT_FORCE * 0.8)
		closest.try_collect_at_player(self)


func _interaction_origin() -> Vector3:
	if fp_tools and fp_tools.has_method("get_interaction_origin"):
		return fp_tools.get_interaction_origin()
	return camera.global_position + (-camera.global_basis.z) * 0.6


func _update_interact_hint() -> void:
	if _ocean:
		var from := camera.global_position
		var dir := -camera.global_basis.z
		var reach := HAND_REACH if GameState.active_tool == GameState.Tool.HAND else GameState.reach_radius * 2.2
		GameState.interact_highlight = _ocean.ray_pick(from, dir, reach) >= 0
		return
	GameState.interact_highlight = not _aim_raycast_physics().is_empty()


func _cycle_tool(step: int) -> void:
	var order: Array[GameState.Tool] = [GameState.Tool.HAND]
	if GameState.harvester_unlocked:
		order.append(GameState.Tool.HARVESTER)
	if GameState.magnet_unlocked:
		order.append(GameState.Tool.MAGNET)
	if order.size() <= 1:
		return
	var idx := order.find(GameState.active_tool)
	if idx < 0:
		idx = 0
	idx = (idx + step) % order.size()
	if idx < 0:
		idx += order.size()
	GameState.set_tool(order[idx])


func _aim_raycast_physics() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var reach := HAND_REACH if GameState.active_tool == GameState.Tool.HAND else GameState.reach_radius * 2.2
	var to := from + (-camera.global_basis.z) * reach
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collision_mask = 2
	return space.intersect_ray(query)