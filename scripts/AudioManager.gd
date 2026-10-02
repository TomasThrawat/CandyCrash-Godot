class_name AudioManager
extends Node

var players: Dictionary = {}
var streams: Dictionary = {}
var music: AudioStreamPlayer

func _ready() -> void:
	for role in ["match","slide","combo","bonus","celebration","win","lose","countdown"]:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		players[role] = p
	music = AudioStreamPlayer.new()
	music.volume_db = -18.0
	music.autoplay = false
	add_child(music)
	load_streams()
	if ResourceLoader.exists("res://assets/audio/music.wav"):
		music.stream = load("res://assets/audio/music.wav")
		music.play()

func load_streams() -> void:
	var roles := {
		"match":"res://assets/audio/match.wav",
		"slide":"res://assets/audio/slide.wav",
		"combo":"res://assets/audio/combo.wav",
		"bonus":"res://assets/audio/bonus.wav",
		"celebration":"res://assets/audio/celebration.wav",
		"win":"res://assets/audio/win.wav",
		"lose":"res://assets/audio/lose.wav",
		"countdown":"res://assets/audio/countdown.wav"
	}
	for role in roles:
		if ResourceLoader.exists(roles[role]):
			var stream = load(roles[role])
			if stream:
				streams[role] = stream

func play(role: String, pitch: float = 1.0) -> void:
	if not players.has(role):
		return
	var p: AudioStreamPlayer = players[role]
	if streams.has(role):
		p.stream = streams[role]
		p.pitch_scale = pitch
		p.play()

func music_on() -> bool:
	return AudioServer.is_bus_mute(0) == false
