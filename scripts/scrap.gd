extends Area2D

@export var xp_value: int = 10
@export var magnet_speed: float = 750.0

var target: Node2D = null
var is_attracted: bool = false

# Dinámica de Tifón Cuántico (Tornado XP)
var is_in_tornado: bool = false
var orbit_angle: float = 0.0
var orbit_dist: float = 180.0
var max_orbit_dist: float = 180.0
var orbit_timer: float = 0.0
var total_orbit_time: float = 1.9
var trail_history: Array[Vector2] = []
var hit_cooldown: float = 0.0

func _ready() -> void:
	collision_layer = 8   # Layer 4: ScrapXP
	collision_mask = 1    # Layer 1: Mecha
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if not is_attracted or not is_instance_valid(target):
		return

	var has_vortex: bool = bool(target.get("has_ultimate_vortex")) if ("has_ultimate_vortex" in target) else false
	
	if has_vortex:
		if not is_in_tornado:
			var to_mecha: Vector2 = target.global_position - global_position
			var dist: float = to_mecha.length()
			if dist <= 185.0:
				# Optimización: si ya hay un torbellino visual completo, devorar directamente para evitar saturación
				if get_tree().get_nodes_in_group("scraps").size() > 20:
					if target.has_method("gain_xp"):
						target.gain_xp(xp_value)
					if "absorb_pulse" in target:
						target.absorb_pulse = 0.16
					queue_free()
					return
				is_in_tornado = true
				orbit_angle = atan2(global_position.y - target.global_position.y, global_position.x - target.global_position.x)
				orbit_dist = dist
				max_orbit_dist = dist
				total_orbit_time = 1.8
				orbit_timer = total_orbit_time
			else:
				global_position += to_mecha.normalized() * (magnet_speed * 1.6) * delta
		else:
			orbit_timer -= delta
			var progress: float = clamp(orbit_timer / total_orbit_time, 0.0, 1.0)
			
			# Giro centrípeto acelerado (7.5 a 15 rad/s)
			var current_speed: float = 8.0 * (1.0 + (1.0 - progress) * 1.5)
			orbit_angle += current_speed * delta
			
			# Espiral logarítmica descendente hacia el núcleo del mecha
			orbit_dist = 20.0 + (max_orbit_dist - 20.0) * pow(progress, 1.3)
			global_position = target.global_position + Vector2(cos(orbit_angle), sin(orbit_angle)) * orbit_dist
			
			# Registro de estela de fricción de plasma
			trail_history.append(global_position)
			if trail_history.size() > 6:
				trail_history.remove_at(0)
						
			# Devoración en el núcleo cuántico
			if orbit_timer <= 0.0 or orbit_dist <= 22.0:
				if target.has_method("gain_xp"):
					target.gain_xp(xp_value)
				if "absorb_pulse" in target:
					target.absorb_pulse = 0.16
				queue_free()
				return
				
			queue_redraw()
	else:
		# Succión lineal convencional cuando no se tiene el ultimate
		var dir := (target.global_position - global_position).normalized()
		global_position += dir * magnet_speed * delta

func _draw() -> void:
	if is_in_tornado:
		# Estela de fricción de plasma púrpura
		for i in range(trail_history.size() - 1):
			var p1: Vector2 = to_local(trail_history[i])
			var p2: Vector2 = to_local(trail_history[i+1])
			var alpha: float = float(i + 1) / float(trail_history.size())
			draw_line(p1, p2, Color(0.85, 0.4, 1.0, alpha * 0.65), 3.0)
			
		# Núcleo de metralla cinético brillante
		draw_circle(Vector2.ZERO, 7.0, Color(0.9, 0.45, 1.0, 0.95))
		draw_circle(Vector2.ZERO, 3.0, Color.WHITE)
		draw_arc(Vector2.ZERO, 10.0, 0, TAU, 16, Color(1.0, 0.65, 1.0, 0.7), 1.5)
		return

	if xp_value <= 15:
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.2, 0.9))
		draw_circle(Vector2.ZERO, 2.5, Color.WHITE)
	elif xp_value <= 60:
		draw_circle(Vector2.ZERO, 9.0, Color(0.2, 0.9, 1.0, 0.9))
		draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
		draw_arc(Vector2.ZERO, 13.0, 0, TAU, 16, Color(0.2, 0.9, 1.0, 0.5), 2.0)
	else:
		draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.2, 0.8, 0.8))
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.85, 0.1, 1.0))
		draw_circle(Vector2.ZERO, 4.0, Color.WHITE)
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(1.0, 0.85, 0.1, 0.6), 3.0)

func attract_to(mecha_node: Node2D) -> void:
	target = mecha_node
	is_attracted = true

func _on_area_entered(area: Area2D) -> void:
	if not is_in_tornado and area.has_method("gain_xp"):
		area.gain_xp(xp_value)
		queue_free()