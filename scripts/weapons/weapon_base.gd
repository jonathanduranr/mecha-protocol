extends Node2D

@export var weapon_id: String = "base_weapon"
@export var weapon_name: String = "Arma Base"
@export var is_unlocked: bool = false
@export var level: int = 1
@export var max_level: int = 5

var mecha_owner: Node2D = null

func _ready() -> void:
	mecha_owner = get_parent().get_parent() # Weapons -> Mecha

func upgrade() -> void:
	if not is_unlocked:
		is_unlocked = true
		level = 1
		on_unlocked()
	elif level < max_level:
		level += 1
		on_upgraded()

func on_unlocked() -> void:
	pass

func on_upgraded() -> void:
	pass

func get_upgrade_title() -> String:
	if not is_unlocked:
		return "Instalar %s" % weapon_name
	return "%s (Nivel %d)" % [weapon_name, level + 1]

func get_upgrade_desc() -> String:
	return "Mejora de armamento"

func is_max_level() -> bool:
	return is_unlocked and level >= max_level
