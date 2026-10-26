extends CanvasLayer

signal upgrade_selected(upgrade_id: String)

@onready var health_bar: ProgressBar = $TopBar/HealthBar
@onready var xp_bar: ProgressBar = $TopBar/XPBar
@onready var level_label: Label = $TopBar/LevelLabel
@onready var timer_label: Label = $TopBar/TimerLabel
@onready var alert_label: Label = $AlertLabel

@onready var upgrade_panel: Control = $UpgradePanel
@onready var cards_container: VBoxContainer = $UpgradePanel/CenterContainer/VBoxContainer/CardsContainer

@onready var game_over_panel: Control = $GameOverPanel
@onready var game_over_stats: Label = $GameOverPanel/CenterContainer/VBoxContainer/StatsLabel
@onready var restart_button: Button = $GameOverPanel/CenterContainer/VBoxContainer/RestartButton

var elapsed_seconds: float = 0.0

var archetype_upgrades := [
	{
		"id": "multi_shot",
		"title": "Batería de Cañones",
		"desc": "+1 Proyectil por ráfaga (fuego paralelo en muralla)",
		"color": Color(0.2, 0.9, 1.0)
	},
	{
		"id": "damage_boost",
		"title": "Sobrecarga de Reactor",
		"desc": "+25% Daño a todos los proyectiles",
		"color": Color(1.0, 0.3, 0.4)
	},
	{
		"id": "fire_rate",
		"title": "Disipador de Plasma",
		"desc": "+25% Cadencia de disparo automático",
		"color": Color(1.0, 0.85, 0.2)
	},
	{
		"id": "speed_boost",
		"title": "Servomotores de Titanio",
		"desc": "+20% Velocidad de evasión del mecha",
		"color": Color(0.3, 1.0, 0.5)
	},
	{
		"id": "magnet_boost",
		"title": "Imán Cuántico de Chatarra",
		"desc": "+60% Radio de atracción de energía XP",
		"color": Color(0.8, 0.4, 1.0)
	},
	{
		"id": "repair_hull",
		"title": "Reparación Nanotecnológica",
		"desc": "Restaura 50 HP y +25 HP máxima",
		"color": Color(0.2, 1.0, 0.8)
	}
]

func _ready() -> void:
	upgrade_panel.visible = false
	game_over_panel.visible = false
	restart_button.pressed.connect(_on_restart_pressed)

func _process(delta: float) -> void:
	if not get_tree().paused:
		elapsed_seconds += delta
		var minutes := int(elapsed_seconds) / 60
		var seconds := int(elapsed_seconds) % 60
		timer_label.text = "%02d:%02d" % [minutes, seconds]

func update_health(current: float, max_val: float) -> void:
	health_bar.max_value = max_val
	health_bar.value = current

func update_xp(current: int, needed: int, level: int) -> void:
	xp_bar.max_value = needed
	xp_bar.value = current
	level_label.text = "NIVEL %d" % level

func show_alert(text: String) -> void:
	if alert_label:
		alert_label.text = text
		alert_label.visible = true
		var tween := create_tween()
		tween.tween_property(alert_label, "modulate:a", 0.2, 0.25).set_trans(Tween.TRANS_SINE)
		tween.tween_property(alert_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
		tween.tween_property(alert_label, "modulate:a", 0.2, 0.25).set_trans(Tween.TRANS_SINE)
		tween.tween_property(alert_label, "modulate:a", 1.0, 0.25).set_trans(Tween.TRANS_SINE)
		tween.tween_interval(1.2)
		tween.tween_callback(func(): alert_label.visible = false)

func show_upgrade_choices(current_level: int) -> void:
	get_tree().paused = true
	upgrade_panel.visible = true
	
	for child in cards_container.get_children():
		child.queue_free()
		
	var pool := archetype_upgrades.duplicate()
	pool.shuffle()
	var selected = pool.slice(0, 3)
	
	for opt in selected:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(550, 105)
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.text = "⚡ %s\n%s" % [opt["title"], opt["desc"]]
		btn.add_theme_font_size_override("font_size", 17)
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 4
		style.border_width_right = 2
		style.border_color = opt["color"]
		style.corner_radius_top_left = 8
		style.corner_radius_bottom_right = 8
		style.content_margin_left = 20.0
		style.content_margin_right = 20.0
		style.content_margin_top = 12.0
		style.content_margin_bottom = 12.0
		btn.add_theme_stylebox_override("normal", style)
		
		var hover_style = style.duplicate()
		hover_style.bg_color = Color(0.14, 0.20, 0.30, 0.98)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		
		btn.pressed.connect(_on_card_selected.bind(opt["id"]))
		cards_container.add_child(btn)

func _on_card_selected(upgrade_id: String) -> void:
	upgrade_panel.visible = false
	get_tree().paused = false
	emit_signal("upgrade_selected", upgrade_id)

func show_game_over(final_level: int) -> void:
	get_tree().paused = true
	upgrade_panel.visible = false
	var minutes := int(elapsed_seconds) / 60
	var seconds := int(elapsed_seconds) % 60
	game_over_stats.text = "⏱️ TIEMPO SOBREVIVIDO: %02d:%02d\n⭐ NIVEL ALCANZADO: %d" % [minutes, seconds, final_level]
	game_over_panel.visible = true

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
