extends "res://scripts/weapons/weapon_base.gd"

@export var base_damage: float = 18.0
@export var aura_radius: float = 85.0
@export var pulse_interval: float = 0.50

var pulse_timer: float = 0.0
var visual_pulse_timer: float = 0.0

func _ready() -> void:
	super._ready()
	weapon_id = "tesla_aura"
	weapon_name = "Campo de Descarga Tesla"

func on_unlocked() -> void:
	visible = true

func on_upgraded() -> void:
	match level:
		2:
			aura_radius = 105.0
			base_damage += 6.0
		3:
			pulse_interval = 0.40
			base_damage += 8.0
		4:
			aura_radius = 130.0
		5:
			pulse_interval = 0.30
			base_damage += 14.0

func get_upgrade_desc() -> String:
	if not is_unlocked:
		return "Anillo eléctrico permanente que electrocuta enemigos cercanos."
	match level:
		1: return "+25% radio de choque eléctrico y +30% de daño."
		2: return "Descargas más frecuentes (cada 0.4s) y mayor daño."
		3: return "Radio ampliado a 130px (barrera perimetral masiva)."
		4: return "Frecuencia máxima (0.3s) y descargas devastadoras."
		_: return "Nivel Máximo alcanzado."

func _physics_process(delta: float) -> void:
	if not is_unlocked:
		visible = false
		return
		
	visible = true
	pulse_timer -= delta
	if visual_pulse_timer > 0:
		visual_pulse_timer -= delta
		queue_redraw()
		
	if pulse_timer <= 0:
		var mult: float = mecha_owner.fire_rate_multiplier if is_instance_valid(mecha_owner) else 1.0
		pulse_timer = max(0.12, pulse_interval * mult)
		trigger_electric_pulse()

func trigger_electric_pulse() -> void:
	visual_pulse_timer = 0.12 # Duración del flash visual
	queue_redraw()
	
	var enemies := get_tree().get_nodes_in_group("enemies")
	var radius_sq := aura_radius * aura_radius
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			if global_position.distance_squared_to(enemy.global_position) <= radius_sq:
				if enemy.has_method("take_damage"):
					enemy.take_damage(base_damage)

func _draw() -> void:
	if not is_unlocked:
		return
		
	# Aura estática suave permanente
	draw_circle(Vector2.ZERO, aura_radius, Color(0.8, 0.2, 1.0, 0.08))
	draw_arc(Vector2.ZERO, aura_radius, 0, TAU, 32, Color(0.9, 0.3, 1.0, 0.25), 1.0)
	
	# Pulso eléctrico brillante al disparar
	if visual_pulse_timer > 0:
		var alpha := visual_pulse_timer / 0.12
		draw_circle(Vector2.ZERO, aura_radius, Color(0.9, 0.2, 1.0, 0.22 * alpha))
		draw_arc(Vector2.ZERO, aura_radius, 0, TAU, 36, Color(1.0, 0.8, 1.0, 0.85 * alpha), 2.5)
