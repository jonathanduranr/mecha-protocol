extends "res://scripts/weapons/weapon_base.gd"

@export var base_damage: float = 24.0
@export var orbit_radius: float = 78.0
@export var orbit_speed: float = 3.2

var current_angle: float = 0.0
var active_drones: int = 1
var hit_cooldowns: Dictionary = {} # id_enemigo -> tiempo restante

func _ready() -> void:
	super._ready()
	weapon_id = "orbit_drones"
	weapon_name = "Drones de Defensa Orbital"

func on_unlocked() -> void:
	active_drones = 1
	visible = true

func on_upgraded() -> void:
	match level:
		2:
			active_drones = 2
			base_damage += 6.0
		3:
			orbit_speed += 1.0
			base_damage += 8.0
		4:
			active_drones = 3
			orbit_radius = 88.0
		5:
			active_drones = 4
			base_damage += 12.0
			orbit_speed += 0.8

func get_upgrade_desc() -> String:
	if not is_unlocked:
		return "Satélite orbital defensivo que gira triturando enemigos."
	match level:
		1: return "+1 Dron orbital (2 drones) y +25% de daño."
		2: return "+30% velocidad de giro y mayor impacto."
		3: return "+1 Dron orbital (3 drones) y radio ampliado."
		4: return "Enjambre de 4 Drones orbitales con barrera máxima."
		_: return "Nivel Máximo alcanzado."

func _physics_process(delta: float) -> void:
	if not is_unlocked:
		visible = false
		return
		
	visible = true
	current_angle += orbit_speed * delta
	if current_angle > TAU:
		current_angle -= TAU
		
	# Actualizar cooldowns de daño por enemigo
	for id in hit_cooldowns.keys():
		hit_cooldowns[id] -= delta
		if hit_cooldowns[id] <= 0:
			hit_cooldowns.erase(id)
			
	# Comprobar impactos con enemigos en la posición de cada dron
	check_collisions()
	queue_redraw()

func check_collisions() -> void:
	var enemies := get_tree().get_nodes_in_group("enemies")
	var hit_radius_sq: float = 18.0 * 18.0
	
	for i in range(active_drones):
		var angle := current_angle + (i * (TAU / active_drones))
		var drone_pos := global_position + Vector2(cos(angle), sin(angle)) * orbit_radius
		
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			var instance_id: int = enemy.get_instance_id()
			if hit_cooldowns.has(instance_id):
				continue
				
			if drone_pos.distance_squared_to(enemy.global_position) <= hit_radius_sq:
				if enemy.has_method("take_damage"):
					enemy.take_damage(base_damage)
					hit_cooldowns[instance_id] = 0.35 # Daño cada 0.35s por enemigo

func _draw() -> void:
	if not is_unlocked:
		return
		
	# Dibujar círculo de órbita sutil
	draw_arc(Vector2.ZERO, orbit_radius, 0, TAU, 32, Color(0.2, 0.9, 1.0, 0.15), 1.0)
	
	# Dibujar cada dron satélite
	for i in range(active_drones):
		var angle := current_angle + (i * (TAU / active_drones))
		var pos := Vector2(cos(angle), sin(angle)) * orbit_radius
		
		# Destello / Aura del dron
		draw_circle(pos, 8.0, Color(0.1, 0.8, 1.0, 0.3))
		# Cuerpo del dron
		draw_circle(pos, 4.5, Color(0.2, 0.9, 1.0, 1.0))
		draw_circle(pos, 2.0, Color(1.0, 1.0, 1.0, 1.0))
