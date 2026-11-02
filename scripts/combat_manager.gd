extends Node

# ==============================================================================
# COMBAT MANAGER & SPATIAL HASH GRID (Motor de Alto Rendimiento para Enjambres)
# Optimiza el procesamiento masivo de enemigos (Nv. 40+) eliminando bucles O(N^2).
# ==============================================================================

const CELL_SIZE: float = 75.0
const INV_CELL_SIZE: float = 1.0 / 75.0

var all_enemies: Array = []
var all_scraps: Array = []
var active_boss: Node2D = null

# Grilla espacial: Vector2i (coordenadas de celda) -> Array[Node2D]
var enemy_grid: Dictionary = {}
var scrap_grid: Dictionary = {}

var scrap_scene: PackedScene = preload("res://scenes/scrap.tscn")

func _physics_process(_delta: float) -> void:
	# 1. Agrupamiento centralizado: se llama get_nodes_in_group solo 1 vez por frame
	all_enemies = get_tree().get_nodes_in_group("enemies")
	all_scraps = get_tree().get_nodes_in_group("scraps")
	
	# 2. Reconstrucción de la grilla espacial de enemigos (O(N))
	enemy_grid.clear()
	active_boss = null
	
	for i in range(all_enemies.size()):
		var enemy := all_enemies[i] as Node2D
		if not is_instance_valid(enemy):
			continue
			
		if active_boss == null and enemy.get("drone_type") == "boss":
			active_boss = enemy
			
		var pos: Vector2 = enemy.global_position
		var cell := Vector2i(int(pos.x * INV_CELL_SIZE), int(pos.y * INV_CELL_SIZE))
		if not enemy_grid.has(cell):
			enemy_grid[cell] = [enemy]
		else:
			(enemy_grid[cell] as Array).append(enemy)

	# 3. Grilla espacial de chatarra no atraída para fusión eficiente de drops
	scrap_grid.clear()
	for j in range(all_scraps.size()):
		var sc := all_scraps[j] as Node2D
		if is_instance_valid(sc) and not sc.get("is_attracted"):
			var pos_sc: Vector2 = sc.global_position
			var cell_sc := Vector2i(int(pos_sc.x * INV_CELL_SIZE), int(pos_sc.y * INV_CELL_SIZE))
			if not scrap_grid.has(cell_sc):
				scrap_grid[cell_sc] = [sc]
			else:
				(scrap_grid[cell_sc] as Array).append(sc)

## Consulta enemigos en un radio determinado examinando sólo las celdas adyacentes
func get_nearby_enemies(pos: Vector2, radius: float = 50.0) -> Array:
	var r_cells: int = max(1, int(ceil(radius * INV_CELL_SIZE)))
	var cx: int = int(pos.x * INV_CELL_SIZE)
	var cy: int = int(pos.y * INV_CELL_SIZE)
	var result: Array = []
	
	for dx in range(-r_cells, r_cells + 1):
		for dy in range(-r_cells, r_cells + 1):
			var cell := Vector2i(cx + dx, cy + dy)
			if enemy_grid.has(cell):
				result.append_array(enemy_grid[cell])
				
	return result

## Encuentra el enemigo más cercano dentro de un rango usando la grilla espacial
func get_closest_enemy_in_range(pos: Vector2, max_dist: float) -> Node2D:
	var closest: Node2D = null
	var min_dist_sq: float = max_dist * max_dist
	
	var nearby := get_nearby_enemies(pos, max_dist)
	for enemy_node: Node in nearby:
		var enemy := enemy_node as Node2D
		if is_instance_valid(enemy):
			var d_sq := pos.distance_squared_to(enemy.global_position)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				closest = enemy
				
	return closest

## Genera chatarra o la fusiona con una existente contigua si hay alta acumulación
func spawn_or_merge_scrap(pos: Vector2, xp: int, parent: Node) -> void:
	var cx: int = int(pos.x * INV_CELL_SIZE)
	var cy: int = int(pos.y * INV_CELL_SIZE)
	var merge_cell := Vector2i(cx, cy)
	
	# Buscar si ya hay un scrap en la misma celda (a menos de 36px) para fusionar
	if scrap_grid.has(merge_cell):
		var cell_scraps: Array = scrap_grid[merge_cell]
		for sc_node: Node in cell_scraps:
			var sc := sc_node as Node2D
			if is_instance_valid(sc) and not sc.get("is_attracted"):
				if pos.distance_squared_to(sc.global_position) <= 36.0 * 36.0:
					sc.set("xp_value", int(sc.get("xp_value")) + xp)
					sc.queue_redraw()
					return
					
	# Si no hay chatarra contigua, se crea un nodo nuevo normalmente
	var new_scrap = scrap_scene.instantiate()
	new_scrap.xp_value = xp
	new_scrap.global_position = pos
	parent.add_child(new_scrap)
	
	if not scrap_grid.has(merge_cell):
		scrap_grid[merge_cell] = [new_scrap]
	else:
		(scrap_grid[merge_cell] as Array).append(new_scrap)
