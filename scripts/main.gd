extends Node2D

@onready var mecha: Node2D = $Mecha
@onready var hud: CanvasLayer = $HUD
@onready var spawner: Node2D = $Spawner

func _ready() -> void:
	DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	if mecha.has_signal("health_changed"):
		mecha.health_changed.connect(hud.update_health)
	if mecha.has_signal("xp_changed"):
		mecha.xp_changed.connect(hud.update_xp)
	if mecha.has_signal("level_up"):
		mecha.level_up.connect(_on_mecha_level_up)
	if mecha.has_signal("mecha_destroyed"):
		mecha.mecha_destroyed.connect(hud.show_game_over)
	if mecha.has_signal("alert_requested"):
		mecha.alert_requested.connect(hud.show_alert)
		
	if hud.has_signal("upgrade_selected"):
		hud.upgrade_selected.connect(_on_upgrade_selected)
		
	hud.mecha_ref = mecha
	if hud.has_signal("manual_input_changed"):
		hud.manual_input_changed.connect(mecha.set_manual_input_vector)
	if hud.has_signal("pilot_mode_changed"):
		hud.pilot_mode_changed.connect(mecha.set_pilot_mode)

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
			mecha.fire_rate_level += 1
		"speed_boost":
			mecha.speed_multiplier += 0.20
		"magnet_boost":
			mecha.magnet_radius += 120.0
		"repair_hull":
			mecha.increase_max_health(25.0, 50.0)
		"emergency_repair":
			mecha.heal(100.0)
		"ultimate_beam":
			mecha.activate_ultimate_beam()
		"ultimate_singularity":
			mecha.activate_ultimate_singularity()
		"ultimate_trail":
			mecha.activate_ultimate_trail()
		"ultimate_vortex":
			mecha.activate_ultimate_vortex()
		"ultimate_aegis":
			mecha.activate_ultimate_aegis()
