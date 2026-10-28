extends Node2D

var lifetime: float = 0.32
var elapsed: float = 0.0
var max_radius: float = 38.0
var spark_dirs: Array[Vector2] = []
var spark_speeds: Array[float] = []

func _ready() -> void:
	for i in range(8):
		var angle: float = randf() * TAU
		spark_dirs.append(Vector2.from_angle(angle))
		spark_speeds.append(randf_range(70.0, 160.0))

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= lifetime:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var t: float = elapsed / lifetime
	var current_radius: float = lerp(6.0, max_radius, ease(t, 0.35))
	var alpha: float = 1.0 - t
	
	# Onda expansiva exterior carmesí/naranja
	draw_arc(Vector2.ZERO, current_radius, 0.0, TAU, 24, Color(1.0, 0.3, 0.1, alpha * 0.95), 3.0)
	
	# Anillo interior amarillo
	if current_radius > 5.0:
		draw_arc(Vector2.ZERO, current_radius * 0.6, 0.0, TAU, 18, Color(1.0, 0.85, 0.2, alpha), 2.0)
		
	# Destello blanco inicial
	if t < 0.25:
		var flash_alpha: float = (1.0 - t / 0.25)
		draw_circle(Vector2.ZERO, 10.0 * (1.0 - t), Color(1.0, 1.0, 1.0, flash_alpha))
		
	# Chispas de impacto
	for i in range(spark_dirs.size()):
		var spark_pos: Vector2 = spark_dirs[i] * (spark_speeds[i] * elapsed)
		draw_circle(spark_pos, max(1.0, 2.2 * (1.0 - t)), Color(1.0, 0.75, 0.2, alpha))
