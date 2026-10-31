extends Node2D

@export var mecha: Node2D

var elapsed_time: float = 0.0
var squad_timer: float = 0.8
var next_swarm_time: float = 40.0

var boss_spawned_3m: bool = false
var boss_spawned_6m: bool = false
var beam_surge_notified: bool = false
var spawned_level_bosses: Dictionary = {
	10: false,
	20: false,
	30: false,
	40: false,
	50: false
}

## Calcula el multiplicador dinámico de densidad combinando Nivel (Opción 2) y Ultimates (Opción 3)
func get_horde_density_multiplier() -> float:
	if not is_instance_valid(mecha):
		return 1.0
		
	# 1. Escalado Progresivo por Nivel del Mecha (Opción 2)
	var lvl: int = mecha.level
	var level_mult: float = 1.0
	if lvl >= 30:
		level_mult = 1.80 + (lvl - 30) * 0.04
	elif lvl >= 20:
		level_mult = 1.45 + (lvl - 20) * 0.035
	elif lvl >= 10:
		level_mult = 1.20 + (lvl - 10) * 0.025
	elif lvl >= 5:
		level_mult = 1.0 + (lvl - 5) * 0.04
		
	# 2. Escalado por Ultimates Desbloqueadas (Opción 3)
	var ult_mult: float = 1.0
	if mecha.has_ultimate_beam:
		var b_lvl: int = mecha.beam_level if "beam_level" in mecha else 1
		ult_mult += 0.25 * float(b_lvl) # Progresivo: Nv 1 (+25%), Nv 2 (+50%), Nv 3 (+75%)
		if b_lvl >= 3 and not beam_surge_notified:
			beam_surge_notified = true
			if hud and hud.has_method("show_alert"):
				hud.show_alert("[!] ALERTA: RESPUESTA DE ENJAMBRE OMEGA ACTIVADA [!]")
	if mecha.has_ultimate_singularity:
		ult_mult += 0.30
	if mecha.has_ultimate_vortex:
		ult_mult += 0.30
	if mecha.has_ultimate_trail:
		ult_mult += 0.25
	if mecha.has_ultimate_aegis:
		ult_mult += 0.25
		
	return level_mult * ult_mult

@onready var drone_scene := preload("res://scenes/enemy_drone.tscn")
@onready var hud: CanvasLayer = get_parent().get_node_or_null("HUD")

func _ready() -> void:
	if is_instance_valid(mecha) and mecha.has_signal("level_up"):
		mecha.level_up.connect(_on_mecha_level_up)

func _on_mecha_level_up(lvl: int) -> void:
	if lvl in spawned_level_bosses and not spawned_level_bosses[lvl]:
		spawned_level_bosses[lvl] = true
		spawn_level_boss(lvl)

func spawn_level_boss(lvl: int) -> void:
	var v_size := get_viewport_rect().size
	var spawn_pos := Vector2(v_size.x * 0.5, -90.0)
	
	match lvl:
		10:
			if hud and hud.has_method("show_alert"):
				hud.show_alert("[!] AMENAZA NIVEL 10: AEGIS COLOSSUS (MK. I) [!]")
			spawn_drone_at_pos(spawn_pos, "boss", 35000.0, "AEGIS COLOSSUS (MK. I)")
			for i in range(6):
				var angle := i * (TAU / 6.0)
				spawn_drone_at_pos(spawn_pos + Vector2(cos(angle), sin(angle)) * 85.0, "tank", 220.0)
		20:
			if hud and hud.has_method("show_alert"):
				hud.show_alert("[!] AMENAZA NIVEL 20: HIVE HYDRA (MK. II) [!]")
			spawn_drone_at_pos(spawn_pos, "boss", 75000.0, "HIVE HYDRA (MK. II)")
			for i in range(12):
				var angle := i * (TAU / 12.0)
				spawn_drone_at_pos(spawn_pos + Vector2(cos(angle), sin(angle)) * 95.0, "swarm", 70.0)
		30:
			if hud and hud.has_method("show_alert"):
				hud.show_alert("[!] AMENAZA NIVEL 30: CHRONOS DREADNOUGHT (MK. III) [!]")
			spawn_drone_at_pos(spawn_pos, "boss", 140000.0, "CHRONOS DREADNOUGHT (MK. III)")
			for i in range(8):
				var angle := i * (TAU / 8.0)
				spawn_drone_at_pos(spawn_pos + Vector2(cos(angle), sin(angle)) * 105.0, "shooter", 180.0)
		40:
			if hud and hud.has_method("show_alert"):
				hud.show_alert("[!] AMENAZA NIVEL 40: APEX ANNIHILATOR (MK. IV) [!]")
			spawn_drone_at_pos(spawn_pos, "boss", 250000.0, "APEX ANNIHILATOR (MK. IV)")
		50:
			if hud and hud.has_method("show_alert"):
				hud.show_alert("[!] ALERTA APOCALÍPTICA: OMEGA SINGULARITY GOD (MK. V) [!]")
			spawn_drone_at_pos(spawn_pos, "boss", 450000.0, "OMEGA SINGULARITY GOD (MK. V)")

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	squad_timer -= delta
	
	# Eventos de Enjambres Periódicos (Frecuencia ajustada por nivel y ultimates)
	if elapsed_time >= next_swarm_time:
		trigger_swarm_event()
		var density: float = get_horde_density_multiplier()
		var delay_range: Vector2 = Vector2(26.0, 34.0) if density >= 1.7 else Vector2(38.0, 46.0)
		next_swarm_time = elapsed_time + randf_range(delay_range.x, delay_range.y)
	
	# Eventos de Jefes por tiempo (+1000% HP)
	if elapsed_time >= 180.0 and not boss_spawned_3m:
		boss_spawned_3m = true
		if hud and hud.has_method("show_alert"):
			hud.show_alert("[!] COLOSO CENTINELA DETECTADO [!]")
		spawn_boss_with_escort(25000.0, "COLOSO CENTINELA (MK. I)")
		
	if elapsed_time >= 360.0 and not boss_spawned_6m:
		boss_spawned_6m = true
		if hud and hud.has_method("show_alert"):
			hud.show_alert("[!] TITAN DE ASALTO MK-II DETECTADO [!]")
		spawn_boss_with_escort(55000.0, "TITÁN DE ASALTO (MK. II)")
	
	# Spawner de Escuadrones Tácticos por Intervalos (Frecuencia dinámica)
	if squad_timer <= 0:
		spawn_tactical_squad()
		var density: float = get_horde_density_multiplier()
		var base_pause: float = max(0.55, 2.2 - (elapsed_time * 0.005))
		var pause: float = max(0.55, base_pause / sqrt(density))
		squad_timer = pause

## Selecciona y despliega una formación táctica escalada por Nivel y Ultimates
func spawn_tactical_squad() -> void:
	if not is_instance_valid(mecha):
		return
		
	var v_size := get_viewport_rect().size
	var formation_type: int = randi() % 4
	var density: float = get_horde_density_multiplier()
	
	# Escalado de vida según el tiempo transcurrido
	var scout_hp: float = 35.0 + (elapsed_time * 0.45)
	var tank_hp: float = 220.0 + (elapsed_time * 1.1)
	var swarm_hp: float = 60.0 + (elapsed_time * 0.35)
	var shooter_hp: float = 90.0 + (elapsed_time * 0.5)

	# FASE 1 (0 a 1 min): Cantidad de Scouts escalada por poder
	if elapsed_time < 60.0:
		var count: int = int(round(10.0 * density))
		match formation_type:
			0, 1:
				spawn_v_formation("scout", count, scout_hp, density)
			2:
				spawn_sweep_wall("scout", count, scout_hp)
			3:
				spawn_pincer_formation("scout", count, scout_hp)

	# FASE 2 (1 a 2.5 min): Pinzas masivas, Escoltas pesadas y Shooters
	elif elapsed_time < 150.0:
		match formation_type:
			0:
				spawn_v_formation("scout", int(round(14.0 * density)), scout_hp, density)
			1:
				spawn_pincer_formation("scout", int(round(12.0 * density)), scout_hp)
			2:
				spawn_escort_squad(tank_hp, scout_hp, density)
			3:
				spawn_shooter_patrol(shooter_hp, scout_hp, density)

	# FASE 3 (2.5 min en adelante): Asaltos combinados de alta presión masivos
	else:
		match formation_type:
			0:
				# Escuadrón V de avispas rápidas
				spawn_v_formation("swarm", int(round(14.0 * density)), swarm_hp, density)
			1:
				# Pinza pesada (Tanque + Shooters + Scouts)
				spawn_pincer_formation("shooter", int(round(8.0 * density)), shooter_hp)
				spawn_pincer_formation("scout", int(round(12.0 * density)), scout_hp)
			2:
				spawn_sweep_wall("scout", int(round(14.0 * density)), scout_hp)
				var tank_count: int = int(round(2.0 * min(2.5, density)))
				for t in range(tank_count):
					spawn_specific_enemy("tank", tank_hp)
			3:
				spawn_escort_squad(tank_hp, swarm_hp, density)

# --- FORMACIONES MILITARES ---

## 1. Formación en Flecha (V) con pinza dual en alta densidad
func spawn_v_formation(type_name: String, count: int, hp: float, density: float = 1.0) -> void:
	var v_size := get_viewport_rect().size
	var edge := randi() % 4
	
	if density >= 1.7 and count >= 16:
		var half_count: int = count / 2
		_spawn_single_v(edge, type_name, half_count, hp, v_size)
		_spawn_single_v((edge + 2) % 4, type_name, count - half_count, hp, v_size)
	else:
		_spawn_single_v(edge, type_name, count, hp, v_size)

func _spawn_single_v(edge: int, type_name: String, count: int, hp: float, v_size: Vector2) -> void:
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

## 4. Patrulla con Escolta (Tanques blindados en convoy + escoltas)
func spawn_escort_squad(tank_hp: float, escort_hp: float, density: float = 1.0) -> void:
	var v_size := get_viewport_rect().size
	var edge := randi() % 4
	var base_pos := Vector2.ZERO
	
	match edge:
		0: base_pos = Vector2(v_size.x * 0.5, -60.0)
		1: base_pos = Vector2(v_size.x * 0.5, v_size.y + 60.0)
		2: base_pos = Vector2(-60.0, v_size.y * 0.5)
		3: base_pos = Vector2(v_size.x + 60.0, v_size.y * 0.5)
		
	# Tanques en convoy (escala de 2 a 4)
	var tank_count: int = max(2, int(round(2.0 * min(2.0, density))))
	for t in range(tank_count):
		var x_off: float = (t - (tank_count - 1) * 0.5) * 45.0
		spawn_drone_at_pos(base_pos + Vector2(x_off, 0), "tank", tank_hp)
	
	# Escoltas rodeando al convoy en círculo
	var escort_count: int = int(round(8.0 * density))
	for i in range(escort_count):
		var angle := i * (TAU / float(escort_count))
		spawn_drone_at_pos(base_pos + Vector2(cos(angle), sin(angle)) * 75.0, "scout", escort_hp)

## 5. Patrulla de Francotiradores a distancia (Shooters + Scouts escudo)
func spawn_shooter_patrol(shooter_hp: float, guard_hp: float, density: float = 1.0) -> void:
	var v_size := get_viewport_rect().size
	var x_pos := 75.0 if randf() < 0.5 else v_size.x - 75.0
	var shooter_count: int = int(round(4.0 * density))
	for s in range(shooter_count):
		var side := -35.0 if s % 2 == 0 else 35.0
		var y_depth := -50.0 - (s / 2) * 45.0
		spawn_drone_at_pos(Vector2(x_pos + side, y_depth), "shooter", shooter_hp)
	
	var guard_count: int = int(round(6.0 * density))
	var guard_step := 150.0 / float(guard_count + 1)
	for i in range(guard_count):
		spawn_drone_at_pos(Vector2(x_pos - 75.0 + (i + 1) * guard_step, -20.0), "scout", guard_hp)

## Jefe Titán con escolta de honor
func spawn_boss_with_escort(boss_hp: float, custom_name: String = "COLOSO CENTINELA (MK. I)") -> void:
	var v_size := get_viewport_rect().size
	var spawn_pos := Vector2(v_size.x * 0.5, -80.0)
	spawn_drone_at_pos(spawn_pos, "boss", boss_hp, custom_name)
	# Escuadra de 8 scouts de escolta
	for i in range(8):
		var angle := i * (TAU / 8.0)
		spawn_drone_at_pos(spawn_pos + Vector2(cos(angle), sin(angle)) * 75.0, "scout", 90.0)

## Evento Masivo de Enjambre (Frecuencia y cantidad escalada)
func trigger_swarm_event() -> void:
	if not is_instance_valid(mecha):
		return
		
	var density: float = get_horde_density_multiplier()
	var is_ring: bool = randf() < 0.5
	if is_ring:
		if hud and hud.has_method("show_alert"):
			hud.show_alert("[!] ANILLO DE ASALTO ENTRANTE [!]")
		var ring_count: int = int(round(48.0 * min(2.5, density)))
		spawn_circle_swarm(ring_count, "scout" if elapsed_time < 100.0 else "swarm")
	else:
		if hud and hud.has_method("show_alert"):
			hud.show_alert("[!] ENJAMBRE HOSTIL MASIVO [!]")
		var stampede_count: int = int(round(52.0 * min(2.5, density)))
		spawn_flank_stampede(stampede_count, "swarm" if elapsed_time > 70.0 else "scout")

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

func spawn_drone_at_pos(pos: Vector2, type_name: String, hp: float, custom_boss_name: String = "") -> Node2D:
	var drone = drone_scene.instantiate()
	drone.drone_type = type_name
	drone.max_health = hp
	if custom_boss_name != "":
		drone.boss_name = custom_boss_name
	drone.target_mecha = mecha
	drone.global_position = pos
	drone.add_to_group("enemies")
	get_parent().add_child(drone)
	return drone
