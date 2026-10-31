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

# Comportamiento especial Boss Devastador
enum BossLaserState { IDLE, CHARGING, FIRING }
var boss_attack_timer: float = 3.6
var boss_attack_pattern_index: int = 0
var boss_laser_state: int = BossLaserState.IDLE
var boss_laser_timer: float = 0.0
var boss_laser_angle: float = 0.0
var boss_laser_hit_timer: float = 0.0

var boss_emp_active: bool = false
var boss_emp_radius: float = 0.0
var boss_emp_max_radius: float = 280.0
var boss_emp_speed: float = 380.0
var boss_emp_has_hit_mecha: bool = false

var boss_danmaku_active: bool = false
var boss_danmaku_timer: float = 0.0
var boss_danmaku_count: int = 0
var boss_danmaku_max: int = 24

var boss_has_shield: bool = false
var boss_shield_flash_timer: float = 0.0
@export var boss_name: String = "COLOSO CENTINELA"
var overhead_bar_node: Node2D = null
var hud_ref: CanvasLayer = null

@onready var scrap_scene := preload("res://scenes/scrap.tscn")
@onready var enemy_bullet_scene := preload("res://scenes/enemy_bullet.tscn")
@onready var explosion_scene := preload("res://scenes/explosion.tscn")

func _ready() -> void:
	setup_type()
	current_health = max_health
	collision_layer = 2  # Layer 2: Enemies
	collision_mask = 5   # Layer 1: Mecha, Layer 3: Bullets
	
	if drone_type == "boss":
		var b_upper: String = boss_name.to_upper()
		if "AEGIS" in b_upper or "COLOSO" in b_upper:
			boss_has_shield = true
		setup_boss_overhead_bar()
		hud_ref = get_tree().get_first_node_in_group("hud") as CanvasLayer
		if not hud_ref and get_parent():
			hud_ref = get_parent().get_node_or_null("HUD") as CanvasLayer
		if hud_ref and hud_ref.has_method("register_boss"):
			hud_ref.register_boss(self)

func _exit_tree() -> void:
	if is_instance_valid(overhead_bar_node):
		overhead_bar_node.queue_free()

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
			xp_reward = 1500
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
			var boss_speed_mult: float = 1.0
			if boss_laser_state == BossLaserState.CHARGING:
				boss_speed_mult = 0.15
			elif boss_laser_state == BossLaserState.FIRING:
				boss_speed_mult = 0.0
				
			var move_dir := (dir_to_mecha + separation * 0.4).normalized()
			global_position += move_dir * (speed * boss_speed_mult) * delta
			if boss_laser_state == BossLaserState.IDLE:
				rotation = lerp_angle(rotation, move_dir.angle(), 4.0 * delta)
			else:
				rotation = lerp_angle(rotation, boss_laser_angle, 3.5 * delta)
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
	fire_enemy_bullet_custom(direction, "standard", Color(1.0, 0.3, 0.1), 290.0, 22.0)

func fire_enemy_bullet_custom(direction: Vector2, b_type: String = "standard", col: Color = Color(1.0, 0.3, 0.1), spd: float = 290.0, dmg: float = 22.0) -> void:
	if not is_inside_tree() or not get_parent():
		return
	var bullet = enemy_bullet_scene.instantiate() as EnemyBullet
	bullet.global_position = global_position + direction * 24.0
	bullet.direction = direction
	bullet.bullet_type = b_type
	bullet.custom_color = col
	bullet.speed = spd
	bullet.damage = dmg
	get_parent().add_child(bullet)

func process_boss_attacks(delta: float, dir_to_mecha: Vector2) -> void:
	# 1. Proceso de Carga y Disparo del Mega Hyper-Láser
	if boss_laser_state == BossLaserState.CHARGING:
		boss_laser_timer -= delta
		boss_laser_angle = lerp_angle(boss_laser_angle, dir_to_mecha.angle(), 4.0 * delta)
		queue_redraw()
		if boss_laser_timer <= 0:
			boss_laser_state = BossLaserState.FIRING
			boss_laser_timer = 1.25 # 1.25s de rayo continuo
			if AudioManager and AudioManager.has_method("play_laser"):
				AudioManager.play_laser()
		return
	elif boss_laser_state == BossLaserState.FIRING:
		boss_laser_timer -= delta
		boss_laser_angle = lerp_angle(boss_laser_angle, dir_to_mecha.angle(), 1.1 * delta)
		queue_redraw()
		
		# Daño por colisión con el haz continuo
		if is_instance_valid(target_mecha):
			var seg_start: Vector2 = global_position
			var seg_end: Vector2 = global_position + Vector2(cos(boss_laser_angle), sin(boss_laser_angle)) * 950.0
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(target_mecha.global_position, seg_start, seg_end)
			if target_mecha.global_position.distance_to(closest) <= 24.0:
				boss_laser_hit_timer -= delta
				if boss_laser_hit_timer <= 0:
					boss_laser_hit_timer = 0.12 # Tick cada 120ms
					target_mecha.take_damage(20.0)
					if AudioManager and AudioManager.has_method("play_mecha_hit"):
						AudioManager.play_mecha_hit()
						
		if boss_laser_timer <= 0:
			boss_laser_state = BossLaserState.IDLE
			queue_redraw()
		return

	# 2. Proceso de Onda de Choque EMP Expansiva
	if boss_emp_active:
		boss_emp_radius += boss_emp_speed * delta
		if not boss_emp_has_hit_mecha and is_instance_valid(target_mecha):
			var dist_to_m: float = global_position.distance_to(target_mecha.global_position)
			if abs(dist_to_m - boss_emp_radius) <= 32.0:
				boss_emp_has_hit_mecha = true
				var push_dir: Vector2 = (target_mecha.global_position - global_position).normalized()
				target_mecha.global_position += push_dir * 95.0
				target_mecha.take_damage(26.0)
				if AudioManager and AudioManager.has_method("play_mecha_hit"):
					AudioManager.play_mecha_hit()
		if boss_emp_radius >= boss_emp_max_radius:
			boss_emp_active = false
		queue_redraw()

	# 3. Proceso de Cortina Doble Espiral Danmaku
	if boss_danmaku_active:
		boss_danmaku_timer -= delta
		if boss_danmaku_timer <= 0:
			boss_danmaku_timer = 0.075
			boss_danmaku_count += 1
			var ang1: float = boss_danmaku_count * 0.28
			var ang2: float = -boss_danmaku_count * 0.28
			fire_enemy_bullet_custom(Vector2(cos(ang1), sin(ang1)), "danmaku", Color(0.75, 0.4, 1.0), 210.0, 16.0)
			fire_enemy_bullet_custom(Vector2(cos(ang2), sin(ang2)), "danmaku", Color(1.0, 0.2, 0.4), 210.0, 16.0)
			if boss_danmaku_count >= boss_danmaku_max:
				boss_danmaku_active = false

	# 4. Timer de flash del escudo
	if boss_shield_flash_timer > 0:
		boss_shield_flash_timer -= delta
		queue_redraw()

	# 5. Selección y Ejecución del Próximo Ataque Devastador
	boss_attack_timer -= delta
	if boss_attack_timer <= 0:
		boss_attack_timer = 3.6
		execute_next_boss_attack(dir_to_mecha)

func execute_next_boss_attack(dir_to_mecha: Vector2) -> void:
	var b_name_up := boss_name.to_upper()
	boss_attack_pattern_index += 1
	
	if "CHRONOS" in b_name_up or "APEX" in b_name_up or "OMEGA" in b_name_up:
		# Jefes Avanzados: Hyper-Láser, Danmaku Doble Espiral, EMP y Super-Novas
		match boss_attack_pattern_index % 4:
			0:
				start_mega_laser(dir_to_mecha)
			1:
				start_danmaku_spiral(28)
			2:
				trigger_emp_shockwave()
			3:
				fire_nova_salvo(5, 0.7, dir_to_mecha)
	elif "HIVE" in b_name_up or "TITÁN" in b_name_up or "TITAN" in b_name_up:
		# Jefe Enjambre / Titán: Super-Novas triples, Danmaku y Pods Kamikaze
		match boss_attack_pattern_index % 3:
			0:
				fire_nova_salvo(3, 0.5, dir_to_mecha)
			1:
				start_danmaku_spiral(22)
			2:
				spawn_kamikaze_drone_pod()
	else:
		# Aegis Colossus / Coloso Centinela: Escudo Égida + Salvas Nova + EMP + Danmaku radial
		match boss_attack_pattern_index % 3:
			0:
				fire_nova_salvo(5, 0.75, dir_to_mecha)
			1:
				trigger_emp_shockwave()
			2:
				# Pulso radial danmaku 360° (12 proyectiles)
				var bullet_count: int = 12
				var angle_step: float = TAU / bullet_count
				for i in range(bullet_count):
					var angle: float = i * angle_step
					fire_enemy_bullet_custom(Vector2(cos(angle), sin(angle)), "danmaku", Color(1.0, 0.35, 0.1), 220.0, 18.0)

func fire_nova_salvo(count: int, spread: float, dir_to_mecha: Vector2) -> void:
	var base_angle: float = dir_to_mecha.angle()
	var start_angle: float = base_angle - (spread * 0.5)
	var angle_step: float = spread / max(1, count - 1) if count > 1 else 0.0
	for i in range(count):
		var ang: float = start_angle + (i * angle_step) if count > 1 else base_angle
		fire_enemy_bullet_custom(Vector2(cos(ang), sin(ang)), "nova", Color(1.0, 0.45, 0.0), 220.0, 45.0)

func trigger_emp_shockwave() -> void:
	boss_emp_active = true
	boss_emp_radius = 12.0
	boss_emp_has_hit_mecha = false
	if AudioManager and AudioManager.has_method("play_ram_explosion"):
		AudioManager.play_ram_explosion()
	queue_redraw()

func start_danmaku_spiral(max_bullets: int = 24) -> void:
	boss_danmaku_active = true
	boss_danmaku_timer = 0.0
	boss_danmaku_count = 0
	boss_danmaku_max = max_bullets

func start_mega_laser(dir_to_mecha: Vector2) -> void:
	boss_laser_state = BossLaserState.CHARGING
	boss_laser_timer = 1.1
	boss_laser_angle = dir_to_mecha.angle()
	boss_laser_hit_timer = 0.0
	if AudioManager and AudioManager.has_method("play_laser"):
		AudioManager.play_laser()
	queue_redraw()

func spawn_kamikaze_drone_pod() -> void:
	if not is_inside_tree() or not get_parent():
		return
	var drone_scene := load("res://scenes/enemy_drone.tscn")
	for i in range(3):
		var angle: float = i * (TAU / 3.0)
		var pod = drone_scene.instantiate()
		pod.drone_type = "swarm"
		pod.global_position = global_position + Vector2(cos(angle), sin(angle)) * 55.0
		pod.target_mecha = target_mecha
		get_parent().add_child(pod)

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
	if drone_type == "boss" and boss_has_shield and knockback_dir != Vector2.ZERO:
		var incoming_angle := (-knockback_dir).angle()
		var diff_angle: float = abs(wrapf(incoming_angle - rotation, -PI, PI))
		if diff_angle <= (PI / 3.0): # Frente dentro del arco de 120°
			amount *= 0.15 # Escudo absorbe el 85% del impacto frontal
			boss_shield_flash_timer = 0.15
			queue_redraw()

	current_health -= amount
	flash_timer = 0.08
	
	if drone_type == "boss" and is_instance_valid(hud_ref) and hud_ref.has_method("update_boss_health"):
		hud_ref.update_boss_health(self)
	
	# Aplicar Knockback
	if force > 0 and knockback_resistance < 1.0:
		var effective_force := force * (1.0 - knockback_resistance)
		knockback_velocity = knockback_dir * effective_force
		
	queue_redraw()
	
	if current_health <= 0:
		die()

func die() -> void:
	if drone_type == "boss":
		if is_instance_valid(hud_ref) and hud_ref.has_method("on_boss_defeated"):
			hud_ref.on_boss_defeated(self)
		if is_instance_valid(overhead_bar_node):
			overhead_bar_node.queue_free()
			overhead_bar_node = null

		# Explosión de recompensa masiva: 8 orbes de chatarra en anillo
		var shard_count: int = 8
		var shard_xp: int = max(50, int(xp_reward / shard_count))
		for i in range(shard_count):
			var angle := i * (TAU / shard_count)
			var scrap = scrap_scene.instantiate()
			scrap.xp_value = shard_xp
			scrap.global_position = global_position + Vector2(cos(angle), sin(angle)) * 36.0
			get_parent().add_child(scrap)
		queue_free()
		return

	var scrap = scrap_scene.instantiate()
	scrap.xp_value = xp_reward
	scrap.global_position = global_position
	get_parent().add_child(scrap)
	queue_free()

func on_rammed_mecha() -> void:
	if drone_type == "scout" or drone_type == "swarm":
		AudioManager.play_ram_explosion()
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
			
			# Cañones montados
			draw_rect(Rect2(36, -8, 16, 16), Color(1.0, 0.2, 0.4))
			draw_rect(Rect2(26, 24, 12, 10), Color(0.8, 0.1, 0.3))
			draw_rect(Rect2(26, -34, 12, 10), Color(0.8, 0.1, 0.3))

			# Núcleo / Ojo colosal
			draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.1, 0.4, 0.85))
			draw_circle(Vector2.ZERO, 8.0, Color(1.0, 0.9, 0.2, 1.0))

			# 1. Escudo Égida Frontal (120°)
			if boss_has_shield:
				var shield_col := Color(1.0, 1.0, 1.0, 0.95) if boss_shield_flash_timer > 0.0 else Color(0.1, 0.9, 0.6, 0.85)
				draw_arc(Vector2.ZERO, 68.0, -PI / 3.0, PI / 3.0, 24, shield_col, 6.0)
				draw_arc(Vector2.ZERO, 64.0, -PI / 3.0, PI / 3.0, 24, Color(0.4, 1.0, 0.8, 0.4), 2.0)

			# 2. Onda de Choque EMP Expansiva
			if boss_emp_active:
				var alpha: float = clamp(1.0 - (boss_emp_radius / boss_emp_max_radius), 0.0, 1.0)
				draw_arc(Vector2.ZERO, boss_emp_radius, 0.0, TAU, 36, Color(0.2, 0.8, 1.0, alpha * 0.9), 5.0)
				draw_circle(Vector2.ZERO, boss_emp_radius, Color(0.1, 0.6, 1.0, alpha * 0.12))

			# 3. Telegrafiado del Hyper-Láser (Carga con mira láser hacia el Mecha)
			if boss_laser_state == BossLaserState.CHARGING:
				var local_laser_dir := Vector2(cos(boss_laser_angle - rotation), sin(boss_laser_angle - rotation))
				draw_line(Vector2.ZERO, local_laser_dir * 950.0, Color(1.0, 0.15, 0.25, 0.75), 2.5)
				if is_instance_valid(target_mecha):
					var local_mecha_pos := to_local(target_mecha.global_position)
					draw_arc(local_mecha_pos, 24.0, 0.0, TAU, 18, Color(1.0, 0.2, 0.2, 0.85), 2.0)

			# 4. Descarga de Hyper-Láser Devastador (44px)
			if boss_laser_state == BossLaserState.FIRING:
				var local_laser_dir := Vector2(cos(boss_laser_angle - rotation), sin(boss_laser_angle - rotation))
				var beam_len: float = 980.0
				# Corona exterior de plasma carmesí (44px)
				draw_line(Vector2.ZERO, local_laser_dir * beam_len, Color(1.0, 0.1, 0.35, 0.35), 44.0)
				# Haz intermedio rojo/magenta brillante (26px)
				draw_line(Vector2.ZERO, local_laser_dir * beam_len, Color(1.0, 0.25, 0.45, 0.85), 26.0)
				# Núcleo blanco incandescente (12px)
				draw_line(Vector2.ZERO, local_laser_dir * beam_len, Color(1.0, 1.0, 1.0, 1.0), 12.0)
				# Destello de boca de cañón
				draw_circle(local_laser_dir * 38.0, 22.0, Color(1.0, 0.9, 0.9, 0.9))

func setup_boss_overhead_bar() -> void:
	overhead_bar_node = BossOverheadBar.new(self)
	overhead_bar_node.global_position = global_position + Vector2(0.0, -78.0)
	overhead_bar_node.global_rotation = 0.0
	call_deferred("_attach_overhead_bar")

func _attach_overhead_bar() -> void:
	if is_instance_valid(overhead_bar_node) and get_parent():
		get_parent().add_child(overhead_bar_node)

class BossOverheadBar extends Node2D:
	var boss: Area2D
	var lag_hp: float = 1.0
	var label: Label
	
	func _init(p_boss: Area2D) -> void:
		boss = p_boss
		lag_hp = boss.current_health
		z_index = 35
		
		label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector2(-120, -22)
		label.size = Vector2(240, 16)
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
		add_child(label)
		
	func _process(delta: float) -> void:
		if not is_instance_valid(boss) or not boss.is_inside_tree():
			queue_free()
			return
		global_position = boss.global_position + Vector2(0.0, -78.0)
		global_rotation = 0.0
		
		lag_hp = lerp(lag_hp, boss.current_health, 8.0 * delta)
		var max_h: float = max(1.0, boss.max_health)
		var pct: float = clamp(boss.current_health / max_h, 0.0, 1.0)
		var b_title: String = boss.boss_name if "boss_name" in boss else "JEFE"
		label.text = "%s  [%d%%]" % [b_title, int(pct * 100.0)]
		queue_redraw()
		
	func _draw() -> void:
		if not is_instance_valid(boss):
			return
			
		var bar_w: float = 140.0
		var bar_h: float = 12.0
		var half_w: float = bar_w * 0.5
		var bar_rect := Rect2(-half_w, -bar_h * 0.5, bar_w, bar_h)
		
		# Sombra exterior
		draw_rect(Rect2(-half_w - 3, -bar_h * 0.5 - 3, bar_w + 6, bar_h + 6), Color(0.0, 0.0, 0.0, 0.75))
		
		# Fondo oscuro tecnológico
		draw_rect(bar_rect, Color(0.04, 0.06, 0.12, 0.94))
		
		var max_h: float = max(1.0, boss.max_health)
		var cur_pct: float = clamp(boss.current_health / max_h, 0.0, 1.0)
		var lag_pct: float = clamp(lag_hp / max_h, 0.0, 1.0)
		
		# Barra de retraso de impacto (lag bar en amarillo ámbar)
		if lag_pct > cur_pct:
			var lag_rect := Rect2(-half_w + 2, -bar_h * 0.5 + 2, (bar_w - 4) * lag_pct, bar_h - 4)
			draw_rect(lag_rect, Color(1.0, 0.75, 0.2, 0.85))
			
		# Barra principal de vida (Carmesí / Neón magenta vibrante)
		if cur_pct > 0.0:
			var hp_rect := Rect2(-half_w + 2, -bar_h * 0.5 + 2, (bar_w - 4) * cur_pct, bar_h - 4)
			var fill_color := Color(1.0, 0.18, 0.38, 1.0)
			if cur_pct < 0.25:
				var pulse: float = 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.014)
				fill_color = Color(1.0, 0.05, 0.15, pulse)
			draw_rect(hp_rect, fill_color)
			
		# Segmentos tácticos cada 20%
		for i in range(1, 5):
			var tick_x: float = -half_w + 2 + (bar_w - 4) * (i * 0.2)
			draw_line(Vector2(tick_x, -bar_h * 0.5 + 2), Vector2(tick_x, bar_h * 0.5 - 2), Color(0.04, 0.06, 0.12, 0.85), 1.5)
			
		# Borde neón cibernético
		draw_rect(bar_rect, Color(1.0, 0.3, 0.52, 0.95), false, 2.0)
		
		# Acentos angulares de tecnología en las esquinas
		var c_len: float = 4.0
		draw_line(Vector2(-half_w - 2, -bar_h*0.5 - 2), Vector2(-half_w - 2 + c_len, -bar_h*0.5 - 2), Color(1.0, 0.85, 0.3), 1.5)
		draw_line(Vector2(-half_w - 2, -bar_h*0.5 - 2), Vector2(-half_w - 2, -bar_h*0.5 - 2 + c_len), Color(1.0, 0.85, 0.3), 1.5)
		draw_line(Vector2(half_w + 2, -bar_h*0.5 - 2), Vector2(half_w + 2 - c_len, -bar_h*0.5 - 2), Color(1.0, 0.85, 0.3), 1.5)
		draw_line(Vector2(half_w + 2, -bar_h*0.5 - 2), Vector2(half_w + 2, -bar_h*0.5 - 2 + c_len), Color(1.0, 0.85, 0.3), 1.5)
