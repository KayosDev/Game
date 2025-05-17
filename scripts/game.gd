extends Node2D

@export var noise_shake_speed: float = 15.0
@export var noise_shake_strength: float = 16.0
@export var shake_decay_rate: float = 20.0
@export var player_death_shake_strength: float = 30.0 # Camera shake strength when player dies
@export var player_hit_shake_strength: float = 15.0 # Camera shake when player is hit
@export var xp_per_kill: int = 25 # Base XP gained for killing an enemy
@export var spawn_interval: float = 1.5 # Time between enemy spawns
@export var max_enemies: int = 10 # Maximum number of enemies at once
@export var difficulty_increase_rate: float = 0.05 # How quickly difficulty increases

var start_pos: Vector2
var enemy_list: Array = []
var noise_i: float = 0.0
var shake_strength: float = 0.0
var game_over: bool = false
var score: int = 0
var player_xp: int = 0
var player_level: int = 1
var xp_to_next_level: int = 100
var xp_scale_factor: float = 1.5 # Each level requires more XP
var spawn_timer: float = 0.0
var game_time: float = 0.0 # Time elapsed since game start
var current_difficulty: float = 1.0 # Scales with game time

@onready var camera: Camera2D = $Camera2D
@onready var enemy_class = preload("res://scenes/enemy.tscn")
@onready var player: CharacterBody2D = $Player
@onready var noise = FastNoiseLite.new()
@onready var rand = RandomNumberGenerator.new()
@onready var xp_display: Label = $UILayer/XPDisplay
@onready var level_display: Label = $UILayer/LevelDisplay
@onready var xp_bar: ProgressBar = $UILayer/XPBar
@onready var level_up_effect: CPUParticles2D = $UILayer/LevelUpEffect
@onready var xp_gain_label: Label = $UILayer/XPGainLabel
@onready var xp_tween: Tween
@onready var upgrade_popup_scene = preload("res://scenes/upgrade_popup.tscn")
@onready var user_interface = $UILayer # Reference to the UI container

func _ready():
	var screen_size = get_viewport_rect().size
	start_pos = Vector2(screen_size.x/2, screen_size.y/2)
	player.setup(start_pos)
	player.connect("player_died", _on_player_died)
	player.connect("player_damaged", _on_player_damaged)
	player.connect("player_level_up", _on_player_level_up)
	
	# Camera shake related
	rand.randomize()
	noise.seed = rand.randi()
	noise.frequency = 0.1
	
	# Initialize game
	game_over = false
	score = 0
	player_xp = 0
	player_level = 1
	xp_to_next_level = 100
	spawn_timer = 0.0
	game_time = 0.0
	current_difficulty = 1.0
	
	# Initialize UI
	update_xp_display()
	
	# Register console commands if Limbo Console is available
	if Engine.has_singleton("LimboConsole"):
		register_console_commands()

func _process(delta: float):
	if game_over:
		return
	
	# Update game time and difficulty
	game_time += delta
	current_difficulty = 1.0 + (game_time * difficulty_increase_rate)
	
	# Handle enemy spawning
	spawn_timer -= delta
	if spawn_timer <= 0 and enemy_list.size() < max_enemies:
		spawn_enemy()
		# Adjust spawn interval based on difficulty
		spawn_timer = spawn_interval / sqrt(current_difficulty)
	
	shake_camera(delta)

func spawn_enemy():
	var enemy = enemy_class.instantiate()
	enemy.connect("enemy_destroyed", on_enemy_destroyed)
	
	# Random position near the edges but inside the playable area
	var screen_size = get_viewport_rect().size
	var pos: Vector2
	
	# Choose which edge to spawn from
	var edge = randi() % 4
	match edge:
		0: # Top
			pos = Vector2(randf_range(100, screen_size.x - 100), 70)
		1: # Right
			pos = Vector2(screen_size.x - 70, randf_range(100, screen_size.y - 100))
		2: # Bottom
			pos = Vector2(randf_range(100, screen_size.x - 100), screen_size.y - 70)
		3: # Left
			pos = Vector2(70, randf_range(100, screen_size.y - 100))
	
	# Randomly choose enemy type based on difficulty
	var enemy_type_roll = randf()
	var enemy_type = "Normal"
	
	if current_difficulty >= 3.0: # After about 40 seconds
		if enemy_type_roll < 0.3:
			enemy_type = "Normal"
		elif enemy_type_roll < 0.6:
			enemy_type = "Fast"
		elif enemy_type_roll < 0.85:
			enemy_type = "Tank"
		else:
			enemy_type = "Ranged"
	elif current_difficulty >= 2.0: # After about 20 seconds
		if enemy_type_roll < 0.4:
			enemy_type = "Normal"
		elif enemy_type_roll < 0.7:
			enemy_type = "Fast" 
		else:
			enemy_type = "Tank"
	elif current_difficulty >= 1.5: # After about 10 seconds
		if enemy_type_roll < 0.6:
			enemy_type = "Normal"
		else:
			enemy_type = "Fast"
	
	enemy.enemy_type = enemy_type
	enemy.setup(pos, player)
	get_tree().root.add_child(enemy)
	enemy_list.append(enemy)

func shake_camera(delta: float):
	# Fade out the intensity over time
	shake_strength = lerp(shake_strength, 0.0, shake_decay_rate * delta)
	var shake_offset: Vector2
	shake_offset = get_noise_offset(delta, noise_shake_speed, shake_strength)
	# Shake by adjusting camera.offset, move the camera via it's position
	camera.offset = shake_offset

func get_noise_offset(delta: float, speed: float, strength: float) -> Vector2:
	noise_i += delta * speed
	# Set the x values of each call to 'get_noise_2d' to a different value
	# so that our x and y vectors will be reading from unrelated areas of noise
	return Vector2(
		noise.get_noise_2d(1, noise_i) * strength,
		noise.get_noise_2d(100, noise_i) * strength
	)

func get_random_offset() -> Vector2:
	return Vector2(
		rand.randf_range(-shake_strength, shake_strength),
		rand.randf_range(-shake_strength, shake_strength)
	)

func on_enemy_destroyed(enemy):
	shake_strength = noise_shake_strength
	enemy_list.erase(enemy)
	
	# Increase score
	score += 10
	
	# Add satisfying destruction particles at enemy position
	var particles = CPUParticles2D.new()
	particles.position = enemy.global_position
	particles.amount = 20
	particles.lifetime = 0.6
	particles.explosiveness = 0.8
	particles.direction = Vector2(0, -1)
	particles.spread = 180
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 120
	particles.scale_amount_min = 3
	particles.scale_amount_max = 3
	
	# Color based on enemy type if available
	if enemy.has_method("get_color") or "color" in enemy:
		var enemy_color = enemy.get("color") if "color" in enemy else enemy.get_color()
		particles.color = enemy_color
	else:
		particles.color = Color(0.8, 0.2, 0.2) # Default red
	
	particles.emitting = true
	particles.one_shot = true
	add_child(particles)
	
	# Auto-remove when done
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = true
	timer.autostart = true
	particles.add_child(timer)
	timer.timeout.connect(func(): particles.queue_free())
	
	# Award XP
	var xp_gained = xp_per_kill
	add_xp(xp_gained, enemy.global_position)

func add_xp(amount: int, position: Vector2 = Vector2.ZERO):
	player_xp += amount
	
	# Show XP gain
	show_xp_gained(amount, position)
	
	# Check for level up
	if player_xp >= xp_to_next_level:
		level_up()
	
	update_xp_display()

func level_up():
	player_level += 1
	player_xp -= xp_to_next_level
	xp_to_next_level = int(xp_to_next_level * xp_scale_factor)
	
	# Play level up effect with more particles
	if level_up_effect:
		level_up_effect.emitting = true
		level_up_effect.amount = 100  # More particles
		level_up_effect.lifetime = 2.0  # Longer duration
	
	# Massive screen shake for level up
	apply_screen_shake(15.0, 0.5)
	
	# Heal player on level up
	if player.has_method("heal"):
		player.heal(50)
	
	# Show upgrade popup
	show_upgrade_popup()
	
	# Signal player level up
	player.emit_signal("player_level_up", player_level)

func show_upgrade_popup():
	var upgrade_popup = upgrade_popup_scene.instantiate()
	add_child(upgrade_popup)
	
	# Connect the upgrade_selected signal
	upgrade_popup.connect("upgrade_selected", _on_upgrade_selected)

func _on_upgrade_selected(upgrade_type, value):
	# Apply the selected upgrade to the player
	player.apply_upgrade(upgrade_type, value)
	
	# Show notification about the upgrade
	var upgrade_text = ""
	match upgrade_type:
		"max_health":
			upgrade_text = "UPGRADE: +%d Max Health!" % value
		"fire_rate":
			upgrade_text = "UPGRADE: +15% Fire Rate!"
		"recoil_control":
			upgrade_text = "UPGRADE: +20% Recoil Control!"
		"speed":
			upgrade_text = "UPGRADE: +10% Movement Speed!"
		"laser":
			if player.weapon_levels.get("laser", 0) > 1:
				upgrade_text = "UPGRADED: Laser Beam Level %d!" % player.weapon_levels["laser"]
			else:
				upgrade_text = "NEW WEAPON: Laser Beam!"
		"shotgun":
			if player.weapon_levels.get("shotgun", 0) > 1:
				upgrade_text = "UPGRADED: Shotgun Level %d!" % player.weapon_levels["shotgun"]
			else:
				upgrade_text = "NEW WEAPON: Shotgun!"
		"orbit":
			if player.weapon_levels.get("orbit", 0) > 1:
				upgrade_text = "UPGRADED: Orbital Protector Level %d!" % player.weapon_levels["orbit"]
			else:
				upgrade_text = "NEW WEAPON: Orbital Protector!"
		"missile":
			if player.weapon_levels.get("missile", 0) > 1:
				upgrade_text = "UPGRADED: Homing Missile Level %d!" % player.weapon_levels["missile"]
			else:
				upgrade_text = "NEW WEAPON: Homing Missile!"
		"lightning":
			if player.weapon_levels.get("lightning", 0) > 1:
				upgrade_text = "UPGRADED: Chain Lightning Level %d!" % player.weapon_levels["lightning"]
			else:
				upgrade_text = "NEW WEAPON: Chain Lightning!"
		_:
			upgrade_text = "UPGRADE: %s improved!" % upgrade_type
	
	# Use the static function from UpgradeNotification class
	var center_pos = camera.get_screen_center_position()
	var notification_pos = Vector2(center_pos.x, center_pos.y - 100)
	
	var UpgradeNotification = load("res://scripts/upgrade_notification.gd")
	UpgradeNotification.show_notification(self, notification_pos, upgrade_text)

func update_xp_display():
	if xp_display:
		xp_display.text = "XP: %d / %d" % [player_xp, xp_to_next_level]
	
	if level_display:
		level_display.text = "Level: %d" % player_level
	
	if xp_bar:
		xp_bar.max_value = xp_to_next_level
		xp_bar.value = player_xp

func show_xp_gained(amount: int, position: Vector2):
	# Cancel previous tween if exists
	if xp_tween and xp_tween.is_valid():
		xp_tween.kill()
	
	# Create floating text at position
	var floating_text = Label.new()
	floating_text.text = "+" + str(amount) + " XP"
	floating_text.position = position
	floating_text.add_theme_font_size_override("font_size", 24)
	floating_text.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	
	# Add glow effect
	floating_text.add_theme_constant_override("outline_size", 3)
	floating_text.add_theme_color_override("font_outline_color", Color(0.2, 0.5, 0.2))
	
	# Center the text
	floating_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floating_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Add to scene
	add_child(floating_text)
	
	# Create a tween for smooth animation
	var tween = create_tween()
	tween.tween_property(floating_text, "position", position + Vector2(0, -80), 1.0)
	tween.parallel().tween_property(floating_text, "modulate", Color(0.5, 1.0, 0.5, 0), 1.0)
	tween.tween_callback(floating_text.queue_free)
	
	# Also update the main XP gain label
	xp_gain_label.text = "+" + str(amount) + " XP"
	xp_gain_label.modulate = Color(0.5, 1.0, 0.5, 1.0)
	
	xp_tween = create_tween()
	xp_tween.tween_property(xp_gain_label, "modulate", Color(0.5, 1.0, 0.5, 0), 1.0)

func _on_player_damaged(amount):
	# Enhanced reaction to player damage
	shake_strength = player_hit_shake_strength
	
	# Spawn damage particles
	spawn_screen_particles(amount / 5)
	
	# Brief slow-mo effect for impactful feel
	Engine.time_scale = 0.7
	var timer = Timer.new()
	timer.wait_time = 0.15
	timer.one_shot = true
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func(): Engine.time_scale = 1.0)

func _on_player_died():
	# Print debug message
	print("Game received player_died signal!")
	
	# Dramatic death effect
	shake_strength = player_death_shake_strength * 2 # Doubled for more impact
	game_over = true
	
	# Massive explosion of particles
	spawn_screen_particles(30)
	
	# Dramatic slow motion
	Engine.time_scale = 0.2
	var timer = Timer.new()
	timer.wait_time = 0.5 # Actual time will be 0.5 / 0.2 = 2.5 seconds
	timer.one_shot = true
	timer.autostart = true
	add_child(timer)
	var restore_time_func = func(): Engine.time_scale = 1.0
	timer.timeout.connect(restore_time_func)
	
	# Create the death screen
	create_premium_death_screen()
	print("Created premium death screen")

# Create a visually stunning death screen
func create_premium_death_screen():
	print("Setting up premium death screen")
	
	# Remove any existing death screen
	var existing = get_node_or_null("PremiumDeathScreen")
	if existing:
		existing.queue_free()
	
	# Create our canvas layer for the death UI
	var canvas = CanvasLayer.new()
	canvas.name = "PremiumDeathScreen"
	canvas.layer = 128  # Very high layer to be on top of everything
	add_child(canvas)
	
	# Create a stylish background with gradient
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.size = get_viewport_rect().size
	bg.position = Vector2.ZERO
	bg.color = Color(0.08, 0.03, 0.12, 0.0) # Start transparent for fade-in
	canvas.add_child(bg)
	
	# Create a stylish vignette overlay
	var vignette = ColorRect.new()
	vignette.name = "Vignette"
	vignette.size = get_viewport_rect().size
	vignette.position = Vector2.ZERO
	
	# Create shader for vignette effect
	var shader_code = """
	shader_type canvas_item;
	
	uniform float vignette_intensity = 0.4;
	uniform float vignette_opacity : hint_range(0.0, 1.0) = 0.5;
	uniform vec4 vignette_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
	
	void fragment() {
		vec2 uv = UV;
		vec2 center = vec2(0.5, 0.5);
		vec2 dist = uv - center;
		float d = length(dist) * 2.0;
		
		float vignette = smoothstep(0.8, vignette_intensity, d);
		COLOR = vec4(vignette_color.rgb, vignette * vignette_opacity);
	}
	"""
	
	var shader = Shader.new()
	shader.code = shader_code
	
	var material = ShaderMaterial.new()
	material.shader = shader
	
	vignette.material = material
	vignette.modulate = Color(1, 1, 1, 0)
	canvas.add_child(vignette)
	
	# Create a container for our content
	var container = VBoxContainer.new()
	container.name = "ContentContainer"
	container.size = Vector2(500, 400)
	container.position = Vector2(get_viewport_rect().size.x / 2 - 250, get_viewport_rect().size.y / 2 - 200)
	container.modulate = Color(1, 1, 1, 0) # Start transparent
	canvas.add_child(container)
	
	# Game Over title with style
	var title = Label.new()
	title.name = "GameOverTitle"
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(0.9, 0.2, 0.3))
	title.add_theme_constant_override("outline_size", 5)
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.0, 0.05, 0.8))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	container.add_child(title)
	
	# Add spacing
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 40)
	container.add_child(spacer1)
	
	# Score display with flare
	var score_container = HBoxContainer.new()
	score_container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_child(score_container)
	
	var score_label = Label.new()
	score_label.text = "FINAL SCORE"
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	score_container.add_child(score_label)
	
	var score_value = Label.new()
	score_value.text = str(score)
	score_value.add_theme_font_size_override("font_size", 42)
	score_value.add_theme_color_override("font_color", Color(1.0, 0.9, 0.2))
	score_value.add_theme_constant_override("outline_size", 2)
	score_value.add_theme_color_override("font_outline_color", Color(0.7, 0.4, 0.0, 0.8))
	score_value.custom_minimum_size = Vector2(180, 0)
	score_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_container.add_child(score_value)
	
	# Add restart instructions
	var restart_label = Label.new()
	restart_label.text = "Press SPACE or ENTER to restart"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.add_theme_font_size_override("font_size", 24)
	restart_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	container.add_child(restart_label)
	
	# Add spacing
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 50)
	container.add_child(spacer2)
	
	# Button container
	var retry_container = HBoxContainer.new()
	retry_container.alignment = BoxContainer.ALIGNMENT_CENTER
	retry_container.custom_minimum_size = Vector2(0, 80)
	container.add_child(retry_container)
	
	# Retry button with style
	var retry_button = Button.new()
	retry_button.text = "TRY AGAIN"
	retry_button.custom_minimum_size = Vector2(200, 70)
	retry_button.add_theme_font_size_override("font_size", 28)
	
	# Button styles
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	normal_style.border_width_left = 3
	normal_style.border_width_top = 3
	normal_style.border_width_right = 3
	normal_style.border_width_bottom = 3
	normal_style.border_color = Color(0.7, 0.2, 0.3)
	normal_style.corner_radius_top_left = 10
	normal_style.corner_radius_top_right = 10
	normal_style.corner_radius_bottom_right = 10
	normal_style.corner_radius_bottom_left = 10
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.25, 0.2, 0.3, 0.9)
	hover_style.border_width_left = 3
	hover_style.border_width_top = 3
	hover_style.border_width_right = 3
	hover_style.border_width_bottom = 3
	hover_style.border_color = Color(0.9, 0.3, 0.4)
	hover_style.corner_radius_top_left = 10
	hover_style.corner_radius_top_right = 10
	hover_style.corner_radius_bottom_right = 10
	hover_style.corner_radius_bottom_left = 10
	
	retry_button.add_theme_stylebox_override("normal", normal_style)
	retry_button.add_theme_stylebox_override("hover", hover_style)
	retry_button.add_theme_stylebox_override("pressed", hover_style)
	retry_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	retry_button.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.7))
	retry_container.add_child(retry_button)
	
	# Add spacing between buttons
	var button_spacer = Control.new()
	button_spacer.custom_minimum_size = Vector2(40, 0)
	retry_container.add_child(button_spacer)
	
	# Quit button with style
	var quit_button = Button.new()
	quit_button.text = "QUIT"
	quit_button.custom_minimum_size = Vector2(200, 70)
	quit_button.add_theme_font_size_override("font_size", 28)
	quit_button.add_theme_stylebox_override("normal", normal_style.duplicate())
	quit_button.add_theme_stylebox_override("hover", hover_style.duplicate())
	quit_button.add_theme_stylebox_override("pressed", hover_style.duplicate())
	quit_button.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	quit_button.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.7))
	retry_container.add_child(quit_button)
	
	# Setup animation and effects
	death_screen_animate(bg, vignette, container, title, score_value)
	
	# Setup particle effects for more visual appeal
	create_death_particles(canvas)
	
	# Connect button signals with proper variable functions
	var restart_game_func = func(): get_tree().reload_current_scene()
	var quit_game_func = func(): get_tree().quit()
	
	retry_button.pressed.connect(restart_game_func)
	quit_button.pressed.connect(quit_game_func)
	
	# Set the game_over flag to true
	game_over = true
	print("Death screen setup complete")

# Create stunning animations for the death screen
func death_screen_animate(bg, vignette, container, title, score_value):
	# Animate background fade in
	var bg_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	bg_tween.tween_property(bg, "color", Color(0.08, 0.03, 0.12, 0.95), 1.2)
	
	# Animate vignette
	var vign_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	vign_tween.tween_property(vignette, "modulate", Color(1, 1, 1, 0.9), 1.5)
	
	# Animate container fade and scale in with elastic bounce
	var cont_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	cont_tween.tween_property(container, "modulate", Color(1, 1, 1, 1), 1.0)
	cont_tween.parallel().tween_property(container, "scale", Vector2(1.0, 1.0), 1.0).from(Vector2(0.7, 0.7))
	
	# Animate title for emphasis with shaking effect
	var title_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	title_tween.tween_property(title, "custom_minimum_size:y", 100, 0.8).from(70)
	title_tween.parallel().tween_property(title, "modulate", Color(1, 1, 1, 1), 0.8).from(Color(1, 0, 0, 1))
	
	# Add title shake effect
	title_tween.tween_callback(func():
		var shake_tween = create_tween().set_loops(3)
		shake_tween.tween_property(title, "position", Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.05)
		shake_tween.tween_property(title, "position", Vector2.ZERO, 0.05)
	)
	
	# Animate score counter with counting effect
	var score_tween = create_tween().set_ease(Tween.EASE_OUT)
	score_tween.tween_property(score_value, "modulate", Color(1, 0.9, 0.2, 1), 0.3).from(Color(1, 1, 1, 0))
	
	# Animate score counting up
	score_tween.tween_callback(func():
		var count = 0
		var duration = 1.5
		var steps = 30
		var increment = score / steps
		
		var count_tween = create_tween()
		for i in range(steps):
			count_tween.tween_callback(func():
				count += increment
				score_value.text = str(int(count))
			)
			count_tween.tween_interval(duration / steps)
		
		count_tween.tween_callback(func():
			score_value.text = str(score) # Ensure final value is exact
		)
	)
	
	# Create pulsing effect for title
	await get_tree().create_timer(2.0).timeout
	var pulse_tween = create_tween().set_loops()
	pulse_tween.tween_property(title, "modulate:a", 0.7, 0.9)
	pulse_tween.tween_property(title, "modulate:a", 1.0, 0.9)

# Create enhanced particle effects for the death screen
func create_death_particles(canvas):
	# Create top embers falling
	var particles = CPUParticles2D.new()
	particles.position = Vector2(get_viewport_rect().size.x / 2, -50)
	particles.amount = 60
	particles.lifetime = 8
	particles.explosiveness = 0.1
	particles.randomness = 0.5
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(get_viewport_rect().size.x / 2, 1)
	particles.direction = Vector2(0, 1)
	particles.gravity = Vector2(0, 20)
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 100
	particles.scale_amount_min = 4
	particles.scale_amount_max = 8
	particles.color = Color(0.9, 0.3, 0.2, 0.7)
	particles.color_ramp = create_death_particle_gradient()
	canvas.add_child(particles)
	
	# Add some glowing dust particles rising from bottom
	var dust = CPUParticles2D.new()
	dust.position = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y + 50)
	dust.amount = 40
	dust.lifetime = 5
	dust.explosiveness = 0.1
	dust.randomness = 0.5
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(get_viewport_rect().size.x / 2, 1)
	dust.direction = Vector2(0, -1)
	dust.gravity = Vector2(0, -30)
	dust.initial_velocity_min = 50
	dust.initial_velocity_max = 100
	dust.scale_amount_min = 3
	dust.scale_amount_max = 6
	dust.color = Color(0.5, 0.3, 0.7, 0.4)
	canvas.add_child(dust)
	
	# Add floating lights - they look beautiful in a death screen
	var lights = CPUParticles2D.new()
	lights.position = Vector2(get_viewport_rect().size.x / 2, get_viewport_rect().size.y / 2)
	lights.amount = 15
	lights.lifetime = 10
	lights.preprocess = 5 # Start with particles already present
	lights.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	lights.emission_rect_extents = Vector2(get_viewport_rect().size.x / 3, get_viewport_rect().size.y / 3)
	lights.gravity = Vector2(0, -5)
	lights.linear_accel_min = -5
	lights.linear_accel_max = 5
	lights.damping_min = 1
	lights.damping_max = 3
	lights.scale_amount_min = 5
	lights.scale_amount_max = 10
	lights.color = Color(0.7, 0.3, 0.5, 0.5)
	canvas.add_child(lights)

# Create a gradient for the particles
func create_death_particle_gradient():
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1, 0.3, 0.3, 0.8))
	gradient.add_point(0.5, Color(0.8, 0.1, 0.1, 0.5))
	gradient.add_point(1.0, Color(0.3, 0.0, 0.0, 0.0))
	return gradient

# Handle input for game restart
func _unhandled_input(event):
	if game_over and event.is_action_pressed("ui_accept"):
		# Restart the game
		get_tree().reload_current_scene()

func _on_player_level_up(level):
	# Additional effects for level up can be added here
	# Increase max enemies with level
	max_enemies = 10 + level

# Function to clean up blood stains if there are too many (performance)
func clean_blood_stains(max_stains: int = 20):
	var stains = get_tree().get_nodes_in_group("blood_stains")
	if stains.size() > max_stains:
		# Remove the oldest stains
		for i in range(stains.size() - max_stains):
			if is_instance_valid(stains[i]):
				stains[i].queue_free()

func apply_screen_shake(amount: float, duration: float = 0.3):
	# Set the shake strength based on the amount
	shake_strength = max(shake_strength, amount)
	
	# Create additional particle effects explosion at random positions
	spawn_screen_particles(3 + int(amount))
	
	# Optional: slow time briefly for impact
	if amount > 10.0:
		Engine.time_scale = 0.8
		var timer = Timer.new()
		timer.wait_time = 0.1
		timer.one_shot = true
		timer.autostart = true
		add_child(timer)
		timer.timeout.connect(func(): Engine.time_scale = 1.0)

func spawn_screen_particles(count: int):
	# Disabled random particle effects
	return
	
	# Original code below (now disabled)
	var screen_size = get_viewport_rect().size
	
	for i in range(count):
		# Create a random explosion effect
		var particles = CPUParticles2D.new()
		particles.position = Vector2(
			randf_range(100, screen_size.x - 100),
			randf_range(100, screen_size.y - 100)
		)
		
		# Configure particles
		particles.amount = randi_range(10, 30)
		particles.lifetime = randf_range(0.5, 1.0)
		particles.explosiveness = 0.8
		particles.randomness = 0.5
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
		particles.direction = Vector2(0, -1)
		particles.spread = 180
		particles.gravity = Vector2.ZERO
		particles.initial_velocity_min = 50
		particles.initial_velocity_max = 150
		particles.scale_amount_min = randf_range(2, 5)
		particles.scale_amount_max = randf_range(2, 5)
		
		# Random color based on explosion type
		var color_type = randi() % 3
		if color_type == 0:
			particles.color = Color(1.0, 0.5, 0.2) # Orange
		elif color_type == 1:
			particles.color = Color(0.3, 0.7, 1.0) # Blue
		else:
			particles.color = Color(1.0, 0.2, 0.8) # Pink
		
		# One-shot explosion
		particles.emitting = true
		particles.one_shot = true
		
		# Add to scene
		add_child(particles)
		
		# Auto-remove when done
		var timer = Timer.new()
		timer.wait_time = particles.lifetime * 1.5
		timer.one_shot = true
		timer.autostart = true
		particles.add_child(timer)
		timer.timeout.connect(func(): particles.queue_free())

# Console command methods
func console_restart_game():
	# Restart the current scene
	get_tree().reload_current_scene()
	return "Game restarted"

func console_set_difficulty(level: float = -1):
	if level < 0:
		return "Current difficulty: " + str(current_difficulty)
	
	current_difficulty = max(level, 0.1)
	return "Difficulty set to " + str(current_difficulty)

func console_spawn_enemies(count: int = 1, type: String = "Normal"):
	var valid_types = ["Normal", "Fast", "Tank", "Ranged"]
	if not valid_types.has(type):
		return "Invalid enemy type. Valid types: " + str(valid_types)
		
	var spawned = 0
	for i in range(count):
		if enemy_list.size() < max_enemies * 2:  # Allow spawning more than the normal limit
			var enemy = enemy_class.instantiate()
			enemy.connect("enemy_destroyed", on_enemy_destroyed)
			
			# Random position near the player
			var offset = Vector2(
				randf_range(-200, 200),
				randf_range(-200, 200)
			)
			var pos = player.global_position + offset
			
			# Keep within screen bounds
			var screen_size = get_viewport_rect().size
			pos.x = clamp(pos.x, 50, screen_size.x - 50)
			pos.y = clamp(pos.y, 50, screen_size.y - 50)
			
			enemy.enemy_type = type
			enemy.setup(pos, player)
			get_tree().root.add_child(enemy)
			enemy_list.append(enemy)
			spawned += 1
		else:
			break
			
	return "Spawned " + str(spawned) + " " + type + " enemies"

func console_add_xp(amount: int = 100):
	add_xp(amount, player.global_position)
	return "Added " + str(amount) + " XP"

func console_set_level(level: int = -1):
	if level < 0:
		return "Current level: " + str(player_level)
		
	player_level = max(level, 1)
	update_xp_display()
	return "Level set to " + str(player_level)

func console_toggle_enemy_spawn(enable: bool = true):
	if enable:
		spawn_interval = 1.5 / current_difficulty
		return "Enemy spawning enabled"
	else:
		spawn_interval = 999999  # Effectively disable spawning
		return "Enemy spawning disabled"
		
func console_clear_enemies():
	var count = enemy_list.size()
	for enemy in enemy_list.duplicate():
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemy_list.clear()
	return "Cleared " + str(count) + " enemies"

func console_show_game_stats():
	var stats = "Game Time: " + str(round(game_time)) + "s\n"
	stats += "Score: " + str(score) + "\n"
	stats += "Player Level: " + str(player_level) + "\n"
	stats += "XP: " + str(player_xp) + "/" + str(xp_to_next_level) + "\n"
	stats += "Difficulty: " + str(snappedf(current_difficulty, 0.01)) + "\n"
	stats += "Enemy Count: " + str(enemy_list.size()) + "/" + str(max_enemies)
	return stats

func console_screen_shake(strength: float = 10.0):
	shake_strength = strength
	return "Applied screen shake with strength " + str(strength)

func console_set_max_enemies(count: int = -1):
	if count < 0:
		return "Current max enemies: " + str(max_enemies)
		
	max_enemies = max(count, 1)
	return "Max enemies set to " + str(max_enemies)

func register_console_commands():
	# Register global game commands with Limbo Console
	LimboConsole.register_command(console_restart_game, "restart", "Restart the game")
	LimboConsole.register_command(console_set_difficulty, "set_difficulty", "Set game difficulty")
	LimboConsole.register_command(console_spawn_enemies, "spawn", "Spawn enemies")
	LimboConsole.register_command(console_add_xp, "add_xp", "Add XP to player")
	LimboConsole.register_command(console_set_level, "set_level", "Set player level")
	LimboConsole.register_command(console_toggle_enemy_spawn, "toggle_spawn", "Enable/disable enemy spawning")
	LimboConsole.register_command(console_clear_enemies, "clear_enemies", "Remove all enemies")
	LimboConsole.register_command(console_show_game_stats, "stats", "Show game statistics")
	LimboConsole.register_command(console_screen_shake, "shake", "Apply screen shake")
	LimboConsole.register_command(console_set_max_enemies, "set_max_enemies", "Set maximum enemy count")
	
	# Create some helpful aliases
	LimboConsole.add_alias("god", "god")  # Shortcut for player.god
	LimboConsole.add_alias("reset", "reset_player")  # Shortcut for reset_player
	LimboConsole.add_alias("heal", "set_health 100")  # Quick heal to full
