# NPC.gd - упрощенная версия с рабочей синхронизацией
extends Node2D

@export var npc_name: String = "Ведущий"
@export var minigame_type: String = "memory"

@onready var anim_sprite = $AnimatedSprite2D
@onready var interaction_area = $InteractionArea
@onready var interaction_label = $InteractionLabel

var ready_players = []    # Синхронизируется через RPC
var players_in_zone = []  # ID игроков в зоне
var minigame_active = false
var dialogue_instance = null

func _ready():
	print("[NPC DEBUG] NPC '", npc_name, "' готов. Позиция: ", position)
	
	# УСТАНАВЛИВАЕМ АВТОРИТЕТ ТОЛЬКО ДЛЯ СЕРВЕРА
	if multiplayer.is_server():
		set_multiplayer_authority(1)  # Сервер
	else:
		# Клиенты НЕ авторитарны над NPC
		pass
	
	if anim_sprite:
		anim_sprite.play("idle")
	
	if interaction_label:
		interaction_label.visible = false
	
	# Подключаем сигналы
	interaction_area.body_entered.connect(_on_body_entered)
	interaction_area.body_exited.connect(_on_body_exited)
	
	print("[NPC DEBUG] NPC инициализирован. Peer:", multiplayer.get_unique_id(), " Сервер:", multiplayer.is_server())

func _on_body_entered(body):
	print("[NPC DEBUG] Тело вошло в зону: ", body.name, " (Класс: ", body.get_class(), ")")
	
	# Проверяем, что это игрок
	if _is_player(body):
		var player_id = int(body.name)
		if player_id not in players_in_zone:
			players_in_zone.append(player_id)
			print("[NPC DEBUG] Игрок ", player_id, " (", body.name, ") добавлен в список в зоне")
		
		# Показываем подсказку для локального игрока
		if body.is_multiplayer_authority():
			print("[NPC DEBUG] Это локальный игрок, показываем метку")
			if interaction_label:
				interaction_label.text = "Диалог открыт"
				interaction_label.visible = true
		
		# Автоматически открываем диалог для локального игрока
		if body.is_multiplayer_authority():
			print("[NPC DEBUG] Открываем диалог для игрока ", body.name)
			show_dialogue(player_id)
			
			# Если мы сервер, немедленно отправляем актуальный список
			if multiplayer.is_server():
				print("[NPC DEBUG] Сервер: отправляю актуальный список игроку", player_id)
				# Небольшая задержка, чтобы диалог успел создатьсь
				await get_tree().create_timer(0.1).timeout
				sync_ready_players.rpc_id(player_id, ready_players)
		else:
			print("[NPC DEBUG] Игрок ", body.name, " не локальный, диалог не открываем")
	else:
		print("[NPC DEBUG] Это не игрок: ", body.name, " (Класс: ", body.get_class(), ")")

func _on_body_exited(body):
	print("[NPC DEBUG] Тело вышло из зоны: ", body.name)
	
	if _is_player(body):
		var player_id = int(body.name)
		if player_id in players_in_zone:
			players_in_zone.erase(player_id)
			print("[NPC DEBUG] Игрок ", player_id, " удален из списка в зоне")
		
		# Скрываем подсказку для локального игрока
		if body.is_multiplayer_authority() and interaction_label:
			interaction_label.visible = false
			print("[NPC DEBUG] Скрыли метку для локального игрока")
		
		# Закрываем диалог для этого игрока
		if body.is_multiplayer_authority() and dialogue_instance:
			close_dialogue(body.name)
			print("[NPC DEBUG] Закрыли диалог для игрока ", body.name)

func _is_player(body) -> bool:
	# Проверяем разными способами, что это игрок
	var is_player = false
	
	# Способ 1: Проверяем имя как число
	if body.name.is_valid_int():
		print("[NPC DEBUG] Имя тела валидно как int: ", body.name)
		is_player = true
	
	# Способ 2: Проверяем класс
	if "Player" in body.get_class():
		print("[NPC DEBUG] Тело содержит 'Player' в классе: ", body.get_class())
		is_player = true
	
	# Способ 3: Проверяем наличие метода
	if body.has_method("is_player"):
		print("[NPC DEBUG] Тело имеет метод is_player")
		is_player = true
	
	print("[NPC DEBUG] Результат проверки is_player: ", is_player)
	return is_player

func show_dialogue(player_id: int):
	print("[NPC DEBUG] Открываем диалог для игрока ", player_id)
	
	# Проверяем, не открыт ли уже диалог
	if dialogue_instance and is_instance_valid(dialogue_instance):
		print("[NPC DEBUG] Диалог уже открыт, выходим")
		return
	
	# Загружаем сцену диалогового окна
	var dialogue_scene = load("res://Scenes/Main/DialogueBox.tscn")
	if not dialogue_scene:
		print("[NPC ERROR] Не могу загрузить сцену диалогового окна!")
		return
	
	# Создаем экземпляр
	dialogue_instance = dialogue_scene.instantiate()
	
	# Передаем данные
	dialogue_instance.npc_name = npc_name
	dialogue_instance.minigame_type = minigame_type
	dialogue_instance.current_player_id = player_id
	# ВАЖНО: Передаем текущий список готовых игроков!
	dialogue_instance.ready_players = ready_players.duplicate()
	
	print("[NPC DEBUG] Передаю в диалог ready_players:", ready_players)
	
	# Передаем позицию NPC для позиционирования диалога
	dialogue_instance.set_meta("npc_position", global_position)
	
	# ПОДКЛЮЧАЕМ СИГНАЛЫ ПРОСТО И ПРАВИЛЬНО
	# Отключаем старые соединения если есть
	if dialogue_instance.is_connected("player_ready", _on_player_ready):
		dialogue_instance.disconnect("player_ready", _on_player_ready)
	
	# Подключаем сигнал
	dialogue_instance.player_ready.connect(_on_dialogue_player_ready)
	print("[NPC DEBUG] Сигнал player_ready подключен")
	
	if dialogue_instance.has_signal("dialogue_closed"):
		dialogue_instance.dialogue_closed.connect(_on_dialogue_closed.bind(str(player_id)))
		print("[NPC DEBUG] Сигнал dialogue_closed подключен")
	
	# Добавляем на сцену
	get_tree().current_scene.add_child(dialogue_instance)
	
	print("[NPC DEBUG] Диалог успешно открыт с ready_players:", ready_players)

# НОВАЯ ФУНКЦИЯ для обработки сигнала из диалога
func _on_dialogue_player_ready(player_id: int):
	print("[NPC _on_dialogue_player_ready] Получен сигнал от диалога для игрока", player_id)
	print("[NPC _on_dialogue_player_ready] Текущий диалог для игрока:", dialogue_instance.current_player_id if dialogue_instance else "нет диалога")
	
	# Используем player_id из сигнала, а не привязываем
	_on_player_ready(player_id)

func _on_player_ready(player_id: int):
	print("[NPC] Игрок ", player_id, " изменил готовность")
	
	# Простая логика как в MinigameTrigger.gd
	if multiplayer.is_server():
		toggle_player_ready(player_id)
	else:
		# Клиент отправляет запрос на сервер
		print("[NPC] Клиент отправляет запрос на сервер для игрока ", player_id)
		request_player_ready.rpc_id(1, player_id)

@rpc("any_peer", "call_local", "reliable")
func request_player_ready(player_id: int):
	if multiplayer.is_server() and not minigame_active:
		print("[NPC] Сервер получил запрос от игрока", player_id)
		toggle_player_ready(player_id)

func toggle_player_ready(player_id: int):
	if minigame_active:
		return
	
	if player_id in ready_players:
		ready_players.erase(player_id)
		print("[NPC] Игрок ", player_id, " снял готовность")
	else:
		ready_players.append(player_id)
		print("[NPC] Игрок ", player_id, " готов")
	
	# Синхронизируем со всеми
	sync_ready_players.rpc(ready_players)
	
	# Проверяем можно ли начать
	if multiplayer.is_server() and ready_players.size() >= 2 and not minigame_active:
		print("[NPC] Оба игрока готовы!")
		minigame_active = true
		
		# ТОЛЬКО сервер запускает отсчет
		start_game_countdown()

@rpc("authority", "call_local", "reliable")
func sync_ready_players(players_list: Array):
	print("[NPC SYNC] Получен список:", players_list, " для NPC в позиции", position)
	print("[NPC SYNC] Мой ID:", multiplayer.get_unique_id(), " сервер?", multiplayer.is_server())
	
	ready_players = players_list.duplicate()
	
	# Обновляем статус над NPC
	if interaction_label:
		interaction_label.text = "Готовы: %d/2" % ready_players.size()
	
	# Обновляем все диалоговые окна
	update_all_dialogue_windows(players_list)

func update_all_dialogue_windows(players_list: Array):
	# Ищем ВСЕ диалоговые окна на сцене
	var all_dialogs = []
	
	# Способ 1: через группу
	var group_dialogs = get_tree().get_nodes_in_group("dialogue")
	print("[NPC UPDATE] Найдено диалогов в группе 'dialogue':", len(group_dialogs))
	all_dialogs.append_array(group_dialogs)
	
	print("[NPC UPDATE] Всего найдено диалогов:", len(all_dialogs))
	
	for dialog in all_dialogs:
		if dialog and dialog.has_method("set_ready_players"):
			print("[NPC UPDATE] Обновляю диалог для игрока", dialog.current_player_id)
			dialog.call_deferred("set_ready_players", players_list.duplicate())
		else:
			print("[NPC UPDATE] Диалог невалиден или не имеет метода set_ready_players")
@rpc("authority", "call_local", "reliable")  
func start_game_countdown():
	print("[NPC] Начинаем отсчет до начала игры")
	minigame_active = true
	
	# Обновляем все диалоговые окна
	if dialogue_instance and is_instance_valid(dialogue_instance):
		dialogue_instance.show_countdown()
	
	# 3 секунды отсчета
	for i in range(3, 0, -1):
		if interaction_label:
			interaction_label.text = "Начинаем через %d..." % i
		await get_tree().create_timer(1.0).timeout
	
	if interaction_label:
		interaction_label.text = "Старт!"
	
	await get_tree().create_timer(0.5).timeout
	
	# ВМЕСТО прямого вызова мини-игры используем новую систему
	launch_minigame()

@rpc("authority", "call_local", "reliable")
func update_countdown_display(step):
	# Эта функция вызывается только сервером, клиенты просто отображают
	if step > 0:
		if interaction_label:
			interaction_label.text = "Начинаем через %d..." % step
	else:
		if interaction_label:
			interaction_label.text = "Старт!"

func close_dialogue(player_name: String):
	if dialogue_instance and is_instance_valid(dialogue_instance):
		# Проверяем, что диалог принадлежит этому игроку
		if dialogue_instance.current_player_id == int(player_name):
			print("[NPC DEBUG] Закрываем диалог для игрока ", player_name)
			dialogue_instance.queue_free()
			dialogue_instance = null

func _on_dialogue_closed(player_name: String):
	print("[NPC] Диалог закрыт игроком ", player_name)
	dialogue_instance = null
	
# ЗАМЕНИТЬ существующую функцию launch_minigame на эту:
func launch_minigame():
	print("NPC: Запуск мини-игры типа: " + minigame_type)
	
	# Закрываем все открытые диалоги
	if dialogue_instance and is_instance_valid(dialogue_instance):
		dialogue_instance.queue_free()
		dialogue_instance = null
	
	# Скрываем статус
	if interaction_label:
		interaction_label.visible = false
	
	# Получаем список готовых игроков
	var players_to_start = ready_players.duplicate()
	reset_npc()
	
	# Запускаем мини-игру через Game.gd
	var game = get_tree().current_scene
	if game and game.has_method("queue_minigame_start"):
		print("NPC: Отправляем запрос на запуск мини-игры для игроков: ", players_to_start)
		
		if multiplayer.is_server():
			# Сервер запускает мини-игру для всех
			game.queue_minigame_start(minigame_type, players_to_start)
		else:
			# Клиент отправляет запрос серверу
			request_minigame_start.rpc_id(1, minigame_type, players_to_start)
func reset_npc():
	ready_players.clear()
	minigame_active = false
	if interaction_label:
		interaction_label.visible = false
		
@rpc("any_peer", "call_local", "reliable")
func request_minigame_start(game_type: String, players: Array):
	if multiplayer.is_server():
		print("СЕРВЕР: Получен запрос на запуск мини-игры ", game_type)
		var game = get_tree().current_scene
		if game and game.has_method("queue_minigame_start"):
			game.queue_minigame_start(game_type, players)
