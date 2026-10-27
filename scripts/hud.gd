extends CanvasLayer

signal upgrade_selected(upgrade_id: String)

const API_BASE_URL: String = "https://mecha-leaderboard.jonathanduran.workers.dev"
const SAVE_PATH: String = "user://pilot_profile.json"
const SECRET_SALT: String = "mp_cyber_core_sig_99x8172b"

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
@onready var pilot_input: LineEdit = $GameOverPanel/CenterContainer/VBoxContainer/PilotContainer/PilotInput
@onready var save_pilot_btn: Button = $GameOverPanel/CenterContainer/VBoxContainer/PilotContainer/SavePilotBtn
@onready var status_label: Label = $GameOverPanel/CenterContainer/VBoxContainer/StatusLabel
@onready var rows_container: VBoxContainer = $GameOverPanel/CenterContainer/VBoxContainer/LeaderboardPanel/BoardVBox/RowsContainer
@onready var http_request: HTTPRequest = $LeaderboardHTTP

var elapsed_seconds: float = 0.0
var final_level_reached: int = 1
var current_user_id: String = ""
var current_pilot_name: String = ""
var is_submitting: bool = false

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
	save_pilot_btn.pressed.connect(_on_change_name_clicked)
	pilot_input.gui_input.connect(_on_pilot_input_gui_input)
	pilot_input.text_submitted.connect(func(text_val): apply_new_pilot_name(text_val))
	
	http_request.request_completed.connect(_on_http_request_completed)
	load_profile()
	pilot_input.text = current_pilot_name

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
	final_level_reached = final_level
	
	var minutes := int(elapsed_seconds) / 60
	var seconds := int(elapsed_seconds) % 60
	game_over_stats.text = "TIEMPO: %02d:%02d   |   NIVEL: %d" % [minutes, seconds, final_level]
	
	load_profile()
	pilot_input.text = current_pilot_name
	
	game_over_panel.visible = true
	submit_score_to_cloud()

func submit_score_to_cloud() -> void:
	if is_submitting:
		return
	is_submitting = true
	save_pilot_btn.disabled = true
	
	status_label.text = "> Sincronizando satelite de clasificacion..."
	status_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	
	var time_snapped: float = snapped(elapsed_seconds, 0.1)
	var time_str: String = "%.1f" % time_snapped
	var raw_sig: String = "%s:%s:%d:%s" % [current_user_id, time_str, final_level_reached, SECRET_SALT]
	var token: String = raw_sig.sha256_text()
	
	var payload := {
		"user_id": current_user_id,
		"pilot_name": current_pilot_name,
		"survival_time": time_snapped,
		"level": final_level_reached,
		"token": token
	}
	var json_str := JSON.stringify(payload)
	var headers := ["Content-Type: application/json"]
	
	http_request.cancel_request()
	var err := http_request.request(API_BASE_URL + "/api/score", headers, HTTPClient.METHOD_POST, json_str)
	if err != OK:
		is_submitting = false
		save_pilot_btn.disabled = false
		status_label.text = "[!] Red desconectada (Jugando local)"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.6, 0.2))

func _on_pilot_input_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if OS.has_feature("web"):
			_on_change_name_clicked()

func _on_change_name_clicked() -> void:
	if is_submitting:
		return
	if OS.has_feature("web"):
		# En navegadores móviles (iOS Safari / Android), levantar ventana nativa con teclado
		var js_prompt := "window.prompt('Ingresa tu apodo o nombre de piloto (max 16 letras):', " + JSON.stringify(current_pilot_name) + ");"
		var res = JavaScriptBridge.eval(js_prompt)
		if res != null and str(res).strip_edges() != "":
			apply_new_pilot_name(str(res))
	else:
		# En PC / Editor
		apply_new_pilot_name(pilot_input.text)

func apply_new_pilot_name(input_name: String) -> void:
	var clean_name := input_name.strip_edges().replace(" ", "_").to_upper()
	if clean_name.is_empty():
		return
	if clean_name.length() > 16:
		clean_name = clean_name.substr(0, 16)
		
	if clean_name == current_pilot_name:
		return
		
	current_pilot_name = clean_name
	pilot_input.text = current_pilot_name
	save_profile()
	submit_score_to_cloud()

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_submitting = false
	save_pilot_btn.disabled = false
	
	if response_code == 200:
		var json_str := body.get_string_from_utf8()
		var data = JSON.parse_string(json_str)
		if data is Dictionary and data.get("success", false):
			var user_rank: int = int(data.get("rank", 0))
			var top10: Array = data.get("top10", [])
			status_label.text = "> PUNTUACION REGISTRADA (PUESTO MUNDIAL #%d)" % user_rank
			status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
			render_leaderboard(top10)
			return
			
	status_label.text = "[!] Servidor no disponible (HTTP %d, res %d)" % [response_code, _result]
	status_label.add_theme_color_override("font_color", Color(1.0, 0.5, 0.4))

func render_leaderboard(top10: Array) -> void:
	for child in rows_container.get_children():
		child.queue_free()
		
	if top10.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Sin registros aun. Eres el primero!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows_container.add_child(empty_label)
		return
		
	for i in range(min(top10.size(), 7)):
		var row_data = top10[i]
		var rank_num := i + 1
		var p_name := str(row_data.get("pilot_name", "DESCONOCIDO"))
		var s_time := float(row_data.get("survival_time", 0.0))
		var lvl := int(row_data.get("level", 1))
		var is_me := bool(row_data.get("is_me", false))
		
		var mins := int(s_time) / 60
		var secs := int(s_time) % 60
		var time_str := "%02d:%02d" % [mins, secs]
		
		var row_hbox := HBoxContainer.new()
		row_hbox.custom_minimum_size = Vector2(0, 24)
		
		var rank_lbl := Label.new()
		rank_lbl.custom_minimum_size = Vector2(55, 0)
		var rank_text := ""
		var rank_color := Color(0.65, 0.72, 0.82)
		
		if rank_num == 1:
			rank_text = "#1"
			rank_color = Color(1.0, 0.85, 0.2)
		elif rank_num == 2:
			rank_text = "#2"
			rank_color = Color(0.85, 0.9, 0.98)
		elif rank_num == 3:
			rank_text = "#3"
			rank_color = Color(1.0, 0.62, 0.35)
		else:
			rank_text = " %d." % rank_num
			
		rank_lbl.text = rank_text
		rank_lbl.add_theme_font_size_override("font_size", 14)
		rank_lbl.add_theme_color_override("font_color", rank_color)
		
		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 14)
		
		var time_lbl := Label.new()
		time_lbl.custom_minimum_size = Vector2(85, 0)
		time_lbl.text = time_str
		time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		time_lbl.add_theme_font_size_override("font_size", 14)
		
		var lvl_lbl := Label.new()
		lvl_lbl.custom_minimum_size = Vector2(65, 0)
		lvl_lbl.text = "Nv. %d" % lvl
		lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lvl_lbl.add_theme_font_size_override("font_size", 14)
		
		# Destacar al usuario actual en Cian brillante neon
		if is_me:
			var cyan := Color(0.2, 0.95, 1.0)
			rank_lbl.add_theme_color_override("font_color", cyan)
			name_lbl.add_theme_color_override("font_color", cyan)
			time_lbl.add_theme_color_override("font_color", cyan)
			lvl_lbl.add_theme_color_override("font_color", cyan)
			name_lbl.text = "> " + p_name + " (TU)"
		else:
			name_lbl.text = p_name
			var muted := Color(0.75, 0.8, 0.9)
			name_lbl.add_theme_color_override("font_color", muted)
			time_lbl.add_theme_color_override("font_color", muted)
			lvl_lbl.add_theme_color_override("font_color", muted)
			
		row_hbox.add_child(rank_lbl)
		row_hbox.add_child(name_lbl)
		row_hbox.add_child(time_lbl)
		row_hbox.add_child(lvl_lbl)
		
		rows_container.add_child(row_hbox)

func load_profile() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var content := file.get_as_text()
			var parsed = JSON.parse_string(content)
			if parsed is Dictionary:
				if parsed.has("user_id"):
					current_user_id = str(parsed["user_id"]).strip_edges()
				if parsed.has("pilot_name"):
					current_pilot_name = str(parsed["pilot_name"]).strip_edges()
				elif parsed.has("pilot_id"):
					current_pilot_name = str(parsed["pilot_id"]).strip_edges()
	
	if current_user_id.is_empty():
		current_user_id = generate_uuid()
	if current_pilot_name.is_empty():
		current_pilot_name = "PILOTO-%04d" % (randi() % 9000 + 1000)
		
	save_profile()

func save_profile() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var data := {
			"user_id": current_user_id,
			"pilot_name": current_pilot_name
		}
		file.store_string(JSON.stringify(data))

func generate_uuid() -> String:
	var b := PackedByteArray()
	for i in range(16):
		b.append(randi() % 256)
	b[6] = (b[6] & 0x0f) | 0x40
	b[8] = (b[8] & 0x3f) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
	]

func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

	get_tree().reload_current_scene()
