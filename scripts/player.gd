extends CharacterBody2D

signal player_died
signal player_damaged(amount)
signal player_healed(amount)
signal player_level_up(level)
signal weapon_added(weapon_type)
signal pause_toggled(is_paused)

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

# This goes with the other variables
var pause_menu_scene = preload("res://scenes/pause_menu.tscn")
var pause_menu_instance = null
var post_processing_scene = preload("res://scenes/post_processing.tscn")
var post_processing_instance = null
var upgrade_menu_instance = null

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

	# Setup pause menu
	pause_menu_instance = pause_menu_scene.instantiate()
	add_child(pause_menu_instance)
	pause_menu_instance.visible = false
	
	# Setup post-processing effects
	setup_post_processing()

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
	
	# Toggle pause on Escape key press	
	if event.is_action_pressed("ui_cancel"):
		var is_paused = pause_menu_instance.toggle_pause()
		emit_signal("pause_toggled", is_paused)
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
		
	# Add post-processing flash effect
	if post_processing_instance and is_instance_valid(post_processing_instance):
		post_processing_instance.increase_intensity(0.15, 0.3)
		post_processing_instance.add_light_flash(bullet_spawn_pos.global_position, 
			Color(1.0, 0.7, 0.2, 0.8), 0.4)

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
	
	# Add post-processing damage effects
	if post_processing_instance and is_instance_valid(post_processing_instance):
		# Intensify effects when taking damage
		post_processing_instance.increase_intensity(0.4, 0.5)
		# Add red flash at the player position
		post_processing_instance.add_light_flash(global_position, 
			Color(1.0, 0.1, 0.1, 0.9), 0.7)
	
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
	
	# Add dramatic post-processing death effects
	if post_processing_instance and is_instance_valid(post_processing_instance):
		# Maximum intensity for death
		post_processing_instance.set_intensity(2.0)
		# Add dramatic light flash
		post_processing_instance.add_light_flash(global_position, 
			Color(1.0, 0.0, 0.0, 1.0), 3.0)
	
	# Emit death signal
	emit_signal("player_died")

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
	
	# Create animated background with gradient
	var background = ColorRect.new()
	background.color = Color(0.05, 0.0, 0.12, 0.9) # Dark purple background
	background.anchors_preset = Control.PRESET_FULL_RECT
	canvas_layer.add_child(background)
	
	# Add particle effect for background
	var bg_particles = CPUParticles2D.new()
	bg_particles.amount = 100
	bg_particles.lifetime = 4.0
	bg_particles.explosiveness = 0.0
	bg_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bg_particles.emission_rect_extents = Vector2(get_viewport_rect().size.x/2, get_viewport_rect().size.y/2)
	bg_particles.gravity = Vector2(0, -20)
	bg_particles.initial_velocity_min = 10
	bg_particles.initial_velocity_max = 30
	bg_particles.scale_amount_min = 1.0
	bg_particles.scale_amount_max = 3.0
	bg_particles.color = Color(0.6, 0.4, 1.0, 0.3)
	bg_particles.position = get_viewport_rect().size / 2
	canvas_layer.add_child(bg_particles)
	
	# Create main container
	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.size = Vector2(600, 400)
	container.position = Vector2(-300, -200)
	canvas_layer.add_child(container)
	
	# Add "MAIN MENU" text at the top
	var menu_label = Label.new()
	menu_label.text = "MAIN MENU"
	menu_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_label.add_theme_font_size_override("font_size", 24)
	menu_label.add_theme_color_override("font_color", Color(0.9, 0.7, 1.0))
	container.add_child(menu_label)
	
	# Add a small separator
	var separator = ColorRect.new()
	separator.color = Color(0.6, 0.3, 0.9, 0.6)
	separator.custom_minimum_size = Vector2(200, 2)
	separator.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(separator)
	
	# Small spacing
	var small_spacer = Control.new()
	small_spacer.custom_minimum_size = Vector2(0, 20)
	container.add_child(small_spacer)
	
	# Title with stylish outline effect
	var title_container = CenterContainer.new()
	title_container.use_top_left = false
	container.add_child(title_container)
	
	# Shadow/glow effect for title
	var title_shadow = Label.new()
	title_shadow.text = "TOPIS"
	title_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_shadow.add_theme_font_size_override("font_size", 96)
	title_shadow.add_theme_color_override("font_color", Color(0.6, 0.2, 0.8, 0.6))
	title_shadow.position = Vector2(4, 4)
	title_container.add_child(title_shadow)
	
	# Main title
	var title = Label.new()
	title.text = "TOPIS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.9))
	title_container.add_child(title)
	
	# Add subtitle
	var subtitle = Label.new()
	subtitle.text = "THE EPIC SURVIVAL ADVENTURE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.5, 0.5))
	container.add_child(subtitle)
	
	# Spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 50)
	container.add_child(spacer)
	
	# Create a stylish button-like frame for the start text
	var button_frame = ColorRect.new()
	button_frame.color = Color(0.4, 0.2, 0.6, 0.6)
	button_frame.custom_minimum_size = Vector2(350, 60)
	button_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	container.add_child(button_frame)
	
	# Start game instruction
	var start_label = Label.new()
	start_label.text = "PRESS SPACE TO BEGIN"
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	start_label.add_theme_font_size_override("font_size", 32)
	start_label.add_theme_color_override("font_color", Color(1.0, 0.9, 1.0))
	start_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button_frame.add_child(start_label)
	
	# Version info at bottom
	var version_label = Label.new()
	version_label.text = "v1.0 - EPIC EDITION"
	version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version_label.add_theme_font_size_override("font_size", 16)
	version_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	version_label.position.y = 50
	container.add_child(version_label)
	
	# Add to scene
	get_tree().root.add_child(canvas_layer)
	
	# Create dynamic UI elements - rotating stars in the background
	for i in range(20):
		var star = Polygon2D.new()
		var points = []
		var outer_radius = randf_range(5, 15)
		var inner_radius = outer_radius * 0.4
		for j in range(10):
			var radius = outer_radius if j % 2 == 0 else inner_radius
			var angle = j * PI / 5
			points.append(Vector2(cos(angle), sin(angle)) * radius)
		star.polygon = PackedVector2Array(points)
		star.color = Color(randf_range(0.7, 1.0), randf_range(0.7, 1.0), randf_range(0.7, 1.0), randf_range(0.4, 0.8))
		star.position = Vector2(randf_range(0, get_viewport_rect().size.x), randf_range(0, get_viewport_rect().size.y))
		canvas_layer.add_child(star)
		
		# Animate the star
		var rotation_tween = create_tween()
		rotation_tween.set_loops()
		rotation_tween.tween_property(star, "rotation", TAU, randf_range(3.0, 8.0))
		
		# Also make it pulse
		var scale_tween = create_tween()
		scale_tween.set_loops()
		scale_tween.tween_property(star, "scale", Vector2(1.5, 1.5), randf_range(1.0, 3.0))
		scale_tween.tween_property(star, "scale", Vector2(1.0, 1.0), randf_range(1.0, 3.0))
	
	# Dramatic entrance animation
	container.scale = Vector2(0.5, 0.5)
	container.modulate = Color(1, 1, 1, 0)
	
	var entrance_tween = create_tween()
	entrance_tween.tween_property(container, "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT)
	entrance_tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_IN)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(container, "modulate", Color(1, 1, 1, 1), 0.7)
	
	# Title pulsing effect
	var title_tween = create_tween()
	title_tween.set_loops()
	title_tween.tween_property(title, "modulate", Color(1.0, 0.6, 1.0), 2.0)
	title_tween.tween_property(title, "modulate", Color(1.0, 1.0, 1.0), 2.0)
	
	# Make start button pulse with a more dramatic effect
	var button_tween = create_tween()
	button_tween.set_loops()
	button_tween.tween_property(button_frame, "color", Color(0.6, 0.3, 0.9, 0.8), 0.8)
	button_tween.tween_property(button_frame, "color", Color(0.4, 0.2, 0.6, 0.6), 0.8)
	
	# Make start label blink with a cooler effect
	var blink_tween = create_tween()
	blink_tween.set_loops()
	blink_tween.tween_property(start_label, "modulate:a", 0.7, 0.5)
	blink_tween.tween_property(start_label, "modulate:a", 1.0, 0.5)
	
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
	# This function is now disabled to prevent performance drops
	pass
	# Original code commented out for reference
	# hit_stop_active = true
	# hit_stop_timer = hit_stop_duration
	# Engine.time_scale = 0.05 # Dramatic slow down
	# 
	# # Schedule the return to normal time
	# var timer = Timer.new()
	# timer.one_shot = true
	# timer.wait_time = hit_stop_duration * 0.05 # Actual real-time wait
	# timer.timeout.connect(func(): Engine.time_scale = 1.0; hit_stop_active = false)
	# add_child(timer)
	# timer.start()
	# 
	# # Play impact effect
	# if melee_impact_effect and melee_hitbox:
	#     melee_impact_effect.global_position = melee_hitbox.global_position
	#     melee_impact_effect.rotation = melee_angle
	#     melee_impact_effect.restart()
	#     melee_impact_effect.emitting = true

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
		
		# Remove hit stop for better performance
		# apply_hit_stop()
		
		# Minimal visual feedback
		if is_instance_valid(melee_impact_effect):
			melee_impact_effect.global_position = hit_position
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
		
		# Process collisions - optimize by limiting per frame
		var hit_count = 0
		for collision in result:
			# Limit hits per frame to 2 for better performance
			hit_count += 1
			if hit_count > 2:
				break
				
			var collider = collision.collider
			if is_instance_valid(collider) and collider.is_in_group("enemies") and collider.has_method("get_hit"):
				# Create transform at hit position
				var hit_transform = Transform2D(0, bullet.global_position)
				
				# Apply damage
				var config = weapon_types["orbit"]
				var level = weapon_levels.get("orbit", 1)
				var damage = int(config.damage * (1.0 + (level - 1) * 0.2))
				collider.get_hit(damage, hit_transform)
				
				# Minimal visual effect for hit
				if melee_impact_effect and is_instance_valid(melee_impact_effect):
					var effect = melee_impact_effect.duplicate()
					effect.global_position = bullet.global_position
					effect.modulate = config.color
					effect.emitting = true
					get_tree().root.call_deferred("add_child", effect)
					
					# Create timer to remove the effect
					var timer = Timer.new()
					timer.wait_time = 0.5  # Shorter duration
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

# Add this new function to set up post-processing effects
func setup_post_processing():
	# Check if post-processing scene exists
	if not FileAccess.file_exists("res://scenes/post_processing.tscn"):
		printerr("Post-processing scene not found!")
		return
	
	# Create post-processing instance and add it to the main scene
	post_processing_instance = post_processing_scene.instantiate()
	get_tree().root.add_child(post_processing_instance)
	
	# Make sure it's always the last layer for proper rendering
	post_processing_instance.layer = 10

# Replace this section with the new stunning upgrade menu implementation
func show_upgrade_menu(available_upgrades = null):
	# Create a canvas layer for the upgrade menu
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	canvas_layer.name = "UpgradeMenuLayer"
	
	# Create animated background
	var background = ColorRect.new()
	background.color = Color(0.05, 0.0, 0.12, 0.9) # Dark purple background
	background.anchors_preset = Control.PRESET_FULL_RECT
	canvas_layer.add_child(background)
	
	# Create fancy background grid
	var grid = create_grid_background()
	grid.anchors_preset = Control.PRESET_FULL_RECT
	canvas_layer.add_child(grid)
	
	# Create main container
	var container = VBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.size = Vector2(700, 500)
	container.position = Vector2(-350, -250)
	canvas_layer.add_child(container)
	
	# Create fancy title with glow effect
	var title_container = CenterContainer.new()
	title_container.use_top_left = false
	container.add_child(title_container)
	
	# Shadow/glow effect for title
	var title_panel = PanelContainer.new()
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.2, 0.05, 0.3, 0.7)
	title_style.border_width_left = 2
	title_style.border_width_top = 2
	title_style.border_width_right = 2
	title_style.border_width_bottom = 2
	title_style.border_color = Color(0.7, 0.3, 1.0)
	title_style.corner_radius_top_left = 15
	title_style.corner_radius_top_right = 15
	title_style.corner_radius_bottom_left = 15
	title_style.corner_radius_bottom_right = 15
	title_style.expand_margin_left = 20
	title_style.expand_margin_top = 10
	title_style.expand_margin_right = 20
	title_style.expand_margin_bottom = 10
	title_panel.add_theme_stylebox_override("panel", title_style)
	title_container.add_child(title_panel)
	
	# Title text
	var title_margin = MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", 20)
	title_margin.add_theme_constant_override("margin_right", 20)
	title_margin.add_theme_constant_override("margin_top", 10)
	title_margin.add_theme_constant_override("margin_bottom", 10)
	title_panel.add_child(title_margin)
	
	var title = Label.new()
	title.text = "LEVEL UP!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.9, 0.3, 0.9))
	title_margin.add_child(title)
	
	# Add subtitle
	var subtitle_container = CenterContainer.new()
	container.add_child(subtitle_container)
	
	var subtitle_panel = PanelContainer.new()
	var subtitle_style = StyleBoxFlat.new()
	subtitle_style.bg_color = Color(0.15, 0.05, 0.25, 0.6)
	subtitle_style.border_width_left = 1
	subtitle_style.border_width_top = 1
	subtitle_style.border_width_right = 1
	subtitle_style.border_width_bottom = 1
	subtitle_style.border_color = Color(0.6, 0.2, 0.8)
	subtitle_style.corner_radius_top_left = 8
	subtitle_style.corner_radius_top_right = 8
	subtitle_style.corner_radius_bottom_left = 8
	subtitle_style.corner_radius_bottom_right = 8
	subtitle_style.expand_margin_left = 10
	subtitle_style.expand_margin_top = 5
	subtitle_style.expand_margin_right = 10
	subtitle_style.expand_margin_bottom = 5
	subtitle_panel.add_theme_stylebox_override("panel", subtitle_style)
	subtitle_container.add_child(subtitle_panel)
	
	var subtitle_margin = MarginContainer.new()
	subtitle_margin.add_theme_constant_override("margin_left", 10)
	subtitle_margin.add_theme_constant_override("margin_right", 10)
	subtitle_margin.add_theme_constant_override("margin_top", 5)
	subtitle_margin.add_theme_constant_override("margin_bottom", 5)
	subtitle_panel.add_child(subtitle_margin)
	
	var subtitle = Label.new()
	subtitle.text = "CHOOSE YOUR UPGRADE"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.5, 0.9))
	subtitle_margin.add_child(subtitle)
	
	# Spacing
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	container.add_child(spacer)
	
	# Create upgrade options container with better styling
	var options_container = HBoxContainer.new()
	options_container.alignment = BoxContainer.ALIGNMENT_CENTER
	options_container.size_flags_horizontal = Control.SIZE_FILL
	options_container.custom_minimum_size = Vector2(0, 320)
	container.add_child(options_container)
	
	# Define available upgrades if not provided
	if available_upgrades == null:
		available_upgrades = [
			{
				"type": "max_health",
				"value": 20,
				"name": "Max Health",
				"description": "Increase maximum health by 20 points. Survive longer against waves of enemies!",
				"icon_color": Color(1.0, 0.3, 0.3),
				"border_color": Color(1.0, 0.5, 0.5),
				"bg_color": Color(0.5, 0.1, 0.1, 0.8)
			},
			{
				"type": "damage",
				"value": 10,
				"name": "Attack Power",
				"description": "Increase melee damage by 10 points. Destroy enemies faster with your powerful strikes!",
				"icon_color": Color(1.0, 0.7, 0.2),
				"border_color": Color(1.0, 0.8, 0.3),
				"bg_color": Color(0.5, 0.3, 0.1, 0.8)
			},
			{
				"type": "speed",
				"value": 30,
				"name": "Movement Speed",
				"description": "Increase movement speed by 30 points. Dash through the battlefield with lightning speed!",
				"icon_color": Color(0.2, 0.8, 0.6),
				"border_color": Color(0.3, 0.9, 0.7),
				"bg_color": Color(0.1, 0.4, 0.3, 0.8)
			}
		]
		
		# Add weapon upgrades if we have space
		if active_weapons.size() < max_weapons:
			# Add a random weapon from available types that player doesn't have yet
			var available_weapon_types = []
			for weapon_type in weapon_types.keys():
				if not active_weapons.has(weapon_type):
					available_weapon_types.append(weapon_type)
			
			if available_weapon_types.size() > 0:
				var random_weapon = available_weapon_types[randi() % available_weapon_types.size()]
				available_upgrades.append({
					"type": "add_weapon",
					"value": random_weapon,
					"name": weapon_types[random_weapon].name,
					"description": "New weapon: " + weapon_types[random_weapon].name + ". Add a powerful new weapon to your arsenal!",
					"icon_color": weapon_types[random_weapon].color,
					"border_color": weapon_types[random_weapon].color.lightened(0.3),
					"bg_color": weapon_types[random_weapon].color.darkened(0.5).lerp(Color(0.1, 0.1, 0.2), 0.5)
				})
		
		# Add weapon level up option for an existing weapon
		if active_weapons.size() > 0:
			var random_active_weapon = active_weapons[randi() % active_weapons.size()]
			available_upgrades.append({
				"type": "upgrade_weapon",
				"value": random_active_weapon,
				"name": "Upgrade " + weapon_types[random_active_weapon].name,
				"description": "Increase the power of your " + weapon_types[random_active_weapon].name + ". Make it even more devastating!",
				"icon_color": weapon_types[random_active_weapon].color,
				"border_color": weapon_types[random_active_weapon].color.lightened(0.3),
				"bg_color": weapon_types[random_active_weapon].color.darkened(0.5).lerp(Color(0.1, 0.1, 0.2), 0.5)
			})
	
	# Shuffle upgrades and pick 3
	available_upgrades.shuffle()
	var display_upgrades = available_upgrades.slice(0, min(3, available_upgrades.size()))
	
	# Create option cards with better styling
	for upgrade in display_upgrades:
		var card_container = MarginContainer.new()
		card_container.add_theme_constant_override("margin_left", 10)
		card_container.add_theme_constant_override("margin_right", 10)
		card_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_container.custom_minimum_size = Vector2(200, 320)
		
		var card = PanelContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_container.add_child(card)
		
		# Add stylish card background
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = upgrade.get("bg_color", Color(0.15, 0.1, 0.2, 0.8))
		card_style.border_width_left = 3
		card_style.border_width_top = 3
		card_style.border_width_right = 3
		card_style.border_width_bottom = 3
		card_style.border_color = upgrade.get("border_color", Color(0.6, 0.3, 0.9))
		card_style.corner_radius_top_left = 15
		card_style.corner_radius_top_right = 15
		card_style.corner_radius_bottom_left = 15
		card_style.corner_radius_bottom_right = 15
		card_style.shadow_color = Color(0, 0, 0, 0.5)
		card_style.shadow_size = 6
		card_style.shadow_offset = Vector2(2, 2)
		card.add_theme_stylebox_override("panel", card_style)
		
		# Add margin container for content
		var margin = MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 15)
		margin.add_theme_constant_override("margin_top", 15)
		margin.add_theme_constant_override("margin_right", 15)
		margin.add_theme_constant_override("margin_bottom", 15)
		card.add_child(margin)
		
		# Add vertical layout for card content
		var card_content = VBoxContainer.new()
		margin.add_child(card_content)
		
		# Add header with icon 
		var header_panel = PanelContainer.new()
		var header_style = StyleBoxFlat.new()
		header_style.bg_color = upgrade.icon_color.darkened(0.5)
		header_style.border_width_left = 2
		header_style.border_width_top = 2
		header_style.border_width_right = 2
		header_style.border_width_bottom = 2
		header_style.border_color = upgrade.icon_color
		header_style.corner_radius_top_left = 10
		header_style.corner_radius_top_right = 10
		header_style.corner_radius_bottom_left = 10
		header_style.corner_radius_bottom_right = 10
		header_panel.add_theme_stylebox_override("panel", header_style)
		header_panel.custom_minimum_size = Vector2(0, 100)
		card_content.add_child(header_panel)
		
		# Create icon container
		var icon_container = CenterContainer.new()
		header_panel.add_child(icon_container)
		
		# Create icon using TextureRect with custom textures
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(70, 70)
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		# Create different icons based on upgrade type
		var icon_texture
		match upgrade.type:
			"max_health":
				icon_texture = create_heart_icon(upgrade.icon_color)
			"damage":
				icon_texture = create_sword_icon(upgrade.icon_color)
			"speed":
				icon_texture = create_lightning_icon(upgrade.icon_color)
			"add_weapon", "upgrade_weapon":
				icon_texture = create_star_icon(upgrade.icon_color)
			_:
				icon_texture = create_generic_icon(upgrade.icon_color)
		
		icon.texture = icon_texture
		icon_container.add_child(icon)
		
		# Add title with better styling
		var title_box = PanelContainer.new()
		var title_box_style = StyleBoxFlat.new()
		title_box_style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
		title_box_style.border_width_left = 1
		title_box_style.border_width_top = 1
		title_box_style.border_width_right = 1
		title_box_style.border_width_bottom = 1
		title_box_style.border_color = upgrade.icon_color.darkened(0.3)
		title_box_style.corner_radius_top_left = 5
		title_box_style.corner_radius_top_right = 5
		title_box_style.corner_radius_bottom_left = 5
		title_box_style.corner_radius_bottom_right = 5
		title_box.add_theme_stylebox_override("panel", title_box_style)
		card_content.add_child(title_box)
		
		var card_title_margin = MarginContainer.new()
		card_title_margin.add_theme_constant_override("margin_left", 10)
		card_title_margin.add_theme_constant_override("margin_right", 10)
		card_title_margin.add_theme_constant_override("margin_top", 5)
		card_title_margin.add_theme_constant_override("margin_bottom", 5)
		title_box.add_child(card_title_margin)
		
		var card_title = Label.new()
		card_title.text = upgrade.name.to_upper()
		card_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_title.add_theme_font_size_override("font_size", 18)
		card_title.add_theme_color_override("font_color", upgrade.icon_color)
		card_title_margin.add_child(card_title)
		
		# Add small spacer
		var mini_spacer = Control.new()
		mini_spacer.custom_minimum_size = Vector2(0, 10)
		card_content.add_child(mini_spacer)
		
		# Add description with better styling
		var desc_panel = PanelContainer.new()
		var desc_style = StyleBoxFlat.new()
		desc_style.bg_color = Color(0.1, 0.1, 0.15, 0.6)
		desc_style.corner_radius_top_left = 5
		desc_style.corner_radius_top_right = 5
		desc_style.corner_radius_bottom_left = 5
		desc_style.corner_radius_bottom_right = 5
		desc_panel.add_theme_stylebox_override("panel", desc_style)
		desc_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_content.add_child(desc_panel)
		
		var desc_margin = MarginContainer.new()
		desc_margin.add_theme_constant_override("margin_left", 10)
		desc_margin.add_theme_constant_override("margin_right", 10)
		desc_margin.add_theme_constant_override("margin_top", 5)
		desc_margin.add_theme_constant_override("margin_bottom", 5)
		desc_panel.add_child(desc_margin)
		
		var description = Label.new()
		description.text = upgrade.description
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 14)
		description.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_margin.add_child(description)
		
		# Add small spacer
		var mini_spacer2 = Control.new()
		mini_spacer2.custom_minimum_size = Vector2(0, 10)
		card_content.add_child(mini_spacer2)
		
		# Add select button with better styling
		var button_panel = PanelContainer.new()
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = upgrade.icon_color.darkened(0.4)
		button_style.border_width_left = 2
		button_style.border_width_top = 2
		button_style.border_width_right = 2
		button_style.border_width_bottom = 2
		button_style.border_color = upgrade.icon_color.darkened(0.2)
		button_style.corner_radius_top_left = 10
		button_style.corner_radius_top_right = 10
		button_style.corner_radius_bottom_left = 10
		button_style.corner_radius_bottom_right = 10
		button_panel.add_theme_stylebox_override("panel", button_style)
		card_content.add_child(button_panel)
		
		var select_button = Button.new()
		select_button.text = "SELECT"
		select_button.flat = true
		select_button.custom_minimum_size = Vector2(0, 40)
		
		# Style the button
		select_button.add_theme_font_size_override("font_size", 18)
		select_button.add_theme_color_override("font_color", Color(1, 1, 1))
		select_button.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		select_button.add_theme_color_override("font_focus_color", Color(1, 1, 1))
		select_button.add_theme_color_override("font_pressed_color", upgrade.icon_color.darkened(0.2))
		button_panel.add_child(select_button)
		
		# Connect button press to apply upgrade
		select_button.pressed.connect(func():
			apply_upgrade(upgrade.type, upgrade.value)
			
			# Play sound effect if available
			if audio_player:
				audio_player.pitch_scale = 0.8
				audio_player.play()
			
			# Apply powerful visual effect on selection
			var flash = ColorRect.new()
			flash.color = upgrade.icon_color
			flash.color.a = 0.0
			flash.anchors_preset = Control.PRESET_FULL_RECT
			canvas_layer.add_child(flash)
			
			var flash_tween = create_tween()
			
			flash_tween.tween_property(flash, "color:a", 0.7, 0.2)
			flash_tween.tween_property(flash, "color:a", 0.0, 0.5)
			flash_tween.tween_callback(func(): 
				canvas_layer.queue_free()
				get_tree().paused = false
			)
		)
		
		options_container.add_child(card_container)
		
		# Create card hover effects
		card.mouse_entered.connect(func():
			var hover_tween = create_tween()
			hover_tween.tween_property(card_container, "position:y", -15, 0.2).set_ease(Tween.EASE_OUT)
			
			# Intensify glow
			var glow_tween = create_tween()
			glow_tween.tween_property(card_style, "border_width_left", 4, 0.2)
			glow_tween.parallel().tween_property(card_style, "border_width_top", 4, 0.2)
			glow_tween.parallel().tween_property(card_style, "border_width_right", 4, 0.2)
			glow_tween.parallel().tween_property(card_style, "border_width_bottom", 4, 0.2)
			glow_tween.parallel().tween_property(card_style, "shadow_size", 10, 0.2)
			
			# Update button style
			button_style.bg_color = upgrade.icon_color.darkened(0.2)
		)
		
		card.mouse_exited.connect(func():
			var exit_tween = create_tween()
			exit_tween.tween_property(card_container, "position:y", 0, 0.2).set_ease(Tween.EASE_IN)
			
			# Reset glow
			var glow_tween = create_tween()
			glow_tween.tween_property(card_style, "border_width_left", 3, 0.2)
			glow_tween.parallel().tween_property(card_style, "border_width_top", 3, 0.2)
			glow_tween.parallel().tween_property(card_style, "border_width_right", 3, 0.2)
			glow_tween.parallel().tween_property(card_style, "border_width_bottom", 3, 0.2)
			glow_tween.parallel().tween_property(card_style, "shadow_size", 6, 0.2)
			
			# Reset button style
			button_style.bg_color = upgrade.icon_color.darkened(0.4)
		)
	
	# Add animated particles at the bottom
	var particles_container = Control.new()
	particles_container.custom_minimum_size = Vector2(0, 50)
	container.add_child(particles_container)
	
	var bottom_particles = CPUParticles2D.new()
	bottom_particles.amount = 30
	bottom_particles.lifetime = 2.0
	bottom_particles.explosiveness = 0.0
	bottom_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	bottom_particles.emission_rect_extents = Vector2(350, 10)
	bottom_particles.direction = Vector2(0, -1)
	bottom_particles.spread = 30
	bottom_particles.gravity = Vector2(0, -20)
	bottom_particles.initial_velocity_min = 10
	bottom_particles.initial_velocity_max = 30
	bottom_particles.scale_amount_min = 1.0
	bottom_particles.scale_amount_max = 3.0
	bottom_particles.color = Color(0.6, 0.4, 1.0, 0.3)
	bottom_particles.position = Vector2(350, 25)
	particles_container.add_child(bottom_particles)
	
	# Dramatic entrance animation
	container.scale = Vector2(0.5, 0.5)
	container.modulate = Color(1, 1, 1, 0)
	
	var entrance_tween = create_tween()
	entrance_tween.tween_property(container, "scale", Vector2(1.1, 1.1), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	entrance_tween.tween_property(container, "scale", Vector2(1.0, 1.0), 0.3).set_ease(Tween.EASE_IN_OUT)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(container, "modulate", Color(1, 1, 1, 1), 0.7)
	
	# Store reference to menu and pause game
	upgrade_menu_instance = canvas_layer
	get_tree().paused = true
	
	# Add to scene
	get_tree().root.add_child(canvas_layer)
	
	return canvas_layer

# Create a fancy grid background
func create_grid_background() -> Control:
	var control = Control.new()
	
	# Create parent node with drawing functionality
	var grid_node = Node2D.new()
	control.add_child(grid_node)
	
	# Connect the draw signal to avoid drawing outside _draw() 
	grid_node.connect("draw", grid_draw_function)
	
	# Setup the control to fill the screen
	control.custom_minimum_size = get_viewport_rect().size
	
	return control

# Function that will be called during the draw cycle
func grid_draw_function(node):
	# Grid properties
	var cell_size = 50
	var viewport_size = get_viewport_rect().size
	var grid_color = Color(0.4, 0.2, 0.6, 0.2)
	
	# Draw horizontal lines
	for y in range(0, int(viewport_size.y) + cell_size, cell_size):
		node.draw_line(Vector2(0, y), Vector2(viewport_size.x, y), grid_color, 1.0)
	
	# Draw vertical lines
	for x in range(0, int(viewport_size.x) + cell_size, cell_size):
		node.draw_line(Vector2(x, 0), Vector2(x, viewport_size.y), grid_color, 1.0)

# Create textures for the icons using proper generation methods
func create_heart_icon(color: Color) -> Texture2D:
	# Create an image with transparent background
	var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Create a heart shape
	var center_x = 50
	var center_y = 50
	var size = 40
	
	# Draw the heart using proper methods
	for x in range(100):
		for y in range(100):
			var dx = (x - center_x) / size
			var dy = (y - center_y) / size
			
			# Heart formula
			if (pow(dx, 2) + pow(dy - 0.35, 2) * 1.3 < 0.5) or \
			   (pow(dx - 0.5, 2) + pow(dy + 0.25, 2) < 0.3) or \
			   (pow(dx + 0.5, 2) + pow(dy + 0.25, 2) < 0.3):
				img.set_pixel(x, y, color)
	
	# Create an ImageTexture from the image
	var texture = ImageTexture.create_from_image(img)
	return texture

func create_sword_icon(color: Color) -> Texture2D:
	# Create an image with transparent background
	var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Create a sword shape
	var center_x = 50
	var center_y = 50
	
	# Draw the sword blade
	for y in range(20, 80):
		var blade_width = 6 if y > 65 else 3
		for x in range(center_x - blade_width, center_x + blade_width):
			img.set_pixel(x, y, color)
	
	# Draw the sword handle
	for y in range(70, 85):
		for x in range(center_x - 15, center_x + 15):
			if x > center_x - 15 and x < center_x + 15 and y > 70 and y < 80:
				img.set_pixel(x, y, color.darkened(0.3))
	
	# Draw the sword guard
	for y in range(65, 72):
		for x in range(center_x - 15, center_x + 15):
			img.set_pixel(x, y, color.lightened(0.2))
	
	# Create an ImageTexture from the image
	var texture = ImageTexture.create_from_image(img)
	return texture

func create_lightning_icon(color: Color) -> Texture2D:
	# Create an image with transparent background
	var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Lightning bolt points
	var points = [
		Vector2(45, 20),
		Vector2(60, 40),
		Vector2(50, 45),
		Vector2(65, 70),
		Vector2(55, 75),
		Vector2(70, 95),
		Vector2(40, 65),
		Vector2(50, 60),
		Vector2(35, 35),
		Vector2(45, 20)
	]
	
	# Fill the lightning bolt
	for x in range(100):
		for y in range(100):
			var point = Vector2(x, y)
			var inside = Geometry2D.is_point_in_polygon(point, points)
			if inside:
				img.set_pixel(x, y, color)
	
	# Create an ImageTexture from the image
	var texture = ImageTexture.create_from_image(img)
	return texture

func create_star_icon(color: Color) -> Texture2D:
	# Create an image with transparent background
	var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Star parameters
	var center_x = 50
	var center_y = 50
	var outer_radius = 40
	var inner_radius = 15
	var points = 5
	
	# Create a star shape
	var star_points = []
	for i in range(points * 2):
		var radius = outer_radius if i % 2 == 0 else inner_radius
		var angle = i * PI / points
		star_points.append(Vector2(
			center_x + cos(angle) * radius,
			center_y + sin(angle) * radius
		))
	
	# Fill the star
	for x in range(100):
		for y in range(100):
			var point = Vector2(x, y)
			var inside = Geometry2D.is_point_in_polygon(point, star_points)
			if inside:
				img.set_pixel(x, y, color)
	
	# Create an ImageTexture from the image
	var texture = ImageTexture.create_from_image(img)
	return texture

func create_generic_icon(color: Color) -> Texture2D:
	# Create an image with transparent background
	var img = Image.create(100, 100, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Create a diamond shape
	var center_x = 50
	var center_y = 50
	var size = 35
	
	# Create diamond points
	var diamond_points = [
		Vector2(center_x, center_y - size),
		Vector2(center_x + size, center_y),
		Vector2(center_x, center_y + size),
		Vector2(center_x - size, center_y)
	]
	
	# Fill the diamond
	for x in range(100):
		for y in range(100):
			var point = Vector2(x, y)
			var inside = Geometry2D.is_point_in_polygon(point, diamond_points)
			if inside:
				img.set_pixel(x, y, color)
	
	# Create an ImageTexture from the image
	var texture = ImageTexture.create_from_image(img)
	return texture

# This shows how to trigger the menu - could be called when player levels up
func trigger_upgrade_menu():
	if is_dead:
		return
		
	# Create upgrade options
	var upgrades = [
		{
			"type": "max_health",
			"value": 20,
			"name": "Max Health",
			"description": "Increase maximum health by 20",
			"icon_color": Color(1.0, 0.3, 0.3)
		},
		{
			"type": "damage",
			"value": 10,
			"name": "Attack Power",
			"description": "Increase melee damage by 10",
			"icon_color": Color(1.0, 0.7, 0.2)
		},
		{
			"type": "speed",
			"value": 30,
			"name": "Movement Speed",
			"description": "Increase movement speed by 30",
			"icon_color": Color(0.2, 0.8, 0.6)
		},
		{
			"type": "fire_rate",
			"value": 0.05,
			"name": "Attack Speed",
			"description": "Increase firing rate by 5%",
			"icon_color": Color(0.3, 0.3, 1.0)
		}
	]
	
	# Add weapon options based on what player has
	for weapon_type in weapon_types.keys():
		if not active_weapons.has(weapon_type):
			upgrades.append({
				"type": "add_weapon",
				"value": weapon_type,
				"name": weapon_types[weapon_type].name,
				"description": "New weapon: " + weapon_types[weapon_type].name,
				"icon_color": weapon_types[weapon_type].color
			})
		else:
			upgrades.append({
				"type": "upgrade_weapon",
				"value": weapon_type,
				"name": "Upgrade " + weapon_types[weapon_type].name,
				"description": "Increase level of " + weapon_types[weapon_type].name,
				"icon_color": weapon_types[weapon_type].color
			})
	
	# Shuffle and select random upgrades
	upgrades.shuffle()
	var display_upgrades = upgrades.slice(0, min(3, upgrades.size()))
	
	# Show the menu
	show_upgrade_menu(display_upgrades)

# Add this to emit_signal("player_level_up") handler
func _on_player_level_up(level):
	trigger_upgrade_menu()

# Connect the level up signal in _ready()
func _on_level_up(level):
	trigger_upgrade_menu()
