extends Area2D

signal health_changed(current: float, max_val: float)
signal xp_changed(current: int, needed: int, level: int)
signal level_up(new_level: int)
signal mecha_destroyed(final_level: int)
signal alert_requested(text: String)

@export var max_health: float = 120.0
@export var base_speed: float = 260.0
@export var fire_rate: float = 0.22          # Cadencia ágil de disparo
@export var sensor_range: float = 520.0
@export var danger_radius: float = 170.0
@export var magnet_radius: float = 240.0

# 🪤 Trampa para escaneo de memoria (Honeypot Decoy)
# Los scripts como HEAPF64 buscarán esta variable de 120.0 para congelarla.
@export var current_health: float = 120.0
var _honeypot_last: float = 120.0

# 🛡️ Almacenamiento seguro ofuscado en memoria RAM
var _mask_key: float = 0.0
var _damage_accumulated: float = 0.0
var _max_health_masked: float = 0.0
var _is_security_tripped: bool = false
var _tamper_check_timer: float = 0.0

var current_xp: int = 0
var xp_needed: int = 35
var level: int = 1

var shoot_timer: float = 0.0
var damage_cooldown: float = 0.0
var current_velocity: Vector2 = Vector2.ZERO

# Modificadores del Arquetipo (Mejorables en Level Up)
var bullet_count: int = 1
var damage_multiplier: float = 1.0
var speed_multiplier: float = 1.0

# Sistema de Piloto (Manual / Automático)
enum PilotMode { AUTO, MANUAL }
var pilot_mode: int = PilotMode.AUTO
var manual_input_vector: Vector2 = Vector2.ZERO
var manual_grace_timer: float = 0.0

func set_manual_input_vector(vec: Vector2) -> void:
	manual_input_vector = vec
	if vec.length_squared() > 0.01:
		manual_grace_timer = 0.55

func set_pilot_mode(mode: int) -> void:
	pilot_mode = mode

func get_keyboard_input_vector() -> Vector2:
	var k := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		k.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		k.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		k.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		k.x += 1.0
	return k.normalized()

func get_effective_manual_direction() -> Vector2:
	var k_vec := get_keyboard_input_vector()
	if k_vec.length_squared() > 0.01:
		return k_vec
	if manual_input_vector.length_squared() > 0.01:
		return manual_input_vector
	return Vector2.ZERO

func is_manually_controlled() -> bool:
	return get_effective_manual_direction().length_squared() > 0.01 or manual_grace_timer > 0.0

# Evoluciones Ultimate de Arquetipos
var has_ultimate_beam: bool = false
var beam_level: int = 0 # 1: 1 rayo frontal, 2: 2 rayos duales, 3: 3 rayos prismáticos
var is_beam_firing: bool = false
var beam_tick_timer: float = 0.0
var electric_anim_time: float = 0.0
var fire_rate_level: int = 1

func get_beam_angles() -> Array[float]:
	match beam_level:
		1:
			return [0.0]
		2:
			return [-deg_to_rad(14.0), deg_to_rad(14.0)]
		3:
			return [-deg_to_rad(24.0), 0.0, deg_to_rad(24.0)]
		_:
			return [-deg_to_rad(24.0), 0.0, deg_to_rad(24.0)] if beam_level >= 3 else [0.0]

func get_beam_length() -> float:
	return 950.0 + (fire_rate_level - 1) * 65.0

func get_beam_half_width() -> float:
	return 20.0 + (fire_rate_level - 1) * 2.8

func get_beam_tick_interval() -> float:
	return max(0.022, 0.065 * pow(0.89, float(fire_rate_level - 1)))

# 1. Singularidad de Antimateria (Sobrecarga de Reactor Nv. 10)
var has_ultimate_singularity: bool = false
var singularity_timer: float = 0.0
var active_singularities: Array[Dictionary] = []

# 2. Estela de Iones Cinética (Servomotores de Titanio Nv. 10)
var has_ultimate_trail: bool = false
var trail_timer: float = 0.0
var dash_cooldown: float = 0.0
var active_trails: Array[Dictionary] = []

# 3. Vórtice de Metralla Orbital (Imán Cuántico Nv. 10)
var has_ultimate_vortex: bool = false
var vortex_angle: float = 0.0
var absorb_pulse: float = 0.0
const VORTEX_RADIUS: float = 68.0
const VORTEX_BLADES: int = 8

# 4. Protocolo Fénix & Égida Hexagonal (Reparación Nanotecnológica Nv. 10)
var has_ultimate_aegis: bool = false
var aegis_shield_active: bool = true
var aegis_cooldown: float = 0.0
var phoenix_used: bool = false
var active_emp_waves: Array[Dictionary] = []

@onready var bullet_scene := preload("res://scenes/bullet.tscn")

func _ready() -> void:
	# Inicializar sistema seguro ofuscado con clave aleatoria
	_mask_key = randf_range(13579.2, 98765.4)
	_max_health_masked = max_health + _mask_key
	_damage_accumulated = 0.0
	
	current_health = max_health
	_honeypot_last = current_health
	
	collision_layer = 1  # Layer 1: Mecha
	collision_mask = 2   # Layer 2: Enemies
	area_entered.connect(_on_area_entered)
	emit_signal("health_changed", get_real_health(), max_health)
	emit_signal("xp_changed", current_xp, xp_needed, level)

func _physics_process(delta: float) -> void:
	if damage_cooldown > 0:
		damage_cooldown -= delta
	if absorb_pulse > 0:
		absorb_pulse -= delta

	# Reloj de animación procedural continuo para efectos visuales neón
	electric_anim_time += delta * 4.0

	# Chequeo periódico de integridad de memoria RAM (Detección de congelamiento HEAPF64)
	_tamper_check_timer -= delta
	if _tamper_check_timer <= 0.0:
		_tamper_check_timer = 0.1  # 10 veces por segundo
		if not _is_security_tripped:
			var real_hp := get_real_health()
			# Si un script forzó externamente `current_health` en 120 mientras el valor real decayó:
			if abs(current_health - real_hp) > 0.5:
				_trigger_security_violation("Discrepancia en comprobación de integridad HEAP")
				return
		
	# 1. NAVEGACIÓN Y PILOTAJE (Híbrido Manual / Automático)
	var active_manual_dir := get_effective_manual_direction()
	var desired_direction := Vector2.ZERO
	
	if active_manual_dir.length_squared() > 0.01:
		manual_grace_timer = 0.55
		desired_direction = active_manual_dir
	elif manual_grace_timer > 0.0:
		manual_grace_timer -= delta
		if pilot_mode == PilotMode.AUTO and manual_grace_timer <= 0.0:
			desired_direction = calculate_steering_direction()
		else:
			desired_direction = Vector2.ZERO
	else:
		if pilot_mode == PilotMode.AUTO:
			desired_direction = calculate_steering_direction()
		else:
			desired_direction = Vector2.ZERO
			
	var target_velocity := desired_direction * (base_speed * speed_multiplier)
	var lerp_weight: float = 12.0 if is_manually_controlled() else 8.0
	current_velocity = current_velocity.lerp(target_velocity, lerp_weight * delta)
	global_position += current_velocity * delta
	
	# Límites de la arena
	var viewport_size := get_viewport_rect().size
	var margin: float = 45.0
	global_position.x = clamp(global_position.x, margin, viewport_size.x - margin)
	global_position.y = clamp(global_position.y, margin, viewport_size.y - margin)

	# 2. SISTEMA DE DISPARO AUTÓNOMO Y ROTACIÓN
	shoot_timer -= delta
	var closest_enemy := get_closest_enemy()
	
	if is_instance_valid(closest_enemy):
		var aim_dir := (closest_enemy.global_position - global_position).normalized()
		rotation = lerp_angle(rotation, aim_dir.angle(), 14.0 * delta)
		
		if has_ultimate_beam:
			is_beam_firing = true
			var speed_factor: float = 14.0 + (fire_rate_level - 1) * 2.2
			electric_anim_time += delta * speed_factor
			process_ultimate_beam(delta, aim_dir)
		else:
			is_beam_firing = false
			if shoot_timer <= 0:
				fire_weapons(aim_dir)
				shoot_timer = fire_rate
	else:
		if is_beam_firing:
			AudioManager.stop_ultimate_beam()
		is_beam_firing = false
		if current_velocity.length_squared() > 900.0:
			rotation = lerp_angle(rotation, current_velocity.angle(), 8.0 * delta)
		else:
			# Escaneo de radar / centinela: rota lentamente buscando objetivos sin temblar
			rotation += 1.3 * delta

	# 3. IMÁN DE CHATARRA
	check_scrap_magnet()
	
	# 4. EVOLUCIONES SUPREMAS (ULTIMATES)
	process_ultimates(delta)
	
	queue_redraw()

func fire_weapons(direction: Vector2) -> void:
	AudioManager.play_laser()
	var perp := Vector2(-direction.y, direction.x)
	var spawn_pos := global_position
	
	if bullet_count == 1:
		spawn_bullet(spawn_pos + direction * 18.0, direction)
	elif bullet_count == 2:
		var offset: float = 9.0
		spawn_bullet(spawn_pos + direction * 18.0 + perp * offset, direction)
		spawn_bullet(spawn_pos + direction * 18.0 - perp * offset, direction)
	elif bullet_count == 3:
		var offset: float = 12.0
		spawn_bullet(spawn_pos + direction * 18.0, direction)
		spawn_bullet(spawn_pos + direction * 18.0 + perp * offset, direction)
		spawn_bullet(spawn_pos + direction * 18.0 - perp * offset, direction)
	else:
		var spread_angle := deg_to_rad(6.0)
		var start_angle := -spread_angle * (bullet_count - 1) / 2.0
		for i in range(bullet_count):
			var current_dir := direction.rotated(start_angle + (i * spread_angle))
			spawn_bullet(spawn_pos + current_dir * 18.0, current_dir)

func spawn_bullet(pos: Vector2, dir: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.direction = dir
	bullet.global_position = pos
	bullet.damage = 30.0 * damage_multiplier
	get_parent().add_child(bullet)

func activate_ultimate_beam() -> void:
	has_ultimate_beam = true
	beam_level = min(3, beam_level + 1)
	queue_redraw()

func process_ultimate_beam(delta: float, aim_dir: Vector2) -> void:
	beam_tick_timer -= delta
	AudioManager.start_ultimate_beam()
	
	var current_beam_len: float = get_beam_length()
	var current_beam_width: float = get_beam_half_width()
	
	# Procesamiento de daño continuo por ticks (frecuencia acelerada por resonancia)
	if beam_tick_timer <= 0.0:
		beam_tick_timer = get_beam_tick_interval()
		var tick_damage: float = 32.0 * damage_multiplier
		var enemies := get_tree().get_nodes_in_group("enemies")
		var hit_enemies: Dictionary = {}
		var beam_angles: Array[float] = get_beam_angles()
		
		for angle_offset in beam_angles:
			var current_dir: Vector2 = aim_dir.rotated(angle_offset)
			var beam_start: Vector2 = global_position + current_dir * 20.0
			
			for enemy in enemies:
				if not is_instance_valid(enemy) or hit_enemies.has(enemy):
					continue
					
				var enemy_pos: Vector2 = enemy.global_position
				var enemy_radius: float = 18.0
				var col_shape = enemy.get_node_or_null("CollisionShape2D")
				if col_shape and col_shape.shape is CircleShape2D:
					enemy_radius = col_shape.shape.radius
					
				var to_enemy: Vector2 = enemy_pos - beam_start
				var proj: float = to_enemy.dot(current_dir)
				if proj >= 0.0 and proj <= current_beam_len:
					var closest_pt: Vector2 = beam_start + current_dir * proj
					var hit_dist: float = enemy_radius + current_beam_width
					if enemy_pos.distance_squared_to(closest_pt) <= hit_dist * hit_dist:
						hit_enemies[enemy] = true
						enemy.take_damage(tick_damage, current_dir, 35.0)

# ==============================================================================
# GESTIÓN Y ACTIVACIÓN DE EVOLUCIONES SUPREMAS (ULTIMATES)
# ==============================================================================

func process_ultimates(delta: float) -> void:
	if has_ultimate_singularity:
		process_singularities(delta)
	if has_ultimate_trail:
		process_kinetic_trail(delta)
	if has_ultimate_vortex:
		process_orbital_vortex(delta)
	if has_ultimate_aegis or not active_emp_waves.is_empty():
		process_aegis_and_emp(delta)

# 1. Singularidad de Antimateria (Sobrecarga de Reactor)
func activate_ultimate_singularity() -> void:
	has_ultimate_singularity = true
	damage_multiplier += 0.35
	singularity_timer = 0.8 # Primera detonación rápida
	queue_redraw()

func process_singularities(delta: float) -> void:
	singularity_timer -= delta
	if singularity_timer <= 0.0:
		singularity_timer = 3.2
		var target_pos := global_position + Vector2.from_angle(rotation) * 160.0
		var closest_enemy := get_closest_enemy()
		if is_instance_valid(closest_enemy):
			target_pos = closest_enemy.global_position
			
		active_singularities.append({
			"pos": target_pos,
			"time": 0.0,
			"max_time": 1.4,
			"radius": 190.0,
			"tick_timer": 0.0
		})

	var enemies := get_tree().get_nodes_in_group("enemies")
	var scraps := get_tree().get_nodes_in_group("scraps")
	
	for i in range(active_singularities.size() - 1, -1, -1):
		var s: Dictionary = active_singularities[i]
		s.time += delta
		s.tick_timer -= delta
		var s_pos: Vector2 = s.pos
		var s_radius: float = s.radius
		
		# Succión gravitacional de enemigos hacia el núcleo
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var dist: float = enemy.global_position.distance_to(s_pos)
			if dist < s_radius and dist > 4.0:
				var pull_dir: Vector2 = (s_pos - enemy.global_position).normalized()
				var pull_speed: float = (230.0 * (1.0 - dist / s_radius) + 70.0)
				enemy.global_position += pull_dir * pull_speed * delta
				
		# Succión de chatarra
		for sc in scraps:
			if not is_instance_valid(sc):
				continue
			var dist_sc: float = sc.global_position.distance_to(s_pos)
			if dist_sc < s_radius:
				var pull_sc: Vector2 = (s_pos - sc.global_position).normalized()
				sc.global_position += pull_sc * 280.0 * delta

		# Daño continuo por compresión en el horizonte de sucesos
		if s.tick_timer <= 0.0:
			s.tick_timer = 0.12
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy.global_position.distance_to(s_pos) < 65.0:
					enemy.take_damage(16.0 * damage_multiplier, (enemy.global_position - s_pos).normalized(), 20.0)

		# Colapso final en Supernova / Implosión cataclísmica
		if s.time >= s.max_time:
			AudioManager.play_ram_explosion()
			for enemy in enemies:
				if is_instance_valid(enemy):
					var dist_e: float = enemy.global_position.distance_to(s_pos)
					if dist_e <= 170.0:
						var blast_dir: Vector2 = (enemy.global_position - s_pos).normalized() if dist_e > 1.0 else Vector2.RIGHT
						enemy.take_damage(460.0 * damage_multiplier, blast_dir, 140.0)
						
			active_emp_waves.append({
				"pos": s_pos,
				"radius": 15.0,
				"max_radius": 170.0,
				"speed": 450.0,
				"life": 0.35,
				"max_life": 0.35,
				"color": Color(1.0, 0.22, 0.42, 0.95),
				"width": 5.0
			})
			active_singularities.remove_at(i)

# 2. Estela de Iones Cinética (Servomotores de Titanio)
func activate_ultimate_trail() -> void:
	has_ultimate_trail = true
	speed_multiplier += 0.35
	queue_redraw()

func process_kinetic_trail(delta: float) -> void:
	if current_velocity.length_squared() > 300.0:
		trail_timer -= delta
		if trail_timer <= 0.0:
			trail_timer = 0.045
			active_trails.append({
				"pos": global_position,
				"life": 1.3,
				"max_life": 1.3
			})

	# Evasión de micro-dash si hay peligro inminente de enjambre
	dash_cooldown -= delta
	if dash_cooldown <= 0.0:
		var enemies := get_tree().get_nodes_in_group("enemies")
		var is_threatened := false
		for enemy in enemies:
			if is_instance_valid(enemy) and global_position.distance_to(enemy.global_position) < 110.0:
				is_threatened = true
				break
		if is_threatened:
			dash_cooldown = 4.2
			perform_ion_dash()

	# Daño de fuego esmeralda a enemigos que pisen la estela
	var enemies := get_tree().get_nodes_in_group("enemies")
	for i in range(active_trails.size() - 1, -1, -1):
		var tr: Dictionary = active_trails[i]
		tr.life -= delta
		if tr.life <= 0.0:
			active_trails.remove_at(i)
			continue
			
		var tr_pos: Vector2 = tr.pos
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(tr_pos) < 26.0:
				enemy.take_damage(26.0 * damage_multiplier * delta * 5.0, (enemy.global_position - tr_pos).normalized(), 15.0)

func perform_ion_dash() -> void:
	var dash_dir := current_velocity.normalized()
	if dash_dir.length_squared() < 0.1:
		dash_dir = Vector2.from_angle(rotation)
		
	var dash_dist: float = 125.0
	var new_pos := global_position + dash_dir * dash_dist
	
	var viewport_size := get_viewport_rect().size
	var margin: float = 45.0
	new_pos.x = clamp(new_pos.x, margin, viewport_size.x - margin)
	new_pos.y = clamp(new_pos.y, margin, viewport_size.y - margin)
	
	for step in range(6):
		var t_pos: Vector2 = global_position.lerp(new_pos, step / 5.0)
		active_trails.append({"pos": t_pos, "life": 1.6, "max_life": 1.6})
		
	global_position = new_pos
	damage_cooldown = 0.35
	AudioManager.play_laser()

# 3. Vórtice de Metralla Orbital (Imán Cuántico)
func activate_ultimate_vortex() -> void:
	has_ultimate_vortex = true
	magnet_radius = 3500.0
	queue_redraw()

func process_orbital_vortex(delta: float) -> void:
	vortex_angle += delta * 4.6
	var enemies := get_tree().get_nodes_in_group("enemies")
	
	for i in range(VORTEX_BLADES):
		var blade_ang := vortex_angle + (i * TAU / VORTEX_BLADES)
		var blade_global := global_position + Vector2(cos(blade_ang), sin(blade_ang)) * VORTEX_RADIUS
		
		for enemy in enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_to(blade_global) < 22.0:
				var hit_dir: Vector2 = (enemy.global_position - global_position).normalized()
				enemy.take_damage(28.0 * damage_multiplier, hit_dir, 45.0)

# 4. Protocolo Fénix & Égida Hexagonal (Reparación Nanotecnológica)
func activate_ultimate_aegis() -> void:
	has_ultimate_aegis = true
	aegis_shield_active = true
	aegis_cooldown = 0.0
	phoenix_used = false
	queue_redraw()

func process_aegis_and_emp(delta: float) -> void:
	if has_ultimate_aegis and not aegis_shield_active:
		aegis_cooldown -= delta
		if aegis_cooldown <= 0.0:
			aegis_shield_active = true
			AudioManager.play_laser()
			active_emp_waves.append({
				"pos": global_position,
				"radius": 10.0,
				"max_radius": 60.0,
				"speed": 220.0,
				"life": 0.3,
				"max_life": 0.3,
				"color": Color(0.2, 1.0, 0.85, 0.8),
				"width": 3.0
			})

	for i in range(active_emp_waves.size() - 1, -1, -1):
		var wave: Dictionary = active_emp_waves[i]
		wave.radius += wave.speed * delta
		wave.life -= delta
		if wave.life <= 0.0 or wave.radius >= wave.max_radius:
			active_emp_waves.remove_at(i)

func trigger_aegis_emp_pulse() -> void:
	AudioManager.play_ram_explosion()
	var enemy_bullets := get_tree().get_nodes_in_group("enemy_bullets")
	for b in enemy_bullets:
		if is_instance_valid(b) and global_position.distance_to(b.global_position) < 280.0:
			b.queue_free()
			
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var dist: float = global_position.distance_to(enemy.global_position)
			if dist < 280.0:
				var push_dir: Vector2 = (enemy.global_position - global_position).normalized()
				enemy.take_damage(95.0 * damage_multiplier, push_dir, 90.0)

	active_emp_waves.append({
		"pos": global_position,
		"radius": 20.0,
		"max_radius": 280.0,
		"speed": 550.0,
		"life": 0.5,
		"max_life": 0.5,
		"color": Color(0.2, 1.0, 0.85, 0.95),
		"width": 4.5
	})

func trigger_phoenix_rebirth() -> void:
	AudioManager.play_ram_explosion()
	_damage_accumulated = 0.0
	var real_hp := get_real_health()
	current_health = real_hp
	_honeypot_last = real_hp
	damage_cooldown = 3.2
	
	emit_signal("health_changed", real_hp, max_health)
	emit_signal("alert_requested", "¡PROTOCOLO FÉNIX! SISTEMA REINICIADO (INVULNERABLE)")
	
	var enemy_bullets := get_tree().get_nodes_in_group("enemy_bullets")
	for b in enemy_bullets:
		if is_instance_valid(b):
			b.queue_free()
			
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy):
			var push_dir: Vector2 = (enemy.global_position - global_position).normalized()
			enemy.take_damage(260.0 * damage_multiplier, push_dir, 150.0)

	active_emp_waves.append({
		"pos": global_position,
		"radius": 30.0,
		"max_radius": 650.0,
		"speed": 700.0,
		"life": 0.85,
		"max_life": 0.85,
		"color": Color(1.0, 0.85, 0.2, 0.95),
		"width": 6.0
	})

func calculate_steering_direction() -> Vector2:
	var avoidance_force := Vector2.ZERO
	var scrap_force := Vector2.ZERO
	var boundary_force := Vector2.ZERO
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var enemy_count_in_danger: int = 0
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or not is_target_on_screen(enemy):
			continue
		var dist := global_position.distance_to(enemy.global_position)
		if dist < danger_radius and dist > 0.01:
			var push_away: Vector2 = (global_position - enemy.global_position).normalized()
			var weight: float = (1.0 - (dist / danger_radius)) * 2.2
			avoidance_force += push_away * weight
			enemy_count_in_danger += 1
			
	# Evasión táctica de proyectiles enemigos
	var enemy_bullets := get_tree().get_nodes_in_group("enemy_bullets")
	for b in enemy_bullets:
		if not is_instance_valid(b):
			continue
		var dist_b := global_position.distance_to(b.global_position)
		if dist_b < 130.0 and dist_b > 0.01:
			var push_b: Vector2 = (global_position - b.global_position).normalized()
			var weight_b: float = (1.0 - (dist_b / 130.0)) * 3.0
			avoidance_force += push_b * weight_b
			
	# 2. Atracción hacia el Scrap/XP más cercano (si no hay peligro extremo)
	if enemy_count_in_danger < 4:
		var closest_scrap := get_closest_scrap()
		if is_instance_valid(closest_scrap):
			scrap_force = (closest_scrap.global_position - global_position).normalized() * 1.8
			
	# 3. Retorno instintivo al CENTRO TÁCTICO de la arena (cuando el camino está despejado)
	var viewport_size := get_viewport_rect().size
	var center := viewport_size * 0.5
	var center_force := Vector2.ZERO
	var dist_to_center := global_position.distance_to(center)
	
	if dist_to_center > 30.0:
		# Cuanto más lejos del centro esté, más deseo tiene de volver al corazón seguro de la arena
		var center_weight: float = 1.0 if enemy_count_in_danger == 0 else 0.4
		# Desaceleración suave (ease-out) al aproximarse al centro para evitar sobrepasar y temblar
		var speed_factor: float = clamp((dist_to_center - 30.0) / 160.0, 0.0, 1.0)
		center_force = (center - global_position).normalized() * speed_factor * center_weight

	# 4. Repulsión de bordes de la pantalla
	var boundary_margin: float = 55.0
	
	if global_position.x < boundary_margin:
		var factor := (boundary_margin - global_position.x) / boundary_margin
		boundary_force.x += factor * 2.0
	elif global_position.x > viewport_size.x - boundary_margin:
		var factor := (global_position.x - (viewport_size.x - boundary_margin)) / boundary_margin
		boundary_force.x -= factor * 2.0
		
	if global_position.y < boundary_margin:
		var factor := (boundary_margin - global_position.y) / boundary_margin
		boundary_force.y += factor * 2.0
	elif global_position.y > viewport_size.y - boundary_margin:
		var factor := (global_position.y - (viewport_size.y - boundary_margin)) / boundary_margin
		boundary_force.y -= factor * 2.0

	# Suma ponderada de fuerzas
	var total_vector: Vector2 = (avoidance_force * 2.0) + scrap_force + boundary_force + (center_force * 1.4)
	
	# Si está en el centro sin enemigos ni chatarra de peligro, frenado absoluto (deadband limpio)
	if avoidance_force.length_squared() < 0.01 and scrap_force.length_squared() < 0.01 and dist_to_center <= 30.0:
		return Vector2.ZERO
		
	if total_vector.length() > 1.0:
		return total_vector.normalized()
	return total_vector

func get_closest_enemy() -> Node2D:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var closest: Node2D = null
	var min_dist: float = sensor_range
	for enemy in enemies:
		if is_instance_valid(enemy) and is_target_on_screen(enemy):
			var dist := global_position.distance_to(enemy.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = enemy
	return closest

func get_closest_scrap() -> Node2D:
	var scraps := get_tree().get_nodes_in_group("scraps")
	var closest: Node2D = null
	var min_dist: float = 2000.0
	for scrap in scraps:
		if is_instance_valid(scrap):
			var dist := global_position.distance_to(scrap.global_position)
			if dist < min_dist:
				min_dist = dist
				closest = scrap
	return closest

func check_scrap_magnet() -> void:
	var scraps := get_tree().get_nodes_in_group("scraps")
	for scrap in scraps:
		if is_instance_valid(scrap) and scrap.has_method("attract_to"):
			var dist := global_position.distance_to(scrap.global_position)
			if dist <= magnet_radius:
				scrap.attract_to(self)

func is_target_on_screen(target_node: Node2D) -> bool:
	var v_rect := get_viewport_rect()
	var screen_rect := Rect2(Vector2.ZERO, v_rect.size).grow(-20.0)
	return screen_rect.has_point(target_node.global_position)

func gain_xp(amount: int) -> void:
	current_xp += amount
	if current_xp >= xp_needed:
		current_xp -= xp_needed
		level += 1
		xp_needed = calculate_xp_needed(level)
		AudioManager.play_levelup()
		emit_signal("level_up", level)
	emit_signal("xp_changed", current_xp, xp_needed, level)

func calculate_xp_needed(lvl: int) -> int:
	if lvl <= 4:
		return 35 + (lvl * 25)
	elif lvl <= 12:
		return 140 + (lvl * 50)
	else:
		var bonus := pow(float(lvl - 10), 1.7) * 20.0
		return int(380 + (lvl * 75) + bonus)

func get_real_health() -> float:
	var real_max := _max_health_masked - _mask_key
	return max(0.0, real_max - _damage_accumulated)

func heal(amount: float) -> void:
	if _is_security_tripped:
		return
	_damage_accumulated = max(0.0, _damage_accumulated - amount)
	var real_hp := get_real_health()
	current_health = real_hp
	_honeypot_last = real_hp
	emit_signal("health_changed", real_hp, max_health)

func increase_max_health(amount: float, heal_amount: float = 0.0) -> void:
	if _is_security_tripped:
		return
	max_health += amount
	_max_health_masked += amount
	if heal_amount > 0.0:
		_damage_accumulated = max(0.0, _damage_accumulated - heal_amount)
	var real_hp := get_real_health()
	current_health = real_hp
	_honeypot_last = real_hp
	emit_signal("health_changed", real_hp, max_health)

func take_damage(amount: float) -> void:
	if damage_cooldown > 0 or _is_security_tripped:
		return
		
	# Detección inmediata si un bucle de script en JS congeló o incrementó la trampa
	if current_health > _honeypot_last + 0.01:
		_trigger_security_violation("Inyección externa en variable de salud detectada")
		return
		
	# 🛡️ Si la Égida Hexagonal está activa, absorbe el impacto completamente y dispara pulso EMP
	if has_ultimate_aegis and aegis_shield_active:
		aegis_shield_active = false
		aegis_cooldown = 10.0 # Tiempo de recarga del escudo
		damage_cooldown = 0.45
		trigger_aegis_emp_pulse()
		return

	# Daño silencioso (el feedback visual de daño parpadea sin saturar sonido)
	_damage_accumulated += amount
	var real_hp := get_real_health()
	
	current_health = real_hp
	_honeypot_last = real_hp
	damage_cooldown = 0.35
	emit_signal("health_changed", real_hp, max_health)
	
	if real_hp <= 0:
		# 🦅 Protocolo Fénix: Resurrección de emergencia si no se ha usado
		if has_ultimate_aegis and not phoenix_used:
			phoenix_used = true
			trigger_phoenix_rebirth()
			return
		emit_signal("mecha_destroyed", level)

func _trigger_security_violation(reason: String) -> void:
	if _is_security_tripped:
		return
	_is_security_tripped = true
	print_debug("[CENTINELA] VIOLACIÓN DE INTEGRIDAD: ", reason)
	current_health = 0.0
	_honeypot_last = 0.0
	emit_signal("health_changed", 0.0, max_health)
	emit_signal("mecha_destroyed", -1)

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies") and "contact_damage" in area:
		take_damage(area.contact_damage)
		if area.has_method("on_rammed_mecha"):
			area.on_rammed_mecha()

func _draw() -> void:
	# 1. EFECTOS GLOBALES EN COORDENADAS LOCALES (FONDO)
	# Estelas de Iones Cinéticas (Fuego Esmeralda)
	for tr in active_trails:
		var lp: Vector2 = to_local(tr.pos)
		var alpha: float = clamp(tr.life / tr.max_life, 0.0, 1.0)
		draw_circle(lp, 11.0 * alpha, Color(0.1, 1.0, 0.5, alpha * 0.4))
		draw_circle(lp, 5.5 * alpha, Color(0.3, 1.0, 0.7, alpha * 0.8))
		draw_circle(lp, 2.0 * alpha, Color(0.9, 1.0, 0.95, alpha))

	# Singularidades de Antimateria (Agujeros negros carmesí)
	for s in active_singularities:
		var sp: Vector2 = to_local(s.pos)
		var s_time_factor: float = clamp(1.0 - (s.time / s.max_time), 0.0, 1.0)
		
		# Distorsión gravitatoria exterior pulsante
		draw_arc(sp, s.radius * s_time_factor, 0.0, TAU, 32, Color(1.0, 0.25, 0.4, 0.28), 2.0)
		# Horizonte de sucesos abisal
		draw_circle(sp, 20.0, Color(0.06, 0.02, 0.10, 0.96))
		# Anillo de acreción carmesí ardiente
		draw_arc(sp, 20.0, 0.0, TAU, 28, Color(1.0, 0.2, 0.42, 0.95), 3.0)
		
		# Brazos espirales rotatorios de antimateria
		var spin_ang := electric_anim_time * 3.0 - rotation
		draw_arc(sp, 26.0 + sin(spin_ang) * 4.0, spin_ang, spin_ang + PI, 20, Color(1.0, 0.45, 0.65, 0.8), 2.0)
		draw_arc(sp, 32.0 + cos(spin_ang) * 5.0, spin_ang + PI, spin_ang + TAU, 20, Color(0.9, 0.3, 0.85, 0.75), 1.8)
		# Singularidad central pura
		draw_circle(sp, 3.5, Color.WHITE)

	# Ondas de Choque EMP Neón
	for w in active_emp_waves:
		var wp: Vector2 = to_local(w.pos)
		var w_alpha: float = clamp(w.life / w.max_life, 0.0, 1.0)
		var c: Color = w.color
		c.a = w_alpha * c.a
		draw_arc(wp, w.radius, 0.0, TAU, 36, c, w.width * w_alpha)

	# 2. HAZ CONTINUO DE FISIÓN CUÁNTICA PROGRESIVO (1 A 3 HACES)
	if has_ultimate_beam and is_beam_firing:
		var current_beam_len: float = get_beam_length()
		var beam_angles: Array[float] = get_beam_angles()
		
		var glow_w: float = 24.0 + (fire_rate_level - 1) * 2.4
		var core_w: float = 12.0 + (fire_rate_level - 1) * 1.4
		var hot_w: float = 3.0 + (fire_rate_level - 1) * 0.4
		var arc_w: float = 2.0 + (fire_rate_level - 1) * 0.22
		var arc_amplitude: float = 9.0 + (fire_rate_level - 1) * 1.8
		var noise_amplitude: float = 4.0 + (fire_rate_level - 1) * 0.8
		var fork_reach: float = 10.0 + (fire_rate_level - 1) * 2.5
		
		for b_idx in range(beam_angles.size()):
			var ang: float = beam_angles[b_idx]
			var dir_vec := Vector2.from_angle(ang)
			var start_pt := dir_vec * 20.0
			var end_pt := dir_vec * current_beam_len
			var perp_vec := Vector2(-dir_vec.y, dir_vec.x)
			
			# 1. Halo difuso exterior expandido
			draw_line(start_pt, end_pt, Color(0.05, 0.65, 1.0, 0.28), glow_w)
			# 2. Haz de plasma medio de alta energía
			draw_line(start_pt, end_pt, Color(0.3, 0.92, 1.0, 0.85), core_w)
			# 3. Núcleo de fisión blanco supercaliente
			draw_line(start_pt, end_pt, Color(1.0, 1.0, 1.0, 1.0), hot_w)
			
			# 4. Rayos y arcos eléctricos serpenteando con amplitud creciente según resonancia
			var arc_pts_1 := PackedVector2Array()
			var arc_pts_2 := PackedVector2Array()
			var num_steps := int((current_beam_len - 24.0) / 30.0)
			var phase_offset: float = b_idx * 1.8
			
			for i in range(num_steps + 1):
				var dist_along: float = 24.0 + (i * 30.0)
				var base_pt := dir_vec * dist_along
				
				# Onda 1 + fluctuación caótica transversal
				var wave1 := sin(dist_along * 0.032 + electric_anim_time + phase_offset) * arc_amplitude
				var noise1 := sin(dist_along * 0.12 + electric_anim_time * 2.2 + b_idx) * noise_amplitude
				arc_pts_1.append(base_pt + perp_vec * (wave1 + noise1))
				
				# Onda 2 en contrafase
				var wave2 := cos(dist_along * 0.038 - electric_anim_time * 1.5 + phase_offset) * (arc_amplitude * 1.1)
				var noise2 := cos(dist_along * 0.14 - electric_anim_time * 2.6 + b_idx) * noise_amplitude
				arc_pts_2.append(base_pt + perp_vec * (wave2 + noise2))
				
			draw_polyline(arc_pts_1, Color(0.75, 0.95, 1.0, 0.95), arc_w)
			draw_polyline(arc_pts_2, Color(0.35, 0.88, 1.0, 0.85), arc_w * 0.85)
			
			# Bifurcaciones y chispas de plasma que brotan del rayo con mayor alcance
			for i in range(2, num_steps - 1, 3):
				var pt: Vector2 = arc_pts_1[i]
				var f_dir: float = 1.0 if (i % 2 == 0) else -1.0
				var f_len: float = fork_reach + sin(electric_anim_time * 3.0 + i + b_idx) * (5.0 + fire_rate_level)
				var fork_end := pt + perp_vec * (f_dir * f_len) + dir_vec * (sin(electric_anim_time + i) * 6.0)
				draw_line(pt, fork_end, Color(0.85, 0.98, 1.0, 0.75), arc_w * 0.7)
				draw_circle(pt, 2.2 + (fire_rate_level - 1) * 0.25, Color.WHITE)
				
			# Flares en las salidas de cada cañón
			draw_circle(start_pt, 5.0 + (fire_rate_level - 1) * 0.6, Color(0.3, 0.9, 1.0, 0.9))
			draw_circle(start_pt, 2.0 + (fire_rate_level - 1) * 0.3, Color.WHITE)
			
		# Gran prisma emisor cuántico central escalado
		draw_circle(Vector2(22, 0), 12.0 + (fire_rate_level - 1) * 1.2, Color(0.15, 0.8, 1.0, 0.45))
		draw_circle(Vector2(22, 0), 5.0 + (fire_rate_level - 1) * 0.5, Color.WHITE)

	# 3. TIFÓN CUÁNTICO DE METRALLA (TORNADO ESPIRAL DE XP)
	if has_ultimate_vortex:
		# Anillos orbitales concéntricos del ciclón
		draw_arc(Vector2.ZERO, 55.0, 0.0, TAU, 32, Color(0.75, 0.35, 1.0, 0.20), 1.2)
		draw_arc(Vector2.ZERO, 110.0, 0.0, TAU, 36, Color(0.75, 0.35, 1.0, 0.16), 1.2)
		draw_arc(Vector2.ZERO, 180.0, 0.0, TAU, 40, Color(0.85, 0.45, 1.0, 0.22), 1.5)
		
		# 4 Brazos de viento etéreo en espiral de tornado
		var num_arms: int = 4
		for a in range(num_arms):
			var base_arm_ang: float = (vortex_angle * 0.45) + (a * TAU / num_arms) - rotation
			var arm_pts := PackedVector2Array()
			var steps := 12
			for st in range(steps + 1):
				var r: float = 24.0 + (st * (180.0 - 24.0) / float(steps))
				var spiral_ang: float = base_arm_ang + (r / 180.0) * 2.4
				arm_pts.append(Vector2(cos(spiral_ang), sin(spiral_ang)) * r)
			draw_polyline(arm_pts, Color(0.78, 0.42, 1.0, 0.28), 2.2)
			
		# Núcleo de absorción / destello al devorar chatarra
		if absorb_pulse > 0.0:
			var pulse_alpha: float = clamp(absorb_pulse / 0.16, 0.0, 1.0)
			draw_circle(Vector2.ZERO, 28.0 + (1.0 - pulse_alpha) * 12.0, Color(0.3, 0.9, 1.0, pulse_alpha * 0.45))
			draw_circle(Vector2.ZERO, 10.0, Color(1.0, 1.0, 1.0, pulse_alpha * 0.85))

	# 4. CHASIS Y AURA DEL MECHA
	var aura_color := Color(1.0, 0.85, 0.2, 0.25) if has_ultimate_beam else Color(0.1, 0.8, 1.0, 0.15)
	if has_ultimate_singularity:
		aura_color = Color(1.0, 0.25, 0.4, 0.3)
	elif has_ultimate_aegis:
		aura_color = Color(0.15, 0.95, 0.85, 0.3)
	draw_circle(Vector2.ZERO, 25.0, aura_color)
	
	var chassis_points := PackedVector2Array([
		Vector2(16, 0),
		Vector2(8, 14),
		Vector2(-12, 14),
		Vector2(-16, 0),
		Vector2(-12, -14),
		Vector2(8, -14)
	])
	
	# Propulsores manuales activos (Fogonazo de plasma ámbar en toberas traseras)
	if is_manually_controlled() and current_velocity.length_squared() > 400.0:
		var thrust_flicker: float = sin(electric_anim_time * 14.0) * 4.0
		for off_y in [-8.0, 8.0]:
			draw_line(Vector2(-14, off_y), Vector2(-24 - thrust_flicker, off_y), Color(1.0, 0.75, 0.2, 0.85), 3.5)
			draw_line(Vector2(-14, off_y), Vector2(-19 - thrust_flicker * 0.5, off_y), Color(1.0, 1.0, 1.0), 1.8)

	draw_colored_polygon(chassis_points, Color(0.12, 0.16, 0.24, 1.0))
	var border_color := Color(1.0, 0.85, 0.2, 1.0) if has_ultimate_beam else Color(0.2, 0.9, 1.0, 1.0)
	draw_polyline(chassis_points, border_color, 2.0)
	
	draw_rect(Rect2(12, -9, 10, 4), border_color)
	draw_rect(Rect2(12, 5, 10, 4), border_color)
	
	if has_ultimate_beam:
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.2, 0.9))
		draw_circle(Vector2.ZERO, 3.5, Color(1.0, 1.0, 1.0, 1.0))
	else:
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 1.0, 1.0, 0.9))
		draw_circle(Vector2.ZERO, 3.0, Color(0.1, 0.9, 1.0, 1.0))

	# 5. PROTOCOLO FÉNIX & ÉGIDA HEXAGONAL (BARRERA DE ENERGÍA Y REVIVE)
	if has_ultimate_aegis:
		if aegis_shield_active:
			var hex_radius: float = 34.0
			var hex_pts := PackedVector2Array()
			var hex_outline := PackedVector2Array()
			
			for a in range(6):
				var ang := (a * TAU / 6.0) + (electric_anim_time * 0.2)
				var pulse: float = sin(electric_anim_time * 4.0 + a) * 1.5
				var pt := Vector2(cos(ang), sin(ang)) * (hex_radius + pulse)
				hex_pts.append(pt)
				hex_outline.append(pt)
			hex_outline.append(hex_pts[0])
			
			draw_colored_polygon(hex_pts, Color(0.12, 0.95, 0.85, 0.16))
			draw_polyline(hex_outline, Color(0.25, 1.0, 0.88, 0.92), 2.4)
			
			for pt in hex_pts:
				draw_circle(pt, 3.0, Color(0.2, 1.0, 0.85, 0.7))
				draw_circle(pt, 1.5, Color.WHITE)
		elif damage_cooldown > 0.0 and phoenix_used:
			# Resplandor radiante de renacimiento fénix
			var phoenix_pulse := (sin(electric_anim_time * 8.0) * 0.5 + 0.5)
			draw_arc(Vector2.ZERO, 38.0 + phoenix_pulse * 6.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.2, 0.85), 3.0)
			draw_circle(Vector2.ZERO, 36.0, Color(1.0, 0.6, 0.1, 0.22))
