extends Area2D

# Circle drawer for ring effects
class CircleDrawer extends Node2D:
	var radius: float = 1.0
	var alpha: float = 1.0
	var color: Color = Color(1, 1, 1)
	
	func _process(_delta):
		queue_redraw()
	
	func _draw():
		var draw_color = Color(color.r, color.g, color.b, alpha)
		draw_circle(Vector2.ZERO, radius, draw_color)

@export var speed: float = 800.0
@export var damage: int = 30
@export var piercing: bool = false
@export var tracking: bool = false
@export var target_node = null
@export var tracking_speed: float = 3.0
@export var chain_count: int = 0
@export var chain_range: float = 0.0
@export var already_hit: Array = []
@export var orbital_mode: bool = false

@onready var bullet_particle = preload("res://scenes/bullet_particle.tscn")
@onready var bullet_hit_sound = preload("res://scenes/bullet_hit_sound.tscn")

func _physics_process(delta):
	# Skip movement for orbital projectiles (handled by player)
	if orbital_mode:
		return
		
	# Handle tracking - adjust direction if tracking is enabled
	if tracking and is_instance_valid(target_node):
		var direction_to_target = global_position.direction_to(target_node.global_position)
		transform = transform.interpolate_with(
			Transform2D(direction_to_target.angle(), global_position),
			tracking_speed * delta
		)
	
	# Move the bullet forward
	position += transform.x * speed * delta
	
	# Clean up if bullet goes too far offscreen (3000 pixels away from center)
	if global_position.length() > 3000:
		queue_free()

func setup(trans: Transform2D):
	transform = trans
	
	# If tracking enabled, find the nearest enemy
	if tracking:
		find_target()

func set_pierce(value: bool):
	piercing = value

func set_tracking(value: bool):
	tracking = value
	if tracking:
		find_target()

func set_orbital_mode(value: bool):
	orbital_mode = value
	if orbital_mode:
		# Adjust collision for orbital mode
		set_collision_mask_value(1, false) # Disable player collision
		set_collision_mask_value(2, true)  # Enable enemy collision

func set_chain_properties(count: int, range: float):
	chain_count = count
	chain_range = range

func find_target():
	# Get all enemies in the scene
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.size() == 0:
		return
		
	# Find the closest enemy
	var closest_enemy = null
	var closest_distance = INF
	
	for enemy in enemies:
		if is_instance_valid(enemy):
			# Skip enemies already hit by this chain
			if already_hit.has(enemy):
				continue
				
			var distance = global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	
	target_node = closest_enemy

func chain_to_next_enemy(hit_enemy):
	# If we've used up all chains, stop
	if chain_count <= 0:
		return
		
	# Reduce chain count
	chain_count -= 1
	
	# Add current enemy to already hit list
	already_hit.append(hit_enemy)
	
	# Find next target within range
	var enemies = get_tree().get_nodes_in_group("enemies")
	var next_target = null
	var closest_distance = chain_range
	
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy != hit_enemy and !already_hit.has(enemy):
			var distance = hit_enemy.global_position.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				next_target = enemy
	
	# If no valid target found, stop chaining
	if next_target == null:
		return
		
	# Create lightning effect between enemies
	create_lightning_effect(hit_enemy.global_position, next_target.global_position)
	
	# Damage the next enemy
	next_target.get_hit(damage, Transform2D(0, next_target.global_position))
	
	# Continue the chain
	chain_to_next_enemy(next_target)

func create_lightning_effect(start_pos: Vector2, end_pos: Vector2):
	# Create a more dramatic lightning effect
	var lightning = Line2D.new()
	lightning.width = 5.0
	lightning.default_color = Color(0.4, 0.4, 1.0, 0.8)
	
	# Add glow effect
	var glow = RectangleShape2D.new()
	glow.size = Vector2(5, 5)
	lightning.set_meta("glow_radius", 3.0)
	
	# Add zigzag points with more detail
	var distance = start_pos.distance_to(end_pos)
	var direction = (end_pos - start_pos).normalized()
	var perpendicular = direction.rotated(PI/2)
	
	var segments = 8 # More segments for more detail
	var points = []
	
	# Start point
	points.append(start_pos)
	
	# Middle zigzag points with more randomness
	for i in range(1, segments):
		var fraction = float(i) / segments
		var point = start_pos.lerp(end_pos, fraction)
		
		# Add increasing randomness toward middle
		var random_factor = sin(fraction * PI) * 1.5
		var offset = perpendicular * randf_range(-15, 15) * random_factor
		point += offset
		
		points.append(point)
	
	# End point
	points.append(end_pos)
	
	# Set the line's points
	lightning.points = PackedVector2Array(points)
	
	# Add to scene
	get_tree().root.add_child(lightning)
	
	# Animate the lightning
	var tween = create_tween()
	tween.tween_property(lightning, "default_color", Color(0.4, 0.4, 1.0, 0.0), 0.3)
	tween.parallel().tween_property(lightning, "width", 2.0, 0.3)
	var free_lightning_func = func(): lightning.queue_free()
	tween.tween_callback(free_lightning_func)
	
	# Add smaller arcs for more detail
	add_secondary_arcs(start_pos, end_pos, lightning.default_color)
	
	return lightning

func add_secondary_arcs(start_pos: Vector2, end_pos: Vector2, color: Color):
	# Add 1-3 smaller branching arcs for more dramatic effect
	var num_arcs = randi() % 3 + 1
	
	for i in range(num_arcs):
		# Create branch point somewhere along the main arc
		var branch_start = start_pos.lerp(end_pos, randf_range(0.2, 0.8))
		
		# Create a random direction for the branch
		var main_direction = (end_pos - start_pos).normalized()
		var branch_angle = main_direction.angle() + randf_range(-PI/2, PI/2)
		var branch_length = start_pos.distance_to(end_pos) * randf_range(0.2, 0.4)
		var branch_end = branch_start + Vector2(cos(branch_angle), sin(branch_angle)) * branch_length
		
		# Create the branch line
		var branch = Line2D.new()
		branch.width = 2.0
		branch.default_color = Color(color.r, color.g, color.b, color.a * 0.7)
		
		# Add points to the branch
		var branch_points = []
		branch_points.append(branch_start)
		
		# Add zigzags
		var segments = 4
		for j in range(1, segments):
			var fraction = float(j) / segments
			var point = branch_start.lerp(branch_end, fraction)
			
			# Add randomness
			var perpendicular = Vector2(cos(branch_angle + PI/2), sin(branch_angle + PI/2))
			var offset = perpendicular * randf_range(-8, 8)
			point += offset
			
			branch_points.append(point)
		
		branch_points.append(branch_end)
		branch.points = PackedVector2Array(branch_points)
		
		# Add to scene
		get_tree().root.add_child(branch)
		
		# Animate and remove
		var tween = create_tween()
		tween.tween_property(branch, "default_color", Color(color.r, color.g, color.b, 0.0), 0.2)
		var free_branch_func = func(): branch.queue_free()
		tween.tween_callback(free_branch_func)

func _on_body_entered(body):
	if body.is_in_group("enemies"):
		if body.has_method("get_hit"):
			# Apply damage with more impact
			body.get_hit(damage, global_transform)
			
			# Create dramatically enhanced visual effects
			create_impact_explosion(global_position, body)
			
			# Handle chaining logic
			if chain_count > 0:
				chain_to_next_enemy(body)
			
			# If piercing or orbital, don't destroy the bullet
			if piercing or orbital_mode:
				return
			else:
				queue_free()
	else:
		# Hit something that's not an enemy (if not in orbital mode)
		if not orbital_mode:
			queue_free()

func create_impact_explosion(pos: Vector2, target = null):
	# Impact explosions disabled
	return
	
	# Original code below (now disabled)
	# Create spectacular impact effect
	var bullet_effect = bullet_particle.instantiate()
	get_tree().root.add_child(bullet_effect)
	bullet_effect.setup(global_transform)
	
	# More impact particles
	if bullet_effect.get("amount"):
		bullet_effect.amount = 30
	
	# Create expanding ring effect
	var ring = await create_impact_ring(pos)
	
	# Bullet hit sound with randomized pitch for variety
	var bullet_hit_player = bullet_hit_sound.instantiate()
	get_tree().root.add_child(bullet_hit_player)
	bullet_hit_player.pitch_scale = randf_range(0.9, 1.1) # Random pitch
	bullet_hit_player.volume_db += 3.0 # Louder!
	bullet_hit_player.play()
	
	# Create small numbers showing damage amount
	if damage > 0:
		await spawn_damage_number(pos, damage)

func create_impact_ring(pos: Vector2):
	# Disabled ring effect
	return
	
	# Original code below (now disabled)
	# Create a circle that expands outward
	var ring = Node2D.new()
	ring.position = pos
	get_tree().root.add_child(ring)
	
	# Create the drawer node
	var circle_drawer = CircleDrawer.new()
	
	# Setup the drawer
	circle_drawer.radius = 5.0
	circle_drawer.alpha = 0.7
	circle_drawer.color = modulate
	ring.add_child(circle_drawer)
	
	# Animate the ring expansion
	var tween = create_tween()
	tween.tween_property(circle_drawer, "radius", 40.0, 0.4)
	tween.parallel().tween_property(circle_drawer, "alpha", 0.0, 0.4)
	var free_ring_func = func(): ring.queue_free()
	tween.tween_callback(free_ring_func)
	
	# Ensure the circle is removed even if tween fails
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(ring) and not ring.is_queued_for_deletion():
		ring.queue_free()
	
	return ring

func spawn_damage_number(pos: Vector2, amount: int):
	# Create floating damage number
	var damage_label = Label.new()
	damage_label.text = str(amount)
	damage_label.position = pos
	damage_label.add_theme_font_size_override("font_size", 20 + int(min(amount / 5, 15)))
	
	# Make critical hits stand out
	var is_critical = randf() < 0.2 # 20% chance of critical
	if is_critical:
		amount *= 2 # Double damage for critical hits
		damage_label.text = str(amount) + "!"
		damage_label.add_theme_font_size_override("font_size", 30 + int(min(amount / 5, 15)))
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	else:
		damage_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	
	# Add outline for better visibility
	damage_label.add_theme_constant_override("outline_size", 2)
	damage_label.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	
	# Center the text
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	get_tree().root.add_child(damage_label)
	
	# Animate the damage number
	var tween = create_tween()
	tween.tween_property(damage_label, "position", pos + Vector2(0, -50), 0.8)
	
	# Make critical hits have more dramatic animation
	if is_critical:
		tween.parallel().tween_property(damage_label, "scale", Vector2(1.5, 1.5), 0.2)
		tween.parallel().tween_property(damage_label, "modulate", Color(1, 0.1, 0.1, 1), 0.2)
		tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.6)
	
	tween.tween_property(damage_label, "modulate", Color(1, 1, 1, 0), 0.5)
	var free_label_func = func(): damage_label.queue_free()
	tween.tween_callback(free_label_func)
	
	# Ensure the damage number is removed even if tween fails
	await get_tree().create_timer(1.5).timeout
	if is_instance_valid(damage_label) and not damage_label.is_queued_for_deletion():
		damage_label.queue_free()
