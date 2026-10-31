extends CanvasLayer

signal upgrade_selected(upgrade_id: String)

const API_BASE_URL: String = "https://mecha-leaderboard.jonathanduran.workers.dev"
const SAVE_PATH: String = "user://pilot_profile.json"
const SECRET_SALT: String = "mp_cyber_core_sig_99x8172b"

const MEDAL_GOLD := preload("res://assets/ui/medal_gold.png")
const MEDAL_SILVER := preload("res://assets/ui/medal_silver.png")
const MEDAL_BRONZE := preload("res://assets/ui/medal_bronze.png")

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

@onready var start_panel: Control = $StartPanel
@onready var personal_best_label: Label = $StartPanel/CenterContainer/VBoxContainer/PersonalBestLabel
@onready var start_rows_container: VBoxContainer = $StartPanel/CenterContainer/VBoxContainer/LeaderboardPanel/BoardVBox/StartRowsContainer
@onready var start_button: Button = $StartPanel/CenterContainer/VBoxContainer/StartButton

@onready var http_request: HTTPRequest = $LeaderboardHTTP

var elapsed_seconds: float = 0.0
var final_level_reached: int = 1
var current_user_id: String = ""
var current_pilot_name: String = ""
var best_survival_time: float = 0.0
var best_level: int = 1
var is_submitting: bool = false

const MAX_UPGRADE_LEVEL: int = 10
var upgrade_levels: Dictionary = {
	"multi_shot": 1,
	"damage_boost": 1,
	"fire_rate": 1,
	"speed_boost": 1,
	"magnet_boost": 1,
	"repair_hull": 1
}

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
	get_tree().paused = true
	start_panel.visible = true
	upgrade_panel.visible = false
	game_over_panel.visible = false
	
	start_button.pressed.connect(_on_start_protocol_pressed)
	
	restart_button.pressed.connect(_on_restart_pressed)
	save_pilot_btn.pressed.connect(_on_change_name_clicked)
	pilot_input.gui_input.connect(_on_pilot_input_gui_input)
	pilot_input.text_submitted.connect(func(text_val): apply_new_pilot_name(text_val))
	
	http_request.request_completed.connect(_on_http_request_completed)
	load_profile()
	pilot_input.text = current_pilot_name
	update_personal_best_display()
	
	fetch_initial_leaderboard()

func _on_start_protocol_pressed() -> void:
	AudioManager.play_bgm()
	start_panel.visible = false
	get_tree().paused = false

func update_personal_best_display() -> void:
	if not is_instance_valid(personal_best_label):
		return
	if best_survival_time > 0.0:
		var mins := int(best_survival_time) / 60
		var secs := int(best_survival_time) % 60
		personal_best_label.text = "TU RECORD: %02d:%02d (Nv. %d)  |  PILOTO: %s" % [mins, secs, best_level, current_pilot_name]
	else:
		personal_best_label.text = "PILOTO: %s  //  SIN REGISTRO" % current_pilot_name

func fetch_initial_leaderboard() -> void:
	var url := API_BASE_URL + "/api/leaderboard?user_id=" + current_user_id
	http_request.cancel_request()
	var _err := http_request.request(url, ["Accept: application/json"], HTTPClient.METHOD_GET)

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
		
	# Filtrar habilidades que aún no alcanzan el nivel 10
	var available_pool: Array = []
	for opt in archetype_upgrades:
		var cur_lvl: int = upgrade_levels.get(opt["id"], 1)
		if cur_lvl < MAX_UPGRADE_LEVEL:
			available_pool.append(opt)
			
	available_pool.shuffle()
	var count_to_show: int = min(available_pool.size(), 3)
	var selected := available_pool.slice(0, count_to_show)
	
	# Si ya maxeó todos los poderes a Nv. 10, ofrecer Reparación de Emergencia
	if selected.is_empty():
		var emergency_opt := {
			"id": "emergency_repair",
			"title": "Reparación de Emergencia",
			"desc": "¡Todos los sistemas al máximo! Restaura 100 HP",
			"color": Color(0.2, 1.0, 0.8)
		}
		selected.append(emergency_opt)
	
	for opt in selected:
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(560, 110)
		btn.text = ""
		
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.07, 0.10, 0.16, 0.95)
		style.border_width_bottom = 2
		style.border_width_top = 2
		style.border_width_left = 5
		style.border_width_right = 2
		style.border_color = opt["color"]
		style.corner_radius_top_left = 8
		style.corner_radius_bottom_right = 8
		btn.add_theme_stylebox_override("normal", style)
		
		var hover_style: StyleBoxFlat = style.duplicate()
		hover_style.bg_color = Color(0.12, 0.18, 0.28, 0.98)
		hover_style.border_color = opt["color"].lightened(0.2)
		btn.add_theme_stylebox_override("hover", hover_style)
		btn.add_theme_stylebox_override("pressed", hover_style)
		
		var margin_c := MarginContainer.new()
		margin_c.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin_c.add_theme_constant_override("margin_left", 18)
		margin_c.add_theme_constant_override("margin_right", 18)
		margin_c.add_theme_constant_override("margin_top", 12)
		margin_c.add_theme_constant_override("margin_bottom", 12)
		btn.add_child(margin_c)
		
		var hbox := HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_theme_constant_override("separation", 16)
		margin_c.add_child(hbox)
		
		# Icono vectorial específico del protocolo
		var icon_path := "res://assets/ui/icons/icon_%s.svg" % opt["id"]
		var icon_tex: Texture2D = null
		if ResourceLoader.exists(icon_path):
			icon_tex = load(icon_path)
			
		var icon_rect := TextureRect.new()
		icon_rect.custom_minimum_size = Vector2(58, 58)
		icon_rect.texture = icon_tex
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hbox.add_child(icon_rect)
		
		# Contenedor de Textos
		var vbox := VBoxContainer.new()
		vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_theme_constant_override("separation", 4)
		
		var header_hbox := HBoxContainer.new()
		header_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_hbox.add_theme_constant_override("separation", 8)
		
		var title_label := Label.new()
		title_label.text = opt["title"]
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.add_theme_font_size_override("font_size", 18)
		title_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
		title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		header_hbox.add_child(title_label)
		
		if opt["id"] != "emergency_repair":
			var cur_lvl: int = upgrade_levels.get(opt["id"], 1)
			var next_lvl: int = cur_lvl + 1
			var level_label_card := Label.new()
			if next_lvl >= MAX_UPGRADE_LEVEL:
				level_label_card.text = "Nv %d → %d (MÁX)" % [cur_lvl, next_lvl]
			else:
				level_label_card.text = "Nv %d → %d" % [cur_lvl, next_lvl]
			level_label_card.add_theme_font_size_override("font_size", 15)
			level_label_card.add_theme_color_override("font_color", opt["color"])
			level_label_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
			header_hbox.add_child(level_label_card)
		
		vbox.add_child(header_hbox)
		
		var desc_label := Label.new()
		desc_label.text = opt["desc"]
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_label.add_theme_font_size_override("font_size", 14)
		desc_label.add_theme_color_override("font_color", Color(0.68, 0.78, 0.88))
		desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(desc_label)
		
		hbox.add_child(vbox)
		
		btn.pressed.connect(_on_card_selected.bind(opt["id"]))
		cards_container.add_child(btn)

func _on_card_selected(upgrade_id: String) -> void:
	for child in cards_container.get_children():
		if child is Button:
			child.disabled = true
			
	if upgrade_id != "emergency_repair":
		var cur: int = upgrade_levels.get(upgrade_id, 1)
		upgrade_levels[upgrade_id] = min(cur + 1, MAX_UPGRADE_LEVEL)
		
	upgrade_panel.visible = false
	get_tree().paused = false
	emit_signal("upgrade_selected", upgrade_id)

func show_game_over(final_level: int) -> void:
	AudioManager.play_gameover()
	get_tree().paused = true
	upgrade_panel.visible = false
	final_level_reached = final_level
	
	if final_level < 0:
		game_over_stats.text = "[!] SISTEMA COMPROMETIDO | PROTOCOLO ANULADO"
		game_over_stats.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))
		load_profile()
		pilot_input.text = current_pilot_name
		save_pilot_btn.disabled = true
		status_label.text = "[!] Manipulación de memoria detectada. Puntuación bloqueada."
		status_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		game_over_panel.visible = true
		return
	
	var minutes := int(elapsed_seconds) / 60
	var seconds := int(elapsed_seconds) % 60
	game_over_stats.text = "TIEMPO: %02d:%02d   |   NIVEL: %d" % [minutes, seconds, final_level]
	
	if elapsed_seconds > best_survival_time:
		best_survival_time = elapsed_seconds
		best_level = final_level
		save_profile()
		update_personal_best_display()
	
	load_profile()
	pilot_input.text = current_pilot_name
	
	game_over_panel.visible = true
	submit_score_to_cloud()

func submit_score_to_cloud() -> void:
	if is_submitting or final_level_reached < 0:
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
		# En navegadores moviles (iOS Safari / Android), levantar ventana nativa con teclado
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
		
	# Filtro preventivo en cliente (anti-leetspeak)
	var normalized := clean_name.to_lower().replace("3", "e").replace("1", "i").replace("0", "o").replace("4", "a").replace("5", "s").replace("7", "t").replace("8", "b").replace("_", "").replace("-", "")
	var banned_roots := ["pene", "verga", "pico", "pito", "porno", "puta", "puto", "concha", "culiao", "weon", "chucha", "nazi", "hitler", "dick", "cock", "pussy", "teta", "xvideo"]
	for b in banned_roots:
		if normalized.contains(b):
			status_label.text = "[!] Nombre no permitido por moderación."
			status_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35))
			pilot_input.text = current_pilot_name
			return
		
	if clean_name == current_pilot_name:
		return
		
	current_pilot_name = clean_name
	pilot_input.text = current_pilot_name
	save_profile()
	update_personal_best_display()
	
	if game_over_panel.visible:
		submit_score_to_cloud()
	else:
		fetch_initial_leaderboard()

func _on_http_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	is_submitting = false
	save_pilot_btn.disabled = false
	
	var json_str := body.get_string_from_utf8()
	var data = JSON.parse_string(json_str)
	
	if response_code == 200 and data is Dictionary and data.get("success", false):
		var rows: Array = []
		if data.has("leaderboard"):
			rows = data.get("leaderboard", [])
			if data.has("user_record") and data["user_record"] is Dictionary:
				var u_rec: Dictionary = data["user_record"]
				var u_time := float(u_rec.get("survival_time", 0.0))
				var u_lvl := int(u_rec.get("level", 1))
				var u_rank := int(u_rec.get("rank", 0))
				if u_time > best_survival_time:
					best_survival_time = u_time
					best_level = u_lvl
					save_profile()
				var mins := int(best_survival_time) / 60
				var secs := int(best_survival_time) % 60
				if u_rank > 0:
					personal_best_label.text = "TU RECORD: %02d:%02d (Nv. %d) - PUESTO #%d" % [mins, secs, best_level, u_rank]
				else:
					personal_best_label.text = "TU RECORD: %02d:%02d (Nv. %d)  |  PILOTO: %s" % [mins, secs, best_level, current_pilot_name]
		elif data.has("top10"):
			rows = data.get("top10", [])
			var user_rank: int = int(data.get("rank", 0))
			status_label.text = "> PUNTUACION REGISTRADA (PUESTO MUNDIAL #%d)" % user_rank
			status_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.5))
			
		render_leaderboard(rows)
		return
		
	var err_msg := "Servidor no disponible"
	if data is Dictionary and data.has("error"):
		err_msg = str(data["error"])
	elif data is Dictionary and data.has("reason"):
		err_msg = str(data["reason"])
	status_label.text = "[!] " + err_msg
	status_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))

func render_leaderboard(all_rows: Array) -> void:
	# Podio de inicio: Top 10
	populate_board_container(start_rows_container, all_rows, 10)
	# Tabla de Game Over: Top 10
	populate_board_container(rows_container, all_rows, 10)
	
	# Verificar si el usuario figura en la lista para actualizar su récord
	for i in range(all_rows.size()):
		var r = all_rows[i]
		if r.get("is_me", false):
			var s_time := float(r.get("survival_time", 0.0))
			var lvl := int(r.get("level", 1))
			if s_time > best_survival_time:
				best_survival_time = s_time
				best_level = lvl
				save_profile()
			var mins := int(best_survival_time) / 60
			var secs := int(best_survival_time) % 60
			personal_best_label.text = "TU RECORD: %02d:%02d (Nv. %d) - PUESTO #%d" % [mins, secs, best_level, i + 1]
			break

func populate_board_container(target_container: VBoxContainer, rows: Array, max_count: int) -> void:
	if not is_instance_valid(target_container):
		return
		
	for child in target_container.get_children():
		child.queue_free()
		
	if rows.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Sin registros aun. ¡Se el primero!"
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		target_container.add_child(empty_label)
		return
		
	for i in range(min(rows.size(), max_count)):
		var row_data = rows[i]
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
		row_hbox.add_theme_constant_override("separation", 4)
		
		# Contenedor de Rango con Medalla para Top 3
		var rank_box := HBoxContainer.new()
		rank_box.custom_minimum_size = Vector2(70, 0)
		rank_box.add_theme_constant_override("separation", 4)
		
		var medal_rect := TextureRect.new()
		medal_rect.custom_minimum_size = Vector2(18, 18)
		medal_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		medal_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var rank_lbl := Label.new()
		var rank_text := ""
		var rank_color := Color(0.65, 0.72, 0.82)
		
		if rank_num == 1:
			medal_rect.texture = MEDAL_GOLD
			rank_text = "#1"
			rank_color = Color(1.0, 0.85, 0.2)
		elif rank_num == 2:
			medal_rect.texture = MEDAL_SILVER
			rank_text = "#2"
			rank_color = Color(0.88, 0.92, 0.98)
		elif rank_num == 3:
			medal_rect.texture = MEDAL_BRONZE
			rank_text = "#3"
			rank_color = Color(1.0, 0.65, 0.35)
		else:
			medal_rect.modulate = Color(1, 1, 1, 0) # Mantiene el mismo ancho sin mostrar medalla
			rank_text = "%2d." % rank_num
			
		rank_lbl.text = rank_text
		rank_lbl.add_theme_font_size_override("font_size", 14)
		rank_lbl.add_theme_color_override("font_color", rank_color)
		
		rank_box.add_child(medal_rect)
		rank_box.add_child(rank_lbl)
		
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
			
		row_hbox.add_child(rank_box)
		row_hbox.add_child(name_lbl)
		row_hbox.add_child(time_lbl)
		row_hbox.add_child(lvl_lbl)
		
		target_container.add_child(row_hbox)

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
				if parsed.has("best_survival_time"):
					best_survival_time = float(parsed["best_survival_time"])
				if parsed.has("best_level"):
					best_level = int(parsed["best_level"])
	
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
			"pilot_name": current_pilot_name,
			"best_survival_time": best_survival_time,
			"best_level": best_level
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
	AudioManager.play_bgm()
	get_tree().paused = false
	get_tree().reload_current_scene()
