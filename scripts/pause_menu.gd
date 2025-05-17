extends CanvasLayer

# Animation variables
var time_passed = 0.0
var active_particles = []

func _ready():
	# Initially hide the pause menu
	visible = false
	
	# Set process mode to continue processing when game is paused
	process_mode = PROCESS_MODE_WHEN_PAUSED
	
	# Connect button signals
	$MenuContainer/ResumeButton.pressed.connect(_on_resume_button_pressed)
	$MenuContainer/OptionsButton.pressed.connect(_on_options_button_pressed)
	$MenuContainer/QuitButton.pressed.connect(_on_quit_button_pressed)
	
	# Setup button hover effects
	var buttons = [$MenuContainer/ResumeButton, $MenuContainer/OptionsButton, $MenuContainer/QuitButton]
	for button in buttons:
		button.mouse_entered.connect(_on_button_hover.bind(button))
		button.mouse_exited.connect(_on_button_mouse_exit.bind(button))

func _process(delta):
	if not visible:
		return
		
	time_passed += delta
	
	# Animate the pause title
	$PauseTitle.scale = Vector2(1.0, 1.0) * (1.0 + sin(time_passed * 2.0) * 0.03)
	$PauseTitle.rotation = sin(time_passed * 1.2) * 0.01
	
	# Animate menu container with subtle float
	$MenuContainer.position.y = 350 + sin(time_passed * 1.4) * 3.0
	
	# Animate the panel borders with color pulsing
	var border_color = Color(0.666667, 0.407843, 1.0, 0.784314 + sin(time_passed * 1.5) * 0.1)
	$BackgroundFrame/BorderTop.color = border_color
	$BackgroundFrame/BorderBottom.color = border_color
	$BackgroundFrame/BorderLeft.color = border_color
	$BackgroundFrame/BorderRight.color = border_color
	
	# Update particle effects
	update_particles(delta)
	
	# Subtle animation for the buttons
	for i in range($MenuContainer.get_child_count()):
		var button = $MenuContainer.get_child(i)
		if button is Button:
			button.position.x = sin(time_passed * (1.0 + i * 0.2) + i) * 3.0

# Toggle the pause state
func toggle_pause():
	visible = !visible
	get_tree().paused = visible
	
	if visible:
		# Show pause menu with effects
		show_with_effects()
		# Make sure mouse is visible
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		# Hide and unpause
		get_tree().paused = false
		
	return visible

func show_with_effects():
	# Reset elements
	$Backdrop.modulate.a = 0
	$BackgroundFrame.modulate.a = 0
	$PausePanel.modulate.a = 0
	$PauseTitle.modulate.a = 0
	$PauseTitle.scale = Vector2(1.5, 1.5)
	$MenuContainer.modulate.a = 0
	$MenuContainer.position.y += 50
	
	# Create animation for dramatic entrance
	var backdrop_tween = create_tween()
	backdrop_tween.tween_property($Backdrop, "modulate:a", 1.0, 0.3)
	
	# Animate frame entrance
	var frame_tween = create_tween()
	frame_tween.tween_property($BackgroundFrame, "modulate:a", 1.0, 0.4)
	
	# Animate panel entrance
	var panel_tween = create_tween()
	panel_tween.tween_property($PausePanel, "modulate:a", 1.0, 0.5)
	
	# Animate title entrance
	var title_tween = create_tween()
	title_tween.tween_property($PauseTitle, "modulate:a", 1.0, 0.5)
	title_tween.parallel().tween_property($PauseTitle, "scale", Vector2(1.0, 1.0), 0.5).set_trans(Tween.TRANS_ELASTIC)
	
	# Animate menu entrance
	var menu_tween = create_tween()
	menu_tween.tween_property($MenuContainer, "modulate:a", 1.0, 0.5)
	menu_tween.parallel().tween_property($MenuContainer, "position:y", $MenuContainer.position.y - 50, 0.5).set_trans(Tween.TRANS_BACK)
	
	# Spawn particle effects for dramatic entrance
	spawn_initial_particles()

func spawn_initial_particles():
	# Spawn burst particles when menu opens
	spawn_particles(get_viewport().size / 2, 50)
	
	# Spawn particles at each button
	for button in $MenuContainer.get_children():
		if button is Button:
			spawn_particles(button.global_position + Vector2(button.size.x/2, button.size.y/2), 15)

func spawn_particles(position, amount):
	var particles = CPUParticles2D.new()
	particles.emitting = true
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = amount
	particles.lifetime = 1.5
	particles.position = position
	particles.spread = 180
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 50
	particles.initial_velocity_max = 150
	particles.scale_amount_min = 2
	particles.scale_amount_max = 5
	
	# Create color gradient
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(0.8, 0.3, 1.0, 1.0))
	gradient.add_point(0.5, Color(0.5, 0.7, 1.0, 0.8))
	gradient.add_point(1.0, Color(0.3, 0.5, 1.0, 0.0))
	particles.color_ramp = gradient
	
	$ParticlesContainer.add_child(particles)
	active_particles.append({
		"node": particles,
		"time": 2.0
	})

func update_particles(delta):
	# Update existing particles
	for i in range(active_particles.size() - 1, -1, -1):
		var particle_data = active_particles[i]
		particle_data.time -= delta
		
		if particle_data.time <= 0:
			if particle_data.node:
				particle_data.node.queue_free()
			active_particles.remove_at(i)

func _on_button_hover(button):
	# Scale up animation
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.1, 1.1), 0.3)
	
	# Particle effect on hover
	spawn_particles(button.global_position + Vector2(button.size.x/2, button.size.y/2), 10)

func _on_button_mouse_exit(button):
	# Scale back down
	var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.3)

func _on_resume_button_pressed():
	# Hide menu with effects
	var backdrop_tween = create_tween()
	backdrop_tween.tween_property($Backdrop, "modulate:a", 0.0, 0.3)
	
	var frame_tween = create_tween()
	frame_tween.tween_property($BackgroundFrame, "modulate:a", 0.0, 0.3)
	
	var panel_tween = create_tween()
	panel_tween.tween_property($PausePanel, "modulate:a", 0.0, 0.3)
	
	var title_tween = create_tween()
	title_tween.tween_property($PauseTitle, "modulate:a", 0.0, 0.3)
	title_tween.parallel().tween_property($PauseTitle, "scale", Vector2(0.5, 0.5), 0.3)
	
	var menu_tween = create_tween()
	menu_tween.tween_property($MenuContainer, "modulate:a", 0.0, 0.3)
	menu_tween.parallel().tween_property($MenuContainer, "position:y", $MenuContainer.position.y + 50, 0.3)
	
	# Unpause after animation completes
	menu_tween.tween_callback(func(): 
		get_tree().paused = false
		visible = false
	)
	
	# Final burst of particles
	spawn_particles(get_viewport().size / 2, 30)

func _on_options_button_pressed():
	# For now just do a visual effect
	var tween = create_tween()
	tween.tween_property($MenuContainer/OptionsButton, "modulate", Color(1.5, 1.5, 1.5), 0.2)
	tween.tween_property($MenuContainer/OptionsButton, "modulate", Color(1, 1, 1), 0.2)
	
	# Add particle effect
	spawn_particles($MenuContainer/OptionsButton.global_position + 
		Vector2($MenuContainer/OptionsButton.size.x/2, $MenuContainer/OptionsButton.size.y/2), 20)

func _on_quit_button_pressed():
	# Dramatic quit animation
	var final_particles = CPUParticles2D.new()
	final_particles.emitting = true
	final_particles.one_shot = true
	final_particles.explosiveness = 0.95
	final_particles.amount = 200
	final_particles.lifetime = 2.0
	final_particles.position = get_viewport().size / 2
	final_particles.spread = 180
	final_particles.gravity = Vector2.ZERO
	final_particles.initial_velocity_min = 100
	final_particles.initial_velocity_max = 300
	final_particles.scale_amount_min = 3
	final_particles.scale_amount_max = 8
	
	# Create color gradient
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.3, 0.3, 1.0))  # Red
	gradient.add_point(0.5, Color(1.0, 0.7, 0.2, 0.8))  # Orange
	gradient.add_point(1.0, Color(0.3, 0.5, 1.0, 0.0))  # Blue fade out
	final_particles.color_ramp = gradient
	
	$ParticlesContainer.add_child(final_particles)
	
	# Flash effect
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	add_child(flash)
	
	# Animate flash and quit
	var flash_tween = create_tween()
	flash_tween.tween_property(flash, "color:a", 0.8, 0.5)
	flash_tween.tween_callback(func(): get_tree().quit()) 