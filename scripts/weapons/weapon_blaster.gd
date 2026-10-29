extends "res://scripts/weapons/weapon_base.gd"

@export var fire_rate: float = 0.22
@export var base_damage: float = 30.0
@export var bullet_count: int = 1
@export var sensor_range: float = 520.0

var shoot_timer: float = 0.0

@onready var bullet_scene := preload("res://scenes/bullet.tscn")

func _ready() -> void:
	super._ready()
	weapon_id = "blaster"
	weapon_name = "Cañón Láser Táctico"
	is_unlocked = true # Arma inicial del mecha

func on_upgraded() -> void:
	match level:
		2:
			bullet_count = 2 # Disparo doble paralelo
			fire_rate = 0.18
		3:
			base_damage += 10.0
			fire_rate = 0.15
		4:
			bullet_count = 3 # Disparo triple
			fire_rate = 0.12
		5:
			bullet_count = 4 # Disparo cuádruple en ráfaga
			base_damage += 15.0
			fire_rate = 0.09

func get_upgrade_desc() -> String:
	match level:
		1: return "+1 Cañón en paralelo y +20% cadencia de tiro."
		2: return "+35% daño por disparo y mayor velocidad de fuego."
		3: return "+1 Cañón adicional (disparo triple) y fuego rápido."
		4: return "Batería cuádruple de cañones pesados a máxima cadencia."
		_: return "Nivel Máximo alcanzado."

func _physics_process(delta: float) -> void:
	if not is_unlocked:
		return
		
	shoot_timer -= delta
	var closest_enemy := get_closest_enemy()
	
	if is_instance_valid(closest_enemy):
		var aim_dir := (closest_enemy.global_position - global_position).normalized()
		if is_instance_valid(mecha_owner):
			mecha_owner.rotation = lerp_angle(mecha_owner.rotation, aim_dir.angle(), 14.0 * delta)
			
		if shoot_timer <= 0:
			fire_bullets(aim_dir)
			var mult: float = mecha_owner.fire_rate_multiplier if is_instance_valid(mecha_owner) else 1.0
			shoot_timer = max(0.06, fire_rate * mult)

func fire_bullets(direction: Vector2) -> void:
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
	bullet.damage = base_damage
	if is_instance_valid(mecha_owner) and "damage_multiplier" in mecha_owner:
		bullet.damage *= mecha_owner.damage_multiplier
	get_parent().get_parent().get_parent().add_child(bullet)

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

func is_target_on_screen(target_node: Node2D) -> bool:
	var v_rect := get_viewport_rect()
	# Solo objetivos que ya entraron claramente en la pantalla visible (20px de margen interior)
	var screen_rect := Rect2(Vector2.ZERO, v_rect.size).grow(-20.0)
	return screen_rect.has_point(target_node.global_position)
