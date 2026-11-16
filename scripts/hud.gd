extends CanvasLayer

const SLOT_ACTIVE := Color(1.15, 1.12, 1.0)
const SLOT_IDLE := Color(0.72, 0.72, 0.76)

@onready var total_label: Label = $Root/TopLeft/HBox/Stats/TotalLabel
@onready var gain_label: Label = $Root/TopLeft/HBox/Stats/GainLabel
@onready var goal_label: Label = $Root/TopLeft/HBox/Stats/GoalLabel
@onready var bag_label: Label = $Root/BagBar/VBox/BagLabel
@onready var bag_progress: ProgressBar = $Root/BagBar/VBox/BagProgress
@onready var hand_btn: Button = $Root/Hotbar/HBox/HandBtn
@onready var harvester_btn: Button = $Root/Hotbar/HBox/HarvesterBtn
@onready var magnet_btn: Button = $Root/Hotbar/HBox/MagnetBtn
@onready var prof_button: Button = $Root/ProficienciesBtn/VBox/ProfButton
@onready var prof_points: Label = $Root/ProficienciesBtn/VBox/ProfPoints
@onready var prof_panel: PanelContainer = $ProficienciesPanel
@onready var prof_list: VBoxContainer = $ProficienciesPanel/Margin/VBox/List
@onready var crosshair: ColorRect = $CrosshairLayer/Crosshair
@onready var interact_tip: Label = $CrosshairLayer/InteractTip


func _ready() -> void:
	GameState.berries_changed.connect(_on_berries_changed)
	GameState.tool_changed.connect(_on_tool_changed)
	GameState.proficiencies_changed.connect(_on_proficiencies_changed)
	GameState.proficiencies_changed.connect(_rebuild_proficiencies)
	GameState.interact_hint_changed.connect(_on_interact_hint)
	GameState.tool_changed.connect(_refresh_interact_text)
	hand_btn.pressed.connect(func(): GameState.set_tool(GameState.Tool.HAND))
	harvester_btn.pressed.connect(func(): GameState.set_tool(GameState.Tool.HARVESTER))
	magnet_btn.pressed.connect(func(): GameState.set_tool(GameState.Tool.MAGNET))
	prof_button.pressed.connect(_toggle_proficiencies)
	_on_berries_changed(GameState.berries_total, GameState.berries_in_bag, GameState.bag_max)
	_on_tool_changed(GameState.active_tool)
	_rebuild_proficiencies()
	_refresh_tool_locks()
	prof_panel.hide()
	_passthrough_ui()


func _passthrough_ui() -> void:
	var root: Control = $Root
	for child in root.get_children():
		if child is Control:
			if child == $Root/Hotbar or child == $Root/ProficienciesBtn:
				continue
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	_passthrough_recursive(root)


func _passthrough_recursive(node: Node) -> void:
	for child in node.get_children():
		if child is Button:
			continue
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		_passthrough_recursive(child)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_proficiencies"):
		_toggle_proficiencies()
	if event.is_action_pressed("deposit"):
		GameState.deposit_bag()


func _process(_delta: float) -> void:
	var gain := GameState.recent_gain()
	gain_label.text = ("+%d colhidas" % gain) if gain > 0 else ""
	_refresh_hotbar_highlight()


func _on_berries_changed(total: int, in_bag: int, bag_max: int) -> void:
	total_label.text = _format_count(total)
	goal_label.text = "meta %s · galpão cheio de berries clicáveis" % _format_count(GameState.GOAL)
	bag_label.text = "%d / %d" % [in_bag, bag_max]
	bag_progress.max_value = float(bag_max)
	bag_progress.value = float(in_bag)
	prof_points.text = str(total)
	_rebuild_proficiencies()


func _on_tool_changed(_tool: GameState.Tool) -> void:
	_refresh_interact_text()


func _on_interact_hint(active: bool) -> void:
	crosshair.color = Color(0.4, 1.0, 0.55, 0.95) if active else Color(1, 1, 1, 0.7)
	interact_tip.visible = active and GameState.berries_in_bag < GameState.bag_max
	if active:
		_refresh_interact_text()


func _refresh_interact_text() -> void:
	match GameState.active_tool:
		GameState.Tool.HAND:
			interact_tip.text = "Clique na berry"
		GameState.Tool.MAGNET:
			interact_tip.text = "Segure LMB — puxar"
		GameState.Tool.HARVESTER:
			interact_tip.text = "Colhendo..."


func _toggle_proficiencies() -> void:
	prof_panel.visible = not prof_panel.visible
	var player := get_tree().get_first_node_in_group("player")
	if player and player.has_method("set_look_enabled"):
		player.set_look_enabled(not prof_panel.visible)


func _on_proficiencies_changed() -> void:
	_refresh_tool_locks()


func _refresh_tool_locks() -> void:
	harvester_btn.visible = GameState.harvester_unlocked
	magnet_btn.visible = GameState.magnet_unlocked
	if not GameState.is_tool_unlocked(GameState.active_tool):
		GameState.set_tool(GameState.Tool.HAND)


func _refresh_hotbar_highlight() -> void:
	var tool := GameState.active_tool
	hand_btn.modulate = SLOT_ACTIVE if tool == GameState.Tool.HAND else SLOT_IDLE
	if harvester_btn.visible:
		harvester_btn.modulate = SLOT_ACTIVE if tool == GameState.Tool.HARVESTER else SLOT_IDLE
	if magnet_btn.visible:
		magnet_btn.modulate = SLOT_ACTIVE if tool == GameState.Tool.MAGNET else SLOT_IDLE


func _format_count(n: int) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (float(n) / 1_000_000.0)
	if n >= 10_000:
		return "%.1fK" % (float(n) / 1000.0)
	return str(n)


func _rebuild_proficiencies() -> void:
	for child in prof_list.get_children():
		child.queue_free()
	for id in GameState.PROFICIENCIES:
		var data: Dictionary = GameState.PROFICIENCIES[id]
		var btn := Button.new()
		if GameState.is_proficiency_owned(id):
			btn.text = "%s — adquirido" % data["title"]
			btn.disabled = true
		else:
			btn.text = "%s (%d) — %s" % [data["title"], data["cost"], data["desc"]]
			var reqs: Array = data.get("req", [])
			for req_id in reqs:
				if not GameState.is_proficiency_owned(req_id):
					btn.text += " [bloqueado]"
					break
			btn.disabled = not GameState.can_buy_proficiency(id)
			var proficiency_id: String = id
			btn.pressed.connect(func(): GameState.buy_proficiency(proficiency_id))
		prof_list.add_child(btn)