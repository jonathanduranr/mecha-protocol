class_name EnemyBullet
extends Area2D

@export var speed: float = 260.0
@export var damage: float = 14.0
@export var lifetime: float = 3.5

var direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	collision_layer = 16  # Layer 5: EnemyBullets
	collision_mask = 1   # Layer 1: Mecha
	add_to_group("enemy_bullets")
	area_entered.connect(_on_area_entered)
	
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _draw() -> void:
	# Esfera de plasma hostil naranja/roja con aura
	draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.2, 0.2, 0.4))
	draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.5, 0.1, 0.9))
	draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 1.0, 1.0))

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		queue_free()
