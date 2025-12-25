# Shooting.gd
extends Node2D

signal game_over

const GAME_DURATION = 60.0
const TARGET_SPAWN_INTERVAL = 1.0
const FIRE_COOLDOWN = 1.0

# Размеры игровой области
const GAME_WIDTH = 1024
const GAME_HEIGHT = 600

# Позиции
const PLAYER1_POS = Vector2(90, 300)    # Левая сторона
const PLAYER2_POS = Vector2(1050, 300)    # Правая сторона
const PLAYER_MOVE_RANGE = Vector2(50, 600)  # Диапазон движения по Y
const TARGET_SPAWN_AREA_X = Vector2(300, 724)  # Где появляются мишени по X
const TARGET_MOVE_RANGE = Vector2(100, 500)  # Где движутся мишени по Y

# Ссылки на узлы
@onready var camera = $Camera2D
@onready var tilemap = $TileMap
@onready var players_container = $Players
@onready var targets_container = $Targets
@onready var darts_container = $Darts
@onready var ui = $UI
@onready var timer_label = $UI/TimerLabel
@onready var player1_score_label = $UI/Player1ScoreLabel
@onready var player2_score_label = $UI/Player2ScoreLabel
@onready var winner_label = $UI/WinnerLabel

# Состояние игры
var game_active = false
var time_left = GAME_DURATION
var player_scores = [0, 0]
var player_cooldowns = [0.0, 0.0]
var targets = []

# Игроки
var player1 = null
var player2 = null

func _ready():
	print("=== SHOOTING ИГРА ЗАПУЩЕНА ===")
	
	# Создаем сигнал если его нет
	if not has_signal("game_over"):
		add_user_signal("game_over")
	
	# Настраиваем камеру
	setup_camera()
	
	# Настраиваем UI
	setup_ui()
	
	# Инициализируем игру
	init_game()

func setup_camera():
	print("Настраиваю камеру...")
	
	# Центрируем камеруы
	camera.zoom = Vector2(1, 1)
	camera.make_current()
	
	print("Камера установлена в центре:", camera.position)

func setup_ui():
	timer_label.text = "Время: 01:00"
	player1_score_label.text = "Игрок 1: 0"
	player2_score_label.text = "Игрок 2: 0"
	winner_label.visible = false
	winner_label.text = ""

func init_game():
	print("Инициализация игры...")
	
	# Очищаем все объекты
	clear_game_objects()
	
	# Сброс состояния
	game_active = false
	time_left = GAME_DURATION
	player_scores = [0, 0]
	player_cooldowns = [0.0, 0.0]
	targets = []
	
	print("Игра инициализирована")
	
	# Создаем игроков
	create_players()
	
	# Ждем и начинаем игру
	await get_tree().create_timer(1.0).timeout
	start_game()

func clear_game_objects():
	# Очищаем мишени и дротики
	for node in [targets_container, darts_container]:
		for child in node.get_children():
			child.queue_free()

func create_players():
	print("Создаю игроков...")
	
	# Очищаем старых игроков
	for child in players_container.get_children():
		child.queue_free()
	
	# Создаем игрока 1 (слева)
	player1 = create_player_cart(1, PLAYER1_POS)
	player1.z_index = 10  # Поверх других объектов
	
	# Создаем игрока 2 (справа)
	player2 = create_player_cart(2, PLAYER2_POS)
	player2.z_index = 10  # Поверх других объектов
	
	print("Игроки созданы")

func create_player_cart(player_id: int, position: Vector2):
	var cart_scene = preload("res://Scenes/Minigames/Shooting/PlayerCart.tscn")
	if not cart_scene:
		print("ОШИБКА: Не могу загрузить сцену вагонетки!")
		return null
	
	var cart = cart_scene.instantiate()
	cart.name = "Player%d" % player_id
	cart.position = position
	cart.scale = Vector2(2, 2)  # Размер вагонетки
	
	players_container.add_child(cart)
	
	# Инициализируем
	if cart.has_method("init"):
		var is_local = true  # В этой версии оба игрока локальные для тестирования
		# Передаем диапазон движения
		cart.init(player_id, is_local, self, PLAYER_MOVE_RANGE)
	
	return cart

func start_game():
	print("ИГРА НАЧИНАЕТСЯ!")
	game_active = true
	
	# Запускаем спавн мишеней
	$SpawnTimer.start(TARGET_SPAWN_INTERVAL)
	
	# Запускаем таймер игры
	$GameTimer.start(1.0)

func _process(delta):
	if not game_active:
		return
	
	# Обновляем задержки выстрелов
	for i in range(2):
		if player_cooldowns[i] > 0:
			player_cooldowns[i] -= delta
	
	# Обновляем таймер
	time_left -= delta
	if time_left <= 0:
		end_game()
	else:
		update_timer_display()

func _input(event):
	if not game_active:
		return
	
	# Стрельба: пробел для игрока 1, Enter для игрока 2
	if event.is_action_pressed("ui_accept"):
		# Игрок 1 стреляет
		if player_cooldowns[0] <= 0:
			player_cooldowns[0] = FIRE_COOLDOWN
			shoot_dart(0)
	
	if event.is_action_pressed("ui_focus_next"):  # Tab
		# Игрок 2 стреляет
		if player_cooldowns[1] <= 0:
			player_cooldowns[1] = FIRE_COOLDOWN
			shoot_dart(1)

func shoot_dart(player_index: int):
	print("Игрок", player_index + 1, " стреляет!")
	
	# Определяем стартовую позицию
	var player_pos = PLAYER1_POS if player_index == 0 else PLAYER2_POS
	var direction = Vector2.RIGHT if player_index == 0 else Vector2.LEFT
	
	# Создаем дротик
	create_dart(player_index + 1, player_pos, direction)

func create_dart(player_id: int, position: Vector2, direction: Vector2):
	var dart_scene = preload("res://Scenes/Minigames/Shooting/Dart.tscn")
	if dart_scene:
		var dart = dart_scene.instantiate()
		dart.position = position
		dart.z_index = 5  # Дротики поверх мишеней
		
		darts_container.add_child(dart)
		
		if dart.has_method("init"):
			dart.init(player_id, 500.0, direction, self)

func update_timer_display():
	var minutes = int(time_left) / 60
	var seconds = int(time_left) % 60
	timer_label.text = "Время: %02d:%02d" % [minutes, seconds]

func _on_target_spawn_timer_timeout():
	if game_active:
		spawn_target()

func spawn_target():
	var size = randi() % 3  # 0=маленькая, 1=средняя, 2=большая
	var x_pos = randf_range(TARGET_SPAWN_AREA_X.x, TARGET_SPAWN_AREA_X.y)
	var y_pos = randf_range(100, 200)  # Появляются сверху
	
	# Скорость в зависимости от размера
	var speed = [150.0, 100.0, 70.0][size]  # Маленькие быстрее
	
	# Направление движения (горизонтально)
	var direction = Vector2.LEFT if x_pos > GAME_WIDTH / 2 else Vector2.RIGHT
	
	# Создаем мишень
	var target_scene = preload("res://Scenes/Minigames/Shooting/Target.tscn")
	if target_scene:
		var target = target_scene.instantiate()
		target.name = "Target_%d" % (randi() % 1000000)
		target.position = Vector2(x_pos, y_pos)
		target.z_index = 1  # Мишени под дротиками
		
		# Масштаб в зависимости от размера
		var scale_val = [0.6, 0.8, 1.0][size]
		target.scale = Vector2(scale_val, scale_val)
		
		targets_container.add_child(target)
		
		if target.has_method("init"):
			target.init(target.get_instance_id(), size, direction * speed, self)

# Функция для обработки попадания (вызывается из Target.gd)
func on_target_hit(target_id: int, player_id: int, target_size: int):
	print("Попадание! Игрок", player_id, " попал в мишень")
	
	# Начисляем очки
	var points = [30, 20, 10][target_size]
	var player_index = player_id - 1
	
	player_scores[player_index] += points
	
	print("Игрок", player_id, " получает", points, " очков. Новый счет:", player_scores[player_index])
	
	# Обновляем UI
	update_score_display()
	
	# Удаляем мишень
	remove_target(target_id)

func remove_target(target_id: int):
	var target = targets_container.get_node_or_null("Target_%d" % target_id)
	if target:
		target.queue_free()

func update_score_display():
	player1_score_label.text = "Игрок 1: %d" % player_scores[0]
	player2_score_label.text = "Игрок 2: %d" % player_scores[1]

func _on_game_timer_timeout():
	# Обновляем таймер каждую секунду
	if game_active:
		update_timer_display()

func end_game():
	print("ИГРА ЗАВЕРШЕНА!")
	game_active = false
	
	# Останавливаем таймеры
	$SpawnTimer.stop()
	$GameTimer.stop()
	
	# Определяем победителя
	var winner_text = ""
	if player_scores[0] > player_scores[1]:
		winner_text = "ПОБЕДИЛ ИГРОК 1!"
	elif player_scores[1] > player_scores[0]:
		winner_text = "ПОБЕДИЛ ИГРОК 2!"
	else:
		winner_text = "НИЧЬЯ!"
	
	print("Результат:", winner_text)
	
	# Показываем победителя
	show_winner(winner_text)

func show_winner(winner_text: String):
	winner_label.text = winner_text
	winner_label.visible = true
	
	# Ждем 5 секунд и завершаем игру
	await get_tree().create_timer(5.0).timeout
	
	print("Отправляю сигнал завершения игры")
	game_over.emit()

func _exit_tree():
	print("Shooting игра завершена")
