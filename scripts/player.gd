extends CharacterBody2D

signal player_died
signal player_damaged(amount)
signal player_healed(amount)
signal player_level_up(level)
signal weapon_added(weapon_type)

@export var speed: float = 360.0
@export var lr_flag: bool = true # Enable body left right animation
@export var rotate_flag: bool = true # Enable body rotation 
@export var max_health: int = 100 # Maximum player health
@export var invincibility_time: float = 0.5 # Reduced from 1.0 to 0.5 seconds
@export var hit_recoil_strength: float = 20.0 # Changed from 600.0 to 20.0 for subtle knockback
@export var gun_recoil_range: float = 15.0 # Degrees of random spread for shooting
@export var fire_rate: float = 0.2 # Time between shots
@export var melee_damage: int = 50 # Increased from 30 to 50 for stronger attacks
@export var melee_cooldown: float = 0.4 # Time between melee attacks
@export var hit_stop_duration: float = 0.08 # Duration of hit stop effect
@export var melee_range: float = 80.0 # Range of melee attack
@export var death_slowmo_factor: float = 0.1 # How slow time gets when player dies
@export var death_slowmo_duration: float = 2.0 # How long slowmo lasts before resetting

var screen_size # Size of the game window.
var lr: bool = true # Default face right
var aim_pos: Vector2 = Vector2(0, 0)
var is_shot_cd: bool = false
var push_dir: Vector2 = Vector2(0, 0)
var push_strength: float = 0.0
var push_timer: float = 0.0
var health: int = 100 # Current health
var invincible: bool = false # Invincibility flag after taking damage
var invincible_timer: float = 0.0 # Invincibility time counter
var is_dead: bool = false # Flag to track if player is dead
var recoil_control: float = 1.0 # Multiplier for gun recoil (lower = more control)
var is_melee_cd: bool = false # Melee cooldown flag
var is_performing_melee: bool = false # Flag for melee animation
var melee_timer: float = 0.0 # Melee animation timer
var melee_angle: float = 0.0 # Angle of melee attack
var hit_stop_active: bool = false # Hit stop effect flag
var hit_stop_timer: float = 0.0 # Hit stop timer
var melee_hit_enemies = [] # Track enemies hit in current swing
var permanent_upgrades = {} # For tracking upgrades kept between runs

# Weapon system
var active_weapons = [] # List of active weapon types
var max_weapons = 5 # Maximum number of addon weapons
var weapon_timers = {} # Dictionary to track weapon cooldowns
var weapon_levels = {} # Dictionary to track weapon upgrade levels

# Reference
@onready var body_lr: Polygon2D = $BodyLR
@onready var body_rotate: Polygon2D = $BodyRotate
@onready var body_lr_player: AnimationPlayer = $BodyLRPlayer
@onready var body_rotete_player: AnimationPlayer = $BodyRotatePlayer
@onready var move_trail_effect: Node2D = $MovementTrailEffect
@onready var bullet_scene = preload("res://scenes/bullet.tscn")
@onready var bullet_spawn_pos: Node2D = $BodyRotate/BulletSpawnPoint
@onready var shot_timer: Timer = $ShotTimer
@onready var shot_effect: Node2D = $BodyRotate/ShootingEffect
@onready var body_lr_collider: CollisionPolygon2D = $CollisionBodyLR
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var health_bar: ProgressBar = $HealthBar
@onready var damage_effect: Node2D = $DamageEffect
@onready var death_effect: Node2D = $DeathEffect
@onready var heal_effect: Node2D = $HealEffect
# We'll create these dynamically instead of using @onready
var melee_timer_node: Timer
var melee_swing: Polygon2D
var melee_hitbox: Area2D
var melee_impact_effect: Node2D

# Dictionary of available weapon types
var weapon_types = {
	"laser": {
		"name": "Laser Beam",
		"fire_rate": 0.4,
		"damage": 15,
		"color": Color(1.0, 0.3, 0.3),
		"projectile_speed": 600,
		"projectile_scale": Vector2(1.5, 0.5),
		"pierce": true
	},
	"shotgun": {
		"name": "Shotgun",
		"fire_rate": 0.7,
		"damage": 8,
		"color": Color(0.9, 0.6, 0.1),
		"projectile_count": 5,
		"spread": 30,
		"projectile_speed": 500
	},
	"orbit": {
		"name": "Orbital Protector",
		"fire_rate": 0.1,
		"damage": 7,
		"color": Color(0.2, 0.8, 0.2),
		"orbit_distance": 80,
		"orbit_speed": 2.0,
		"projectile_scale": Vector2(0.8, 0.8)
	},
	"missile": {
		"name": "Homing Missile",
		"fire_rate": 1.0,
		"damage": 25,
		"color": Color(0.7, 0.7, 0.7),
		"projectile_speed": 300,
		"projectile_scale": Vector2(1.2, 0.8),
		"tracking": true
	},
	"lightning": {
		"name": "Chain Lightning",
		"fire_rate": 0.8,
		"damage": 12,
		"color": Color(0.4, 0.4, 1.0),
		"projectile_speed": 550,
		"chain_count": 3,
		"chain_range": 100
	}
}

# Orbital projectiles tracking
var orbital_projectiles = []
var orbital_angles = []
var orbital_timer = 0.0

# No preload since we'll create it dynamically
var death_message_instance = null

func _ready():
	screen_size = get_viewport_rect().size
	hide()
	health = max_health
	health_bar.max_value = max_health
	health_bar.value = health
	
	# Check if bullet scene loaded correctly
	if bullet_scene == null:
		printerr("Failed to load bullet scene! Check if 'res://scenes/bullet.tscn' exists.")
		# Fallback to a simple polygon for bullets
		bullet_scene = _create_fallback_bullet()
	
	# Improve health bar appearance
	health_bar.modulate = Color(1.0, 1.0, 1.0, 0.9)
	health_bar.size = Vector2(80, 8)
	health_bar.position = Vector2(-40, -60)
	
	# Update health bar style
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.7)
	style_bg.corner_radius_top_left = 4
	style_bg.corner_radius_top_right = 4
	style_bg.corner_radius_bottom_left = 4
	style_bg.corner_radius_bottom_right = 4
	style_bg.border_width_left = 2
	style_bg.border_width_top = 2
	style_bg.border_width_right = 2
	style_bg.border_width_bottom = 2
	style_bg.border_color = Color(0, 0, 0, 0.3)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.8, 0.2, 0.2)
	style_fill.corner_radius_top_left = 4
	style_fill.corner_radius_top_right = 4
	style_fill.corner_radius_bottom_left = 4
	style_fill.corner_radius_bottom_right = 4
	
	health_bar.add_theme_stylebox_override("background", style_bg)
	health_bar.add_theme_stylebox_override("fill", style_fill)
	
	is_dead = false
	shot_timer.wait_time = fire_rate
	
	# Create melee attack elements dynamically
	setup_melee_components()
	
	# Initialize weapon system
	active_weapons = []
	weapon_timers = {}
	weapon_levels = {}
	orbital_projectiles = []
	orbital_angles = []
	orbital_timer = 0.0
	
	# Load permanent upgrades
	load_permanent_upgrades()
	
	# Register console commands if Limbo Console is available
	if Engine.has_singleton("LimboConsole"):
		register_console_commands()
	
	# Player starts with only the basic left-click weapon
	# No additional weapons until unlocked by the player

# Create all melee components dynamically
func setup_melee_components():
	# 1. Create melee timer
	if has_node("MeleeTimer"):
		melee_timer_node = get_node("MeleeTimer")
	else:
		melee_timer_node = Timer.new()
		melee_timer_node.name = "MeleeTimer"
		melee_timer_node.one_shot = true
		melee_timer_node.wait_time = melee_cooldown
		add_child(melee_timer_node)
	
	# Connect the timer signal
	if not melee_timer_node.timeout.is_connected(_on_melee_timer_timeout):
		melee_timer_node.timeout.connect(_on_melee_timer_timeout)
	
	# 2. Get or create the BodyRotate node for swing and hitbox
	var body_rotate = get_node_or_null("BodyRotate")
	if not body_rotate:
		print("ERROR: BodyRotate node not found!")
		return
	
	# 3. Create melee swing (visual representation)
	if body_rotate.has_node("MeleeSwing"):
		melee_swing = body_rotate.get_node("MeleeSwing")
	else:
		melee_swing = Polygon2D.new()
		melee_swing.name = "MeleeSwing"
		
		# Create a swing arc shape
		var points = []
		for i in range(6):
			var angle = lerp(-0.8, 0.8, i / 5.0)
			var length = 80.0
			points.append(Vector2(cos(angle) * length, sin(angle) * length))
		
		# Add inner points to create thickness
		for i in range(5, -1, -1):
			var angle = lerp(-0.8, 0.8, i / 5.0)
			var length = 60.0
			points.append(Vector2(cos(angle) * length, sin(angle) * length))
		
		melee_swing.polygon = PackedVector2Array(points)
		melee_swing.color = Color(1.0, 0.7, 0.3, 0.8)
		melee_swing.visible = false
		body_rotate.add_child(melee_swing)
	
	# 4. Create melee hitbox (collision area)
	if body_rotate.has_node("MeleeHitbox"):
		melee_hitbox = body_rotate.get_node("MeleeHitbox")
	else:
		melee_hitbox = Area2D.new()
		melee_hitbox.name = "MeleeHitbox"
		
		# Create collision shape
		var collision_shape = CollisionShape2D.new()
		var shape = CircleShape2D.new()
		shape.radius = 40
		collision_shape.shape = shape
		collision_shape.position = Vector2(40, 0) # Position at the middle of the swing
		
		# Set collision layer and mask
		melee_hitbox.collision_layer = 4 # Same as projectiles
		melee_hitbox.collision_mask = 2  # Same as enemies
		melee_hitbox.monitoring = false  # Disabled by default
		
		melee_hitbox.add_child(collision_shape)
		body_rotate.add_child(melee_hitbox)
	
	# Connect the hitbox signal
	if not melee_hitbox.body_entered.is_connected(_on_melee_hitbox_body_entered):
		melee_hitbox.body_entered.connect(_on_melee_hitbox_body_entered)
	
	# 5. Create melee impact effect (particles)
	if has_node("MeleeImpactEffect"):
		melee_impact_effect = get_node("MeleeImpactEffect")
	else:
		melee_impact_effect = CPUParticles2D.new()
		melee_impact_effect.name = "MeleeImpactEffect"
		
		# Set up CPU particle properties directly
		melee_impact_effect.emitting = false
		melee_impact_effect.amount = 16
		melee_impact_effect.lifetime = 0.4
		melee_impact_effect.explosiveness = 0.8
		melee_impact_effect.one_shot = true
		melee_impact_effect.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		melee_impact_effect.emission_sphere_radius = 5.0
		melee_impact_effect.direction = Vector2(1, 0)
		melee_impact_effect.spread = 60.0
		melee_impact_effect.initial_velocity_min = 80.0
		melee_impact_effect.initial_velocity_max = 120.0
		melee_impact_effect.gravity = Vector2(0, 0)
		melee_impact_effect.damping_min = 20.0
		melee_impact_effect.damping_max = 40.0
		melee_impact_effect.scale_amount_min = 1.0
		melee_impact_effect.scale_amount_max = 2.0
		melee_impact_effect.color = Color(1.0, 0.7, 0.3)
		
		# Setup color ramp if needed
		var color_ramp = Gradient.new()
		color_ramp.add_point(0.0, Color(1.0, 0.7, 0.3, 1.0))
		color_ramp.add_point(1.0, Color(1.0, 0.2, 0.1, 0.0))
		melee_impact_effect.color_ramp = color_ramp
		
		add_child(melee_impact_effect)
	
	# Safety check - initialize melee components state
	if melee_swing:
		melee_swing.visible = false
	if melee_hitbox:
		melee_hitbox.monitoring = false
	if melee_impact_effect:
		melee_impact_effect.emitting = false

func _physics_process(delta):
	if is_dead:
		return
		
	if hit_stop_active:
		hit_stop_timer -= delta
		if hit_stop_timer <= 0:
			hit_stop_active = false
			Engine.time_scale = 1.0
			return
		
	velocity = Vector2.ZERO # The player's movement vector.
	# Movement input
	if Input.is_action_pressed("move_right"):
		velocity.x += 1
	if Input.is_action_pressed("move_left"):
		velocity.x -= 1
	if Input.is_action_pressed("move_down"):
		velocity.y += 1
	if Input.is_action_pressed("move_up"):
		velocity.y -= 1
	# Shot input - CONTINUOUS FIRING for more fun!
	if Input.is_action_pressed("shot"):
		if not is_shot_cd:
			shoot()
			is_shot_cd = true
			shot_timer.start(fire_rate * 0.6) # 40% faster firing
	# Normalize velocity if move along x and y together
	if velocity.length() > 0:
		velocity = velocity.normalized() * speed
		move_trail_effect.emitting = true # Play movement trail effect
		move_trail_effect.amount = 24  # More particles!
		move_trail_effect.lifetime = 0.6  # Longer trails
	else:
		move_trail_effect.emitting = false
	# Handle body_lr
	update_body_lr()
	# Handle push
	push_back(delta)
	# Handle invincibility timer
	if invincible:
		invincible_timer -= delta
		# Flash the player to indicate invincibility (faster flashing)
		modulate.a = 0.5 if int(invincible_timer * 15) % 2 == 0 else 1.0
		if invincible_timer <= 0:
			invincible = false
			modulate.a = 1.0
	# Limit the player movement, add your character scale if needed
	position.x = clamp(position.x, 0, screen_size.x)
	position.y = clamp(position.y, 0, screen_size.y)
	
	# Process additional weapons - update timers and fire when ready
	for weapon in weapon_timers.keys():
		if weapon_timers[weapon] > 0:
			weapon_timers[weapon] -= delta * 1.5 # Weapons fire 50% faster!
		elif active_weapons.has(weapon):
			fire_weapon(weapon)
	
	# Process orbital weapons
	if active_weapons.has("orbit"):
		process_orbital_weapons(delta)
	
	# Process melee attack
	process_melee(delta)
	
	move_and_slide()

func _input(event):
	if is_dead:
		return
		
	if event is InputEventMouseMotion:
		update_body_rotate(event.position)
		
	# Handle right-click for melee attack
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if not is_melee_cd and not is_performing_melee:
			perform_melee_attack(event.position)

func setup(pos: Vector2):
	position = pos
	show()
	health = max_health
	health_bar.value = health
	is_dead = false
	modulate.a = 1.0
	# Reset all effects
	if damage_effect:
		damage_effect.emitting = false
	if death_effect:
		death_effect.emitting = false
	if heal_effect:
		heal_effect.emitting = false
	
	# Reset weapons
	active_weapons = []
	weapon_timers = {}
	weapon_levels = {}
	orbital_projectiles = []
	orbital_angles = []
	
	# Player starts with only the basic left-click weapon
	# Do not add any secondary weapons here

func update_body_lr():
	if not lr_flag:
		return
	# Play body animation
	if velocity.length() > 0:
		# Move up / down
		if lr:
			body_lr_player.play("MoveR")
		else:
			body_lr_player.play("MoveL")
		# Move left / right
		if velocity.x > 0:
			body_lr_player.play("MoveR")
			body_lr_collider.scale.x = -1
			lr = true
		elif velocity.x < 0:
			body_lr_player.play("MoveL")
			body_lr_collider.scale.x = 1
			lr = false
	else:
		# Idle
		if lr:
			body_lr_player.play("IdleR")
		else:
			body_lr_player.play("IdleL")

func update_body_rotate(mouse_pos: Vector2):
	if not rotate_flag:
		return
	# Rotate with mouse
	body_rotate.look_at(mouse_pos)
	aim_pos = mouse_pos.normalized()

func shoot():
	body_rotete_player.play("Shot")
	
	# Fire multiple bullets in a spread pattern for more excitement!
	var bullet_count = 3
	
	for i in range(bullet_count):
		var bullet
		
		# Check if we're using a PackedScene or a GDScript for bullets
		if bullet_scene is PackedScene:
			bullet = bullet_scene.instantiate()
		else:
			# Create from script instead
			bullet = Area2D.new()
			bullet.set_script(bullet_scene)
		
		# Calculate a random angle based on recoil control
		var spread = 20.0
		var angle_offset = 0
		
		if bullet_count > 1:
			# For 3 bullets, do -spread, 0, +spread
			angle_offset = (i - (bullet_count-1)/2.0) * spread
			
		var random_angle = randf_range(-gun_recoil_range, gun_recoil_range) + angle_offset
		
		# Get the original transform from the bullet spawn position
		var original_transform = bullet_spawn_pos.global_transform
		
		# Create a rotated transform for the bullet
		var rotated_transform = Transform2D()
		rotated_transform.origin = original_transform.origin
		rotated_transform.x = original_transform.x.rotated(deg_to_rad(random_angle))
		rotated_transform.y = original_transform.y.rotated(deg_to_rad(random_angle))
		
		bullet.setup(rotated_transform)
		get_tree().root.add_child(bullet)
	
	# Enhanced shot effect
	if shot_effect:
		shot_effect.emitting = true
		shot_effect.amount = 20  # More particles
		shot_effect.lifetime = 0.4  # Visible longer
	
	# Add screen shake for impact!
	var screen_shake = randf_range(3.0, 6.0)
	if get_parent().has_method("apply_screen_shake"):
		get_parent().apply_screen_shake(screen_shake, 0.2)
	
	# Play shoot sound with random pitch for variety
	if audio_player:
		audio_player.play()
		audio_player.pitch_scale = randf_range(0.9, 1.1)

func set_push(dir: Vector2, strength: float, timer: float):
	push_dir = dir
	push_strength = strength
	push_timer = timer

func push_back(delta: float):
	if push_timer > 0.0:
		position -= push_dir * push_strength * delta
		push_timer -= delta
	else:
		push_timer = 0.0

func _on_shot_timer_timeout():
	is_shot_cd = false

func take_damage(amount: int):
	if invincible or is_dead:
		return
		
	health -= amount
	health_bar.value = health
	
	# Signal that player was damaged
	emit_signal("player_damaged", amount)
	
	# Play damage effect
	if damage_effect:
		damage_effect.restart()
		damage_effect.emitting = true
	
	# Apply damage effects
	invincible = true
	invincible_timer = invincibility_time
	
	# Apply strong push effect when damaged
	var random_dir = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	set_push(random_dir, hit_recoil_strength, 0.3) # Increased duration too
	
	# Check if player is dead
	if health <= 0:
		die()

func heal(amount: int):
	if is_dead:
		return
		
	# Cap health at max_health
	var actual_heal = min(amount, max_health - health)
	if actual_heal <= 0:
		return
		
	health += actual_heal
	health_bar.value = health
	
	# Play heal effect
	if heal_effect:
		heal_effect.restart()
		heal_effect.emitting = true
	
	# Signal that player was healed
	emit_signal("player_healed", actual_heal)

func die():
	is_dead = true
	health = 0
	health_bar.value = 0
	
	# Print debug message
	print("Player died!")
	# Apply slow motion effect
	Engine.time_scale = death_slowmo_factor
	
	# Play death effect particles
	if death_effect:
		death_effect.restart()
		death_effect.emitting = true
	
	# Make player semitransparent
	modulate.a = 0.7
	
	# Stop movement and disable controls
	velocity = Vector2.ZERO
	
	# Emit death signal
	emit_signal("player_died")
	
	# Schedule return to normal time
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = death_slowmo_duration * death_slowmo_factor # Adjusted for slowmo
	timer.timeout.connect(_on_death_slowmo_timeout)
	add_child(timer)
	timer.start()
	
	# Create death message if it doesn't exist
	if death_message_instance == null:
		death_message_instance = create_death_message()
	
	# Add to scene if valid
	if death_message_instance:
		get_tree().root.add_child(death_message_instance)
		print("Death menu added to scene tree")

func create_death_message():
	# Create a death message canvas layer
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	canvas_layer.name = "DeathMessageLayer"
	
	# Create background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.5)
	background.anchors_preset = Control.PRESET_FULL_RECT
	canvas_layer.add_child(background)
	
	# Create container
	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.size = Vector2(500, 300)
	container.position = Vector2(-250, -150)
	canvas_layer.add_child(container)
	
	# Death message
	var message = Label.new()
	message.text = "YOU DIED"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.add_theme_font_size_override("font_size", 72)
	message.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
	container.add_child(message)
	
	# Spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	container.add_child(spacer)
	
	# Restart instruction
	var restart_label = Label.new()
	restart_label.text = "Press SPACE or R to restart"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.add_theme_font_size_override("font_size", 32)
	container.add_child(restart_label)
	
	# Animate the death menu
	animate_death_menu(container, background)
	
	# Add blood effects
	add_blood_effects(canvas_layer)
	
	return canvas_layer

func animate_death_menu(container, background):
	# Start with everything transparent
	container.modulate = Color(1, 1, 1, 0)
	background.color.a = 0
	
	# Create tweens for dramatic effect
	var tween = create_tween()
	tween.tween_property(background, "color:a", 0.7, 0.8)
	
	# Message appears with a fade
	var message_tween = create_tween()
	message_tween.tween_property(container, "modulate", Color(1, 1, 1, 1), 0.5)
	
	# Shake the container for emphasis
	var initial_pos = container.position
	for i in range(5):
		message_tween.tween_property(container, "position", initial_pos + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.05)
	message_tween.tween_property(container, "position", initial_pos, 0.1)

func add_blood_effects(parent):
	# Add some blood splatter polygons for effect
	for i in range(8):
		var splatter = Polygon2D.new()
		var points = []
		var center = Vector2(randf_range(100, get_viewport_rect().size.x - 100), 
							randf_range(100, get_viewport_rect().size.y - 100))
		
		# Create a random splatter shape
		for j in range(8):
			var radius = randf_range(20, 80) # Larger splatters
			var angle = randf_range(0, TAU)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		
		splatter.polygon = PackedVector2Array(points)
		
		# Randomize the blood colors slightly for better effect
		var red_shade = randf_range(0.5, 0.8)
		splatter.color = Color(red_shade, red_shade * 0.1, red_shade * 0.1, randf_range(0.4, 0.8))
		parent.add_child(splatter)

func _on_death_slowmo_timeout():
	# Restore normal time
	Engine.time_scale = 1.0
	
	# Save permanent upgrades before game ends
	save_permanent_upgrades()
	
	# Keep menu visible but wait for player input to restart

# Handle input for restart
func _unhandled_input(event):
	# Check for restart input when dead
	if is_dead and death_message_instance:
		if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select") or \
		   event is InputEventKey and (event.keycode == KEY_R or event.keycode == KEY_SPACE):
			restart_game()

func restart_game():
	# Remove death message
	if death_message_instance:
		death_message_instance.queue_free()
		death_message_instance = null
	
	# Reset time scale
	Engine.time_scale = 1.0
	
	# Restart the game
	get_tree().reload_current_scene()

func show_start_menu():
	# Create start menu canvas
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	canvas_layer.name = "StartMenuLayer"
	
	# Create background
	var background = ColorRect.new()
	background.color = Color(0, 0, 0, 0.8)
	background.anchors_preset = Control.PRESET_FULL_RECT
	canvas_layer.add_child(background)
	
	# Create container
	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.size = Vector2(500, 300)
	container.position = Vector2(-250, -150)
	canvas_layer.add_child(container)
	
	# Title
	var title = Label.new()
	title.text = "TOPIS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	container.add_child(title)
	
	# Spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	container.add_child(spacer)
	
	# Start game instruction
	var start_label = Label.new()
	start_label.text = "Press SPACE to start game"
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_label.add_theme_font_size_override("font_size", 32)
	container.add_child(start_label)
	
	# Add to scene
	get_tree().root.add_child(canvas_layer)
	
	# Animation
	container.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(container, "modulate", Color(1, 1, 1, 1), 0.5)
	
	# Make start label blink
	var blink_tween = create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(start_label, "modulate:a", 0.3, 0.7)
	blink_tween.tween_property(start_label, "modulate:a", 1.0, 0.7)
	
	return canvas_layer

# Permanent upgrades system
func drop_permanent_upgrade(position: Vector2):
	# Generate a random permanent upgrade
	var upgrade_types = ["max_health_boost", "damage_boost", "speed_boost"]
	var upgrade_type = upgrade_types[randi() % upgrade_types.size()]
	
	# Create a visible pickup item
	var pickup = Area2D.new()
	pickup.position = position
	
	# Visual representation
	var sprite = Polygon2D.new()
	sprite.polygon = PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)])
	sprite.color = Color(1.0, 0.5, 0.9) # Bright pink for rare items
	pickup.add_child(sprite)
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 15
	collision.shape = shape
	pickup.add_child(collision)
	
	# Add to scene
	get_tree().root.add_child(pickup)
	
	# Store the upgrade type
	pickup.set_meta("upgrade_type", upgrade_type)
	
	# Connect signal
	pickup.body_entered.connect(_on_permanent_upgrade_pickup.bind(pickup, upgrade_type))
	
	# Text popup to show it's rare
	var label = Label.new()
	label.text = "RARE ITEM!"
	label.position = Vector2(-30, -30)
	pickup.add_child(label)

func _on_permanent_upgrade_pickup(body, pickup, upgrade_type):
	if body == self:
		# Apply the permanent upgrade
		match upgrade_type:
			"max_health_boost":
				permanent_upgrades["max_health"] = permanent_upgrades.get("max_health", 0) + 10
				max_health += 10
				health += 10
				health_bar.max_value = max_health
				health_bar.value = health
			"damage_boost":
				permanent_upgrades["damage"] = permanent_upgrades.get("damage", 0) + 5
				melee_damage += 5
			"speed_boost":
				permanent_upgrades["speed"] = permanent_upgrades.get("speed", 0) + 20
				speed += 20
		
		# Remove the pickup
		pickup.queue_free()
		
		# Visual feedback
		if heal_effect:
			heal_effect.emitting = true
		
		# Show notification
		print("Acquired permanent upgrade: " + upgrade_type)

func save_permanent_upgrades():
	# Create a ConfigFile object
	var config = ConfigFile.new()
	
	# Store the values
	config.set_value("permanent_upgrades", "upgrades", permanent_upgrades)
	
	# Save it to a file
	config.save("user://permanent_upgrades.cfg")
	print("Saved permanent upgrades")

func load_permanent_upgrades():
	var config = ConfigFile.new()
	
	# If the file doesn't exist, no need to load it
	if config.load("user://permanent_upgrades.cfg") != OK:
		print("No permanent upgrades file found")
		return
	
	# Load the dictionary of upgrades
	if config.has_section_key("permanent_upgrades", "upgrades"):
		permanent_upgrades = config.get_value("permanent_upgrades", "upgrades")
		
		# Apply the loaded upgrades
		if permanent_upgrades.has("max_health"):
			max_health += permanent_upgrades["max_health"]
			health += permanent_upgrades["max_health"]
			health_bar.max_value = max_health
		
		if permanent_upgrades.has("damage"):
			melee_damage += permanent_upgrades["damage"]
		
		if permanent_upgrades.has("speed"):
			speed += permanent_upgrades["speed"]
		
		print("Loaded permanent upgrades: ", permanent_upgrades)
	else:
		print("No upgrades section in file")

func perform_melee_attack(target_pos: Vector2):
	is_melee_cd = true
	is_performing_melee = true
	melee_timer = 0.0
	
	# Reset hit enemies for new swing
	melee_hit_enemies = []
	
	# Calculate angle for melee attack (toward mouse position)
	melee_angle = (target_pos - global_position).angle()
	
	# Setup the melee swing visuals
	if melee_swing:
		melee_swing.rotation = melee_angle
		melee_swing.visible = true
	
	# Enable the hitbox for collision detection
	if melee_hitbox:
		melee_hitbox.rotation = melee_angle
		melee_hitbox.monitoring = true
	
	# Start cooldown timer
	if melee_timer_node:
		melee_timer_node.start(melee_cooldown)
	
	# Play melee sound
	if audio_player:
		audio_player.pitch_scale = 1.1
		audio_player.play()

func process_melee(delta):
	if is_performing_melee and melee_swing:
		melee_timer += delta
		
		# Simple 3-frame animation (0-0.1s wind up, 0.1-0.2s attack, 0.2-0.5s active)
		if melee_timer < 0.1:
			# Wind up
			melee_swing.scale = Vector2(0.6, 0.6) * (melee_timer / 0.1)
			melee_swing.modulate = Color(1, 1, 1, 0.7)
		elif melee_timer < 0.2:
			# Attack - full extension
			melee_swing.scale = Vector2(1.0, 1.0)
			melee_swing.modulate = Color(1, 1, 1, 1.0)
		elif melee_timer < 0.5: # Extended active time for more hits
			# Keep active
			melee_swing.scale = Vector2(1.0, 1.0)
			melee_swing.modulate = Color(1, 1, 1, 0.8)
		else:
			# End of animation
			is_performing_melee = false
			if melee_swing:
				melee_swing.visible = false
			if melee_hitbox:
				melee_hitbox.monitoring = false

func apply_hit_stop():
	hit_stop_active = true
	hit_stop_timer = hit_stop_duration
	Engine.time_scale = 0.05 # Dramatic slow down
	
	# Schedule the return to normal time
	var timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = hit_stop_duration * 0.05 # Actual real-time wait
	timer.timeout.connect(func(): Engine.time_scale = 1.0; hit_stop_active = false)
	add_child(timer)
	timer.start()
	
	# Play impact effect
	if melee_impact_effect and melee_hitbox:
		melee_impact_effect.global_position = melee_hitbox.global_position
		melee_impact_effect.rotation = melee_angle
		melee_impact_effect.restart()
		melee_impact_effect.emitting = true

func _on_melee_timer_timeout():
	is_melee_cd = false

func _on_melee_hitbox_body_entered(body):
	# Skip if already hit this enemy in current swing
	if body in melee_hit_enemies:
		return
	
	# Also skip if body is invalid
	if not is_instance_valid(body):
		return
	
	if body.is_in_group("enemies") and body.has_method("get_hit") and is_instance_valid(melee_hitbox):
		# Add to list of hit enemies for this swing to prevent multiple hits
		melee_hit_enemies.append(body)
		
		# Calculate hit position for proper transform
		var hit_position = melee_hitbox.global_position + Vector2.RIGHT.rotated(melee_angle) * (melee_range/2)
		var hit_transform = Transform2D(melee_angle, hit_position)
		
		# Apply damage to enemy
		body.get_hit(melee_damage, hit_transform)
		
		# Apply hit stop effect
		apply_hit_stop()
		
		# Visual feedback
		if is_instance_valid(melee_impact_effect):
			melee_impact_effect.global_position = hit_position
			melee_impact_effect.restart()
			melee_impact_effect.emitting = true
			
		# Check for rare item drop (very low chance - 0.5%)
		if randf() < 0.005:
			drop_permanent_upgrade(body.global_position)

# Process additional weapons
func process_weapons(delta):
	# Process orbital projectiles
	if active_weapons.has("orbit"):
		process_orbital_weapons(delta)

func process_orbital_weapons(delta):
	# Update the orbital timer
	orbital_timer += delta
	
	# Get the orbital weapon configuration
	var config = weapon_types["orbit"]
	var level = weapon_levels.get("orbit", 1)
	
	# Calculate the orbit speed - increase with level
	var orbit_speed = config.orbit_speed * (1.0 + (level - 1) * 0.2)
	
	# Determine number of orbital projectiles based on level
	var desired_projectiles = level + 1  # Level 1 = 2 projectiles, Level 2 = 3, etc.
	
	# Spawn new projectiles if needed
	while orbital_projectiles.size() < desired_projectiles:
		spawn_orbital_projectile(config, level)
	
	# Update the position of each orbital projectile
	for i in range(len(orbital_projectiles)):
		if i >= len(orbital_angles):
			continue
			
		# Skip invalid projectiles and remove them from the array
		if not is_instance_valid(orbital_projectiles[i]):
			continue
			
		# Update the angle based on orbit speed
		orbital_angles[i] += orbit_speed * delta
		
		# Calculate the new position
		var orbit_distance = config.orbit_distance * (1.0 + (level - 1) * 0.15) # Increase distance by 15% per level
		var pos = global_position + Vector2(cos(orbital_angles[i]), sin(orbital_angles[i])) * orbit_distance
		
		# Update the projectile position
		orbital_projectiles[i].global_position = pos
		
		# Make the projectile face the direction of movement for better visuals
		if i > 0 and i < len(orbital_angles):
			var prev_angle = orbital_angles[i] - orbit_speed * delta
			var prev_pos = global_position + Vector2(cos(prev_angle), sin(prev_angle)) * orbit_distance
			var direction = (pos - prev_pos).normalized()
			orbital_projectiles[i].rotation = direction.angle()
	
	# Clean up invalid projectiles
	for i in range(len(orbital_projectiles) - 1, -1, -1):
		if not is_instance_valid(orbital_projectiles[i]):
			orbital_projectiles.remove_at(i)
			if i < len(orbital_angles):
				orbital_angles.remove_at(i)
			
	# Check for collisions with enemies - more frequently for better response
	check_orbital_projectile_collisions()

func spawn_orbital_projectile(config, level):
	# Disable orbital projectiles as they look bad on the floor
	return
	
	# Create a new projectile for the orbit
	var bullet
	if bullet_scene is PackedScene:
		bullet = bullet_scene.instantiate()
	else:
		bullet = Area2D.new()
		bullet.set_script(bullet_scene)
	
	# Use the player's position as the base position
	bullet.global_position = global_position
	
	# Set bullet properties
	bullet.modulate = config.color
	if config.has("projectile_scale"):
		bullet.scale = config.projectile_scale
	bullet.damage = int(config.damage * (1.0 + (level - 1) * 0.2)) # 20% damage increase per level
	
	# Disable motion for orbital projectiles
	if bullet.has_method("set_orbital_mode"):
		bullet.set_orbital_mode(true)
	else:
		# If no custom method, just stop normal movement
		bullet.speed = 0
	
	# Add to the scene
	get_tree().root.add_child(bullet)
	
	# Add to our tracking arrays
	orbital_projectiles.append(bullet)
	
	# Calculate starting angle - distribute projectiles evenly
	var base_angle = orbital_timer * 2.0 # Use time for some variation
	var angle_offset = 2 * PI / (len(orbital_projectiles) + level - 1) # Space based on level
	var angle = base_angle + orbital_projectiles.size() * angle_offset
	orbital_angles.append(angle)

func check_orbital_projectile_collisions():
	# For each orbital projectile, check for nearby enemies
	for i in range(len(orbital_projectiles)):
		if i >= len(orbital_projectiles):
			continue
			
		# Skip invalid projectiles
		if not is_instance_valid(orbital_projectiles[i]):
			continue
			
		var bullet = orbital_projectiles[i]
		
		# Get all enemies in range
		var nearby_enemies = []
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsPointQueryParameters2D.new()
		query.position = bullet.global_position
		query.collision_mask = 2 # Enemy collision layer
		query.collide_with_areas = false
		query.collide_with_bodies = true
		
		var result = space_state.intersect_point(query)
		
		# Process collisions
		for collision in result:
			var collider = collision.collider
			if is_instance_valid(collider) and collider.is_in_group("enemies") and collider.has_method("get_hit"):
				# Create transform at hit position
				var hit_transform = Transform2D(0, bullet.global_position)
				
				# Apply damage
				var config = weapon_types["orbit"]
				var level = weapon_levels.get("orbit", 1)
				var damage = int(config.damage * (1.0 + (level - 1) * 0.2))
				collider.get_hit(damage, hit_transform)
				
				# Visual effect for hit
				if melee_impact_effect and is_instance_valid(melee_impact_effect):
					var effect = melee_impact_effect.duplicate()
					effect.global_position = bullet.global_position
					effect.modulate = config.color
					effect.emitting = true
					get_tree().root.add_child(effect)
					
					# Create timer to remove the effect
					var timer = Timer.new()
					timer.wait_time = 1.0
					timer.one_shot = true
					timer.autostart = true
					effect.add_child(timer)
					timer.timeout.connect(func(): effect.queue_free())

func apply_upgrade(upgrade_type, value = 1):
	match upgrade_type:
		# Stat upgrades
		"max_health":
			max_health += int(value)
			health += int(value)
			health_bar.max_value = max_health
			health_bar.value = health
		"speed":
			speed += value
		"damage":
			melee_damage += int(value)
		"fire_rate":
			fire_rate = max(0.05, fire_rate - value) # Cap at minimum 0.05s between shots
			shot_timer.wait_time = fire_rate
		"recoil_control":
			recoil_control = max(0.2, recoil_control - value) # Lower value = better control
		
		# Weapon upgrades
		"add_weapon":
			add_weapon(value) # Here value is the weapon type string
		"upgrade_weapon":
			if typeof(value) == TYPE_STRING and active_weapons.has(value):
				# Increase level of specific weapon
				weapon_levels[value] = weapon_levels.get(value, 1) + 1
			
		# Healing
		"heal":
			heal(int(value))
		
		# Permanent upgrades (saved between runs)
		"permanent_max_health":
			permanent_upgrades["max_health"] = permanent_upgrades.get("max_health", 0) + int(value)
			max_health += int(value)
			health += int(value)
			health_bar.max_value = max_health
			health_bar.value = health
		"permanent_damage":
			permanent_upgrades["damage"] = permanent_upgrades.get("damage", 0) + int(value)
			melee_damage += int(value)
		"permanent_speed":
			permanent_upgrades["speed"] = permanent_upgrades.get("speed", 0) + value
			speed += value
	
	# Visual feedback for upgrade
	if heal_effect:
		heal_effect.modulate = Color(1.0, 0.7, 1.0) # Purple tint for upgrades
		heal_effect.emitting = true

func add_weapon(weapon_type):
	# Check if weapon exists in weapon_types dictionary
	if not weapon_types.has(weapon_type):
		print("ERROR: Weapon type not found: ", weapon_type)
		return
		
	# Check if we already have this weapon
	if active_weapons.has(weapon_type):
		# Upgrade existing weapon instead
		weapon_levels[weapon_type] = weapon_levels.get(weapon_type, 1) + 1
		print("Upgraded weapon: ", weapon_type, " to level ", weapon_levels[weapon_type])
		return
		
	# Check if we've reached maximum weapons
	if active_weapons.size() >= max_weapons:
		print("Maximum weapons reached!")
		return
		
	# Add the weapon
	active_weapons.append(weapon_type)
	weapon_levels[weapon_type] = 1
	weapon_timers[weapon_type] = 0.0 # Start ready to fire
	
	# Visual feedback
	if heal_effect:
		heal_effect.modulate = weapon_types[weapon_type].color
		heal_effect.emitting = true
	
	# Emit signal for UI updates
	emit_signal("weapon_added", weapon_type)
	
	print("Added weapon: ", weapon_type)

func fire_weapon(weapon_type):
	# Ensure weapon exists in the configuration
	if not weapon_types.has(weapon_type):
		print("ERROR: Weapon type not found: ", weapon_type)
		return
	
	# Reset the weapon cooldown - faster firing rate for more fun!
	weapon_timers[weapon_type] = weapon_types[weapon_type].fire_rate * 0.65
	
	# Get the weapon configuration
	var config = weapon_types[weapon_type]
	
	# Apply weapon level scaling if applicable
	var level = weapon_levels.get(weapon_type, 1)
	var damage_multiplier = 1.0 + (level - 1) * 0.3 # 30% damage increase per level
	
	# Add screen shake based on weapon type
	var shake_amount = 0.0
	
	match weapon_type:
		"laser":
			# Create a laser beam projectile with increased scale for impact
			var bullet
			if bullet_scene is PackedScene:
				bullet = bullet_scene.instantiate()
			else:
				bullet = Area2D.new()
				bullet.set_script(bullet_scene)
				
			bullet.setup(bullet_spawn_pos.global_transform)
			bullet.modulate = config.color
			if config.has("projectile_scale"):
				bullet.scale = config.projectile_scale * 1.5 # Bigger bullets!
			bullet.damage = int(config.damage * damage_multiplier)
			bullet.speed = config.projectile_speed * 1.2 # Faster bullets!
			
			# Set pierce property if supported by bullet
			if config.has("pierce"):
				if bullet.has_method("set_pierce"):
					bullet.set_pierce(config.pierce)
				elif "piercing" in bullet:
					bullet.piercing = config.pierce
			
			get_tree().root.add_child(bullet)
			shake_amount = 2.0
			
		"shotgun":
			# Create multiple shotgun pellets with more pellets per level
			var pellet_count = config.projectile_count + (level - 1) * 2
			for i in range(pellet_count):
				var bullet
				if bullet_scene is PackedScene:
					bullet = bullet_scene.instantiate()
				else:
					bullet = Area2D.new()
					bullet.set_script(bullet_scene)
					
				var spread_angle = randf_range(-config.spread, config.spread)
				
				# Create a rotated transform for the bullet
				var rotated_transform = bullet_spawn_pos.global_transform
				rotated_transform = rotated_transform.rotated(deg_to_rad(spread_angle))
				
				bullet.setup(rotated_transform)
				bullet.modulate = config.color
				bullet.damage = int(config.damage * damage_multiplier)
				bullet.speed = config.projectile_speed * randf_range(0.8, 1.2) # Varied speeds
				get_tree().root.add_child(bullet)
			shake_amount = 8.0
				
		"missile":
			# Create a homing missile with explosions
			var bullet
			if bullet_scene is PackedScene:
				bullet = bullet_scene.instantiate()
			else:
				bullet = Area2D.new()
				bullet.set_script(bullet_scene)
				
			bullet.setup(bullet_spawn_pos.global_transform)
			bullet.modulate = config.color
			if config.has("projectile_scale"):
				bullet.scale = config.projectile_scale * 1.3
			bullet.damage = int(config.damage * damage_multiplier * 1.5) # Extra damage!
			bullet.speed = config.projectile_speed
			
			# Add tracking property to the bullet if supported
			if bullet.has_method("set_tracking"):
				bullet.set_tracking(true)
				
			get_tree().root.add_child(bullet)
			shake_amount = 5.0
			
		"lightning":
			# Create a chain lightning projectile with more chains per level
			var bullet
			if bullet_scene is PackedScene:
				bullet = bullet_scene.instantiate()
			else:
				bullet = Area2D.new()
				bullet.set_script(bullet_scene)
				
			bullet.setup(bullet_spawn_pos.global_transform)
			bullet.modulate = config.color
			bullet.damage = int(config.damage * damage_multiplier)
			bullet.speed = config.projectile_speed * 1.3 # Faster lightning!
			
			# Set chain properties if available with increased parameters
			if bullet.has_method("set_chain_properties"):
				var chains = config.chain_count + (level - 1) * 2
				var range = config.chain_range * (1.0 + (level - 1) * 0.3)
				bullet.set_chain_properties(chains, range)
				
			get_tree().root.add_child(bullet)
			shake_amount = 3.0
			
		"orbit":
			# Add a new orbital projectile
			spawn_orbital_projectile(config, level)
			shake_amount = 1.0
	
	# Apply screen shake based on weapon type
	if get_parent().has_method("apply_screen_shake") and shake_amount > 0:
		get_parent().apply_screen_shake(shake_amount, 0.2)
	
	# Play sound effect with random pitch for variety
	if audio_player and not weapon_type == "orbit":
		audio_player.pitch_scale = 1.0 + randf_range(-0.2, 0.2)
		audio_player.play()
	
	# Enhanced visual feedback
	if shot_effect and not weapon_type == "orbit":
		var effect = shot_effect.duplicate()
		effect.global_position = bullet_spawn_pos.global_position
		effect.modulate = config.color
		effect.amount = 15 # More particles!
		effect.emitting = true
		get_tree().current_scene.add_child(effect)
		
		# Auto-remove the effect after it's done
		var timer = Timer.new()
		timer.wait_time = 2.0
		timer.one_shot = true
		timer.autostart = true
		effect.add_child(timer)
		timer.timeout.connect(func(): effect.queue_free())

# Console command methods
func console_reset_player():
	# Reset health
	health = max_health
	health_bar.value = health
	
	# Clear all weapons
	active_weapons = []
	weapon_timers = {}
	weapon_levels = {}
	orbital_projectiles = []
	orbital_angles = []
	
	# Reset modifiers
	speed = 360.0
	invincible = false
	invincible_timer = 0.0
	is_dead = false
	
	# Reset visual state
	modulate.a = 1.0
	
	# Reset position (center of screen)
	position = get_viewport_rect().size / 2
	
	# Reset effects
	if damage_effect:
		damage_effect.emitting = false
	if death_effect:
		death_effect.emitting = false
	if heal_effect:
		heal_effect.emitting = false
		
	# Clear death menu if it exists
	if death_message_instance:
		death_message_instance.queue_free()
		death_message_instance = null
		
	# Restore time scale
	Engine.time_scale = 1.0
	
	return "Player reset complete"

func console_set_health(amount: int):
	health = clamp(amount, 1, max_health)
	health_bar.value = health
	return "Health set to " + str(health)

func console_set_max_health(amount: int):
	max_health = max(amount, 1)
	health_bar.max_value = max_health
	health = max_health
	health_bar.value = health
	return "Max health set to " + str(max_health)

func console_toggle_invincibility():
	invincible = !invincible
	if invincible:
		invincible_timer = 999999.0 # Very long duration
		return "Player invincibility enabled"
	else:
		invincible_timer = 0.0
		modulate.a = 1.0
		return "Player invincibility disabled"

func console_add_weapon(weapon_type: String = ""):
	if weapon_type == "":
		# List available weapons if no type specified
		var weapon_list = ""
		for weapon in weapon_types.keys():
			weapon_list += weapon + ", "
		return "Available weapons: " + weapon_list.trim_suffix(", ")
	
	if weapon_types.has(weapon_type):
		add_weapon(weapon_type)
		return "Added weapon: " + weapon_type
	else:
		return "Invalid weapon type: " + weapon_type
		
func console_upgrade_weapon(weapon_type: String = ""):
	if weapon_type == "":
		# List active weapons if no type specified
		var weapon_list = ""
		for weapon in active_weapons:
			weapon_list += weapon + " (level " + str(weapon_levels.get(weapon, 1)) + "), "
		return "Active weapons: " + (weapon_list.trim_suffix(", ") if weapon_list else "none")
	
	if active_weapons.has(weapon_type):
		weapon_levels[weapon_type] = weapon_levels.get(weapon_type, 1) + 1
		return "Upgraded " + weapon_type + " to level " + str(weapon_levels[weapon_type])
	else:
		return "Weapon not active: " + weapon_type

func console_set_position(x: float = -1, y: float = -1):
	if x < 0 or y < 0:
		return "Current position: " + str(position)
		
	position = Vector2(x, y)
	return "Position set to " + str(position)

func console_kill_all_enemies():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var count = 0
	for enemy in enemies:
		if enemy.has_method("die"):
			enemy.die()
			count += 1
	return "Killed " + str(count) + " enemies"

func console_set_speed(amount: float):
	speed = max(amount, 1.0)
	return "Speed set to " + str(speed)

func register_console_commands():
	# Register player commands with Limbo Console
	LimboConsole.register_command(console_reset_player, "reset_player", "Reset player completely to initial state")
	LimboConsole.register_command(console_set_health, "set_health", "Set player health")
	LimboConsole.register_command(console_set_max_health, "set_max_health", "Set player maximum health")
	LimboConsole.register_command(console_toggle_invincibility, "god", "Toggle player invincibility")
	LimboConsole.register_command(console_add_weapon, "add_weapon", "Add a weapon to the player")
	LimboConsole.register_command(console_upgrade_weapon, "upgrade_weapon", "Upgrade a player weapon")
	LimboConsole.register_command(console_set_position, "set_position", "Set player position")
	LimboConsole.register_command(console_kill_all_enemies, "kill_all", "Kill all enemies in the scene")
	LimboConsole.register_command(console_set_speed, "set_speed", "Set player movement speed")

# Create a fallback bullet class
func _create_fallback_bullet():
	# Create a custom script class for bullets
	var script = GDScript.new()
	script.source_code = """
extends Area2D

var velocity = Vector2(1, 0)
var speed = 500
var damage = 10

func _init():
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 5
	collision.shape = shape
	add_child(collision)
	
	# Add visual
	var polygon = Polygon2D.new()
	polygon.polygon = PackedVector2Array([Vector2(-5, -2), Vector2(5, -2), Vector2(5, 2), Vector2(-5, 2)])
	polygon.color = Color(1, 0.7, 0.2)
	add_child(polygon)

func _ready():
	add_to_group("projectiles")

func setup(transform):
	global_transform = transform
	velocity = transform.x.normalized()
	rotation = velocity.angle()

func _physics_process(delta):
	position += velocity * speed * delta
	
	# Auto destroy bullets that go too far off screen
	if position.length() > 2000:
		queue_free()

func set_tracking(value):
	pass

func set_chain_properties(chains, range_val):
	pass

func set_pierce(value):
	pass

func set_orbital_mode(value):
	speed = 0
"""
	
	script.reload()
	
	# Return the script as our bullet "scene"
	return script
