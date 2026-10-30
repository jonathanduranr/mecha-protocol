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
var current_tween: Tween = null
var user_interacted: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # Funciona incluso si el juego está en pausa
	
	# Evitar que la pantalla se bloquee o entre en reposo (iOS, Android, etc.)
	DisplayServer.screen_set_keep_on(true)
	if OS.has_feature("web"):
		_request_web_wake_lock()
	
	# Configurar reproductor de música de fondo
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.stream = bgm_combat
	bgm_player.volume_db = -3.5 # Volumen equilibrado para que los disparos y efectos resalten con claridad
	bgm_player.finished.connect(_on_bgm_finished)
	add_child(bgm_player)
	
	# Crear pool de reproductores SFX para permitir polifonía
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_pool.append(p)
		
	# Intentar reproducir de inmediato (si la plataforma lo permite)
	play_bgm()

func _request_web_wake_lock() -> void:
	if ClassDB.class_exists("JavaScriptBridge"):
		var js := Engine.get_singleton("JavaScriptBridge")
		if js:
			js.eval("if ('wakeLock' in navigator) { navigator.wakeLock.request('screen').catch(function(){}); }")

func _input(event: InputEvent) -> void:
	# Desbloqueo garantizado de WebAudio en iOS Safari / Chrome al primer tap o clic
	if not user_interacted:
		if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
			user_interacted = true
			if is_music_enabled and not bgm_player.playing:
				play_bgm()
			if OS.has_feature("web"):
				_request_web_wake_lock()

func _on_bgm_finished() -> void:
	# Garantizar bucle infinito continuo
	if is_music_enabled and is_instance_valid(bgm_player):
		bgm_player.volume_db = -3.5
		bgm_player.play()

func play_bgm() -> void:
	if not is_music_enabled:
		return
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
		
	bgm_player.volume_db = -3.5
	if not bgm_player.playing:
		bgm_player.play()

func stop_bgm() -> void:
	if current_tween and current_tween.is_valid():
		current_tween.kill()
		current_tween = null
	if bgm_player.playing:
		bgm_player.stop()

func fade_out_bgm(duration: float = 0.8) -> void:
	if not bgm_player.playing:
		return
	if current_tween and current_tween.is_valid():
		current_tween.kill()
	current_tween = create_tween()
	current_tween.tween_property(bgm_player, "volume_db", -36.0, duration)
	current_tween.tween_callback(Callable(self, "stop_bgm"))

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
	# Disparo láser mecha: presente, potente y claramente audible
	_play_sfx(sfx_laser, -2.0, 0.96, 1.04)

func play_explosion() -> void:
	_play_sfx(sfx_explosion, -8.0, 0.90, 1.10)

func play_ram_explosion() -> void:
	_play_sfx(sfx_ram_explosion, -4.0, 0.88, 1.05)

func play_scrap() -> void:
	pass # Silenciado según preferencia del usuario (recolección de orbes XP silenciosa)

func play_levelup() -> void:
	_play_sfx(sfx_levelup, -3.0, 1.0, 1.0)

func play_mecha_hit() -> void:
	pass # Silenciado según preferencia del usuario (combate limpio)

func play_gameover() -> void:
	fade_out_bgm(0.6)
	_play_sfx(sfx_gameover, 0.0, 1.0, 1.0)
