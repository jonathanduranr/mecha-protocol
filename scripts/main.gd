extends Node2D

@onready var mecha: Node2D = $Mecha
@onready var hud: CanvasLayer = $HUD
@onready var spawner: Node2D = $Spawner

func _ready() -> void:
	if mecha.has_signal("health_changed"):
		mecha.health_changed.connect(hud.update_health)
	if mecha.has_signal("xp_changed"):
		mecha.xp_changed.connect(hud.update_xp)
	if mecha.has_signal("level_up"):
		mecha.level_up.connect(_on_mecha_level_up)
	if mecha.has_signal("mecha_destroyed"):
		mecha.mecha_destroyed.connect(hud.show_game_over)
		
	if hud.has_signal("upgrade_selected"):
		hud.upgrade_selected.connect(_on_upgrade_selected)

func _on_mecha_level_up(new_level: int) -> void:
	hud.show_upgrade_choices(new_level)

func _on_upgrade_selected(upgrade_id: String) -> void:
	match upgrade_id:
		"multi_shot":
			mecha.bullet_count += 1
		"damage_boost":
			mecha.damage_multiplier += 0.25
		"fire_rate":
			mecha.fire_rate = max(0.08, mecha.fire_rate * 0.78)
		"speed_boost":
			mecha.speed_multiplier += 0.20
		"magnet_boost":
			mecha.magnet_radius += 120.0
		"repair_hull":
			mecha.max_health += 25.0
			mecha.current_health = min(mecha.max_health, mecha.current_health + 50.0)
			hud.update_health(mecha.current_health, mecha.max_health)
		"emergency_repair":
			mecha.current_health = min(mecha.max_health, mecha.current_health + 100.0)
			hud.update_health(mecha.current_health, mecha.max_health)
