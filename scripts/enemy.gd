extends CharacterBody2D

signal enemy_destroyed(enemy)

# This was the old CircleDrawer class used for ring effects
# Removed as we now use the physics-based particle system instead

@export var health: int = 100
@export var max_health: int = 100
@export var speed: float = 120.0  # Increased base speed (was 50.0)
@export var damage: int = 10 # Damage dealt to player
@export var damage_cooldown: float = 0.5 # Time between damage ticks
@export var recoil_strength: float = 300.0 # How much enemy recoils when hit
@export_enum("Normal", "Fast", "Tank", "Ranged", "Exploder", "Splitter", "Teleporter", "Shielder", "Boss") var enemy_type: String = "Normal"

var player: CharacterBody2D
var push_dir: Vector2 = Vector2(0, 0)
var push_strength: float = 0.0
var push_timer: float = 0.0
var damage_timer: float = 0.0 # Timer for damage cooldown
var is_health_bar_visible: bool = false
var health_bar_visible_timer: float = 0.0
var movement_pattern: String = "direct" # Can be "direct", "circle", "zigzag", "teleport", "charge"
var circle_radius: float = 100.0
var circle_speed: float = 2.0
var zigzag_amplitude: float = 50.0
var zigzag_frequency: float = 3.0
var time_alive: float = 0.0
var special_ability_cooldown: float = 0.0
var charge_cooldown: float = 0.0
var charge_ready: bool = false
var teleport_cooldown: float = 0.0
var shield_active: bool = false
var shield_health: int = 50
var children_spawned: bool = false
var projectile_cooldown: float = 0.0
var boss_phase: int = 1
var invulnerable: bool = false
var invulnerable_timer: float = 0.0

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var damage_text: Label = $DamageTextContainer/DamageText
@onready var blood_particle = preload("res://scenes/blood_particle.tscn")
@onready var blood_stain = preload("res://scenes/blood_stain.tscn")
@onready var damage_area: Area2D = $DamageArea
@onready var health_bar: ProgressBar = $HealthBar

func _ready():
	damage_text.visible = false
	damage_timer = 0.0
	health = max_health
	
	# Improve health bar appearance
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_bar.visible = false
		
		# Create better stylebox for health bar
		var style_bg = StyleBoxFlat.new()
		style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.7)
		style_bg.corner_radius_top_left = 3
		style_bg.corner_radius_top_right = 3
		style_bg.corner_radius_bottom_left = 3
		style_bg.corner_radius_bottom_right = 3
		style_bg.border_width_left = 1
		style_bg.border_width_top = 1
		style_bg.border_width_right = 1
		style_bg.border_width_bottom = 1
		style_bg.border_color = Color(0, 0, 0, 0.3)
		
		var style_fill = StyleBoxFlat.new()
		style_fill.bg_color = Color(0.7, 0.2, 0.2)
		style_fill.corner_radius_top_left = 3
		style_fill.corner_radius_top_right = 3
		style_fill.corner_radius_bottom_left = 3
		style_fill.corner_radius_bottom_right = 3
		
		health_bar.add_theme_stylebox_override("background", style_bg)
		health_bar.add_theme_stylebox_override("fill", style_fill)
		health_bar.modulate = Color(1.0, 1.0, 1.0, 0.9)
		health_bar.size = Vector2(60, 6)
		health_bar.position = Vector2(-30, -45)
	
	# Setup damage text with better appearance
	if damage_text:
		damage_text.add_theme_font_size_override("font_size", 24)
		damage_text.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		damage_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		damage_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Add outline to damage text for better visibility
		damage_text.add_theme_constant_override("outline_size", 2)
		damage_text.add_theme_color_override("font_outline_color", Color(0.1, 0.1, 0.1))
	
	# Connect the damage area signal if it exists and isn't already connected
	if has_node("DamageArea"):
		var area = get_node("DamageArea")
		if not area.is_connected("body_entered", _on_damage_area_body_entered):
			area.connect("body_entered", _on_damage_area_body_entered)
	
	# Configure enemy based on type
	configure_enemy_type()
	
	# Make shield inactive by default
	shield_active = false
	
	# Add to enemies group for targeting
	add_to_group("enemies")

func configure_enemy_type():
	match enemy_type:
		"Normal":
			# Default values
			speed = 120.0
			health = 100
			max_health = 100
			damage = 25 # Increased from 10
			movement_pattern = "direct"
			modulate = Color(1, 1, 1)
		"Fast":
			# Fast but weak enemy
			speed = 200.0
			health = 70
			max_health = 70
			damage = 20 # Increased from 8
			movement_pattern = "zigzag"
			modulate = Color(0.2, 0.8, 1.0)
		"Tank":
			# Slow but tough enemy
			speed = 80.0
			health = 180
			max_health = 180
			damage = 35 # Increased from 15
			movement_pattern = "direct"
			modulate = Color(1.0, 0.4, 0.4)
		"Ranged":
			# Keeps distance and circles the player
			speed = 100.0
			health = 90
			max_health = 90
			damage = 30 # Increased from 12
			movement_pattern = "circle"
			modulate = Color(0.8, 0.8, 0.2)
		"Exploder":
			# Rushes toward player and explodes
			speed = 140.0
			health = 60
			max_health = 60
			damage = 50 # Increased from 25
			movement_pattern = "charge"
			modulate = Color(1.0, 0.5, 0.0)
		"Splitter":
			# Splits into smaller enemies when killed
			speed = 90.0
			health = 120
			max_health = 120
			damage = 25 # Increased from 10
			movement_pattern = "direct"
			scale = Vector2(1.3, 1.3)
			modulate = Color(0.6, 0.2, 0.6)
		"Teleporter":
			# Teleports around the player
			speed = 110.0
			health = 80
			max_health = 80
			damage = 35 # Increased from 14
			movement_pattern = "teleport"
			modulate = Color(0.4, 0.4, 1.0)
		"Shielder":
			# Has a shield that must be broken first
			speed = 70.0
			health = 100
			max_health = 100
			damage = 30 # Increased from 12
			shield_active = true
			shield_health = 50
			movement_pattern = "direct"
			modulate = Color(0.3, 0.7, 0.3)
		"Boss":
			# Multi-phase boss enemy
			speed = 60.0
			health = 500
			max_health = 500
			damage = 45 # Increased from 20
			movement_pattern = "circle"
			scale = Vector2(2.0, 2.0)
			modulate = Color(0.9, 0.2, 0.2)
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = health
		health_bar.visible = true
		is_health_bar_visible = true
		
		# Make boss health bar stay visible
		if enemy_type == "Boss":
			health_bar_visible_timer = 999999.0

func setup(pos: Vector2, _player: CharacterBody2D):
	position = pos
	player = _player
	health = max_health
	is_health_bar_visible = false
	health_bar_visible_timer = 0.0
	time_alive = 0.0
	if health_bar:
		health_bar.value = health
		health_bar.visible = false
	
	# Reset special ability timers
	special_ability_cooldown = 2.0
	charge_cooldown = 3.0
	teleport_cooldown = 4.0
	projectile_cooldown = 2.0
	
	# Reset flags
	charge_ready = false
	children_spawned = false
	
	# Make boss health bar visible immediately
	if enemy_type == "Boss":
		if health_bar:
			health_bar.visible = true
			is_health_bar_visible = true
			health_bar_visible_timer = 999999.0

func _physics_process(delta):
	time_alive += delta
	
	# Check if player reference is valid
	if not is_instance_valid(player):
		return
	
	# Handle different movement patterns
	match movement_pattern:
		"direct":
			direct_movement()
		"circle":
			circle_movement(delta)
		"zigzag":
			zigzag_movement(delta)
		"charge":
			charge_movement(delta)
		"teleport":
			teleport_movement(delta)
	
	move_and_slide()
	
	# Handle push
	push_back(delta)
	
	# Reduce timers
	if damage_timer > 0:
		damage_timer -= delta
	
	if special_ability_cooldown > 0:
		special_ability_cooldown -= delta
	else:
		use_special_ability(delta)
		special_ability_cooldown = randf_range(3.0, 6.0)
	
	if charge_cooldown > 0:
		charge_cooldown -= delta
	else:
		charge_ready = true
	
	if teleport_cooldown > 0:
		teleport_cooldown -= delta
	
	if projectile_cooldown > 0:
		projectile_cooldown -= delta
	else:
		if enemy_type == "Ranged" or enemy_type == "Boss":
			shoot_projectile()
			projectile_cooldown = randf_range(1.0, 3.0)
	
	# Handle health bar visibility
	if is_health_bar_visible:
		health_bar_visible_timer -= delta
		if health_bar_visible_timer <= 0 and enemy_type != "Boss":
			is_health_bar_visible = false
			if health_bar:
				health_bar.visible = false
				
	# Check for player collision continuously
	check_player_collision()

# Check if the enemy is overlapping with the player and deal damage if necessary
func check_player_collision():
	# Only check if damage cooldown has expired
	if damage_timer <= 0 and is_instance_valid(player):
		# Check if damage area is overlapping with player
		var overlapping_bodies = damage_area.get_overlapping_bodies()
		if overlapping_bodies.has(player):
			deal_damage_to_player()

func direct_movement():
	if is_instance_valid(player):
		var dir = (player.global_position - global_position).normalized()
		velocity = dir * speed
	else:
		velocity = Vector2.ZERO

func circle_movement(delta):
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
		
	var dir_to_player = player.global_position - global_position
	var distance = dir_to_player.length()
	
	if distance > circle_radius * 1.5:
		# Move closer to player if too far
		velocity = dir_to_player.normalized() * speed
	elif distance < circle_radius * 0.8:
		# Move away from player if too close
		velocity = -dir_to_player.normalized() * speed
	else:
		# Circle around player
		var tangent = Vector2(-dir_to_player.y, dir_to_player.x).normalized()
		velocity = tangent * speed
		
		# Add some randomness to avoid perfect circles
		velocity = velocity.rotated(sin(time_alive * 0.5) * 0.2)

func zigzag_movement(delta):
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
		
	var dir = (player.global_position - global_position).normalized()
	var perpendicular = Vector2(-dir.y, dir.x)
	
	# Sine wave movement perpendicular to direction to player
	var zigzag = perpendicular * sin(time_alive * zigzag_frequency) * zigzag_amplitude
	
	# Base velocity toward player with zigzag added
	velocity = (dir * speed) + zigzag

func charge_movement(delta):
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
		
	if charge_ready:
		# Prepare to charge by slowing down
		if velocity.length() > speed * 0.5:
			velocity = velocity.lerp(Vector2.ZERO, delta * 3.0)
		else:
			# Charge toward player
			var dir = (player.global_position - global_position).normalized()
			velocity = dir * speed * 3.0
			charge_ready = false
			charge_cooldown = randf_range(2.0, 4.0)
			
			# If exploder, check if close to player for explosion
			if enemy_type == "Exploder" and (player.global_position - global_position).length() < 50:
				explode()
	else:
		# Normal movement between charges
		direct_movement()

func teleport_movement(delta):
	if not is_instance_valid(player):
		velocity = Vector2.ZERO
		return
		
	if teleport_cooldown <= 0:
		# Teleport to a random position near the player
		var random_offset = Vector2(randf_range(-200, 200), randf_range(-200, 200))
		position = player.global_position + random_offset
		
		# Brief invulnerability after teleporting
		invulnerable = true
		invulnerable_timer = 0.5
		
		teleport_cooldown = randf_range(3.0, 6.0)
		
		# Show teleport effect (flash)
		modulate.a = 0.5
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 1.0, 0.3)
	else:
		# Normal movement when not teleporting
		direct_movement()

func use_special_ability(delta):
	if not is_instance_valid(player):
		return
		
	match enemy_type:
		"Boss":
			use_boss_abilities(delta)
		"Exploder":
			check_explosion()
		"Splitter":
			check_split()

func use_boss_abilities(delta):
	if not is_instance_valid(player):
		return
		
	match boss_phase:
		"Boss":
			if health < max_health * 0.7:
				boss_phase = 2
				speed *= 1.5
				movement_pattern = "teleport"
			elif health < max_health * 0.3:
				boss_phase = 3
				spawn_minions()
				shield_active = true
				shield_health = 100
				modulate = Color(1.0, 0.4, 0.0)

func check_explosion():
	if not is_instance_valid(player):
		return
		
	var distance_to_player = global_position.distance_to(player.global_position)
	if distance_to_player < 50:
		# Explode
		var explosion = create_explosion(global_position, 100, 80)
		destroy()

func shoot_projectile():
	if not is_instance_valid(player):
		return
		
	var projectile = Area2D.new()
	projectile.position = global_position
	
	# Create sprite
	var proj_sprite = Polygon2D.new()
	var points = PackedVector2Array([Vector2(-5, -5), Vector2(5, -5), Vector2(5, 5), Vector2(-5, 5)])
	proj_sprite.polygon = points
	proj_sprite.color = Color(1.0, 0.3, 0.3)
	projectile.add_child(proj_sprite)
	
	# Add collision
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 10
	collision.shape = shape
	projectile.add_child(collision)
	
	# Set collision properties
	projectile.collision_layer = 4 # Enemy projectile layer
	projectile.collision_mask = 1  # Player layer
	
	# Add to scene
	get_tree().root.add_child(projectile)
	
	# Launch toward player with some randomness
	var target_pos = player.global_position
	var random_offset = Vector2(randf_range(-30, 30), randf_range(-30, 30))
	target_pos += random_offset
	
	var direction = (target_pos - global_position).normalized()
	var projectile_speed = 200
	
	# Add script to handle movement and collision
	projectile.set_meta("direction", direction)
	projectile.set_meta("speed", projectile_speed)
	projectile.set_meta("damage", 15)
	
	projectile.body_entered.connect(_on_projectile_body_entered.bind(projectile))
	
	# Create a custom process function for the projectile
	projectile.set_process(true)
	projectile.set_script(create_projectile_script())

func deal_damage_to_player():
	if damage_timer <= 0 and is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(damage)
		damage_timer = damage_cooldown

func explode():
	# Create simplified explosion effect
	var particle = blood_particle.instantiate()
	get_tree().root.call_deferred("add_child", particle)
	particle.global_position = global_position
	particle.modulate = Color(1.0, 0.5, 0.0)
	
	# Deal area damage to player if nearby
	if is_instance_valid(player):
		var distance = (player.global_position - global_position).length()
		if distance < 100:
			var explosion_damage = int(30 * (1.0 - distance / 100.0))
			if explosion_damage > 0 and player.has_method("take_damage"):
				player.take_damage(explosion_damage)
	
	# Self-destruct
	destroy()

func spawn_mini_splitters():
	if children_spawned:
		return
	
	children_spawned = true
	
	# Spawn only 2 smaller versions instead of 3 to reduce lag
	for i in range(2):
		var mini = duplicate()
		mini.scale = Vector2(0.6, 0.6)
		mini.health = 40
		mini.max_health = 40
		mini.children_spawned = true  # Prevent infinite splitting
		
		var angle = TAU * i / 2
		var dist = 30
		var pos = global_position + Vector2(cos(angle), sin(angle)) * dist
		
		get_tree().root.call_deferred("add_child", mini)
		mini.setup(pos, player)

func spawn_minions():
	# Spawn support enemies for boss
	for i in range(4):
		var minion_type = ["Fast", "Ranged"][randi() % 2]
		var minion = duplicate()
		minion.enemy_type = minion_type
		minion.scale = Vector2(0.8, 0.8)
		minion.configure_enemy_type()
		
		var angle = TAU * i / 4
		var dist = 80
		var pos = global_position + Vector2(cos(angle), sin(angle)) * dist
		
		get_tree().root.add_child(minion)
		minion.setup(pos, player)

func get_hit(damage: int, bullet_trans: Transform2D):
	# If shield is active, damage shield first
	if shield_active:
		shield_health -= damage
		
		if shield_health <= 0:
			shield_active = false
			modulate = Color(1, 1, 1)  # Normal color when shield breaks
		else:
			# Flash shield but don't take damage
			modulate = Color(0.8, 0.8, 1.0, 0.8)
			animation_tree['parameters/conditions/is_damaged'] = true
			return
	
	# Calculate if this is a critical hit (20% chance)
	var is_critical = randf() < 0.2
	if is_critical:
		damage = int(damage * 1.5) # 50% more damage
	
	health -= damage
	
	# Update health bar
	if health_bar:
		health_bar.value = health
		health_bar.visible = true
		is_health_bar_visible = true
		health_bar_visible_timer = 3.0 # Show health bar for 3 seconds
	
	# Display damage text with animation - optimized
	damage_text.text = str(damage)
	if is_critical:
		damage_text.text += "!"
		damage_text.add_theme_color_override("font_color", Color(1.0, 0.1, 0.1))
	else:
		damage_text.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	
	damage_text.visible = true
	animation_tree['parameters/conditions/is_damaged'] = true
	
	# Simple animation instead of tween for better performance
	damage_text.get_parent().position = Vector2(0, -40)
	
	# Optimize push effect
	set_push(Vector2.RIGHT.rotated(bullet_trans.get_rotation()), recoil_strength, 0.2)
	
	# Check if dead
	if health <= 0:
		animation_tree['parameters/conditions/is_destroyed'] = true
		
		# Do splitter special case
		if enemy_type == "Splitter" and !children_spawned:
			call_deferred("spawn_mini_splitters")
		
		# Small screen shake on death only
		if get_parent() and get_parent().has_method("apply_screen_shake"):
			get_parent().apply_screen_shake(8.0, 0.2)

func create_death_explosion():
	# Create simplified death effect to reduce lag
	var particles = CPUParticles2D.new()
	particles.position = global_position
	particles.amount = 10 # Reduced from 30
	particles.lifetime = 0.6
	particles.explosiveness = 1.0
	particles.direction = Vector2(0, 0)
	particles.spread = 180
	particles.gravity = Vector2(0, 200)
	particles.initial_velocity_min = 80
	particles.initial_velocity_max = 160
	particles.scale_amount_min = 4
	particles.scale_amount_max = 8
	
	# Set color based on enemy type
	match enemy_type:
		"Fast":
			particles.color = Color(0.2, 0.7, 0.2)  # Green
		"Tank":
			particles.color = Color(0.2, 0.2, 0.8)  # Blue
		"Splitter":
			particles.color = Color(0.8, 0.6, 0.2)  # Orange
		_:
			particles.color = Color(0.8, 0.2, 0.2)  # Default red
	
	particles.emitting = true
	particles.one_shot = true
	get_tree().root.call_deferred("add_child", particles)
	
	# Auto-clean up
	var timer = Timer.new()
	timer.wait_time = 0.7
	timer.one_shot = true
	timer.autostart = true
	particles.add_child(timer)
	timer.timeout.connect(func(): particles.queue_free())
	
	# Remove slow-motion effect to prevent stutter
	# Engine.time_scale = 1.0 // We're not using slow-motion anymore

# Completely disable visual effects that aren't essential
func create_shield_break_effect():
	pass
	
func add_hit_particles(bullet_trans):
	pass
	
func create_blood_stain():
	pass

func destroy():
	enemy_destroyed.emit(self)
	queue_free()

func set_push(dir: Vector2, strength: float, timer: float):
	push_dir = -dir
	push_strength = strength
	push_timer = timer

func push_back(delta: float):
	if push_timer > 0.0:
		position -= push_dir * push_strength * delta
		push_timer -= delta
	else:
		push_timer = 0.0

func _on_damage_area_body_entered(body):
	if body == player:
		deal_damage_to_player()

func _on_animation_tree_animation_finished(anim_name):
	if anim_name == "get_damage":
		animation_tree['parameters/conditions/is_damaged'] = false
	elif anim_name == "destroy":
		animation_tree['parameters/conditions/is_destroyed'] = false
		destroy()

# Method to safely update player reference
func set_player(new_player):
	player = new_player

func check_split():
	if not is_instance_valid(player):
		return
		
	if health < max_health * 0.3 and not children_spawned:
		spawn_mini_splitters()

func _on_projectile_body_entered(projectile):
	var direction = projectile.get_meta("direction")
	var speed = projectile.get_meta("speed")
	var damage = projectile.get_meta("damage")
	
	if is_instance_valid(player):
		var projectile_instance = projectile.duplicate()
		projectile_instance.position = global_position
		projectile_instance.velocity = direction * speed
		projectile_instance.damage = damage
		projectile_instance.set_script(create_projectile_script())
		
		get_tree().root.add_child(projectile_instance)
		projectile_instance.body_entered.connect(_on_projectile_body_entered.bind(projectile_instance))

func create_projectile_script():
	var script_text = """extends Area2D

var velocity = Vector2.ZERO
var damage = 30

func _ready():
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	position += velocity * delta
	
	# Delete after 3 seconds
	if get_parent() and get_tree().get_frame() % 180 == 0:
		queue_free()

func _on_body_entered(body):
	if body.has_method('take_damage'):
		body.take_damage(damage)
	queue_free()
"""
	
	var script = GDScript.new()
	script.source_code = script_text
	script.reload()
	
	return script

func create_explosion(pos: Vector2, damage_radius: float, damage_amount: int):
	# Explosion effects disabled
	# Deal damage to player if in radius
	if is_instance_valid(player):
		var distance = (player.global_position - pos).length()
		if distance < damage_radius:
			var explosion_damage = int(damage_amount * (1.0 - distance / damage_radius))
			if explosion_damage > 0 and player.has_method("take_damage"):
				player.take_damage(explosion_damage)
				
	# Return null instead of particles
	return null
