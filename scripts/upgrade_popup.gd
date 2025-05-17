extends CanvasLayer

signal upgrade_selected(upgrade_type, value)

# Dictionary of available upgrades
var upgrades = {
	"max_health": {
		"name": "+20 Max Health",
		"description": "Increase your maximum health.",
		"type": "max_health",
		"value": 20.0
	},
	"fire_rate": {
		"name": "+15% Fire Rate",
		"description": "Shoot faster.",
		"type": "fire_rate", 
		"value": 0.03 # 15% reduction in fire rate cooldown
	},
	"recoil_control": {
		"name": "+20% Recoil Control",
		"description": "More accurate shots.",
		"type": "recoil_control",
		"value": 0.2 # 20% reduction in recoil
	},
	"speed": {
		"name": "+10% Movement Speed",
		"description": "Move faster.",
		"type": "speed",
		"value": 36.0 # 10% of base speed 360
	},
	"laser": {
		"name": "Laser Beam",
		"description": "Piercing beam that passes through enemies.",
		"type": "laser",
		"value": 1.0
	},
	"shotgun": {
		"name": "Shotgun",
		"description": "Fires multiple projectiles in a spread.",
		"type": "shotgun",
		"value": 1.0
	},
	"orbit": {
		"name": "Orbital Protector",
		"description": "Projectiles orbit around you, damaging enemies.",
		"type": "orbit",
		"value": 1.0
	},
	"missile": {
		"name": "Homing Missile",
		"description": "Tracks enemies and explodes on impact.",
		"type": "missile",
		"value": 1.0
	},
	"lightning": {
		"name": "Chain Lightning",
		"description": "Jumps from enemy to enemy, electrifying them.",
		"type": "lightning",
		"value": 1.0
	}
}

var available_upgrades = []
var player_weapons = []

func _ready():
	# Pause the game when popup appears
	get_tree().paused = true
	
	# Get player's current weapons if possible
	var player = get_node_or_null("/root/Main/Player")
	if player:
		player_weapons = player.active_weapons.duplicate()
	
	# Randomly select upgrades to show
	randomize_upgrades()
	
	# Connect button signals
	connect_buttons()

func randomize_upgrades():
	# Get all upgrade keys
	var stat_upgrades = ["max_health", "fire_rate", "recoil_control", "speed"]
	var weapon_upgrades = ["laser", "shotgun", "orbit", "missile", "lightning"]
	
	# Filter out weapons the player already has (unless all weapons are obtained)
	if player_weapons.size() < 5:
		for weapon in player_weapons:
			weapon_upgrades.erase(weapon)
	
	# Shuffle both arrays
	stat_upgrades.shuffle()
	weapon_upgrades.shuffle()
	
	# We want to offer at least one weapon if possible
	available_upgrades = []
	
	# If player doesn't have max weapons yet, offer at least one weapon
	if player_weapons.size() < 5 and weapon_upgrades.size() > 0:
		available_upgrades.append(weapon_upgrades.pop_front())
	
	# Add stat upgrades
	for i in range(min(2, stat_upgrades.size())):
		available_upgrades.append(stat_upgrades[i])
	
	# Fill remaining slots with weapons or more stats
	while available_upgrades.size() < 4 and (weapon_upgrades.size() > 0 or stat_upgrades.size() > 2):
		if weapon_upgrades.size() > 0:
			available_upgrades.append(weapon_upgrades.pop_front())
		elif stat_upgrades.size() > 2:
			available_upgrades.append(stat_upgrades[2])
			stat_upgrades.remove_at(2)
	
	# Shuffle the final list to avoid predictable order
	available_upgrades.shuffle()
	
	# Set button texts
	for i in range(min(4, available_upgrades.size())):
		var upgrade_key = available_upgrades[i]
		var upgrade = upgrades[upgrade_key]
		var button = get_node("CenterContainer/Panel/VBoxContainer/UpgradesContainer/Upgrade" + str(i+1))
		
		# Format differently for weapons vs stats
		if ["laser", "shotgun", "orbit", "missile", "lightning"].has(upgrade_key):
			if player_weapons.has(upgrade_key):
				button.text = "Upgrade " + upgrade.name + ": " + upgrade.description
			else:
				button.text = "New Weapon: " + upgrade.name + " - " + upgrade.description
		else:
			button.text = upgrade.name + ": " + upgrade.description

func connect_buttons():
	# Connect each button's pressed signal
	for i in range(min(4, available_upgrades.size())):
		var button = get_node("CenterContainer/Panel/VBoxContainer/UpgradesContainer/Upgrade" + str(i+1))
		button.pressed.connect(_on_upgrade_button_pressed.bind(i))

func _on_upgrade_button_pressed(index):
	var upgrade_key = available_upgrades[index]
	var upgrade = upgrades[upgrade_key]
	
	# Emit signal with the selected upgrade type and value
	emit_signal("upgrade_selected", upgrade.type, upgrade.value)
	
	# Unpause the game
	get_tree().paused = false
	
	# Close the popup
	queue_free()

# Add upgrade particle effects
func _process(_delta):
	# Add subtle animation to the panel
	var panel = $CenterContainer/Panel
	panel.modulate.a = 0.9 + sin(Time.get_ticks_msec() * 0.005) * 0.1 