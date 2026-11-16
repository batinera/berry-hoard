extends Area3D

@onready var label: Label3D = $Label3D

var _player_inside: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	GameState.berries_changed.connect(func(_t, _b, _m): _update_label())
	_update_label()


func _process(_delta: float) -> void:
	if _player_inside and Input.is_action_just_pressed("deposit"):
		GameState.deposit_bag()
		_update_label()


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_update_label()


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		_update_label()


func _update_label() -> void:
	if _player_inside:
		label.text = "E — esvaziar cesto (%d)" % GameState.berries_in_bag
	else:
		label.text = "Caixa de entrega"