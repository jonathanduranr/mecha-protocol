extends Area2D

@export var drone_type: String = "scout" # "scout", "tank", "swarm", "shooter", "boss"
@export var max_health: float = 30.0
@export var speed: float = 160.0
@export var contact_damage: float = 12.0
@export var xp_reward: int = 10

var current_health: float
var target_mecha: Node2D = null
var flash_timer: float = 0.0

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_resistance: float = 0.0 # 0.0 (vuela lejos) a 1.0 (inmune)

# Comportamiento especial Charger (swarm)
enum ChargerState { PURSUE, CHARGING, DASHING, COOLDOWN }
var charger_state: int = ChargerState.PURSUE
var state_timer: float = 0.0
var dash_direction: Vector2 = Vector2.ZERO

# Comportamiento especial Shooter
var shoot_timer: float = 1.5

# Comportamiento especial Boss
var boss_attack_timer: float = 4.0

@onready var scrap_scene := preload("res://scenes/scrap.tscn")
@onready var enemy_bullet_scene := preload("res://scenes/enemy_bullet.tscn")
@onready var explosion_scene := preload("res://scenes/explosion.tscn")

func _ready() -> void:
	setup_type()
	current_health = max_health
	collision_layer = 2  # Layer 2: Enemies
	collision_mask = 5   # Layer 1: Mecha, Layer 3: Bullets

func setup_type() -> void:
	var shape := $CollisionShape2D.shape as CircleShape2D
	match drone_type:
		"scout":
			speed = 185.0
			contact_damage = 18.0
			xp_reward = 10
			knockback_resistance = 0.15
			if shape: shape.radius = 16.0
		"tank":
			speed = 95.0
			contact_damage = 42.0
			xp_reward = 40
			knockback_resistance = 0.85
			if shape: shape.radius = 28.0
		"swarm":
			speed = 285.0 # Más rápido que el Mecha (260 px/s) para obligar a dispararle
			contact_damage = 22.0
			xp_reward = 12
			knockback_resistance = 0.05
			if shape: shape.radius = 14.0
		"shooter":
			speed = 120.0
			contact_damage = 16.0
			xp_reward = 25
			knockback_resistance = 0.4
			if shape: shape.radius = 18.0
		"boss":
			speed = 75.0
			contact_damage = 55.0
			xp_reward = 250
			knockback_resistance = 1.0
			if shape: shape.radius = 48.0

func _physics_process(delta: float) -> void:
	if flash_timer > 0:
		flash_timer -= delta
		queue_redraw()
		
	# Disipar velocidad de knockback
	if knockback_velocity.length_squared() > 10.0:
		global_position += knockback_velocity * delta
		knockback_velocity = knockback_velocity.lerp(Vector2.ZERO, 10.0 * delta)
		
	if not is_instance_valid(target_mecha):
		return
		
	var dist_to_mecha := global_position.distance_to(target_mecha.global_position)
	var dir_to_mecha := (target_mecha.global_position - global_position).normalized()
	
	# Separación de enjambre (Evitar que se apilen encima unos de otros)
	var separation := calculate_flock_separation()
	
	match drone_type:
		"scout", "tank":
			var move_dir := (dir_to_mecha + separation * 0.8).normalized()
			global_position += move_dir * speed * delta
			rotation = lerp_angle(rotation, move_dir.angle(), 10.0 * delta)
			
		"swarm":
			process_charger_behavior(delta, dist_to_mecha, dir_to_mecha, separation)
			
		"shooter":
			process_shooter_behavior(delta, dist_to_mecha, dir_to_mecha, separation)
			
		"boss":
			var move_dir := (dir_to_mecha + separation * 0.4).normalized()
			global_position += move_dir * speed * delta
			rotation = lerp_angle(rotation, move_dir.angle(), 4.0 * delta)
			process_boss_attacks(delta, dir_to_mecha)

func process_charger_behavior(delta: float, dist: float, dir_to_mecha: Vector2, separation: Vector2) -> void:
	state_timer -= delta
	match charger_state:
		ChargerState.PURSUE:
			var move_dir := (dir_to_mecha + separation * 0.9).normalized()
			global_position += move_dir * speed * delta
			rotation = lerp_angle(rotation, move_dir.angle(), 12.0 * delta)
			# Si se acerca a menos de 220px, prepara la embestida
			if dist < 220.0 and state_timer <= 0:
				charger_state = ChargerState.CHARGING
				state_timer = 0.45 # Tiempo de carga
				dash_direction = dir_to_mecha
				queue_redraw()
				
		ChargerState.CHARGING:
			# Se frena y vibra antes de salir disparado
			rotation = dash_direction.angle()
			queue_redraw()
			if state_timer <= 0:
				charger_state = ChargerState.DASHING
				state_timer = 0.45 # Duración del dash
				
		ChargerState.DASHING:
			# Embestida a toda velocidad en línea recta
			global_position += dash_direction * (speed * 2.8) * delta
			rotation = dash_direction.angle()
			if state_timer <= 0:
				charger_state = ChargerState.COOLDOWN
				state_timer = 1.0
				
		ChargerState.COOLDOWN:
			# Recuperándose brevemente
			global_position += (dir_to_mecha + separation * 0.5).normalized() * (speed * 0.5) * delta
			if state_timer <= 0:
				charger_state = ChargerState.PURSUE

func process_shooter_behavior(delta: float, dist: float, dir_to_mecha: Vector2, separation: Vector2) -> void:
	shoot_timer -= delta
	rotation = lerp_angle(rotation, dir_to_mecha.angle(), 8.0 * delta)
	
	# Mantiene distancia táctica (idealmente ~330px)
	var move_vector := Vector2.ZERO
	if dist > 360.0:
		move_vector = dir_to_mecha # Acercarse
	elif dist < 270.0:
		move_vector = -dir_to_mecha * 0.8 # Retroceder
	else:
		# Orbitar lateralmente
		move_vector = Vector2(-dir_to_mecha.y, dir_to_mecha.x) * 0.6
		
	var final_move := (move_vector + separation * 1.2).normalized()
	global_position += final_move * speed * delta
	
	if shoot_timer <= 0:
		shoot_timer = 1.7
		fire_enemy_bullet(dir_to_mecha)

func fire_enemy_bullet(direction: Vector2) -> void:
	var bullet = enemy_bullet_scene.instantiate()
	bullet.global_position = global_position + direction * 16.0
	bullet.direction = direction
	get_parent().add_child(bullet)

func process_boss_attacks(delta: float, dir_to_mecha: Vector2) -> void:
	boss_attack_timer -= delta
	if boss_attack_timer <= 0:
		boss_attack_timer = 4.8
		# Pulso de 8 proyectiles radiales (360 grados)
		var bullet_count: int = 8
		var angle_step := TAU / bullet_count
		for i in range(bullet_count):
			var angle := i * angle_step
			var dir := Vector2(cos(angle), sin(angle))
			fire_enemy_bullet(dir)

func calculate_flock_separation() -> Vector2:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var separation_force := Vector2.ZERO
	var neighbor_count: int = 0
	var desired_separation: float = 34.0
	var desired_sep_sq := desired_separation * desired_separation
	
	for other in enemies:
		if other == self or not is_instance_valid(other):
			continue
		var dist_sq := global_position.distance_squared_to(other.global_position)
		if dist_sq < desired_sep_sq and dist_sq > 0.01:
			var diff: Vector2 = (global_position - other.global_position).normalized()
			separation_force += diff / sqrt(dist_sq)
			neighbor_count += 1
			if neighbor_count >= 5: # Límite para rendimiento óptimo
				break
				
	return separation_force.normalized()

func take_damage(amount: float, knockback_dir: Vector2 = Vector2.ZERO, force: float = 0.0) -> void:
	current_health -= amount
	flash_timer = 0.08
	
	# Aplicar Knockback
	if force > 0 and knockback_resistance < 1.0:
		var effective_force := force * (1.0 - knockback_resistance)
		knockback_velocity = knockback_dir * effective_force
		
	queue_redraw()
	
	if current_health <= 0:
		die()

func die() -> void:
	var scrap = scrap_scene.instantiate()
	scrap.xp_value = xp_reward
	scrap.global_position = global_position
	get_parent().add_child(scrap)
	queue_free()

func on_rammed_mecha() -> void:
	if drone_type == "scout" or drone_type == "swarm":
		spawn_explosion()
		die()

func spawn_explosion() -> void:
	var exp_node = explosion_scene.instantiate()
	exp_node.global_position = global_position
	get_parent().add_child(exp_node)

func _draw() -> void:
	var flash := flash_timer > 0
	
	match drone_type:
		"scout":
			var body_color := Color(1.0, 1.0, 1.0) if flash else Color(1.0, 0.2, 0.4)
			var pts := PackedVector2Array([
				Vector2(14, 0), Vector2(-10, -10), Vector2(-4, 0), Vector2(-10, 10)
			])
			draw_colored_polygon(pts, body_color)
			draw_polyline(pts, Color(1.0, 0.5, 0.7), 1.5)
			draw_circle(Vector2(2, 0), 2.5, Color(1.0, 0.9, 0.2))

		"tank":
			var body_color := Color(1.0, 1.0, 1.0) if flash else Color(0.2, 0.3, 0.6)
			var border_color := Color(0.4, 0.7, 1.0)
			var pts := PackedVector2Array([
				Vector2(24, 0), Vector2(12, 20), Vector2(-16, 20),
				Vector2(-24, 0), Vector2(-16, -20), Vector2(12, -20)
			])
			draw_colored_polygon(pts, body_color)
			draw_polyline(pts, border_color, 2.5)
			draw_rect(Rect2(-8, -8, 16, 16), Color(0.3, 0.8, 1.0, 0.7))

		"swarm":
			# Embestidor (parpadea intensamente si está cargando energía)
			var body_color := Color(1.0, 1.0, 1.0) if (flash or charger_state == ChargerState.CHARGING) else Color(1.0, 0.85, 0.1)
			if charger_state == ChargerState.CHARGING:
				# Línea de mira de advertencia
				draw_line(Vector2.ZERO, Vector2(60, 0), Color(1.0, 0.2, 0.2, 0.7), 2.0)
			var pts := PackedVector2Array([
				Vector2(15, 0), Vector2(-9, -7), Vector2(-9, 7)
			])
			draw_colored_polygon(pts, body_color)
			draw_circle(Vector2(-2, 0), 3.0, Color(1.0, 0.3, 0.1))

		"shooter":
			# Dron Francotirador a Distancia (Romboide verde/ámbar tecnológico)
			var body_color := Color(1.0, 1.0, 1.0) if flash else Color(0.1, 0.6, 0.4)
			var border_color := Color(0.2, 1.0, 0.6)
			var pts := PackedVector2Array([
				Vector2(16, 0), Vector2(0, 12), Vector2(-14, 0), Vector2(0, -12)
			])
			draw_colored_polygon(pts, body_color)
			draw_polyline(pts, border_color, 2.0)
			# Cañón frontal
			draw_rect(Rect2(12, -2.5, 8, 5), Color(0.2, 1.0, 0.6))
			draw_circle(Vector2.ZERO, 3.5, Color(1.0, 0.8, 0.2))

		"boss":
			var body_color := Color(1.0, 1.0, 1.0) if flash else Color(0.15, 0.12, 0.22)
			var border_color := Color(1.0, 0.2, 0.5)
			var pts := PackedVector2Array([
				Vector2(44, 0), Vector2(32, 32), Vector2(0, 44), Vector2(-32, 32),
				Vector2(-44, 0), Vector2(-32, -32), Vector2(0, -44), Vector2(32, -32)
			])
			draw_colored_polygon(pts, body_color)
			draw_polyline(pts, border_color, 4.0)
			draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.1, 0.4, 0.85))
			draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.9, 0.2, 1.0))
			
			var bar_width: float = 80.0
			var bar_height: float = 8.0
			var bar_pos := Vector2(-bar_width / 2.0, -60.0)
			draw_rect(Rect2(bar_pos, Vector2(bar_width, bar_height)), Color(0.1, 0.1, 0.1, 0.8))
			var pct: float = clamp(current_health / max_health, 0.0, 1.0)
			draw_rect(Rect2(bar_pos, Vector2(bar_width * pct, bar_height)), Color(1.0, 0.2, 0.3, 1.0))
