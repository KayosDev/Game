extends Node2D

var lifetime = 2.0  # How long the notification stays visible
var move_distance = 50.0  # How far it moves up
var start_y = 0.0  # Starting Y position

func _ready():
	# Store initial position
	start_y = position.y
	
	# Create animation
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y - move_distance, lifetime)
	tween.parallel().tween_property(self, "modulate:a", 0.0, lifetime)
	tween.tween_callback(queue_free)

# Set the notification text
func set_text(text: String):
	$Label.text = text

# Static function to create and show a notification
static func show_notification(parent: Node, position: Vector2, upgrade_text: String):
	var scene = load("res://scenes/upgrade_notification.tscn")
	var notification = scene.instantiate()
	
	parent.add_child(notification)
	notification.position = position
	notification.set_text(upgrade_text)
	
	return notification 