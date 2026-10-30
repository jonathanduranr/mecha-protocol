extends Area2D

signal health_changed(current: float, max_val: float)
signal xp_changed(current: int, needed: int, level: int)
signal level_up(new_level: int)
signal mecha_destroyed(final_level: int)

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
		
	# 1. IA DE SUPERVIVENCIA Y NAVEGACIÓN
	var desired_direction: Vector2 = calculate_steering_direction()
	var target_velocity := desired_direction * (base_speed * speed_multiplier)
	
	current_velocity = current_velocity.lerp(target_velocity, 8.0 * delta)
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
		
		if shoot_timer <= 0:
			fire_weapons(aim_dir)
			shoot_timer = fire_rate
	else:
		if current_velocity.length_squared() > 900.0:
			rotation = lerp_angle(rotation, current_velocity.angle(), 8.0 * delta)
		else:
			# Escaneo de radar / centinela: rota lentamente buscando objetivos sin temblar
			rotation += 1.3 * delta

	# 3. IMÁN DE CHATARRA
	check_scrap_magnet()
	queue_redraw()

func fire_weapons(direction: Vector2) -> void:
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
		
	# Daño silencioso (el feedback visual de daño parpadea sin saturar sonido)
	_damage_accumulated += amount
	var real_hp := get_real_health()
	
	current_health = real_hp
	_honeypot_last = real_hp
	damage_cooldown = 0.35
	emit_signal("health_changed", real_hp, max_health)
	
	if real_hp <= 0:
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
	draw_circle(Vector2.ZERO, 24.0, Color(0.1, 0.8, 1.0, 0.15))
	
	var chassis_points := PackedVector2Array([
		Vector2(16, 0),
		Vector2(8, 14),
		Vector2(-12, 14),
		Vector2(-16, 0),
		Vector2(-12, -14),
		Vector2(8, -14)
	])
	draw_colored_polygon(chassis_points, Color(0.12, 0.16, 0.24, 1.0))
	draw_polyline(chassis_points, Color(0.2, 0.9, 1.0, 1.0), 2.0)
	
	draw_rect(Rect2(12, -9, 10, 4), Color(0.2, 0.9, 1.0, 1.0))
	draw_rect(Rect2(12, 5, 10, 4), Color(0.2, 0.9, 1.0, 1.0))
	
	draw_circle(Vector2.ZERO, 5.0, Color(1.0, 1.0, 1.0, 0.9))
	draw_circle(Vector2.ZERO, 3.0, Color(0.1, 0.9, 1.0, 1.0))
