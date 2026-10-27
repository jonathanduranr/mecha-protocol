extends Node2D

@export var mecha: Node2D

var elapsed_time: float = 0.0
var squad_timer: float = 0.8
var next_swarm_time: float = 40.0

var boss_spawned_3m: bool = false
var boss_spawned_6m: bool = false

@onready var drone_scene := preload("res://scenes/enemy_drone.tscn")
@onready var hud: CanvasLayer = get_parent().get_node_or_null("HUD")

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	squad_timer -= delta
	
	# Eventos de Enjambres Periódicos (Cada ~40s)
	if elapsed_time >= next_swarm_time:
		trigger_swarm_event()
		next_swarm_time = elapsed_time + randf_range(38.0, 46.0)
	
	# Eventos de Jefes por tiempo
	if elapsed_time >= 180.0 and not boss_spawned_3m:
		boss_spawned_3m = true
		if hud and hud.has_method("show_alert"):
			hud.show_alert("⚠️ ¡COLOSO CENTINELA DETECTADO! ⚠️")
		spawn_boss_with_escort(2500.0)
		
	if elapsed_time >= 360.0 and not boss_spawned_6m:
		boss_spawned_6m = true
		if hud and hud.has_method("show_alert"):
			hud.show_alert("⚠️ ¡TITÁN DE ASALTO MK-II DETECTADO! ⚠️")
		spawn_boss_with_escort(5200.0)
	
	# Spawner de Escuadrones Tácticos por Intervalos (Frecuencia duplicada)
	if squad_timer <= 0:
		spawn_tactical_squad()
		# Pausa táctica entre escuadrones más ágil y tensa
		var pause: float = max(1.2, 2.2 - (elapsed_time * 0.005))
		squad_timer = pause

## Selecciona y despliega una formación táctica según el minuto de juego
func spawn_tactical_squad() -> void:
	if not is_instance_valid(mecha):
		return
		
	var v_size := get_viewport_rect().size
	var formation_type: int = randi() % 4
	
	# Escalado de vida según el tiempo transcurrido
	var scout_hp: float = 35.0 + (elapsed_time * 0.45)
	var tank_hp: float = 220.0 + (elapsed_time * 1.1)
	var swarm_hp: float = 60.0 + (elapsed_time * 0.35)
	var shooter_hp: float = 90.0 + (elapsed_time * 0.5)

	# FASE 1 (0 a 1 min): Cantidad duplicada de Scouts (V, Muro y Pinza)
	if elapsed_time < 60.0:
		match formation_type:
			0, 1:
				spawn_v_formation("scout", 10, scout_hp)
			2:
				spawn_sweep_wall("scout", 10, scout_hp)
			3:
				spawn_pincer_formation("scout", 10, scout_hp)

	# FASE 2 (1 a 2.5 min): Pinzas masivas, Escoltas pesadas dobles y Shooters
	elif elapsed_time < 150.0:
		match formation_type:
			0:
				spawn_v_formation("scout", 14, scout_hp)
			1:
				spawn_pincer_formation("scout", 12, scout_hp)
			2:
				spawn_escort_squad(tank_hp, scout_hp)
			3:
				spawn_shooter_patrol(shooter_hp, scout_hp)

	# FASE 3 (2.5 min en adelante): Asaltos combinados de alta presión masivos
	else:
		match formation_type:
			0:
				# Escuadrón V de avispas rápidas
				spawn_v_formation("swarm", 14, swarm_hp)
			1:
				# Pinza pesada (Tanque + Shooters + Scouts)
				spawn_pincer_formation("shooter", 8, shooter_hp)
				spawn_pincer_formation("scout", 12, scout_hp)
			2:
				spawn_sweep_wall("scout", 14, scout_hp)
				spawn_specific_enemy("tank", tank_hp)
				spawn_specific_enemy("tank", tank_hp)
			3:
				spawn_escort_squad(tank_hp, swarm_hp)

# --- FORMACIONES MILITARES ---

## 1. Formación en Flecha (V)
func spawn_v_formation(type_name: String, count: int, hp: float) -> void:
	var v_size := get_viewport_rect().size
	var edge := randi() % 4
	var center_pos := Vector2.ZERO
	var spacing: float = 40.0
	var depth_step: float = 30.0
	
	match edge:
		0: # Desde arriba hacia abajo
			center_pos = Vector2(randf_range(160, v_size.x - 160), -50.0)
			for i in range(count):
				var side_offset: float = (i / 2 + 1) * spacing * (1 if i % 2 == 0 else -1) if i > 0 else 0.0
				var back_offset: float = (i / 2) * -depth_step if i > 0 else 0.0
				spawn_drone_at_pos(center_pos + Vector2(side_offset, back_offset), type_name, hp)
		1: # Desde abajo hacia arriba
			center_pos = Vector2(randf_range(160, v_size.x - 160), v_size.y + 50.0)
			for i in range(count):
				var side_offset: float = (i / 2 + 1) * spacing * (1 if i % 2 == 0 else -1) if i > 0 else 0.0
				var back_offset: float = (i / 2) * depth_step if i > 0 else 0.0
				spawn_drone_at_pos(center_pos + Vector2(side_offset, back_offset), type_name, hp)
		2: # Desde la izquierda hacia la derecha
			center_pos = Vector2(-50.0, randf_range(200, v_size.y - 200))
			for i in range(count):
				var side_offset: float = (i / 2 + 1) * spacing * (1 if i % 2 == 0 else -1) if i > 0 else 0.0
				var back_offset: float = (i / 2) * -depth_step if i > 0 else 0.0
				spawn_drone_at_pos(center_pos + Vector2(back_offset, side_offset), type_name, hp)
		3: # Desde la derecha hacia la izquierda
			center_pos = Vector2(v_size.x + 50.0, randf_range(200, v_size.y - 200))
			for i in range(count):
				var side_offset: float = (i / 2 + 1) * spacing * (1 if i % 2 == 0 else -1) if i > 0 else 0.0
				var back_offset: float = (i / 2) * depth_step if i > 0 else 0.0
				spawn_drone_at_pos(center_pos + Vector2(back_offset, side_offset), type_name, hp)

## 2. Ataque en Pinza (Izquierda y Derecha simultáneos)
func spawn_pincer_formation(type_name: String, total_count: int, hp: float) -> void:
	var v_size := get_viewport_rect().size
	var per_side: int = total_count / 2
	var base_y: float = clamp(mecha.global_position.y, 250.0, v_size.y - 250.0)
	
	for i in range(per_side):
		var y_off: float = (i - per_side / 2.0) * 45.0
		# Flanco izquierdo
		spawn_drone_at_pos(Vector2(-50.0, base_y + y_off), type_name, hp)
		# Flanco derecho
		spawn_drone_at_pos(Vector2(v_size.x + 50.0, base_y + y_off), type_name, hp)

## 3. Muro Barredor (Línea recta horizontal)
func spawn_sweep_wall(type_name: String, count: int, hp: float) -> void:
	var v_size := get_viewport_rect().size
	var from_top: bool = randf() < 0.5
	var y_pos: float = -50.0 if from_top else v_size.y + 50.0
	var step: float = v_size.x / float(count + 1)
	
	for i in range(count):
		var x_pos: float = step * float(i + 1)
		spawn_drone_at_pos(Vector2(x_pos, y_pos), type_name, hp)

## 4. Patrulla con Escolta (2 Tanques blindados en convoy + 8 escoltas)
func spawn_escort_squad(tank_hp: float, escort_hp: float) -> void:
	var v_size := get_viewport_rect().size
	var edge := randi() % 4
	var base_pos := Vector2.ZERO
	
	match edge:
		0: base_pos = Vector2(v_size.x * 0.5, -60.0)
		1: base_pos = Vector2(v_size.x * 0.5, v_size.y + 60.0)
		2: base_pos = Vector2(-60.0, v_size.y * 0.5)
		3: base_pos = Vector2(v_size.x + 60.0, v_size.y * 0.5)
		
	# 2 Tanques en convoy
	spawn_drone_at_pos(base_pos + Vector2(-35, 0), "tank", tank_hp)
	spawn_drone_at_pos(base_pos + Vector2(35, 0), "tank", tank_hp)
	
	# 8 escoltas rodeando al convoy en círculo
	for i in range(8):
		var angle := i * (TAU / 8.0)
		spawn_drone_at_pos(base_pos + Vector2(cos(angle), sin(angle)) * 68.0, "scout", escort_hp)

## 5. Patrulla de Francotiradores a distancia (4 Shooters + 6 Scouts escudo)
func spawn_shooter_patrol(shooter_hp: float, guard_hp: float) -> void:
	var v_size := get_viewport_rect().size
	var x_pos := 75.0 if randf() < 0.5 else v_size.x - 75.0
	# 4 Tiradores escalonados
	spawn_drone_at_pos(Vector2(x_pos - 35, -50.0), "shooter", shooter_hp)
	spawn_drone_at_pos(Vector2(x_pos + 35, -50.0), "shooter", shooter_hp)
	spawn_drone_at_pos(Vector2(x_pos - 35, -95.0), "shooter", shooter_hp)
	spawn_drone_at_pos(Vector2(x_pos + 35, -95.0), "shooter", shooter_hp)
	# Escuadrón de 6 Scouts frontales como escudo
	for i in range(6):
		spawn_drone_at_pos(Vector2(x_pos - 75 + (i * 30), -20.0), "scout", guard_hp)

## Jefe Titán con escolta de honor
func spawn_boss_with_escort(boss_hp: float) -> void:
	var v_size := get_viewport_rect().size
	var spawn_pos := Vector2(v_size.x * 0.5, -80.0)
	spawn_drone_at_pos(spawn_pos, "boss", boss_hp)
	# Escuadra de 8 scouts de escolta
	for i in range(8):
		var angle := i * (TAU / 8.0)
		spawn_drone_at_pos(spawn_pos + Vector2(cos(angle), sin(angle)) * 75.0, "scout", 90.0)

## Evento Masivo de Enjambre (Cada ~40s)
func trigger_swarm_event() -> void:
	if not is_instance_valid(mecha):
		return
		
	var is_ring := randf() < 0.5
	if is_ring:
		if hud and hud.has_method("show_alert"):
			hud.show_alert("⚠️ ¡ANILLO DE ASALTO ENTRANTE! ⚠️")
		spawn_circle_swarm(48, "scout" if elapsed_time < 100.0 else "swarm")
	else:
		if hud and hud.has_method("show_alert"):
			hud.show_alert("⚠️ ¡ENJAMBRE HOSTIL MASIVO! ⚠️")
		spawn_flank_stampede(52, "swarm" if elapsed_time > 70.0 else "scout")

func spawn_circle_swarm(count: int, enemy_type: String) -> void:
	var radius: float = 460.0
	var angle_step := TAU / count
	for i in range(count):
		var angle := i * angle_step
		var pos := mecha.global_position + Vector2(cos(angle), sin(angle)) * radius
		spawn_drone_at_pos(pos, enemy_type, 30.0 + (elapsed_time * 0.25))

func spawn_flank_stampede(count: int, enemy_type: String) -> void:
	var v_size := get_viewport_rect().size
	for i in range(count):
		var spawn_pos := Vector2.ZERO
		if i % 2 == 0:
			spawn_pos = Vector2(randf_range(20, v_size.x - 20), -40.0 - (i * 14))
		else:
			spawn_pos = Vector2(randf_range(20, v_size.x - 20), v_size.y + 40.0 + (i * 14))
		spawn_drone_at_pos(spawn_pos, enemy_type, 30.0 + (elapsed_time * 0.25))

func spawn_specific_enemy(type_name: String, hp: float) -> void:
	if not is_instance_valid(mecha):
		return
	var v_size := get_viewport_rect().size
	var spawn_pos := Vector2(randf_range(40, v_size.x - 40), -50.0)
	spawn_drone_at_pos(spawn_pos, type_name, hp)

func spawn_drone_at_pos(pos: Vector2, type_name: String, hp: float) -> void:
	var drone = drone_scene.instantiate()
	drone.drone_type = type_name
	drone.max_health = hp
	drone.target_mecha = mecha
	drone.global_position = pos
	drone.add_to_group("enemies")
	get_parent().add_child(drone)
