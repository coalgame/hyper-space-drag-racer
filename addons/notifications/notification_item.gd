# NotificationItem.gd
extends Label
class_name NotificationItem

# The path to the Notification Item scene (set this path correctly).
const FADE_DURATION = 0.5
const DISPLAY_TIME = 3.0
const TOTAL_DURATION = DISPLAY_TIME + FADE_DURATION

var fade_out_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready():
	# Set up the internal Timer for controlling the fade-out start time.
	fade_out_timer = Timer.new()
	add_child(fade_out_timer)
	fade_out_timer.wait_time = DISPLAY_TIME
	fade_out_timer.one_shot = true
	fade_out_timer.timeout.connect(_on_fade_out_timer_timeout)
	
	# Start the timer immediately after setting the text
	# (The 'set_text' function in the Autoload script will call this).
	
	# Initial positioning (align to the bottom left corner of its parent container)
	# This ensures new items appear below existing ones when the container's
	# layout is set to vertical stacking.
	# The parent container will handle the actual stack arrangement.
	
	# Start fully opaque
	modulate.a = 1.0

# Public method to set the notification text.
func set_text_a(content: String):
	text = content
	fade_out_timer.start()

# Called when the display time is up. Starts the fade animation.
func _on_fade_out_timer_timeout():
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	# After fading, clean up the notification.
	tween.tween_callback(queue_free)

# SETUP INSTRUCTION:
# 1. Create a new scene (Control node root) named 'NotificationItem.tscn'.
# 2. Add a Label child named 'TextLabel'.
# 3. Add this script ('NotificationItem.gd') to the root Control node.
# 4. Style the Label (Font, size, color, background padding, etc.).
# 5. Save the scene.
