extends Node2D

@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

# Add pitch_scale and volume_db properties to pass through to audio_player
var _pitch_scale: float = 1.0
var _volume_db: float = 0.0

# Pitch scale property with getter/setter
var pitch_scale: float:
	get:
		return audio_player.pitch_scale
	set(value):
		_pitch_scale = value
		if audio_player:
			audio_player.pitch_scale = value

# Volume db property with getter/setter
var volume_db: float:
	get:
		return audio_player.volume_db
	set(value):
		_volume_db = value
		if audio_player:
			audio_player.volume_db = value

func play():
	audio_player.play()

func _on_audio_stream_player_finished():
	queue_free()
