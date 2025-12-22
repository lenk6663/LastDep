extends Control

signal game_over

const GAME_DURATION = 60.0
const TARGET_SPAWN_INTERVAL = 1.0
const PLAYER_SPEED = 200.0
const DART_SPEED = 500.0
const FIRE_COOLDOWN = 1.0

enum TargetSize { SMALL, MEDIUM, LARGE }

var target_points = {
	TargetSize.SMALL: 30,
	TargetSize.MEDIUM: 20,
	TargetSize.LARGE: 10
}

var target_speeds = {
	TargetSize.SMALL: 150,
	TargetSize.MEDIUM: 100,
	TargetSize.LARGE: 50
}

# Ссылки на узлы
@onready var 	timer_label = $CanvasLayer/VBoxContainer/HBoxContainer/TimerLabel
@onready var 	player1_score_label = $CanvasLayer/VBoxContainer/HBoxContainer/Player1ScoreLabel
@onready var 	player2_score_label = $CanvasLayer/VBoxContainer/HBoxContainer/Player2ScoreLabel
@onready var 	winner_label = $CanvasLayer/VBoxContainer/WinnerLabel
@onready var 	game_timer = $GameTimer
@onready var 	spawn_timer = $SpawnTimer
	
@onready var 	player1_container = $CanvasLayer/VBoxContainer/MainGameContainer/GameArea/LeftRailArea/Player1Container
@onready var 	player2_container = $CanvasLayer/VBoxContainer/MainGameContainer/GameArea/RightRailArea/Player2Container
@onready var 	targets_container = $CanvasLayer/VBoxContainer/MainGameContainer/GameArea/TargetsArea/TargetsContainer
@onready var 	targets_area = $CanvasLayer/VBoxContainer/MainGameContainer/GameArea/TargetsArea

# Сетевые переменные
var player_scores = {}
var game_active = false
var time_left = GAME_DURATION
var targets = []
var player_cooldowns = {}

var my_id: int
var is_host: bool
var player1_cart = null
var player2_cart = null

func _ready():
	print("=== СТРЕЛЬБА ЗАПУЩЕНА ===")
	print("Мой ID:", multiplayer.get_unique_id())
	print("Это сервер?", multiplayer.is_server())
	# Инициализация
	my_id = multiplayer.get_unique_id()
	is_host = multiplayer.is_server()
	
	# Инициализация счета
	if is_host:
		set_multiplayer_authority(1)
		player_scores[1] = 0
		var peers = multiplayer.get_peers()
		if peers.size() > 0:
			player_scores[peers[0]] = 0
	else:
		player_scores[my_id] = 0
	
	# Инициализация задержек
	player_cooldowns[1] = 0.0
	var peers = multiplayer.get_peers()
	if peers.size() > 0:
		player_cooldowns[peers[0]] = 0.0
	
	# Создание игроков
	create_players()
	
	# Обновление UI
	update_ui()
	
	# Только хост управляет игрой
	if is_host:
		# Даем небольшую задержку для создания всех объектов
		await get_tree().create_timer(0.5).timeout
		start_game()

func create_players():
	print("Создание игроков...")
	
	# Игрок 1 (слева) - всегда хост
	create_player_cart(1, player1_container)
	
	# Игрок 2 (справа) - второй игрок
	var peers = multiplayer.get_peers()
	if peers.size() > 0:  # Есть подключенный игрок
		create_player_cart(peers[0], player2_container)
	elif not multiplayer.is_server():  # Если клиент и нет других пиров
		# Клиент создает себя
		create_player_cart(my_id, player2_container)

func create_player_cart(player_id: int, container: Control):
	print("Создание вагонетки для игрока", player_id)
	
	# Загружаем сцену вагонетки
	var cart_scene = preload("res://Scenes/Minigames/Shooting/PlayerCart.tscn")
	var cart = cart_scene.instantiate()
	cart.name = str(player_id)
	
	# Добавляем в контейнер
	container.add_child(cart)
	
	# Центрируем в контейнере
	cart.position = Vector2(container.size.x / 2, container.size.y / 2)
	
	# Инициализируем
	cart.init(player_id, player_id == my_id, self)
	
	# Сохраняем ссылку
	if player_id == 1:
		player1_cart = cart
	else:
		player2_cart = cart

func _process(delta):
	if not game_active:
		return
	
	# Обновляем задержки выстрелов
	for player_id in player_cooldowns:
		if player_cooldowns[player_id] > 0:
			player_cooldowns[player_id] -= delta
	
	# Обновляем таймер
	if is_host:
		time_left -= delta
		if time_left <= 0:
			end_game()
		else:
			update_timer.rpc(time_left)

# Обычная функция для начала игры
func start_game():
	print("Хост начинает игру")
	game_active = true
	time_left = GAME_DURATION
	
	# Запускаем таймеры
	game_timer.start(1.0)
	spawn_timer.start(TARGET_SPAWN_INTERVAL)
	
	# Сигнал всем игрокам
	start_game_rpc.rpc()

# RPC версия для синхронизации
@rpc("authority", "call_local", "reliable")
func start_game_rpc():
	print("Игра началась для всех игроков")
	game_active = true
	winner_label.visible = false

func create_target():
	if not is_host or not game_active:
		return
	
	var size = randi() % 3
	var target_width = targets_area.size.x
	var x_pos = randf_range(0, target_width)
	
	var target = {
		"id": randi() % 1000000,
		"size": size,
		"position": Vector2(x_pos, -30),  # Начинаем чуть выше экрана
		"velocity": Vector2(0, target_speeds[size]),
	}
	
	targets.append(target)
	spawn_target.rpc(target)

@rpc("authority", "call_local", "reliable")
func spawn_target(target_data: Dictionary):
	# Создаем мишень
	var target_scene = preload("res://Scenes/Minigames/Shooting/Target.tscn")
	var target = target_scene.instantiate()
	target.name = "target_%d" % target_data.id
	
	# Позиционируем относительно targets_container
	target.position = target_data.position
	targets_container.add_child(target)
	
	# Инициализируем
	target.init(target_data.id, target_data.size, target_data.velocity)

# Функция для выстрела - вызывается из PlayerCart
func request_fire(player_id: int):
	if not game_active:
		return
	
	# Проверяем задержку
	if player_cooldowns.get(player_id, 0) > 0:
		return
	
	# Устанавливаем задержку
	player_cooldowns[player_id] = FIRE_COOLDOWN
	
	# Создаем дротик
	create_dart(player_id)

func create_dart(player_id: int):
	var cart = null
	var container = null
	
	# Находим нужную вагонетку
	if player_id == 1 and player1_cart:
		cart = player1_cart
		container = player1_container
	elif player2_cart and (player2_cart.name == str(player_id) or player_id != 1):
		cart = player2_cart
		container = player2_container
	
	if not cart or not container:
		print("Не могу найти вагонетку для игрока", player_id)
		return
	
	# Загружаем сцену дротика
	var dart_scene = preload("res://Scenes/Minigames/Shooting/Dart.tscn")
	var dart = dart_scene.instantiate()
	
	# Позиция дротика - от вагонетки
	# Преобразуем локальную позицию в глобальную
	var cart_global_pos = cart.global_position
	var container_global_pos = container.global_position
	var dart_pos = cart_global_pos
	
	# Добавляем в контейнер мишеней (чтобы дротик был поверх всего)
	targets_container.add_child(dart)
	dart.global_position = dart_pos
	
	# Инициализируем
	dart.init(player_id, DART_SPEED, self)
	
	# Синхронизируем с другими игроками
	fire_dart.rpc(player_id, dart_pos)

@rpc("authority", "call_local", "reliable")
func fire_dart(player_id: int, position: Vector2):
	# Создаем дротик для всех игроков (визуально)
	if player_id != my_id:
		var dart_scene = preload("res://Scenes/Minigames/Shooting/Dart.tscn")
		var dart = dart_scene.instantiate()
		dart.init(player_id, DART_SPEED, self, true)
		targets_container.add_child(dart)
		dart.global_position = position

# Функция для попадания в мишень
func hit_target(target_id: int, player_id: int, target_size: int):
	if not is_host or not game_active:
		return
	
	# Начисляем очки
	var points = target_points[target_size]
	player_scores[player_id] = player_scores.get(player_id, 0) + points
	
	# Удаляем мишень
	remove_target(target_id)
	
	# Обновляем UI
	update_score(player_id, player_scores[player_id])
	
	# Отправляем обновление всем
	target_hit.rpc(target_id, player_id, points, player_scores[player_id])

@rpc("authority", "call_local", "reliable")
func target_hit(target_id: int, player_id: int, points: int, new_score: int):
	# Удаляем мишень у всех
	var target = targets_container.get_node_or_null("target_%d" % target_id)
	if target:
		target.queue_free()
	
	# Обновляем счет
	player_scores[player_id] = new_score
	update_score(player_id, new_score)

func remove_target(target_id: int):
	var target = targets_container.get_node_or_null("target_%d" % target_id)
	if target:
		target.queue_free()
	
	# Удаляем из массива на хосте
	if is_host:
		for i in range(targets.size()):
			if targets[i].id == target_id:
				targets.remove_at(i)
				break

func update_score(player_id: int, score: int):
	if player_id == 1:
		player1_score_label.text = "Игрок 1: %d" % score
	else:
		player2_score_label.text = "Игрок 2: %d" % score

func update_ui():
	if player1_score_label:
		player1_score_label.text = "Игрок 1: 0"
	if player2_score_label:
		player2_score_label.text = "Игрок 2: 0"
	if timer_label:
		timer_label.text = "Время: 01:00"

@rpc("authority", "call_local", "reliable")
func update_timer(current_time: float):
	time_left = current_time
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60
	timer_label.text = "Время: %02d:%02d" % [minutes, seconds]

# Обычная функция для завершения игры
func end_game():
	print("Хост завершает игру")
	game_active = false
	game_timer.stop()
	spawn_timer.stop()
	
	# Определяем победителя
	var winner_id = 1
	var max_score = -1
	
	for player_id in player_scores:
		if player_scores[player_id] > max_score:
			max_score = player_scores[player_id]
			winner_id = player_id
	
	var winner_text = ""
	var peers = multiplayer.get_peers()
	var player2_id = peers[0] if peers.size() > 0 else 2
	
	if player_scores.get(1, 0) == player_scores.get(player2_id, 0):
		winner_text = "НИЧЬЯ!"
	elif winner_id == 1:
		winner_text = "ПОБЕДИЛ ИГРОК 1!"
	else:
		winner_text = "ПОБЕДИЛ ИГРОК 2!"
	
	# Показываем победителя всем
	show_winner.rpc(winner_text)

@rpc("authority", "call_local", "reliable")
func show_winner(winner_text: String):
	winner_label.text = winner_text
	winner_label.visible = true
	
	# Ждем 5 секунд и возвращаемся
	await get_tree().create_timer(5.0).timeout
	game_over.emit()

func _on_spawn_timer_timeout():
	if game_active and is_host:
		create_target()

func _on_game_timer_timeout():
	if game_active and is_host:
		update_timer.rpc(time_left)
