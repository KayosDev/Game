extends Node2D

@export var lifetime = 2.0  # How long particles live
@export var particle_count = 20  # Number of particles to spawn
@export var min_size = 3.0  # Minimum particle size
@export var max_size = 8.0  # Maximum particle size
@export var min_speed = 80.0  # Minimum particle speed
@export var max_speed = 200.0  # Maximum particle speed
@export var gravity = 400.0  # Gravity pulling particles down
@export var damping = 0.9  # Speed reduction per second

var particles = []  # List of particle objects
var time_elapsed = 0.0  # Track how long the effect has been running
var base_color = Color(0.8, 0.2, 0.2)  # Default red color for particles

class Particle:
	var position: Vector2
	var velocity: Vector2
	var rotation: float
	var rotation_speed: float
	var size: float
	var color: Color
	var lifetime: float
	var max_lifetime: float
	
	func _init(pos, vel, rot_speed, sz, col, life):
		position = pos
		velocity = vel
		rotation = randf_range(0, TAU)
		rotation_speed = rot_speed
		size = sz
		color = col
		lifetime = life
		max_lifetime = life
	
	func update(delta, gravity, damping):
		# Update position based on velocity
		position += velocity * delta
		
		# Apply gravity
		velocity.y += gravity * delta
		
		# Apply damping
		velocity *= pow(damping, delta)
		
		# Update rotation
		rotation += rotation_speed * delta
		
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

func initialize_particles():
	particles.clear()
	
	# Create particles with random properties
	for i in range(particle_count):
		var angle = randf_range(0, TAU)
		var speed = randf_range(min_speed, max_speed)
		var velocity = Vector2(cos(angle), sin(angle)) * speed
		
		# Randomize other properties
		var rot_speed = randf_range(-5.0, 5.0)
		var size = randf_range(min_size, max_size)
		
		# Slightly vary the color
		var color_variation = randf_range(-0.1, 0.1)
		var particle_color = base_color
		particle_color.r = clamp(particle_color.r + color_variation, 0, 1)
		particle_color.g = clamp(particle_color.g + color_variation, 0, 1)
		particle_color.b = clamp(particle_color.b + color_variation, 0, 1)
		
		# Create the particle
		particles.append(Particle.new(
			Vector2.ZERO,  # Start at center
			velocity,
			rot_speed,
			size,
			particle_color,
			randf_range(lifetime * 0.5, lifetime)
		))

func _process(delta):
	time_elapsed += delta
	
	# Update particles
	for i in range(particles.size() - 1, -1, -1):
		if not particles[i].update(delta, gravity, damping):
			particles.remove_at(i)
	
	# Force redraw
	queue_redraw()
	
	# If all particles are gone, we can free this node
	if particles.size() == 0:
		queue_free()

func _draw():
	# Draw each particle
	for particle in particles:
		# Calculate opacity based on remaining lifetime
		var opacity = particle.lifetime / particle.max_lifetime
		var draw_color = particle.color
		draw_color.a = opacity
		
		# Draw as polygons for more interesting shapes
		draw_particle_shape(particle.position, particle.size, particle.rotation, draw_color)

func draw_particle_shape(position, size, rotation, color):
	# Choose between different shapes
	var shape_type = randi() % 3
	
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

func set_particle_color(enemy_type):
	# Set particle color based on enemy type
	match enemy_type:
		"basic":
			base_color = Color(0.8, 0.2, 0.2)  # Red
		"fast":
			base_color = Color(0.2, 0.7, 0.2)  # Green
		"tank":
			base_color = Color(0.2, 0.2, 0.8)  # Blue
		"splitter":
			base_color = Color(0.8, 0.6, 0.2)  # Orange
		"bomber":
			base_color = Color(0.7, 0.2, 0.7)  # Purple
		"shooter":
			base_color = Color(0.2, 0.7, 0.7)  # Cyan
		_:
			base_color = Color(0.8, 0.2, 0.2)  # Default red
	
	# Reinitialize particles with the new color
	initialize_particles() 