extends Node3D

const TOOL_OFFSET := Vector3(0.45, -0.36, -0.78)

@onready var hand: Node3D = $Hand
@onready var harvester: Node3D = $Harvester
@onready var magnet: Node3D = $Magnet
@onready var magnet_glow: MeshInstance3D = $Magnet/Core/Glow

var _magnet_active: bool = false
var _grab_time: float = 0.0
var _harvester_spin: float = 0.0


func _ready() -> void:
	GameState.tool_changed.connect(_on_tool_changed)
	call_deferred("_refresh_visibility", GameState.active_tool)


func _process(delta: float) -> void:
	_grab_time = maxf(0.0, _grab_time - delta * 3.0)
	var sway := sin(Time.get_ticks_msec() * 0.004) * 0.012
	position = TOOL_OFFSET + Vector3(0.0, sway, _grab_time * 0.15)

	match GameState.active_tool:
		GameState.Tool.HAND:
			hand.rotation.x = -_grab_time * 0.35
		GameState.Tool.HARVESTER:
			_harvester_spin += delta * 7.0
			harvester.get_node("Head").rotation.y = _harvester_spin
		GameState.Tool.MAGNET:
			var pulse := 1.0
			if _magnet_active:
				pulse = 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.08
			magnet.scale = Vector3.ONE * pulse
			if magnet_glow:
				magnet_glow.visible = _magnet_active


func play_grab() -> void:
	_grab_time = 1.0


func set_magnet_pulling(active: bool) -> void:
	_magnet_active = active
	if magnet_glow:
		magnet_glow.visible = active and magnet.visible


func get_interaction_origin() -> Vector3:
	var tool_root: Node3D = _active_tool_node()
	return tool_root.global_position + (-tool_root.global_basis.z) * 0.55


func _active_tool_node() -> Node3D:
	match GameState.active_tool:
		GameState.Tool.HARVESTER:
			return harvester.get_node("Head")
		GameState.Tool.MAGNET:
			return magnet.get_node("Core")
	return hand.get_node("Palm")


func _on_tool_changed(tool: GameState.Tool) -> void:
	_refresh_visibility(tool)


func _refresh_visibility(tool: GameState.Tool) -> void:
	hand.visible = tool == GameState.Tool.HAND
	harvester.visible = tool == GameState.Tool.HARVESTER
	magnet.visible = tool == GameState.Tool.MAGNET
	_magnet_active = false
	if magnet_glow:
		magnet_glow.visible = false