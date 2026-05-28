class_name HUD extends CanvasLayer

var _player_labels: Dictionary = {} # Player node -> Label node

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
		
	DebugDraw2D.set_text("top_speed", snappedf(player.top_speed, 0.1))
	DebugDraw2D.set_text("speed", snappedf(player.speed, 0.1))
	DebugDraw2D.set_text("velocity", player.velocity)
	DebugDraw2D.set_text("lap", player.lap)
	
	# Sort active players by race progress (Z position)
	var active_players = _player_labels.keys().filter(func(p): return is_instance_valid(p))
	active_players.sort_custom(func(a, b):
		return a.global_position.z > b.global_position.z
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
			label.text = "%d. %s %s" % [i + 1, display_name, str(int((p.global_position.z / Main.world.track_length) * 100)) + "%"]
			label.modulate = p.player_color
			# Visually move the label to the correct index in the list
			%PlayerPlacements.move_child(label, i)
	
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
