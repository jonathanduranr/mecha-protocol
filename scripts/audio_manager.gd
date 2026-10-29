extends Node

# AudioManager - Singleton para gestión global de música y efectos
var bgm_combat: AudioStream = load("res://assets/audio/bgm_combat.wav")
var sfx_laser: AudioStream = load("res://assets/audio/sfx_laser.wav")
var sfx_explosion: AudioStream = load("res://assets/audio/sfx_explosion.wav")
var sfx_ram_explosion: AudioStream = load("res://assets/audio/sfx_ram_explosion.wav")
var sfx_scrap: AudioStream = load("res://assets/audio/sfx_scrap.wav")
var sfx_levelup: AudioStream = load("res://assets/audio/sfx_levelup.wav")
var sfx_mecha_hit: AudioStream = load("res://assets/audio/sfx_mecha_hit.wav")
var sfx_gameover: AudioStream = load("res://assets/audio/sfx_gameover.wav")

var bgm_player: AudioStreamPlayer
var sfx_pool: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 12
var pool_index: int = 0

var is_music_enabled: bool = true
var is_sfx_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Funciona incluso si el juego está en pausa
	
	# Configurar reproductor de música de fondo
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	if bgm_combat is AudioStreamWAV:
		bgm_combat.loop_mode = AudioStreamWAV.LOOP_FORWARD
	bgm_player.stream = bgm_combat
	bgm_player.volume_db = -6.0
	add_child(bgm_player)
	
	# Crear pool de reproductores SFX para permitir polifonía
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_pool.append(p)

func play_bgm() -> void:
	if not is_music_enabled:
		return
	if not bgm_player.playing:
		bgm_player.volume_db = -6.0
		bgm_player.play()

func stop_bgm() -> void:
	if bgm_player.playing:
		bgm_player.stop()

func fade_out_bgm(duration: float = 1.0) -> void:
	if not bgm_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(bgm_player, "volume_db", -40.0, duration)
	tween.tween_callback(Callable(self, "stop_bgm"))

func _get_available_sfx_player() -> AudioStreamPlayer:
	for p in sfx_pool:
		if not p.playing:
			return p
	var p := sfx_pool[pool_index]
	pool_index = (pool_index + 1) % POOL_SIZE
	return p

func _play_sfx(stream: AudioStream, vol_db: float = 0.0, p_min: float = 0.95, p_max: float = 1.05) -> void:
	if not is_sfx_enabled or stream == null:
		return
	var player := _get_available_sfx_player()
	player.stream = stream
	player.volume_db = vol_db
	player.pitch_scale = randf_range(p_min, p_max)
	player.play()

func play_laser() -> void:
	_play_sfx(sfx_laser, -8.0, 0.92, 1.08)

func play_explosion() -> void:
	_play_sfx(sfx_explosion, -4.0, 0.90, 1.10)

func play_ram_explosion() -> void:
	_play_sfx(sfx_ram_explosion, -2.0, 0.85, 1.05)

func play_scrap() -> void:
	_play_sfx(sfx_scrap, -10.0, 0.95, 1.15)

func play_levelup() -> void:
	_play_sfx(sfx_levelup, -2.0, 1.0, 1.0)

func play_mecha_hit() -> void:
	_play_sfx(sfx_mecha_hit, -3.0, 0.90, 1.05)

func play_gameover() -> void:
	fade_out_bgm(0.5)
	_play_sfx(sfx_gameover, 0.0, 1.0, 1.0)
