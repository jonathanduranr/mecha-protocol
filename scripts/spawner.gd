extends Node2D

@export var mecha: Node2D
@export var base_spawn_interval: float = 0.65

var spawn_timer: float = 0.0
var elapsed_time: float = 0.0
var next_swarm_time: float = 50.0

var boss_spawned_3m: bool = false
var boss_spawned_6m: bool = false

@onready var drone_scene := preload("res://scenes/enemy_drone.tscn")
@onready var hud: CanvasLayer = get_parent().get_node_or_null("HUD")

func _physics_process(delta: float) -> void:
	elapsed_time += delta
	spawn_timer -= delta
	
	# Evento de Enjambres Periódicos (Swarm Rushes)
	if elapsed_time >= next_swarm_time:
		trigger_swarm_event()
		next_swarm_time = elapsed_time + randf_range(45.0, 55.0)
	
	# Eventos de Jefes por tiempo
	if elapsed_time >= 180.0 and not boss_spawned_3m:
		boss_spawned_3m = true
		if hud and hud.has_method("show_alert"):
			hud.show_alert("⚠️ ¡COLOSO CENTINELA DETECTADO! ⚠️")
		spawn_specific_enemy("boss", 2200.0)
		
	if elapsed_time >= 360.0 and not boss_spawned_6m:
		boss_spawned_6m = true
		if hud and hud.has_method("show_alert"):
			hud.show_alert("⚠️ ¡TITÁN DE ASALTO MK-II DETECTADO! ⚠️")
		spawn_specific_enemy("boss", 4800.0)
	
	# Mayor densidad de spawns continuos
	var current_interval: float = max(0.24, base_spawn_interval - (elapsed_time * 0.0022))
	
	if spawn_timer <= 0:
		spawn_timer = current_interval
		process_wave_spawns()

func process_wave_spawns() -> void:
	if elapsed_time < 60.0:
		spawn_specific_enemy("scout", 35.0 + (elapsed_time * 0.4))
		if elapsed_time > 30.0 and randf() < 0.45:
			spawn_specific_enemy("scout", 35.0 + (elapsed_time * 0.4))
	elif elapsed_time < 130.0:
		spawn_specific_enemy("scout", 60.0 + (elapsed_time * 0.5))
		if randf() < 0.35:
			spawn_specific_enemy("tank", 220.0 + (elapsed_time * 1.0))
		if elapsed_time > 75.0 and randf() < 0.30:
			spawn_specific_enemy("shooter", 90.0 + (elapsed_time * 0.5))
	else:
		# Fase de combate intenso: múltiples spawns por tick
		for i in range(2):
			if randf() < 0.40:
				spawn_specific_enemy("swarm", 65.0 + (elapsed_time * 0.35))
			elif randf() < 0.35:
				spawn_specific_enemy("shooter", 110.0 + (elapsed_time * 0.5))
			else:
				spawn_specific_enemy("scout", 95.0 + (elapsed_time * 0.5))
				
		if randf() < 0.35:
			spawn_specific_enemy("tank", 340.0 + (elapsed_time * 1.2))

func trigger_swarm_event() -> void:
	if not is_instance_valid(mecha):
		return
		
	var is_ring := randf() < 0.5
	if is_ring:
		if hud and hud.has_method("show_alert"):
			hud.show_alert("⚠️ ¡ANILLO DE ASALTO ENTRANTE! ⚠️")
		spawn_circle_swarm(28, "scout" if elapsed_time < 100.0 else "swarm")
	else:
		if hud and hud.has_method("show_alert"):
			hud.show_alert("⚠️ ¡ENJAMBRE HOSTIL MASIVO! ⚠️")
		spawn_flank_stampede(30, "swarm" if elapsed_time > 70.0 else "scout")

## Spawnea un círculo de enemigos alrededor del mecha que convergen hacia él
func spawn_circle_swarm(count: int, enemy_type: String) -> void:
	var radius: float = 460.0
	var angle_step := TAU / count
	for i in range(count):
		var angle := i * angle_step
		var pos := mecha.global_position + Vector2(cos(angle), sin(angle)) * radius
		spawn_drone_at_pos(pos, enemy_type, 25.0 + (elapsed_time * 0.2))

## Spawnea una estampida desde los bordes superior e inferior
func spawn_flank_stampede(count: int, enemy_type: String) -> void:
	var viewport_size := get_viewport_rect().size
	for i in range(count):
		var spawn_pos := Vector2.ZERO
		if i % 2 == 0:
			spawn_pos = Vector2(randf_range(20, viewport_size.x - 20), -40.0 - (i * 12))
		else:
			spawn_pos = Vector2(randf_range(20, viewport_size.x - 20), viewport_size.y + 40.0 + (i * 12))
		spawn_drone_at_pos(spawn_pos, enemy_type, 25.0 + (elapsed_time * 0.2))

func spawn_drone_at_pos(pos: Vector2, type_name: String, hp: float) -> void:
	var drone = drone_scene.instantiate()
	drone.drone_type = type_name
	drone.max_health = hp
	drone.target_mecha = mecha
	drone.global_position = pos
	drone.add_to_group("enemies")
	get_parent().add_child(drone)

func spawn_specific_enemy(type_name: String, hp: float) -> void:
	if not is_instance_valid(mecha):
		return
		
	var viewport_size := get_viewport_rect().size
	var spawn_pos := Vector2.ZERO
	var edge := randi() % 4
	var offset: float = 50.0
	
	match edge:
		0: spawn_pos = Vector2(randf_range(0, viewport_size.x), -offset)
		1: spawn_pos = Vector2(randf_range(0, viewport_size.x), viewport_size.y + offset)
		2: spawn_pos = Vector2(-offset, randf_range(0, viewport_size.y))
		3: spawn_pos = Vector2(viewport_size.x + offset, randf_range(0, viewport_size.y))
			
	spawn_drone_at_pos(spawn_pos, type_name, hp)
