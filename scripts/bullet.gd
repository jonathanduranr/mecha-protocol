extends Area2D

@export var speed: float = 1050.0
@export var damage: float = 30.0
@export var lifetime: float = 1.5
@export var knockback_force: float = 180.0

var direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	rotation = direction.angle()
	collision_layer = 4   # Layer 3: PlayerBullets
	collision_mask = 2    # Layer 2: Enemies
	area_entered.connect(_on_area_entered)
	
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	
	# Despawn inmediato al cruzar los bordes de la arena visible (+10px)
	var v_rect := get_viewport_rect()
	if not v_rect.grow(10.0).has_point(global_position):
		queue_free()

func _draw() -> void:
	draw_line(Vector2(-12, 0), Vector2(12, 0), Color(0.2, 0.9, 1.0, 1.0), 4.0)
	draw_circle(Vector2(12, 0), 2.5, Color(1, 1, 1, 1))

func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemies") and area.has_method("take_damage"):
		# Prevenir daño a enemigos fuera de la pantalla
		var v_rect := get_viewport_rect()
		if v_rect.grow(15.0).has_point(area.global_position):
			area.take_damage(damage, direction, knockback_force)
		queue_free()
