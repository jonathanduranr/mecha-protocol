extends Node2D

func _draw() -> void:
	var viewport_size := get_viewport_rect().size
	var grid_size: float = 60.0
	var line_color := Color(0.12, 0.16, 0.25, 0.35)
	
	# Líneas verticales
	var x: float = 0.0
	while x <= viewport_size.x:
		draw_line(Vector2(x, 0), Vector2(x, viewport_size.y), line_color, 1.0)
		x += grid_size
		
	# Líneas horizontales
	var y: float = 0.0
	while y <= viewport_size.y:
		draw_line(Vector2(0, y), Vector2(viewport_size.x, y), line_color, 1.0)
		y += grid_size
