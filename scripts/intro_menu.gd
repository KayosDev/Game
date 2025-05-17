extends Control

# Animation variables
var logo_rotation = 0.0
var logo_scale_pulse = 0.0
var character_rotation = 0.0
var bullet_timer = 0.0
var bullet_particles = []
var active_bullets = []
var rotating_stars = []
var time_passed = 0.0

# Music and sound
var menu_music
var button_sound
var shoot_sound

# Background stars
class Star:
	var position: Vector2
	var size: float
	var speed: float
	var color: Color

func _ready():
	# Setup UI animation initial state
	randomize()
	
	# Create tween for UI appearance - ensure it has at least one tweener
	var tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid($GameTitle):
		tween.tween_property($GameTitle, "position:y", $GameTitle.position.y, 0.8).from($GameTitle.position.y - 300)
	if is_instance_valid($MenuContainer):
		tween.tween_property($MenuContainer, "position:y", $MenuContainer.position.y, 0.8).from($MenuContainer.position.y + 300)
		tween.tween_property($MenuContainer, "modulate:a", 1.0, 1.0).from(0.0)
	if is_instance_valid($Tagline):
		tween.tween_property($Tagline, "modulate:a", 1.0, 1.2).from(0.0)
	
	# Add a fallback tweener if needed
	# In Godot 4, we can check if the tween has any tweeners by using the is_valid() method
	# If we don't have any tweeners added, add a dummy one to prevent errors
	if not is_instance_valid($GameTitle) and not is_instance_valid($MenuContainer) and not is_instance_valid($Tagline):
		tween.tween_property(self, "modulate:a", 1.0, 0.5).from(1.0)
	
	# Zoom in effect for the logo
	var logo_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	# Add a fallback tweener even if the logo effect is commented out
	logo_tween.tween_property(self, "position", position, 0.5)
	
	# Create animated stars in the background
	create_background_stars()
	
	# Set up audio
	setup_audio()
	
	# Move buttons on highlight (when hovered)
	var buttons = [$MenuContainer/StartButton, $MenuContainer/OptionsButton, $MenuContainer/QuitButton]
	for button in buttons:
		button.mouse_entered.connect(_on_button_hover.bind(button))

func _process(delta):
	time_passed += delta
	
	# Animate logo
	logo_rotation += delta * 0.2
	logo_scale_pulse = sin(time_passed * 2.0) * 0.05
	#$LogoDynamicPolygons.rotation = sin(logo_rotation) * 0.05
	#$LogoDynamicPolygons.scale = Vector2(1.5, 1.5) * (1.0 + logo_scale_pulse)
	
	# Logo parts subtle animation
	#$LogoDynamicPolygons/LogoTop.position.y = -10 + sin(time_passed * 1.5) * 3.0                              
	#$LogoDynamicPolygons/LogoBottom.position.y = 10 + cos(time_passed * 1.5) * 3.0
	#$LogoDynamicPolygons/LogoLeft.position.x = -10 + sin(time_passed * 2.0) * 2.0
	#$LogoDynamicPolygons/LogoRight.position.x = 10 + cos(time_passed * 2.0) * 2.0
	#$LogoDynamicPolygons/LogoMiddle.scale = Vector2(1.0, 1.0) * (1.0 + sin(time_passed * 3.0) * 0.1)
	
	# Animate character preview - subtle bobbing and rotation
	$CharacterPreview.position.y = 400 + sin(time_passed * 1.7) * 8.0
	$CharacterPreview.rotation = sin(time_passed * 0.8) * 0.1
	
	# Character gun rotation (small random movement)aa
	character_rotation = sin(time_passed * 5.0) * 0.1
	$CharacterPreview/CharacterGun.rotation += (character_rotation - $CharacterPreview/CharacterGun.rotation) * 0.1
	
	# Auto-fire bullets occasionally
	bullet_timer -= delta
	if bullet_timer <= 0:
		fire_demo_bullet()
		bullet_timer = randf_range(0.5, 1.5)
	
	# Animate active bullets
	for i in range(active_bullets.size() - 1, -1, -1):
		if i < active_bullets.size():
			var bullet = active_bullets[i]
			if is_instance_valid(bullet):
				# Move bullet forward
				bullet.position += Vector2.RIGHT.rotated(bullet.rotation) * delta * 600.0
				
				# Remove bullet if it goes off screen
				if bullet.position.x > 1500 or bullet.position.x < -300 or bullet.position.y > 1000 or bullet.position.y < -200:
					bullet.queue_free()
					active_bullets.remove_at(i)
	
	# Animate background stars
	update_background_stars(delta)
	
	# Make title text pulse
	$GameTitle.scale = Vector2(1.0, 1.0) * (1.0 + sin(time_passed * 2.0) * 0.03)
	
	# Make buttons slightly move
	for i in range($MenuContainer.get_child_count()):
		var button = $MenuContainer.get_child(i)
		button.position.x = sin(time_passed * (1.0 + i * 0.2) + i) * 5.0

func create_background_stars():
	# Create a Node2D to hold the stars
	var stars_container = Node2D.new()
	stars_container.name = "BackgroundStars"
	$FXContainer.add_child(stars_container)
	
	# Generate 100 stars with different properties
	for i in range(100):
		var star = Star.new()
		star.position = Vector2(randf_range(0, get_viewport_rect().size.x), randf_range(0, get_viewport_rect().size.y))
		star.size = randf_range(1.0, 3.0)
		star.speed = randf_range(10.0, 50.0)
		
		# Determine star color - mostly white/blue with occasional colorful ones
		var color_choice = randf()
		if color_choice < 0.7:
			# White/blue stars (common)
			star.color = Color(0.8 + randf() * 0.2, 0.8 + randf() * 0.2, 1.0, 0.7 + randf() * 0.3)
		elif color_choice < 0.85:
			# Yellow/orange stars
			star.color = Color(1.0, 0.7 + randf() * 0.3, 0.3 + randf() * 0.3, 0.7 + randf() * 0.3)
		else:
			# Pink/purple stars
			star.color = Color(0.8 + randf() * 0.2, 0.4 + randf() * 0.3, 0.8 + randf() * 0.2, 0.7 + randf() * 0.3)
		
		# Create visual representation
		var polygon = Polygon2D.new()
		polygon.color = star.color
		
		# Create a circle approximation using polygons
		var points = []
		var num_points = 8
		for j in range(num_points):
			var angle = j * TAU / num_points
			points.append(Vector2(cos(angle), sin(angle)) * star.size)
		polygon.polygon = PackedVector2Array(points)
		polygon.position = star.position
		
		# Add to scene
		stars_container.add_child(polygon)
		rotating_stars.append({"polygon": polygon, "data": star, "angle": randf() * TAU})

func update_background_stars(delta):
	for star_data in rotating_stars:
		var polygon = star_data.polygon
		var data = star_data.data
		
		# Move star down slightly
		polygon.position.y += data.speed * delta
		
		# Wrap around if off screen
		if polygon.position.y > get_viewport_rect().size.y + 10:
			polygon.position.y = -10
			polygon.position.x = randf_range(0, get_viewport_rect().size.x)
		
		# Twinkle effect
		var twinkle = (sin(time_passed * randf_range(1.0, 3.0) + data.position.x) + 1.0) / 2.0
		polygon.modulate.a = 0.4 + twinkle * 0.6
		
		# Rotate stars slightly
		star_data.angle += delta * 0.2
		polygon.rotation = star_data.angle

func setup_audio():
	# Create audio players
	menu_music = AudioStreamPlayer.new()
	menu_music.volume_db = -10
	button_sound = AudioStreamPlayer.new()
	button_sound.volume_db = -5
	shoot_sound = AudioStreamPlayer.new()
	shoot_sound.volume_db = -8
	
	# Add them to scene
	add_child(menu_music)
	add_child(button_sound)
	add_child(shoot_sound)
	
	# We would load audio streams here, but we'll skip it for now as
	# we don't have audio assets in the project:
	# menu_music.stream = load("res://assets/music/menu_theme.ogg")
	# menu_music.play()

func fire_demo_bullet():
	# Create a visual bullet
	var bullet = Polygon2D.new()
	bullet.color = Color(0.8, 0.4, 1.0, 0.8)
	
	# Bullet shape
	var points = []
	points.append(Vector2(-8, -3))
	points.append(Vector2(8, -3))
	points.append(Vector2(12, 0))
	points.append(Vector2(8, 3))
	points.append(Vector2(-8, 3))
	bullet.polygon = PackedVector2Array(points)
	
	# Position and rotation
	bullet.position = $CharacterPreview/CharacterGun/BulletSpawn.global_position
	bullet.rotation = $CharacterPreview/CharacterGun.global_rotation
	
	# Add bullet trail
	var trail = CPUParticles2D.new()
	trail.emitting = true
	trail.amount = 20
	trail.lifetime = 0.5
	trail.local_coords = false
	trail.explosiveness = 0.0
	trail.randomness = 0.2
	trail.lifetime_randomness = 0.2
	trail.direction = Vector2.LEFT.rotated(bullet.rotation)
	trail.spread = 5
	trail.gravity = Vector2.ZERO
	trail.initial_velocity_min = 30
	trail.initial_velocity_max = 50
	trail.scale_amount_min = 2
	trail.scale_amount_max = 4
	trail.color = Color(0.9, 0.3, 1.0, 0.6)
	bullet.add_child(trail)
	
	# Add to trackers
	add_child(bullet)
	active_bullets.append(bullet)
	
	# Create an enhanced muzzle flash effect
	var flash = CPUParticles2D.new()
	flash.emitting = true
	flash.one_shot = true
	flash.explosiveness = 0.95
	flash.amount = 30  # More particles
	flash.lifetime = 0.4  # Longer lifetime
	flash.position = $CharacterPreview/CharacterGun/BulletSpawn.global_position
	flash.direction = Vector2.RIGHT.rotated($CharacterPreview/CharacterGun.global_rotation)
	flash.spread = 40  # More spread
	flash.gravity = Vector2.ZERO
	flash.initial_velocity_min = 50
	flash.initial_velocity_max = 150  # Higher velocity
	flash.scale_amount_min = 1
	flash.scale_amount_max = 5  # Larger particles
	flash.color = Color(1.0, 0.6, 1.0, 0.8)
	
	# Create a color gradient for the muzzle flash
	var color_ramp = Gradient.new()
	color_ramp.add_point(0.0, Color(1.0, 0.9, 1.0, 1.0))
	color_ramp.add_point(0.2, Color(1.0, 0.6, 1.0, 0.8))
	color_ramp.add_point(1.0, Color(0.8, 0.2, 1.0, 0.0))
	flash.color_ramp = color_ramp
	
	add_child(flash)
	bullet_particles.append(flash)
	
	# Add flash light effect
	var light = PointLight2D.new()
	light.position = $CharacterPreview/CharacterGun/BulletSpawn.global_position
	light.texture = create_light_texture()
	light.energy = 0.8
	light.color = Color(1.0, 0.6, 0.9)
	light.texture_scale = 2.0
	
	# Animate the light
	var tween = create_tween()
	if is_instance_valid(light):
		tween.tween_property(light, "energy", 0.0, 0.4)
		tween.tween_callback(light.queue_free)
	else:
		# Fallback tweener
		tween.tween_property(self, "modulate:a", 1.0, 0.4)
	
	add_child(light)
	
	# Clean up old particles
	for i in range(bullet_particles.size() - 1, -1, -1):
		if i < bullet_particles.size():
			var particle = bullet_particles[i]
			if not particle.emitting or not is_instance_valid(particle):
				if is_instance_valid(particle):
					particle.queue_free()
				bullet_particles.remove_at(i)
	
	# Create a bullet impact after a delay
	var random_pos = Vector2(randf_range(300, 900), randf_range(200, 500))
	# Don't hit the character or menu
	if random_pos.distance_to($CharacterPreview.position) < 150 or random_pos.y > 250 and random_pos.y < 450:
		random_pos = Vector2(randf_range(100, 200), randf_range(100, 200))
	
	var timer = Timer.new()
	timer.wait_time = randf_range(0.5, 1.0)
	timer.one_shot = true
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func(): create_bullet_impact(random_pos))
	
	# Play sound (if we had one)
	if shoot_sound:
		shoot_sound.pitch_scale = randf_range(0.9, 1.1)
		# shoot_sound.play()

# Create light texture for bullet effects
func create_light_texture():
	var radius = 64
	var canvas = Image.create(radius * 2, radius * 2, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	
	# Draw a radial gradient
	for x in range(radius * 2):
		for y in range(radius * 2):
			var dist = Vector2(x, y).distance_to(Vector2(radius, radius))
			if dist <= radius:
				var alpha = 1.0 - (dist / radius)
				alpha = pow(alpha, 2) # Make gradient smoother
				canvas.set_pixel(x, y, Color(1, 1, 1, alpha))
	
	var texture = ImageTexture.create_from_image(canvas)
	return texture

# Create bullet impact effect
func create_bullet_impact(pos: Vector2):
	# Impact particles
	var impact = CPUParticles2D.new()
	impact.position = pos
	impact.emitting = true
	impact.one_shot = true
	impact.explosiveness = 0.95
	impact.amount = 40
	impact.lifetime = 0.6
	impact.spread = 180
	impact.gravity = Vector2.ZERO
	impact.initial_velocity_min = 50
	impact.initial_velocity_max = 150
	impact.scale_amount_min = 2
	impact.scale_amount_max = 6
	
	# Color gradient for impact
	var color_ramp = Gradient.new()
	color_ramp.add_point(0.0, Color(1.0, 0.8, 1.0, 1.0))
	color_ramp.add_point(0.3, Color(0.9, 0.3, 0.9, 0.7))
	color_ramp.add_point(1.0, Color(0.5, 0.1, 0.5, 0.0))
	impact.color_ramp = color_ramp
	
	add_child(impact)
	bullet_particles.append(impact)
	
	# Flash light at impact point
	var light = PointLight2D.new()
	light.position = pos
	light.texture = create_light_texture()
	light.energy = 1.0
	light.color = Color(1.0, 0.5, 0.9)
	light.texture_scale = 3.0
	
	# Animate the light
	var tween = create_tween()
	if is_instance_valid(light):
		tween.tween_property(light, "energy", 0.0, 0.5)
		tween.tween_callback(light.queue_free)
	else:
		# Fallback tweener
		tween.tween_property(self, "modulate:a", 1.0, 0.5)
	
	add_child(light)
	
	# Add a small shockwave
	var shockwave = ColorRect.new()
	shockwave.position = pos - Vector2(5, 5)
	shockwave.size = Vector2(10, 10)
	shockwave.color = Color(1.0, 0.7, 1.0, 0.8)
	add_child(shockwave)
	
	# Animate the shockwave
	var shock_tween = create_tween()
	shock_tween.set_parallel(true)
	if is_instance_valid(shockwave):
		shock_tween.tween_property(shockwave, "position", pos - Vector2(100, 100), 0.3)
		shock_tween.tween_property(shockwave, "size", Vector2(200, 200), 0.3)
		shock_tween.tween_property(shockwave, "color:a", 0.0, 0.3)
		shock_tween.tween_callback(shockwave.queue_free)
	else:
		# Fallback tweener
		shock_tween.tween_property(self, "modulate:a", 1.0, 0.3)

# Handle mouse input
func _input(event):
	if event is InputEventMouseMotion and is_instance_valid($CharacterPreview/CharacterGun):
		# Make gun look at mouse position
		var direction = event.position - $CharacterPreview.global_position
		$CharacterPreview/CharacterGun.rotation = direction.angle()

func _on_button_hover(button):
	# Scale up animation
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.3)
	
	# Play hover sound (if we had one)
	if button_sound:
		button_sound.pitch_scale = randf_range(0.9, 1.1)
		# button_sound.play()

func _on_start_button_pressed():
	# Create screen flash effect
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	add_child(flash)
	
	# Flash then change scene
	var tween = create_tween()
	tween.tween_property(flash, "color:a", 0.8, 0.3)
	tween.tween_callback(start_game)

func _on_options_button_pressed():
	# We would open options panel here
	# For now, just provide visual feedback
	var tween = create_tween()
	if is_instance_valid($MenuContainer/OptionsButton):
		tween.tween_property($MenuContainer/OptionsButton, "modulate", Color(1.5, 1.5, 1.5), 0.2)
		tween.tween_property($MenuContainer/OptionsButton, "modulate", Color(1, 1, 1), 0.2)
	else:
		# Fallback tweener
		tween.tween_property(self, "modulate:a", 1.0, 0.2)

func _on_quit_button_pressed():
	# Fade out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.5)
	tween.tween_callback(quit_game)

func start_game():
	# Load the main game scene
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func quit_game():
	# Quit the game
	get_tree().quit() 
