@tool
extends EditorScript

func _run():
	# This script adds the necessary components for the melee attack to the player scene
	
	# Find the player scene
	var player_scene_path = "res://scenes/player.tscn"
	if not FileAccess.file_exists(player_scene_path):
		print("Player scene not found at: " + player_scene_path)
		return
	
	var player_scene = load(player_scene_path)
	var player = player_scene.instantiate()
	
	# Find the BodyRotate node for the melee components
	var body_rotate = player.get_node_or_null("BodyRotate")
	if not body_rotate:
		print("BodyRotate node not found in player scene. Adding components to player root.")
		body_rotate = player
	
	# Add Melee Timer
	if not player.has_node("MeleeTimer"):
		var melee_timer = Timer.new()
		melee_timer.name = "MeleeTimer"
		melee_timer.one_shot = true
		melee_timer.wait_time = 0.4
		player.add_child(melee_timer)
		melee_timer.owner = player
		
		# Connect the timeout signal
		var script = player.get_script()
		if script and script.has_method("_on_melee_timer_timeout"):
			melee_timer.timeout.connect(player._on_melee_timer_timeout)
	
	# Add Melee Swing (visual representation)
	if not body_rotate.has_node("MeleeSwing"):
		var melee_swing = Polygon2D.new()
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
		melee_swing.position = Vector2(0, 0)
		melee_swing.visible = false
		body_rotate.add_child(melee_swing)
		melee_swing.owner = player
	
	# Add Melee Hitbox (collision area)
	if not body_rotate.has_node("MeleeHitbox"):
		var melee_hitbox = Area2D.new()
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
		collision_shape.owner = player
		body_rotate.add_child(melee_hitbox)
		melee_hitbox.owner = player
		
		# Connect the body_entered signal
		var script = player.get_script()
		if script and script.has_method("_on_melee_hitbox_body_entered"):
			melee_hitbox.body_entered.connect(player._on_melee_hitbox_body_entered)
	
	# Add Melee Impact Effect (particles)
	if not player.has_node("MeleeImpactEffect"):
		var impact_effect = GPUParticles2D.new()
		impact_effect.name = "MeleeImpactEffect"
		
		# Create particle material
		var material = ParticleProcessMaterial.new()
		material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		material.emission_sphere_radius = 5.0
		material.direction = Vector3(1, 0, 0)
		material.spread = 60.0
		material.initial_velocity_min = 80.0
		material.initial_velocity_max = 120.0
		material.gravity = Vector3(0, 0, 0)
		material.damping_min = 20.0
		material.damping_max = 40.0
		material.scale_min = 3.0
		material.scale_max = 5.0
		material.color = Color(1.0, 0.7, 0.3)
		material.color_ramp = Gradient.new()
		material.color_ramp.add_point(0.0, Color(1.0, 0.7, 0.3, 1.0))
		material.color_ramp.add_point(1.0, Color(1.0, 0.2, 0.1, 0.0))
		
		impact_effect.process_material = material
		impact_effect.amount = 16
		impact_effect.lifetime = 0.4
		impact_effect.explosiveness = 0.8
		impact_effect.one_shot = true
		impact_effect.emitting = false
		
		player.add_child(impact_effect)
		impact_effect.owner = player
	
	# Save the modified scene
	var packed_scene = PackedScene.new()
	packed_scene.pack(player)
	ResourceSaver.save(packed_scene, player_scene_path)
	
	# Cleanup
	player.queue_free()
	
	print("Melee components added to player scene successfully!") 