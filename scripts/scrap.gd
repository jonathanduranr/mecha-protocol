extends Area2D

@export var xp_value: int = 10
@export var magnet_speed: float = 750.0

var target: Node2D = null
var is_attracted: bool = false

func _ready() -> void:
	collision_layer = 8   # Layer 4: ScrapXP
	collision_mask = 1    # Layer 1: Mecha
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if is_attracted and is_instance_valid(target):
		var dir := (target.global_position - global_position).normalized()
		global_position += dir * magnet_speed * delta

func _draw() -> void:
	if xp_value <= 15:
		# Pequeño (Scout) - Amarillo
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.85, 0.2, 0.9))
		draw_circle(Vector2.ZERO, 2.5, Color(1.0, 1.0, 1.0, 1.0))
	elif xp_value <= 60:
		# Mediano (Tanque/Blindado) - Cian eléctrico brillante
		draw_circle(Vector2.ZERO, 9.0, Color(0.2, 0.9, 1.0, 0.9))
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 1.0, 1.0))
		draw_arc(Vector2.ZERO, 13.0, 0, TAU, 16, Color(0.2, 0.9, 1.0, 0.5), 2.0)
	else:
		# Mega Núcleo (Jefe) - Oro y Magenta con aura
		draw_circle(Vector2.ZERO, 15.0, Color(1.0, 0.2, 0.8, 0.8))
		draw_circle(Vector2.ZERO, 9.0, Color(1.0, 0.85, 0.1, 1.0))
		draw_circle(Vector2.ZERO, 4.0, Color(1.0, 1.0, 1.0, 1.0))
		draw_arc(Vector2.ZERO, 20.0, 0, TAU, 24, Color(1.0, 0.85, 0.1, 0.6), 3.0)

func attract_to(mecha_node: Node2D) -> void:
	target = mecha_node
	is_attracted = true

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("gain_xp"):
		area.gain_xp(xp_value)
		queue_free()
