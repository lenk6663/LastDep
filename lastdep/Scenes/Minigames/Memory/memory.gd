# memory.gd - исправленная версия без f-строк
extends GridContainer

signal game_over

const CARD_PAIRS = 21
const GRID_COLUMNS = 7 
const GRID_ROWS = 6
const PLAYER_COLORS = [Color("ff6b6b"), Color("4ecdc4")]

var cards = []
var card_values = []
var flipped_cards = []
var matched_pairs = 0

var scores = [0, 0]
var current_player = 0
var can_play = false
var game_started = false

# Ссылки на UI элементы
@onready var current_player_label = $"../CurrentPlayerLabel"
@onready var player1_score_label = $"../Player1Score"
@onready var player2_score_label = $"../Player2Score"
@onready var timer_label = $"../TimerLabel"
@onready var game_status_label = $"../GameStatusLabel"

# Текстуры карт
var card_textures = []

# Таймер игры
var game_time = 0
var game_timeout_timer: SceneTreeTimer

func _ready():
	print("Memory: Игра запущена")
	
	# ПРОВЕРЯЕМ что сигнал создан
	if not has_signal("game_over"):
		print("ОШИБКА: Сигнал game_over не создан! Создаю...")
		add_user_signal("game_over")
		print("Сигнал создан: ", has_signal("game_over"))
	
	# Проверяем количество подключений
	print("Количество подключений к сигналу: ", game_over.get_connections().size())
	# Настраиваем сетку
	columns = GRID_COLUMNS
	custom_minimum_size = Vector2(GRID_COLUMNS * 85, GRID_ROWS * 110)
	# Загружаем текстуры
	load_card_textures()
	# Создаем карты
	create_cards()
	# Настраиваем UI
	setup_ui()
	# Если сервер - инициализируем игру
	if multiplayer.is_server():
		print("СЕРВЕР: Инициализирую игру")
		init_game()
		start_game.rpc()
	else:
		print("КЛИЕНТ: Жду начала игры")
		if game_status_label:
			game_status_label.text = "Ожидание начала игры..."
	if not has_signal("game_over"):
		print("Создаю сигнал game_over")
		add_user_signal("game_over")
	else:
		print("Сигнал game_over уже существует")
func load_card_textures():
	card_textures.clear()
	
	# Загружаем текстуры (нужно 21 уникальная картинка)
	for i in range(1, 22):  # 1-21
		var texture = load("res://Assets/MemoryGame/%d.png" % i)
		if texture:
			card_textures.append(texture)
			print("Загружена текстура:", i)
		else:
			print("Ошибка загрузки текстуры:", i)
			# Создаем цветную карточку если текстуры нет
			var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
			var color = Color.from_hsv(float(i)/21.0, 0.7, 0.9)
			image.fill(color)
			var tex = ImageTexture.create_from_image(image)
			card_textures.append(tex)
	
	# Проверяем что текстур достаточно
	if card_textures.size() < CARD_PAIRS:
		print("ВНИМАНИЕ: Недостаточно текстур! Нужно ", CARD_PAIRS, ", есть ", card_textures.size())
		# Дублируем существующие текстуры если не хватает
		while card_textures.size() < CARD_PAIRS:
			for i in range(min(card_textures.size(), CARD_PAIRS - card_textures.size())):
				card_textures.append(card_textures[i])

func create_cards():
	# Очищаем старые карты
	for child in get_children():
		if child is Button:
			child.queue_free()
	cards.clear()
	
	# Создаем карты
	for i in range(CARD_PAIRS * 2):
		var card = Button.new()
		card.custom_minimum_size = Vector2(80, 80)  # Можно уменьшить для 7x6 сетки
		card.name = "Card_%d" % i
		card.text = "?"
		card.add_theme_font_size_override("font_size", 20)  # Уменьшаем шрифт
		
		card.set_meta("card_index", i)
		card.set_meta("is_flipped", false)
		card.set_meta("is_matched", false)
		
		card.pressed.connect(_on_card_pressed.bind(card))
		
		add_child(card)
		cards.append(card)
	
	print("Создано карт: ", cards.size(), " (", CARD_PAIRS, " пар)")

func setup_ui():
	if player1_score_label:
		player1_score_label.text = "Игрок 1: 0"
	if player2_score_label:
		player2_score_label.text = "Игрок 2: 0"
	
	if player1_score_label:
		player1_score_label.add_theme_color_override("font_color", PLAYER_COLORS[0])
	if player2_score_label:
		player2_score_label.add_theme_color_override("font_color", PLAYER_COLORS[1])
	
	if timer_label:
		timer_label.text = "Время: 05:00"

func init_game():
	print("СЕРВЕР: Генерация значений карт")
	
	card_values = []
	for i in range(CARD_PAIRS):
		card_values.append(i)
		card_values.append(i)
	
	card_values.shuffle()
	print("Сгенерировано ", card_values.size(), " значений")
	
	sync_game_state.rpc(card_values, 0)

@rpc("authority", "call_local", "reliable")
func sync_game_state(values: Array, starting_player: int):
	print("СИНХРОНИЗАЦИЯ: Получено ", values.size(), " значений, игрок ", starting_player)
	
	card_values = values
	current_player = starting_player
	
	for i in range(min(cards.size(), values.size())):
		cards[i].set_meta("card_value", card_values[i])
	
	game_started = true
	can_play = multiplayer.is_server()
	
	update_game_ui()
	
	if game_status_label:
		game_status_label.text = "Игра началась!"
		game_status_label.add_theme_color_override("font_color", Color.GREEN)
	
	print("ИГРА НАЧАТА: Мой ход? ", can_play)

func update_game_ui():
	if current_player_label:
		current_player_label.text = "Ход игрока: %d" % (current_player + 1)
		current_player_label.add_theme_color_override("font_color", PLAYER_COLORS[current_player])
	
	if player1_score_label:
		player1_score_label.text = "Игрок 1: %d" % scores[0]
	if player2_score_label:
		player2_score_label.text = "Игрок 2: %d" % scores[1]
	
	if game_status_label:
		if can_play:
			game_status_label.text = "ВАШ ХОД!"
			game_status_label.add_theme_color_override("font_color", Color.GREEN)
		else:
			game_status_label.text = "Ход другого игрока"
			game_status_label.add_theme_color_override("font_color", Color.RED)

func _on_card_pressed(card: Button):
	if not game_started:
		print("ОШИБКА: Игра не начата")
		return
	
	if not can_play:
		print("ОШИБКА: Не мой ход")
		return
	
	var card_index = card.get_meta("card_index")
	var is_flipped = card.get_meta("is_flipped")
	var is_matched = card.get_meta("is_matched")
	
	if is_flipped:
		print("ОШИБКА: Карта уже перевернута")
		return
	
	if is_matched:
		print("ОШИБКА: Карта уже совпала")
		return
	
	if flipped_cards.size() >= 2:
		print("ОШИБКА: Уже перевернуто 2 карты")
		return
	
	print("ИГРОК ", current_player + 1, " переворачивает карту ", card_index)
	
	if multiplayer.is_server():
		process_card_flip(card_index)
	else:
		request_card_flip.rpc_id(1, card_index)

@rpc("any_peer", "call_local", "reliable")
func request_card_flip(card_index: int):
	if multiplayer.is_server() and game_started:
		process_card_flip(card_index)
	else:
		print("ОШИБКА RPC: Сервер не доступен или игра не начата")

func process_card_flip(card_index: int):
	print("ОБРАБОТКА: Переворот карты ", card_index)
	
	flip_card.rpc(card_index, true)
	flipped_cards.append(card_index)
	
	print("Перевернуто карт: ", flipped_cards.size())
	
	if flipped_cards.size() == 2:
		print("Проверка совпадения...")
		check_card_match()

@rpc("authority", "call_local", "reliable")
func flip_card(card_index: int, show_front: bool):
	if card_index >= cards.size():
		print("ОШИБКА FLIP: Неверный индекс ", card_index)
		return
	
	var card = cards[card_index]
	
	if show_front:
		var card_value = card.get_meta("card_value", 0)
		if card_value < card_textures.size():
			card.icon = card_textures[card_value]
		card.text = ""
		card.set_meta("is_flipped", true)
		print("Карта ", card_index, " перевернута (значение: ", card_value, ")")
	else:
		card.icon = null
		card.text = "?"
		card.set_meta("is_flipped", false)
		print("Карта ", card_index, " скрыта")

func check_card_match():
	print("ПРОВЕРКА СОВПАДЕНИЯ")
	
	if flipped_cards.size() < 2:
		print("ОШИБКА: Недостаточно карт для проверки")
		return
	
	# Даем время увидеть карты
	await get_tree().create_timer(1.5).timeout
	
	var card1_index = flipped_cards[0]
	var card2_index = flipped_cards[1]
	
	if card1_index >= cards.size() or card2_index >= cards.size():
		print("ОШИБКА: Неверные индексы ", card1_index, ", ", card2_index)
		flipped_cards.clear()
		return
	
	var card1 = cards[card1_index]
	var card2 = cards[card2_index]
	
	var value1 = card1.get_meta("card_value", -1)
	var value2 = card2.get_meta("card_value", -1)
	
	print("Сравнение: карта ", card1_index, " = ", value1, ", карта ", card2_index, " = ", value2)
	
	if value1 == value2:
		print("СОВПАДЕНИЕ!")
		process_match(card1_index, card2_index)
	else:
		print("НЕ СОВПАЛО")
		process_no_match(card1_index, card2_index)

func process_match(card1_index: int, card2_index: int):
	print("ИГРОК ", current_player + 1, " нашел пару!")
	
	cards[card1_index].set_meta("is_matched", true)
	cards[card2_index].set_meta("is_matched", true)
	
	scores[current_player] += 1
	matched_pairs += 1
	
	print("Счет: Игрок 1=", scores[0], ", Игрок 2=", scores[1])
	print("Найдено пар: ", matched_pairs, "/", CARD_PAIRS)
	
	# СИНХРОНИЗИРУЕМ СЧЕТ СО ВСЕМИ ИГРОКАМИ
	sync_scores.rpc(scores, matched_pairs)
	
	update_game_ui()
	hide_matched_cards.rpc(card1_index, card2_index)
	
	flipped_cards.clear()
	
	# Проверяем завершение игры
	if matched_pairs >= CARD_PAIRS:
		print("ВСЕ ПАРЫ НАЙДЕНЫ! Завершение игры...")
		end_game("Все пары найдены!")
	else:
		print("Игрок продолжает ход")
		# Тот же игрок ходит снова
		can_play = multiplayer.is_server() if current_player == 0 else not multiplayer.is_server()
		update_game_ui()
		
@rpc("authority", "call_local", "reliable")
func sync_scores(new_scores: Array, new_matched_pairs: int):
	print("СИНХРОНИЗАЦИЯ СЧЕТА: ", new_scores, " пары: ", new_matched_pairs)
	scores = new_scores.duplicate()  # Копируем массив
	matched_pairs = new_matched_pairs
	update_game_ui()

func process_no_match(card1_index: int, card2_index: int):
	print("Не совпало, передача хода")
	
	flip_card.rpc(card1_index, false)
	flip_card.rpc(card2_index, false)
	
	flipped_cards.clear()
	switch_player()

@rpc("authority", "call_local", "reliable")
func hide_matched_cards(card1_index: int, card2_index: int):
	if card1_index < cards.size():
		cards[card1_index].disabled = true
		cards[card1_index].modulate = Color(0.5, 0.5, 0.5, 0.7)
	if card2_index < cards.size():
		cards[card2_index].disabled = true
		cards[card2_index].modulate = Color(0.5, 0.5, 0.5, 0.7)

func switch_player():
	print("СМЕНА ХОДА: Игрок ", current_player + 1, " -> ")
	current_player = 1 if current_player == 0 else 0
	print("Игрок ", current_player + 1)
	
	sync_player_turn.rpc(current_player)
	can_play = multiplayer.is_server() if current_player == 0 else not multiplayer.is_server()
	update_game_ui()

@rpc("authority", "call_local", "reliable")
func sync_player_turn(player_index: int):
	print("СИНХРОНИЗАЦИЯ ХОДА: Игрок ", player_index + 1)
	current_player = player_index
	can_play = multiplayer.is_server() if current_player == 0 else not multiplayer.is_server()
	update_game_ui()

@rpc("authority", "call_local", "reliable")
func start_game():
	print("СТАРТ ИГРЫ получен")
	game_started = true
	
	# Запускаем таймер обратного отсчета
	start_countdown_timer()
	
	can_play = multiplayer.is_server()
	update_game_ui()
	
	if game_status_label:
		game_status_label.text = "Игра началась!"
		game_status_label.add_theme_color_override("font_color", Color.GREEN)

func start_countdown_timer():
	print("ТАЙМЕР: Запуск (300 секунд)")
	var time_left = 300
	
	while time_left > 0 and game_started:
		await get_tree().create_timer(1.0).timeout
		
		# Проверяем еще раз, вдруг игра завершилась во время ожидания
		if not game_started:
			print("ТАЙМЕР: Игра завершена, останавливаю таймер")
			return
		
		time_left -= 1
		
		if timer_label:
			var minutes = time_left / 60
			var seconds = time_left % 60
			timer_label.text = "Время: %02d:%02d" % [minutes, seconds]
		
		# Логируем каждые 30 секунд
		if time_left % 30 == 0:
			print("ТАЙМЕР: Осталось ", time_left, " секунд")
		
		if time_left <= 30 and timer_label:
			timer_label.add_theme_color_override("font_color", Color.RED)
	
	# Проверяем почему вышли из цикла
	if not game_started:
		print("ТАЙМЕР: Остановлен, игра уже завершена")
		return
	
	print("ТАЙМЕР: Время вышло!")
	end_game("Время вышло!")

func end_game(reason: String = ""):
	if not game_started:
		print("end_game вызван, но игра уже завершена")
		return
	
	print("==================================================")
	print("ЗАВЕРШЕНИЕ ИГРЫ НА СЕРВЕРЕ")
	print("Причина: ", reason)
	print("Найдено пар: ", matched_pairs, "/", CARD_PAIRS)
	print("Счет: Игрок 1=", scores[0], ", Игрок 2=", scores[1])
	print("==================================================")
	
	game_started = false
	
	# Отправляем команду завершения всем игрокам
	finish_game_for_all.rpc(reason, scores)

@rpc("authority", "call_local", "reliable")
func finish_game_for_all(reason: String, final_scores: Array):
	print("КОМАНДА ЗАВЕРШЕНИЯ ПОЛУЧЕНА")
	
	# Устанавливаем финальный счет
	scores = final_scores.duplicate()
	game_started = false
	
	# Определяем победителя
	var winner_text = ""
	if scores[0] > scores[1]:
		winner_text = "Победил Игрок 1!"
	elif scores[1] > scores[0]:
		winner_text = "Победил Игрок 2!"
	else:
		winner_text = "Ничья!"
	
	if game_status_label:
		game_status_label.text = "Игра окончена! " + winner_text + "\n" + reason
		game_status_label.add_theme_color_override("font_color", Color.GOLD)
	
	print("Результат: ", winner_text)
	print("Ожидание 3 секунд перед возвратом...")
	
	# Ждем 5 секунд
	await get_tree().create_timer(3.0).timeout
	
	print("=")
	print("MEMORY: Отправка сигнала и прямого вызова")
	print("=")
	
	# 1. Пытаемся отправить сигнал (на всякий случай)
	game_over.emit()
	
	# 2. ПРЯМОЙ ВЫЗОВ: Ищем Game.gd в родительской цепочке
	call_game_return()

func call_game_return():
	print("ПРЯМОЙ ВЫЗОВ: Ищу Game.gd...")
	
	# Поднимаемся по родительской цепочке
	var parent = get_parent()
	var depth = 0
	
	while parent and depth < 10:  # Ограничиваем глубину поиска
		print("Уровень ", depth, ": ", parent.name, " (", parent.get_class(), ")")
		
		# Проверяем есть ли метод _on_memory_game_over
		if parent.has_method("_on_memory_game_over"):
			print("✓ Нашел Game.gd! Вызываю _on_memory_game_over()")
			parent._on_memory_game_over()
			return
		
		parent = parent.get_parent()
		depth += 1
	
	print("✗ Game.gd не найден в родительской цепочке")
	
	# Альтернатива: ищем по имени
	var game_node = get_node_or_null("/root/main")
	if game_node and game_node.has_method("_on_memory_game_over"):
		print("✓ Нашел Game.gd по пути /root/main")
		game_node._on_memory_game_over()
		return
	
	print("✗ Game.gd не найден вообще")
	
@rpc("authority", "call_local", "reliable")
func stop_game_for_all(reason: String):
	# Эта функция вызывается у всех игроков
	game_started = false
	
	# Определяем победителя
	var winner_text = ""
	if scores[0] > scores[1]:
		winner_text = "Победил Игрок 1!"
	elif scores[1] > scores[0]:
		winner_text = "Победил Игрок 2!"
	else:
		winner_text = "Ничья!"
	
	if game_status_label:
		game_status_label.text = "Игра окончена! " + winner_text + "\n" + reason
		game_status_label.add_theme_color_override("font_color", Color.GOLD)
	
	# Ждем 5 секунд чтобы игроки увидели результат
	print("Ожидание 5 секунд перед возвратом...")
	await get_tree().create_timer(5.0).timeout
	
	print("Отправка сигнала game_over")
	game_over.emit()

func _enter_tree():
	if not has_signal("game_over"):
		add_user_signal("game_over")
