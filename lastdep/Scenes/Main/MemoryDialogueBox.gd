extends Node2D

signal player_ready(player_id: int)
signal dialogue_closed

var npc_name: String = ""
var dialogue_data: Array[Dictionary] = []
var current_player_id: int = -1
var ready_players: Array = []
var minigame_type: String = ""

@onready var panel = $Panel
@onready var title_label = $Panel/TitleLabel
@onready var content_label = $Panel/ContentLabel
@onready var ready_button = $Panel/ReadyButton
@onready var ready_status_label = $Panel/ReadyStatusLabel

var is_player_ready: bool = false

func _ready():
	add_to_group("dialogue")
	print("[DIALOG DEBUG] Диалоговое окно создано для игрока ", current_player_id)
	_setup_appearance()
	update_content()
	ready_button.pressed.connect(_on_ready_pressed)
	position_dialog_above_npc()
	

	is_player_ready = current_player_id in ready_players
	print("[DIALOG DEBUG] Инициализация: игрок", current_player_id, 
		  " ready=", is_player_ready, " из списка:", ready_players)
	
	update_ready_status()

func _setup_appearance():
	title_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	content_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.custom_minimum_size = Vector2(200, 150)
	
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.2, 0.4, 0.8, 0.9)  # Синий полупрозрачный
	panel_style.border_color = Color(0.1, 0.2, 0.6, 1.0)
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 15
	panel_style.corner_radius_top_right = 15
	panel_style.corner_radius_bottom_right = 15
	panel_style.corner_radius_bottom_left = 15
	panel.add_theme_stylebox_override("panel", panel_style)
	
	
	title_label.add_theme_font_size_override("font_size", 10)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1))
	content_label.add_theme_font_size_override("font_size", 8)
	content_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	ready_status_label.add_theme_font_size_override("font_size", 7)
	ready_status_label.add_theme_color_override("font_color", Color.YELLOW)
	
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.3, 0.6, 0.3, 1.0)  # Зеленый
	button_style.border_color = Color(0.1, 0.3, 0.1, 1.0)
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_right = 5
	button_style.corner_radius_bottom_left = 5
	ready_button.add_theme_stylebox_override("normal", button_style)
	
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.4, 0.7, 0.4, 1.0)
	ready_button.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = button_style.duplicate()
	pressed_style.bg_color = Color(0.2, 0.5, 0.2, 1.0)
	ready_button.add_theme_stylebox_override("pressed", pressed_style)
	
	ready_button.add_theme_font_size_override("font_size", 5)
	ready_button.add_theme_color_override("font_color", Color.WHITE)

func update_content():
	title_label.text = get_dialog_title()
	
	content_label.text = get_dialog_text()
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	
	update_ready_status()

func get_dialog_title():
	match minigame_type:
		"memory":
			return "Приветствую! Игра 'Память'"
		"battleship":
			return "Добро пожаловать! 'Поиск фейерверков'"
		"shooting":
			return "Здравствуйте! 'Стрельба по мишеням'"
		_:
			return "Добро пожаловать!"

func get_dialog_text():
	match minigame_type:
		"memory":
			return """
			Добро пожаловать на игру 'Память'!
			Правила просты:
			1. На столе лежат карточки рубашкой вверх
			2. Открывайте по две карточки за ход
			3. Если карточки совпадают - вы получаете очко и продолжаете ход
			4. Игра продолжается, пока не будут найдены все пары
			5. Побеждает игрок с наибольшим количеством пар
			Готовы проверить свою память?
			"""
		"battleship":
			return """
			Приветствую в игре 'Поиск фейерверков'!
			Ваша задача:
			1. На поле спрятаны фейерверки
			2. По очереди выбирайте клетки на поле
			3. Если попали во фейерверк - получаете очко
			4. Побеждает игрок, нашедший больше фейерверков
			Удачи в поисках!
			"""
		"shooting":
			return """
			Добро пожаловать на стрельбище!
			Правила игры:
			1. Стреляйте по мишеням, которые появляются на экране
			2. За каждое попадание получаете очки
			3. Избегайте попадания в свои цели
			4. Игра длится 2 минуты
			5. Побеждает игрок с наибольшим счетомф
			Готовы показать свою меткость?
			"""

func update_ready_status():
	if is_player_ready:
		ready_button.text = "ГОТОВ"
	else:
		ready_button.text = "ПРИГОТОВИТЬСЯ"
	
	# Обновляем статус
	print("[DIALOG DEBUG] Обновление статуса: игрок ", current_player_id, 
		  " (локальный: ", multiplayer.get_unique_id(), 
		  ") ready=", is_player_ready)
	print("[DIALOG DEBUG] Список готовых игроков:", ready_players)
	
	ready_status_label.text = "Готовы: %d/2 игрока" % [ready_players.size()]

func position_dialog_above_npc():
	var npc_position = get_meta("npc_position", Vector2.ZERO)
	
	self.position = npc_position + Vector2(-100, -100)

func _on_ready_pressed():
	is_player_ready = !is_player_ready
	
	print("[DIALOG] Игрок ", current_player_id, 
		  " (локальный ID: ", multiplayer.get_unique_id(), 
		  ") изменил готовность на: ", is_player_ready)
	
	update_ready_status()
	
	print("[DIALOG] Отправляю сигнал player_ready для игрока ", current_player_id)
	player_ready.emit(current_player_id)


func set_ready_players(players_list: Array):
	print("[DIALOG] set_ready_players вызвана для игрока ", current_player_id)
	print("[DIALOG] Получен список готовых игроков:", players_list)
	
	ready_players = players_list.duplicate()
	is_player_ready = current_player_id in ready_players
	
	print("[DIALOG] После синхронизации: is_player_ready =", is_player_ready)
	
	update_ready_status()

func show_countdown():
	print("[DIALOG] Показываю отсчет для игрока ", current_player_id)
	ready_button.disabled = true
	ready_status_label.text = "Начинаем игру..."

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		print("[DIALOG] Закрытие по ESC для игрока ", current_player_id)
		dialogue_closed.emit()
		queue_free()
