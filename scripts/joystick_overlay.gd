extends Control

var is_active: bool = false
var center_pos: Vector2 = Vector2.ZERO
var current_pos: Vector2 = Vector2.ZERO
var fade_alpha: float = 0.0

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE

func update_joystick(active: bool, center: Vector2, cur: Vector2, alpha: float) -> void:
	is_active = active
	center_pos = center
	current_pos = cur
	fade_alpha = alpha
	queue_redraw()

func _draw() -> void:
	if fade_alpha <= 0.01:
		return
		
	var base_r: float = 64.0
	var knob_r: float = 22.0
	
	# 1. Base Ring (Fondo y halo cian futurista)
	draw_circle(center_pos, base_r, Color(0.04, 0.08, 0.16, 0.45 * fade_alpha))
	draw_arc(center_pos, base_r, 0.0, TAU, 36, Color(0.2, 0.9, 1.0, 0.75 * fade_alpha), 2.5)
	draw_arc(center_pos, base_r - 6.0, 0.0, TAU, 36, Color(0.2, 0.9, 1.0, 0.25 * fade_alpha), 1.0)
	
	# 4 Marcas de cruceta en los puntos cardinales del anillo base
	var tick_len: float = 8.0
	for ang in [0.0, PI * 0.5, PI, PI * 1.5]:
		var dir := Vector2(cos(ang), sin(ang))
		draw_line(center_pos + dir * (base_r - tick_len), center_pos + dir * (base_r + 2.0), Color(0.3, 0.95, 1.0, 0.85 * fade_alpha), 2.0)
		
	# 2. Línea de conexión / Vector de potencia
	var stick_delta := current_pos - center_pos
	if stick_delta.length_squared() > 16.0:
		draw_line(center_pos, current_pos, Color(1.0, 0.8, 0.2, 0.7 * fade_alpha), 3.0)
		# Flecha direccional adelantada
		var fwd := stick_delta.normalized()
		var arrow_tip := current_pos + fwd * 14.0
		var arrow_left := current_pos + fwd * 6.0 + Vector2(-fwd.y, fwd.x) * 7.0
		var arrow_right := current_pos + fwd * 6.0 - Vector2(-fwd.y, fwd.x) * 7.0
		var arrow_pts := PackedVector2Array([arrow_tip, arrow_left, arrow_right])
		draw_colored_polygon(arrow_pts, Color(1.0, 0.85, 0.3, 0.9 * fade_alpha))
		
	# 3. Knob / Puntero táctil (Ámbar cibernético con núcleo brillante)
	draw_circle(current_pos, knob_r, Color(0.12, 0.18, 0.28, 0.9 * fade_alpha))
	draw_arc(current_pos, knob_r, 0.0, TAU, 24, Color(1.0, 0.8, 0.25, 0.95 * fade_alpha), 2.5)
	draw_circle(current_pos, 6.0, Color(1.0, 1.0, 1.0, 0.95 * fade_alpha))
