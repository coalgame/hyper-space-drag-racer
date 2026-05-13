# Notifications.gd (Must be registered as Autoload 'Notifications')
extends Node

# --- Configuration ---

# Path to the NotificationItem scene (MUST BE CORRECT)
const NOTIFICATION_SCENE_PATH = "res://addons/notifications/notification_item.tscn"

# Path to the container node in your main scene (MUST BE CORRECT)
# Example: If your Main Scene has a CanvasLayer/Control named 'ToastContainer'
# positioned on the middle-left of the screen, use that path.
const CONTAINER_PATH = "res://MainScene.tscn/root/CanvasLayer/ToastContainer"

# Maximum number of notifications visible simultaneously.
const MAX_NOTIFICATIONS = 5

var notification_scene: PackedScene
var container_node: VBoxContainer # A VBoxContainer will handle the stacking automatically!

# --- Initialization ---

func _ready():
	# Load the notification scene once on startup.
	if ResourceLoader.exists(NOTIFICATION_SCENE_PATH):
		notification_scene = load(NOTIFICATION_SCENE_PATH)
	else:
		# Important: Log an error if the path is wrong.
		push_error("Notification scene not found at: ", NOTIFICATION_SCENE_PATH)

	# Find the container node in the current scene tree.
	# We use get_tree().get_root().find_child(..., true, false) for robustness
	# across different main scenes, but using the specific path is safer.
	
	container_node = VBoxContainer.new()
	container_node.position = Vector2(0,350)
	container_node.size = Vector2(300, 1000)
	add_child(container_node)

# --- Public API ---

# The user-callable function. Can take multiple arguments which are converted to a single string.
func notify(...args:Array):
	# If the user passes multiple arguments, concatenate them.
	# Example: Notifications.notify("Player ", player.name, " defeated ", enemy.name)
	var full_message = ""
	for arg in args:
		full_message += " " + str(arg)

	if notification_scene == null || container_node == null:
		# Fail gracefully if setup is incomplete.
		push_error("Notifications system is not fully initialized. Check paths.")
		return

	# 1. Instantiate the new notification item.
	var new_notification = notification_scene.instantiate()
	
	# 2. Add it to the VBoxContainer.
	# VBoxContainer automatically stacks new children vertically.
	container_node.add_child(new_notification)

	# 3. Set the text and start the countdown timer.
	if new_notification is Control: # Check if it's the correct type
		new_notification.set_text_a(full_message)
		
	# 4. Handle the "stack" limit (similar to a killfeed queue).
	# Remove the oldest (topmost) notification if the limit is exceeded.
	if container_node.get_child_count() > MAX_NOTIFICATIONS:
		var oldest_notification = container_node.get_child(0)
		# Start its immediate fade-out animation and removal.
		# Note: We manually start a quicker removal here instead of waiting for its timer.
		if oldest_notification is NotificationItem:
			var tween = create_tween()
			tween.tween_property(oldest_notification, "modulate:a", 0.0, 0.2)
			tween.tween_callback(oldest_notification.queue_free)
		else:
			oldest_notification.queue_free()
