# background_music.gd
extends AudioStreamPlayer

# Треки для разных состояний
enum GameMusic {
	GAME_0 = 0,
	GAME_1 = 1,
	GAME_2 = 2,
	GAME_3 = 3
}

# Пути к файлам музыки
var menu_tracks = {
	"menu": "res://Assets/music/menu.ogg",
	"last": "res://Assets/music/last.ogg",
	"game1": "res://Assets/music/1.ogg",
	"game2": "res://Assets/music/2.ogg",
	"game3": "res://Assets/music/3.ogg"
}

var game_tracks = {
	GameMusic.GAME_0: "res://Assets/music/0.ogg",
	GameMusic.GAME_1: "res://Assets/music/1.ogg",
	GameMusic.GAME_2: "res://Assets/music/2.ogg",
	GameMusic.GAME_3: "res://Assets/music/3.ogg"
}

var current_game_track: GameMusic = GameMusic.GAME_0
var is_in_game: bool = false

func _ready():
	# Настройки
	volume_db = -5
	autoplay = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	bus = "Music"
	
	# Всегда начинаем с музыки меню
	play_menu_music("menu")

# ================== МЕНЮ МУЗЫКА ==================

func play_menu_music(track_name: String):
	if is_in_game:
		print("Ошибка: Музыку меню нельзя включать во время игры!")
		return
	
	if menu_tracks.has(track_name):
		var track_path = menu_tracks[track_name]
		_play_track_from_path(track_path)
		print("Включаем музыку меню: ", track_name)

func play_menu():
	play_menu_music("menu")

func play_last():
	play_menu_music("last")

# ================== ИГРОВАЯ МУЗЫКА ==================

func start_game_music():
	"""Начать игру - всегда с трека 0"""
	is_in_game = true
	play_game_track(GameMusic.GAME_0)

func play_game_track(track: GameMusic):
	if not is_in_game:
		print("Ошибка: Игровую музыку можно включать только во время игры!")
		return
	
	if game_tracks.has(track):
		var track_path = game_tracks[track]
		_play_track_from_path(track_path)
		current_game_track = track
		print("Включаем игровую музыку: Трек ", track)

func play_game_0():
	play_game_track(GameMusic.GAME_0)

func play_game_1():
	play_game_track(GameMusic.GAME_1)

func play_game_2():
	play_game_track(GameMusic.GAME_2)

func play_game_3():
	play_game_track(GameMusic.GAME_3)

func next_game_track():
	"""Переключить на следующий игровой трек (0→1→2→3→0)"""
	var next_track = current_game_track + 1
	if next_track > GameMusic.GAME_3:
		next_track = GameMusic.GAME_0
	play_game_track(next_track)

func previous_game_track():
	"""Переключить на предыдущий игровой трек"""
	var prev_track = current_game_track - 1
	if prev_track < GameMusic.GAME_0:
		prev_track = GameMusic.GAME_3
	play_game_track(prev_track)

# ================== ОБЩИЕ ФУНКЦИИ ==================

func _play_track_from_path(path: String):
	var audio_stream = load(path)
	if audio_stream:
		if stream != audio_stream or not playing:
			stream = audio_stream
			play()
	else:
		print("Ошибка: Не могу загрузить музыку: ", path)

func stop_all():
	"""Остановить всю музыку"""
	stop()
	is_in_game = false

func back_to_menu():
	"""Вернуться к музыке меню (выход из игры)"""
	is_in_game = false
	play_menu_music("menu")

func get_current_track_name() -> String:
	"""Получить название текущего трека"""
	if is_in_game:
		return "game_" + str(current_game_track)
	else:
		# Определяем какая музыка меню играет
		if stream:
			for name in menu_tracks:
				if menu_tracks[name] == stream.resource_path:
					return name
		return "unknown"

# ================== ДЛЯ ОТЛАДКИ ==================

func _input(event):
	"""Тестовые клавиши"""
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			# Меню музыка
			KEY_M:
				back_to_menu()
				print("Текущая музыка: ", get_current_track_name())
			KEY_L:
				play_last()
			
			# Игровая музыка
			KEY_G:
				start_game_music()
			KEY_0:
				play_game_0() if is_in_game else null
			KEY_1:
				play_game_1() if is_in_game else null
			KEY_2:
				play_game_2() if is_in_game else null
			KEY_3:
				play_game_3() if is_in_game else null
			KEY_RIGHT:
				next_game_track() if is_in_game else null
			KEY_LEFT:
				previous_game_track() if is_in_game else null
			KEY_S:
				stop_all()
				print("Музыка остановлена")
