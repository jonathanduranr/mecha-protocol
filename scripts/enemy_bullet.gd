class_name EnemyBullet
extends Area2D

@export var speed: float = 290.0
@export var damage: float = 22.0
@export var lifetime: float = 3.5
@export var bullet_type: String = "standard" # "standard", "nova", "danmaku"
@export var bullet_radius: float = 6.0
@export var custom_color: Color = Color(1.0, 0.3, 0.1)

var direction: Vector2 = Vector2.DOWN
var has_detonated: bool = false
var pulse_time: float = 0.0

@onready var explosion_scene := preload("res://scenes/explosion.tscn")

func _ready() -> void:
	collision_layer = 16  # Layer 5: EnemyBullets
	collision_mask = 1   # Layer 1: Mecha
	add_to_group("enemy_bullets")
	area_entered.connect(_on_area_entered)
	
	if bullet_type == "nova":
		speed = 220.0
		damage = 45.0
		bullet_radius = 20.0
		lifetime = 2.8
		var col_shape := CircleShape2D.new()
		col_shape.radius = 18.0
		$CollisionShape2D.shape = col_shape
	elif bullet_type == "danmaku":
		damage = 18.0
		bullet_radius = 7.0
		var col_shape := CircleShape2D.new()
		col_shape.radius = 6.5
		$CollisionShape2D.shape = col_shape
	
	var timer := get_tree().create_timer(lifetime)
	timer.timeout.connect(_on_lifetime_expired)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	if bullet_type == "nova":
		pulse_time += delta * 8.0
		queue_redraw()

func _draw() -> void:
	match bullet_type:
		"nova":
			# Super-Esfera Nova Pesada de Plasma (20px)
			var pulse: float = sin(pulse_time) * 2.0
			draw_circle(Vector2.ZERO, bullet_radius + 8.0 + pulse, Color(1.0, 0.35, 0.05, 0.25))
			draw_arc(Vector2.ZERO, bullet_radius + pulse, 0.0, TAU, 24, Color(1.0, 0.85, 0.2, 0.85), 2.5)
			draw_circle(Vector2.ZERO, bullet_radius, Color(1.0, 0.45, 0.0, 0.95))
			draw_circle(Vector2.ZERO, bullet_radius * 0.55, Color(1.0, 0.9, 0.3, 1.0))
			draw_circle(Vector2.ZERO, bullet_radius * 0.25, Color(1.0, 1.0, 1.0, 1.0))
		"danmaku":
			# Perlas Danmaku Bullet-Hell
			draw_circle(Vector2.ZERO, bullet_radius + 3.0, Color(custom_color.r, custom_color.g, custom_color.b, 0.35))
			draw_circle(Vector2.ZERO, bullet_radius, custom_color)
			draw_circle(Vector2.ZERO, bullet_radius * 0.4, Color(1.0, 1.0, 1.0, 1.0))
		_:
			# Esfera estándar naranja/roja
			draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.2, 0.2, 0.4))
			draw_circle(Vector2.ZERO, 4.0, Color(1.0, 0.5, 0.1, 0.9))
			draw_circle(Vector2.ZERO, 2.0, Color(1.0, 1.0, 1.0, 1.0))

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(damage)
		detonate(false)

func _on_lifetime_expired() -> void:
	detonate(true)

func detonate(from_timeout: bool) -> void:
	if has_detonated:
		return
	has_detonated = true
	
	if bullet_type == "nova" and is_inside_tree() and get_parent():
		if AudioManager and AudioManager.has_method("play_explosion"):
			AudioManager.play_explosion()
			
		var expl = explosion_scene.instantiate()
		expl.global_position = global_position
		get_parent().add_child(expl)
		
		# Fragmentación en 6 esquirlas secundarias si expira por alcance
		if from_timeout:
			var shard_count: int = 6
			var angle_step: float = TAU / shard_count
			for i in range(shard_count):
				var shard_dir := Vector2(cos(i * angle_step), sin(i * angle_step))
				var shard = load("res://scenes/enemy_bullet.tscn").instantiate() as EnemyBullet
				shard.global_position = global_position + shard_dir * 12.0
				shard.direction = shard_dir
				shard.speed = 190.0
				shard.damage = 14.0
				shard.bullet_type = "danmaku"
				shard.custom_color = Color(1.0, 0.5, 0.1)
				shard.lifetime = 1.4
				get_parent().add_child(shard)
				
	queue_free()
