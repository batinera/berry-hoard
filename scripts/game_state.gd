extends Node

enum Tool { HAND, HARVESTER, MAGNET }

signal berries_changed(total: int, in_bag: int, bag_max: int)
signal tool_changed(tool: Tool)
signal proficiencies_changed
signal interact_hint_changed(active: bool)

const GOAL := 1_000_000
const START_BAG_MAX := 25

const PROFICIENCIES := {
	"unlock_harvester": {
		"title": "Desbloquear colhedor",
		"desc": "Ferramenta automática",
		"cost": 75,
		"req": [],
	},
	"unlock_magnet": {
		"title": "Desbloquear ímã",
		"desc": "Puxa berries no chão",
		"cost": 140,
		"req": [],
	},
	"quick_hands": {
		"title": "Mãos rápidas",
		"desc": "−25% recarga do clique",
		"cost": 35,
		"req": [],
	},
	"handful": {
		"title": "Punhado",
		"desc": "+1 berry por clique",
		"cost": 60,
		"req": [],
	},
	"bigger_basket": {
		"title": "Cesto maior",
		"desc": "+40 capacidade",
		"cost": 50,
		"req": [],
	},
	"longer_reach": {
		"title": "Braço longo",
		"desc": "+35% alcance",
		"cost": 45,
		"req": [],
	},
	"strong_magnet": {
		"title": "Ímã forte",
		"desc": "+70% força",
		"cost": 90,
		"req": ["unlock_magnet"],
	},
	"swift_harvester": {
		"title": "Colhedor veloz",
		"desc": "Colhedor 2× mais rápido",
		"cost": 70,
		"req": ["unlock_harvester"],
	},
}

var interact_highlight: bool = false:
	set(value):
		if interact_highlight == value:
			return
		interact_highlight = value
		interact_hint_changed.emit(value)

var berries_total: int = 0
var berries_in_bag: int = 0
var bag_max: int = START_BAG_MAX
var reach_radius: float = 3.6
var magnet_force_mult: float = 1.0
var harvester_cooldown: float = 0.55
var hand_click_cooldown: float = 0.42
var hand_yield: int = 1
var active_tool: Tool = Tool.HAND

var harvester_unlocked: bool = false
var magnet_unlocked: bool = false

var _purchased: Dictionary = {}
var _last_gain: int = 0
var _gain_decay_timer: float = 0.0


func _process(delta: float) -> void:
	if _gain_decay_timer > 0.0:
		_gain_decay_timer -= delta
		if _gain_decay_timer <= 0.0:
			_last_gain = 0


func is_tool_unlocked(tool: Tool) -> bool:
	match tool:
		Tool.HAND:
			return true
		Tool.HARVESTER:
			return harvester_unlocked
		Tool.MAGNET:
			return magnet_unlocked
	return false


func set_tool(tool: Tool) -> void:
	if not is_tool_unlocked(tool):
		return
	if active_tool == tool:
		return
	active_tool = tool
	tool_changed.emit(active_tool)


func is_proficiency_owned(id: String) -> bool:
	return _purchased.get(id, false)


func can_buy_proficiency(id: String) -> bool:
	if not PROFICIENCIES.has(id) or is_proficiency_owned(id):
		return false
	for req_id in PROFICIENCIES[id].get("req", []):
		if not is_proficiency_owned(req_id):
			return false
	return berries_total >= int(PROFICIENCIES[id]["cost"])


func buy_proficiency(id: String) -> bool:
	if not can_buy_proficiency(id):
		return false
	_purchased[id] = true
	match id:
		"unlock_harvester":
			harvester_unlocked = true
		"unlock_magnet":
			magnet_unlocked = true
		"quick_hands":
			hand_click_cooldown = maxf(0.12, hand_click_cooldown * 0.75)
		"handful":
			hand_yield += 1
		"bigger_basket":
			bag_max += 40
		"longer_reach":
			reach_radius *= 1.35
		"strong_magnet":
			magnet_force_mult = 1.7
		"swift_harvester":
			harvester_cooldown = 0.28
	proficiencies_changed.emit()
	berries_changed.emit(berries_total, berries_in_bag, bag_max)
	return true


func try_collect(amount: int = -1) -> bool:
	var grab := hand_yield if amount < 0 else amount
	if berries_in_bag >= bag_max:
		return false
	var add := mini(grab, bag_max - berries_in_bag)
	if add <= 0:
		return false
	berries_in_bag += add
	berries_total += add
	_last_gain += add
	_gain_decay_timer = 1.2
	berries_changed.emit(berries_total, berries_in_bag, bag_max)
	return true


func deposit_bag() -> void:
	if berries_in_bag == 0:
		return
	berries_in_bag = 0
	berries_changed.emit(berries_total, berries_in_bag, bag_max)


func recent_gain() -> int:
	return _last_gain if _gain_decay_timer > 0.0 else 0


func tool_name(tool: Tool = active_tool) -> String:
	match tool:
		Tool.HAND:
			return "Mão"
		Tool.HARVESTER:
			return "Colhedor"
		Tool.MAGNET:
			return "Ímã"
	return ""