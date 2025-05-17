extends Node2D

@export var lifetime = 2.0  # How long particles live
@export var particle_count = 30  # Number of particles to spawn (increased)
@export var min_size = 3.0  # Minimum particle size
@export var max_size = 12.0  # Maximum particle size (increased)
@export var min_speed = 120.0  # Minimum particle speed (increased)
@export var max_speed = 280.0  # Maximum particle speed (increased)
@export var gravity = 400.0  # Gravity pulling particles down
@export var damping = 0.85  # Speed reduction per second (reduced for longer travel)
@export var color_intensity = 1.2  # Color intensity multiplier (new)
@export var shock_wave_radius = 60.0  # Radius of initial shockwave (new)
@export var glow_intensity = 1.5  # How much the particles glow (new)

var particles = []  # List of particle objects
var time_elapsed = 0.0  # Track how long the effect has been running
var base_color = Color(0.8, 0.2, 0.2)  # Default red color for particles
var shock_wave_active = true  # Whether to show shockwave (new)
var shock_wave_lifetime = 0.4  # How long the shockwave lasts (new)
var flash_active = true  # Whether to show flash (new)
var flash_lifetime = 0.15  # How long the flash lasts (new)
var trails_enabled = true  # Whether to show particle trails (new)
var trail_points = {}  # Store trail positions for each particle (new)
var impact_freeze = true  # Whether to do time freeze on impact (new)

class Particle:
	var position: Vector2
	var velocity: Vector2
	var rotation: float
	var rotation_speed: float
	var size: float
	var color: Color
	var lifetime: float
	var max_lifetime: float
	var shape_type: int  # Store shape type
	var pulse_rate: float  # For size pulsing effect
	var glow_size: float  # Extra size for glow effect
	var base_size: float  # Store the original size for pulsing
	
	func _init(pos, vel, rot_speed, sz, col, life):
		position = pos
		velocity = vel
		rotation = randf_range(0, TAU)
		rotation_speed = rot_speed
		size = sz
		base_size = sz  # Store original size
		color = col
		lifetime = life
		max_lifetime = life
		shape_type = randi() % 4  # Now with 4 shape types
		pulse_rate = randf_range(3.0, 8.0)  # Random pulse speed
		glow_size = sz * 1.5  # Glow is 1.5x particle size
	
	func update(delta, gravity, damping, current_time):
		# Update position based on velocity
		position += velocity * delta
		
		# Apply gravity
		velocity.y += gravity * delta
		
		# Apply damping
		velocity *= pow(damping, delta)
		
		# Add some turbulence for more chaotic movement
		velocity += Vector2(
			randf_range(-20, 20),
			randf_range(-20, 20)
		) * delta
		
		# Update rotation
		rotation += rotation_speed * delta
		
		# Pulsate size for more dynamic effect using current_time instead of time_elapsed
		size = lerp(base_size, base_size * (1.0 + 0.2 * sin(current_time * pulse_rate)), delta * 2)
		
		# Decrease lifetime
		lifetime -= delta
		
		return lifetime > 0

func _ready():
	# Initialize the particle system
	initialize_particles()
	
	# Set up auto-destruction timer
	var timer = Timer.new()
	timer.wait_time = lifetime + 0.5  # Add a small buffer
	timer.one_shot = true
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(queue_free)
	
	# Do impact time freeze
	if impact_freeze:
		Engine.time_scale = 0.05  # Almost stop time
		await get_tree().create_timer(0.03).timeout  # For 0.03 real seconds
		Engine.time_scale = 1.0  # Resume normal time

func initialize_particles():
	particles.clear()
	trail_points.clear()
	
	# Create particles with random properties and directional bias
	for i in range(particle_count):
		var angle = randf_range(0, TAU)
		var speed = randf_range(min_speed, max_speed)
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		
		# Randomize other properties
		var rot_speed = randf_range(-8.0, 8.0)
		var size = randf_range(min_size, max_size)
		
		# Create more intense colors
		var color_variation = randf_range(-0.2, 0.2)
		var particle_color = base_color
		particle_color.r = clamp(particle_color.r + color_variation, 0, 1) * color_intensity
		particle_color.g = clamp(particle_color.g + color_variation, 0, 1) * color_intensity
		particle_color.b = clamp(particle_color.b + color_variation, 0, 1) * color_intensity
		particle_color = particle_color.clamp()  # Ensure color values stay in valid range
		
		# Create the particle
		var particle = Particle.new(
			Vector2(randf_range(-5, 5), randf_range(-5, 5)),  # Slight random offset
			velocity,
			rot_speed,
			size,
			particle_color,
			randf_range(lifetime * 0.5, lifetime)
		)
		particles.append(particle)
		
		# Initialize trail for this particle
		trail_points[i] = []

func _process(delta):
	time_elapsed += delta
	
	# Update shockwave and flash lifetimes
	if shock_wave_active:
		shock_wave_lifetime -= delta
		if shock_wave_lifetime <= 0:
			shock_wave_active = false
	
	if flash_active:
		flash_lifetime -= delta
		if flash_lifetime <= 0:
			flash_active = false
	
	# Update particles
	for i in range(particles.size() - 1, -1, -1):
		var particle = particles[i]
		if not particle.update(delta, gravity, damping, time_elapsed):
			particles.remove_at(i)
			if trail_points.has(i):
				trail_points.erase(i)
		elif trails_enabled and trail_points.has(i):
			# Store trail points (only every few frames to optimize)
			if Engine.get_frames_drawn() % 2 == 0:
				var trail = trail_points[i]
				trail.append(particle.position)
				# Limit trail length
				if trail.size() > 10:
					trail.remove_at(0)
	
	# Force redraw
	queue_redraw()
	
	# If all particles are gone, we can free this node
	if particles.size() == 0:
		queue_free()

func _draw():
	# Draw flash
	if flash_active:
		var flash_color = Color(1, 1, 1, flash_lifetime / 0.15)
		draw_circle(Vector2.ZERO, 100, flash_color)
	
	# Draw shockwave
	if shock_wave_active:
		var progress = 1.0 - (shock_wave_lifetime / 0.4)
		var radius = shock_wave_radius * progress
		var shock_color = Color(1, 1, 1, 1.0 - progress)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 32, shock_color, 3.0, true)
	
	# Draw trails first (under particles)
	if trails_enabled:
		for i in range(particles.size()):
			if trail_points.has(i) and trail_points[i].size() > 1:
				var trail = trail_points[i]
				var particle = particles[i]
				
				# Create gradient for trail
				for j in range(trail.size() - 1):
					var progress = float(j) / trail.size()
					var trail_color = particle.color
					trail_color.a = progress * 0.7 * (particle.lifetime / particle.max_lifetime)
					
					var width = particle.size * 0.7 * progress
					draw_line(trail[j], trail[j+1], trail_color, width)
	
	# Draw each particle
	for particle in particles:
		# Calculate opacity based on remaining lifetime
		var opacity = particle.lifetime / particle.max_lifetime
		var draw_color = particle.color
		draw_color.a = opacity
		
		# Draw glow (if enabled)
		var glow_color = draw_color
		glow_color.a *= 0.4
		draw_circle(particle.position, particle.glow_size * glow_intensity, glow_color)
		
		# Draw particle shape
		draw_particle_shape(particle.position, particle.size, particle.rotation, draw_color, particle.shape_type)

func draw_particle_shape(position, size, rotation, color, shape_type):
	match shape_type:
		0:  # Triangle
			var points = PackedVector2Array([
				position + Vector2(0, -size).rotated(rotation),
				position + Vector2(-size, size).rotated(rotation),
				position + Vector2(size, size).rotated(rotation)
			])
			draw_colored_polygon(points, color)
		
		1:  # Square/Diamond
			var points = PackedVector2Array([
				position + Vector2(0, -size).rotated(rotation),
				position + Vector2(size, 0).rotated(rotation),
				position + Vector2(0, size).rotated(rotation),
				position + Vector2(-size, 0).rotated(rotation)
			])
			draw_colored_polygon(points, color)
		
		2:  # Circle (approximated with polygon)
			var points = PackedVector2Array()
			var segments = 8
			for i in range(segments):
				var angle = TAU * i / segments
				points.append(position + Vector2(cos(angle), sin(angle)) * size)
			draw_colored_polygon(points, color)
			
		3:  # Star shape (new)
			var points = PackedVector2Array()
			var outer_radius = size
			var inner_radius = size * 0.4
			var points_count = 5
			
			for i in range(points_count * 2):
				var angle = TAU * i / (points_count * 2)
				var radius = outer_radius if i % 2 == 0 else inner_radius
				points.append(position + Vector2(cos(angle), sin(angle)) * radius)
			
			draw_colored_polygon(points, color)

func set_particle_color(enemy_type):
	# Set particle color based on enemy type
	match enemy_type:
		"Normal":
			base_color = Color(0.8, 0.2, 0.2)  # Red
			color_intensity = 1.2
		"Fast":
			base_color = Color(0.2, 0.7, 0.8)  # Blue-Green
			color_intensity = 1.4
		"Tank":
			base_color = Color(0.2, 0.2, 0.8)  # Blue
			color_intensity = 1.3
		"Splitter":
			base_color = Color(0.8, 0.6, 0.2)  # Orange
			color_intensity = 1.5
		"Exploder":
			base_color = Color(1.0, 0.3, 0.0)  # Bright orange-red
			color_intensity = 1.6
			particle_count += 10  # More particles for exploder
		"Ranged":
			base_color = Color(0.7, 0.7, 0.2)  # Yellow
			color_intensity = 1.2
		"Teleporter":
			base_color = Color(0.5, 0.2, 0.8)  # Purple
			color_intensity = 1.4
		"Shielder":
			base_color = Color(0.2, 0.7, 0.2)  # Green
			color_intensity = 1.3
		"Boss":
			base_color = Color(1.0, 0.1, 0.1)  # Bright red
			color_intensity = 1.8
			particle_count *= 2  # Double particles for bosses
			glow_intensity = 2.0  # More glow for bosses
			impact_freeze = true  # Always freeze time for bosses
		_:
			base_color = Color(0.8, 0.2, 0.2)  # Default red
	
	# Reinitialize particles with the new color
	initialize_particles() 
