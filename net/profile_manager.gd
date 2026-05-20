extends Node

const SAVE_PATH = "user://player_profile.cfg"
const PRESET_COLORS = [
	Color.RED,
	Color.ORANGE,
	Color.YELLOW,
	Color.GREEN,
	Color.DODGER_BLUE,
	Color.MEDIUM_PURPLE,
	Color.HOT_PINK,
]

var data = {"name": "", "color": Color.WHITE}

func _ready():
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	
	var default_color = PRESET_COLORS.pick_random()
	var default_name = "CHUD" + str(randi_range(0, 9))
	
	if err == OK:
		data.name = config.get_value("profile", "name", default_name)
		data.color = config.get_value("profile", "color", default_color)
	else:
		data.name = default_name
		data.color = default_color
		save_settings()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("profile", "name", data.name)
	config.set_value("profile", "color", data.color)
	config.save(SAVE_PATH)

func set_username(new_name: String):
	data.name = new_name
	save_settings()
	_sync_with_network()

func set_color(new_color: Color):
	data.color = new_color
	save_settings()
	_sync_with_network()

func _sync_with_network():
	if NetworkManager.has_connection():
		NetworkManager.update_local_player_registration()
