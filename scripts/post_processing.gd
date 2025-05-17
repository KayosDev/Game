extends CanvasLayer

# Animation variables
var time_passed = 0.0
var active_effects = []
var intensity_scale = 1.0  # Used to control global intensity of effects
var bloom_size = 0.7       # Controls the size of bloom

# Lighting variables
var light_positions = []
var light_colors = []
var light_intensities = []
var light_speeds = []

func _ready():
	# Set process mode to always process
	process_mode = PROCESS_MODE_ALWAYS
	
	# Initialize light sources
	initialize_light_sources()
	
	# Ensure shaders are initialized
	$Bloom.material.set_shader_parameter("bloom_intensity", 0.4)
	$Bloom.material.set_shader_parameter("bloom_threshold", 0.6)
	$Bloom.material.set_shader_parameter("bloom_size", bloom_size)
	
	$ChromaticAberration.material.set_shader_parameter("aberration_amount", 0.5)
	$ChromaticAberration.material.set_shader_parameter("aberration_offset", Vector2(0.001, 0.001))
	
	$Vignette.material.set_shader_parameter("vignette_intensity", 0.4)
	$Vignette.material.set_shader_parameter("vignette_color", Color(0.05, 0.0, 0.1, 1.0))
	
	$FilmGrain.material.set_shader_parameter("grain_amount", 0.03)
	$FilmGrain.material.set_shader_parameter("grain_speed", 25.0)
	
	# Set proper draw order for the ColorRect nodes
	# The order in the scene tree already determines rendering order
	# We can use CanvasItem's z_index for fine-tuning if needed
	$Bloom.z_as_relative = false
	$DynamicLighting.z_as_relative = false
	$ChromaticAberration.z_as_relative = false
	$Vignette.z_as_relative = false
	$FilmGrain.z_as_relative = false
	
	$Bloom.z_index = 1
	$DynamicLighting.z_index = 2
	$ChromaticAberration.z_index = 3
	$Vignette.z_index = 4
	$FilmGrain.z_index = 5

func _process(delta):
	time_passed += delta
	
	# Update bloom effect
	update_bloom_effect(delta)
	
	# Update dynamic lighting
	update_dynamic_lighting(delta)
	
	# Update chromatic aberration based on game intensity
	update_chromatic_aberration(delta)
	
	# Pulse vignette subtly
	update_vignette(delta)
	
	# Update film grain effect
	update_film_grain(delta)
	
	# Automatically adjust effects based on game context
	adapt_effects_to_gameplay(delta)

func initialize_light_sources():
	# Create several dynamic light sources
	var viewport_size = get_viewport().size
	var num_lights = 5
	
	for i in range(num_lights):
		var pos = Vector2(
			randf_range(0, viewport_size.x),
			randf_range(0, viewport_size.y)
		)
		
		var light_color
		var intensity
		
		# Create different types of lights
		match i % 3:
			0:  # Purple light
				light_color = Color(0.7, 0.3, 1.0, 0.8) 
				intensity = randf_range(0.4, 0.7)
			1:  # Blue light
				light_color = Color(0.2, 0.4, 1.0, 0.7)
				intensity = randf_range(0.3, 0.6)
			2:  # Pink light
				light_color = Color(1.0, 0.3, 0.7, 0.8)
				intensity = randf_range(0.3, 0.6)
		
		# Store light properties
		light_positions.append(pos)
		light_colors.append(light_color)
		light_intensities.append(intensity)
		light_speeds.append(Vector2(
			randf_range(-40, 40),
			randf_range(-40, 40)
		))

func update_bloom_effect(delta):
	# Make bloom pulsate slightly
	var bloom_intensity = 0.4 + sin(time_passed * 0.8) * 0.1
	$Bloom.material.set_shader_parameter("bloom_intensity", bloom_intensity * intensity_scale)
	
	# Subtle change in bloom size
	bloom_size = 0.7 + sin(time_passed * 0.5) * 0.1
	$Bloom.material.set_shader_parameter("bloom_size", bloom_size)

func update_dynamic_lighting(delta):
	# Update light positions
	for i in range(len(light_positions)):
		light_positions[i] += light_speeds[i] * delta
		
		# Bounce off screen edges
		var viewport_size = get_viewport().size
		if light_positions[i].x < 0 or light_positions[i].x > viewport_size.x:
			light_speeds[i].x = -light_speeds[i].x
		if light_positions[i].y < 0 or light_positions[i].y > viewport_size.y:
			light_speeds[i].y = -light_speeds[i].y
			
		# Keep within screen bounds
		light_positions[i].x = clamp(light_positions[i].x, 0, viewport_size.x)
		light_positions[i].y = clamp(light_positions[i].y, 0, viewport_size.y)
	
	# Update the shader with the new light positions
	var packed_positions = PackedVector2Array(light_positions)
	var packed_colors = PackedColorArray(light_colors)
	var packed_intensities = PackedFloat32Array(light_intensities)
	
	$DynamicLighting.material.set_shader_parameter("light_positions", packed_positions)
	$DynamicLighting.material.set_shader_parameter("light_colors", packed_colors)
	$DynamicLighting.material.set_shader_parameter("light_intensities", packed_intensities)
	$DynamicLighting.material.set_shader_parameter("num_lights", len(light_positions))
	$DynamicLighting.material.set_shader_parameter("time", time_passed)

func update_chromatic_aberration(delta):
	# Subtle pulsing of chromatic aberration
	var aberration = 0.5 + sin(time_passed * 1.2) * 0.1
	var offset = 0.001 + sin(time_passed * 0.9) * 0.0005
	
	$ChromaticAberration.material.set_shader_parameter("aberration_amount", aberration * intensity_scale)
	$ChromaticAberration.material.set_shader_parameter("aberration_offset", Vector2(offset, offset))

func update_vignette(delta):
	# Subtle pulsing vignette
	var vignette_intensity = 0.4 + sin(time_passed * 0.6) * 0.05
	$Vignette.material.set_shader_parameter("vignette_intensity", vignette_intensity * intensity_scale)

func update_film_grain(delta):
	# Update the grain time value for animated noise
	$FilmGrain.material.set_shader_parameter("grain_time", time_passed)

func adapt_effects_to_gameplay(delta):
	# This would be adjusted based on game events like:
	# - Player taking damage (increase intensity)
	# - Player near death (increase red vignette)
	# - Player getting power-up (increase bloom, adjust colors)
	# - Intense action (increase all effects)
	pass

# Public methods to control effects externally
func increase_intensity(amount = 0.2, duration = 0.5):
	# Save the current intensity
	var original_intensity = intensity_scale
	
	# Increase the intensity immediately
	intensity_scale += amount
	
	# Create a tween to restore intensity after duration
	var tween = create_tween()
	tween.tween_property(self, "intensity_scale", original_intensity, duration)

func set_intensity(value):
	intensity_scale = value

# Method to add a temporary light effect at position
func add_light_flash(position, color = Color(1.0, 0.7, 0.3, 0.9), duration = 0.5):
	# Add a new light
	light_positions.append(position)
	light_colors.append(color)
	light_intensities.append(1.0)  # Start at full intensity
	light_speeds.append(Vector2(0, 0))  # Static light
	
	var light_index = light_positions.size() - 1
	
	# Create a tween to fade out the light and use a safe approach
	var tween = create_tween()
	
	# Define a function to safely update the intensity
	var update_intensity = func(value):
		if light_index < light_intensities.size():
			light_intensities[light_index] = value
	
	# Fade out the light
	tween.tween_method(update_intensity, 1.0, 0.0, duration)
	
	# After duration, remove the light
	tween.tween_callback(func():
		if light_index < light_positions.size():
			light_positions.remove_at(light_index)
			light_colors.remove_at(light_index)
			light_intensities.remove_at(light_index)
			light_speeds.remove_at(light_index)
	) 
