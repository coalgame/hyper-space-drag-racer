class_name HUD extends CanvasLayer

@export var rear_indicator_texture: Texture2D

var _player_labels: Dictionary = {} # Player node -> Label node
var _indicators: Dictionary = {} # Player node -> TextureRect

func _ready() -> void:
	# Connect to tree signals to handle players joining/leaving mid-game
	get_tree().node_added.connect(_on_node_added)
	get_tree().node_removed.connect(_on_node_removed)
	
	# Sync any players already in the scene
	for p in get_tree().get_nodes_in_group("player"):
		_add_player_label(p)

func _process(_delta: float) -> void:
	var player = Global.local_player
	var world = Main.world
	
	if !is_instance_valid(player) or !is_instance_valid(world):
		visible = false
		return
	visible = true
	var screen_size = get_viewport().get_visible_rect().size
		
	DebugDraw2D.set_text("top_speed", snappedf(player.top_speed, 0.1))
	DebugDraw2D.set_text("speed", snappedf(player.speed, 0.1))
	DebugDraw2D.set_text("velocity", player.velocity)
	DebugDraw2D.set_text("lap", player.lap)
	
	# Sort active players by race progress (Z position)
	var active_players = _player_labels.keys().filter(func(p): return is_instance_valid(p))
	active_players.sort_custom(func(a, b):
		return a.get_total_distance() > b.get_total_distance()
	)
	
	# Update labels and reorder them in the UI container
	for i in range(active_players.size()):
		var p = active_players[i]
		var label = _player_labels[p]
		
		if is_instance_valid(label):
			var is_local = (p == Global.local_player)
			var display_name = p.player_name
			
			if is_local:
				label.add_theme_constant_override("outline_size", 7)
				label.add_theme_font_size_override("font_size", 21)
			else:
				label.remove_theme_constant_override("outline_size")
				label.remove_theme_font_size_override("font_size")

			# Sync with name and color from player.gd
			label.text = "%d. %s %s" % [i + 1, display_name, str(int(p.get_progress_percentage())) + "%"]
			label.modulate = p.player_color
			# Visually move the label to the correct index in the list
			%PlayerPlacements.move_child(label, i)

	_update_rear_indicators(player, active_players, screen_size)

func _update_rear_indicators(local_player: Player, active_players: Array, screen_size: Vector2) -> void:
	if !rear_indicator_texture: return
	var cam = local_player.cam
	var max_dist = 150.0 # Distance at which the indicator fully fades out

	for p in active_players:
		if p == local_player: continue
		
		# Check if player is behind and within range
		var dist_z = local_player.global_position.z - p.global_position.z
		
		if cam.is_position_behind(p.global_position) and dist_z < max_dist:
			var icon : TextureRect
			
			if not _indicators.has(p):
				icon = TextureRect.new()
				icon.texture = rear_indicator_texture
				icon.custom_minimum_size = Vector2(64, 64)
				icon.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
				add_child(icon)
				_indicators[p] = icon
			
			icon = _indicators[p]
			icon.show()
			var proximity = 1.0 - (dist_z / max_dist)
			
			var screen_pos := cam.unproject_position(p.global_position)
			screen_pos.x = screen_size.x - screen_pos.x
			screen_pos.x = clamp(screen_pos.x, 50.0, screen_size.x - 50.0)
			screen_pos.y = screen_size.y - 80.0
		
			icon.position = screen_pos
			icon.modulate = p.player_color
			icon.modulate.a = proximity
			icon.scale = Vector2.ONE * lerp(0.5, 1.5, proximity)
		elif _indicators.has(p):
			_indicators[p].hide()

func _on_node_added(node: Node) -> void:
	if node.is_in_group("player"):
		_add_player_label(node)

func _on_node_removed(node: Node) -> void:
	_remove_player_label(node)

func _add_player_label(p: Node) -> void:
	if _player_labels.has(p):
		return
	
	var label = preload("res://ui/player_placements_label.tscn").instantiate()
	%PlayerPlacements.add_child(label)
	_player_labels[p] = label

func _remove_player_label(p: Node) -> void:
	if _player_labels.has(p):
		var label = _player_labels[p]
		if is_instance_valid(label):
			label.queue_free()
		_player_labels.erase(p)
	if _indicators.has(p):
		if is_instance_valid(_indicators[p]):
			_indicators[p].queue_free()
		_indicators.erase(p)
