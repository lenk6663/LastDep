extends Node2D

signal game_over

const GRID_SIZE : int = 10
var ship_sizes : Array = [4, 3, 3, 2, 2, 2, 1, 1, 1, 1]
var total_ship_cells = 20

var player_board : Array = []  # Мое поле с кораблями
var enemy_shots_board : Array = []  # Куда я стрелял (поле справа)
var player_ships : Array = []  # Мои корабли

@onready var title_label : Label = $CanvasLayer/MainUI/TitleLabel
@onready var timer_label : Label = $CanvasLayer/MainUI/TimerLabel
@onready var player1_label : Label = $CanvasLayer/MainUI/Player1Info/Player1Label
@onready var player1_score_label : Label = $CanvasLayer/MainUI/Player1Info/Player1ScoreLabel
@onready var player2_label : Label = $CanvasLayer/MainUI/Player2Info/Player2Label
@onready var player2_score_label : Label = $CanvasLayer/MainUI/Player2Info/Player2ScoreLabel
@onready var status_label : Label = $CanvasLayer/MainUI/StatusLabel
@onready var ships_container : VBoxContainer = $CanvasLayer/MainUI/GameArea/MyShipsContainer/ShipsContainer
@onready var player_grid : GridContainer = $CanvasLayer/MainUI/GameArea/PlayerSection/PlayerGrid
@onready var enemy_grid : GridContainer = $CanvasLayer/MainUI/GameArea/EnemySection/EnemyGrid
@onready var ready_button : Button = $CanvasLayer/MainUI/ControlButtons/ReadyButton
@onready var random_button : Button = $CanvasLayer/MainUI/ControlButtons/RandomButton
@onready var rotate_button : Button = $CanvasLayer/MainUI/ControlButtons/RotateButton

var placing_horizontal : bool = true
var selected_ship_index : int = 0
var selected_ship_size : int = 4
var selected_ship_hbox : HBoxContainer = null
var highlight_cells : Array = []
var ships_data : Array = []
var placed_ships_count : int = 0
var player_ready : bool = false
var game_started : bool = false
var my_turn : bool = false
var player_number : int = 0
var player_boards = {}  # Доски всех игроков (ключ: player_id)
var player_ships_data = {}  # Корабли всех игроков
var player_hits = {}  # Попадания всех игроков
var current_player_turn : int = 1
var my_id : int = 0
var my_shots_made = []  # Куда я стрелял (мои выстрелы)
var enemy_shots_received = []  # Куда стреляли по мне
var ready_players = []
var opponent_ready : bool = false

func _ready() -> void:
	if not has_signal("game_over"):
		add_user_signal("game_over")
	
	await get_tree().process_frame
	
	if player_grid:
		player_grid.columns = GRID_SIZE
	if enemy_grid:
		enemy_grid.columns = GRID_SIZE
		enemy_grid.visible = false
	
	my_id = multiplayer.get_unique_id()
	player_number = 0 if my_id == 1 else 1
	
	if title_label:
		title_label.text = "МОРСКОЙ БОЙ"
	if timer_label:
		timer_label.text = "Время: 05:00"
	if player1_label:
		player1_label.text = "ИГРОК 1"
	if player1_score_label:
		player1_score_label.text = "Попаданий: 0"
	if player2_label:
		player2_label.text = "ИГРОК 2"
	if player2_score_label:
		player2_score_label.text = "Попаданий: 0"
	if status_label:
		status_label.text = "Расставьте ваши корабли"
	if ready_button:
		ready_button.text = "ГОТОВО"
		ready_button.disabled = true
	if random_button:
		random_button.text = "СЛУЧАЙНО"
	if rotate_button:
		rotate_button.text = "ПОВЕРНУТЬ"
	
	_init_boards()
	
	if player_grid:
		_create_grid(player_grid, true)
	if enemy_grid:
		_create_grid(enemy_grid, false)
	
	_create_ships_preview()
	
	if ready_button:
		ready_button.pressed.connect(_on_ready_pressed)
	if random_button:
		random_button.pressed.connect(_on_random_pressed)
	if rotate_button:
		rotate_button.pressed.connect(_on_rotate_pressed)
	
	if multiplayer.is_server():
		player_boards[1] = []
		player_ships_data[1] = []
		player_hits[1] = 0
		
		var peers = multiplayer.get_peers()
		if peers.size() > 0:
			player_boards[peers[0]] = []
			player_ships_data[peers[0]] = []
			player_hits[peers[0]] = 0

func _init_boards():
	player_board.clear()
	player_ships.clear()
	enemy_shots_board.clear()
	placed_ships_count = 0
	my_shots_made.clear()
	enemy_shots_received.clear()
	
	for y in range(GRID_SIZE):
		player_board.append([])
		enemy_shots_board.append([])
		for x in range(GRID_SIZE):
			player_board[y].append(0)
			enemy_shots_board[y].append(0)

func _create_grid(grid: GridContainer, is_player: bool):
	if not grid:
		return
	
	for child in grid.get_children():
		child.queue_free()
	
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var button = Button.new()
			button.name = "%d_%d" % [x, y]
			button.custom_minimum_size = Vector2(40, 40)
			button.add_theme_font_size_override("font_size", 16)
			
			if is_player:
				button.text = ""
				button.disabled = game_started
				if not game_started:
					button.pressed.connect(_on_player_cell_pressed.bind(button))
					button.mouse_entered.connect(_on_cell_hover.bind(button))
					button.mouse_exited.connect(_on_cell_exited)
				else:
					button.disabled = true
			else:
				button.text = "?"
				button.disabled = true  # Сначала все кнопки отключены
				button.visible = game_started
				button.pressed.connect(_on_enemy_cell_pressed.bind(button))
			
			grid.add_child(button)

func _create_ships_preview():
	if not ships_container:
		return
	
	for child in ships_container.get_children():
		child.queue_free()
	
	ships_data.clear()
	
	for i in range(ship_sizes.size()):
		var size = ship_sizes[i]
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(40 * size, 40)
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		
		for j in range(size):
			var cell = ColorRect.new()
			cell.color = Color(0.2, 0.4, 0.8)
			cell.custom_minimum_size = Vector2(30, 30)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(cell)
		
		hbox.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				_select_ship(hbox, size, i)
		)
		
		ships_container.add_child(hbox)
		ships_data.append({
			"hbox": hbox,
			"size": size,
			"placed": false,
			"index": i,
			"horizontal": true
		})
	
	if ships_data.size() > 0:
		_select_ship(ships_data[0]["hbox"], ship_sizes[0], 0)

func _select_ship(hbox: HBoxContainer, size: int, index: int):
	if selected_ship_hbox:
		for c in selected_ship_hbox.get_children():
			if c is ColorRect:
				if not ships_data[selected_ship_index]["placed"]:
					c.color = Color(0.2, 0.4, 0.8)
				else:
					c.color = Color(0, 1, 0)
	
	selected_ship_hbox = hbox
	selected_ship_size = size
	selected_ship_index = index
	
	for c in hbox.get_children():
		if c is ColorRect:
			if ships_data[index]["placed"]:
				c.color = Color(0, 1, 0)
			else:
				c.color = Color(1, 1, 0)
	
	for data in ships_data:
		if data["hbox"] == hbox:
			placing_horizontal = data["horizontal"]
			break
	
	if status_label:
		status_label.text = "Выбран корабль размером %d (осталось: %d)" % [size, ship_sizes.size() - placed_ships_count]

func _on_rotate_pressed():
	if selected_ship_hbox and not game_started:
		placing_horizontal = !placing_horizontal
		
		for data in ships_data:
			if data["hbox"] == selected_ship_hbox:
				data["horizontal"] = placing_horizontal
				break
		
		var children = selected_ship_hbox.get_children()
		selected_ship_hbox.queue_free()
		
		var new_hbox = HBoxContainer.new()
		new_hbox.custom_minimum_size = Vector2(40 * selected_ship_size, 40)
		new_hbox.mouse_filter = Control.MOUSE_FILTER_PASS
		
		for i in range(selected_ship_size):
			var cell = ColorRect.new()
			if ships_data[selected_ship_index]["placed"]:
				cell.color = Color(0, 1, 0)
			else:
				cell.color = Color(1, 1, 0)
			cell.custom_minimum_size = Vector2(30, 30)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			new_hbox.add_child(cell)
		
		new_hbox.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.pressed:
				_select_ship(new_hbox, selected_ship_size, selected_ship_index)
		)
		
		ships_container.add_child(new_hbox)
		ships_container.move_child(new_hbox, selected_ship_index)
		selected_ship_hbox = new_hbox
		
		for data in ships_data:
			if data["index"] == selected_ship_index:
				data["hbox"] = new_hbox
				break

func _on_cell_hover(button: Button):
	if game_started or not selected_ship_hbox or placed_ships_count >= ship_sizes.size():
		return
	
	var coords = button.name.split("_")
	if coords.size() != 2:
		return
	
	var start_x = int(coords[0])
	var start_y = int(coords[1])
	
	_on_cell_exited()
	
	if _can_place_ship(start_x, start_y, selected_ship_size, placing_horizontal):
		for i in range(selected_ship_size):
			var x = start_x + (i if placing_horizontal else 0)
			var y = start_y + (i if not placing_horizontal else 0)
			
			if x < GRID_SIZE and y < GRID_SIZE:
				var cell_button = player_grid.get_node("%d_%d" % [x, y])
				if cell_button:
					cell_button.modulate = Color(1, 1, 0)
					highlight_cells.append(cell_button)
	else:
		button.modulate = Color(1, 0, 0)
		highlight_cells.append(button)

func _on_cell_exited():
	for button in highlight_cells:
		var coords = button.name.split("_")
		if coords.size() == 2:
			var x = int(coords[0])
			var y = int(coords[1])
			
			if y < player_board.size() and x < player_board[y].size():
				if player_board[y][x] == 1:
					button.modulate = Color(0, 1, 0)
				else:
					button.modulate = Color(1, 1, 1)
	
	highlight_cells.clear()

func _can_place_ship(start_x: int, start_y: int, size: int, horizontal: bool) -> bool:
	if placed_ships_count >= ship_sizes.size():
		return false
	
	if horizontal:
		if start_x + size > GRID_SIZE:
			return false
	else:
		if start_y + size > GRID_SIZE:
			return false
	
	for i in range(size):
		var x = start_x + (i if horizontal else 0)
		var y = start_y + (i if not horizontal else 0)
		
		if player_board[y][x] == 1:
			return false
		
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				var nx = x + dx
				var ny = y + dy
				
				if nx >= 0 and nx < GRID_SIZE and ny >= 0 and ny < GRID_SIZE:
					if player_board[ny][nx] == 1:
						return false
	
	return true

func _on_player_cell_pressed(button: Button):
	if game_started or placed_ships_count >= ship_sizes.size():
		return
	
	if not selected_ship_hbox:
		if status_label:
			status_label.text = "Сначала выберите корабль!"
		return
	
	var coords = button.name.split("_")
	if coords.size() != 2:
		return
	
	var start_x = int(coords[0])
	var start_y = int(coords[1])
	
	if _can_place_ship(start_x, start_y, selected_ship_size, placing_horizontal):
		var ship_cells = []
		for i in range(selected_ship_size):
			var x = start_x + (i if placing_horizontal else 0)
			var y = start_y + (i if not placing_horizontal else 0)
			
			player_board[y][x] = 1
			ship_cells.append(Vector2(x, y))
			
			var cell_button = player_grid.get_node("%d_%d" % [x, y])
			if cell_button:
				cell_button.modulate = Color(0, 1, 0)
				cell_button.text = "█"
		
		player_ships.append({
			"x": start_x,
			"y": start_y,
			"size": selected_ship_size,
			"horizontal": placing_horizontal,
			"cells": ship_cells,
			"hits": 0
		})
		
		for data in ships_data:
			if data["hbox"] == selected_ship_hbox:
				data["placed"] = true
				for c in data["hbox"].get_children():
					if c is ColorRect:
						c.color = Color(0, 1, 0)
				break
		
		placed_ships_count += 1
		
		_select_next_ship()
		_check_all_placed()
	else:
		if status_label:
			status_label.text = "Нельзя поставить корабль здесь!"

func _on_placed_ship_clicked(button: Button):
	if game_started or player_ready:
		return
	
	var coords = button.name.split("_")
	if coords.size() != 2:
		return
	
	var x = int(coords[0])
	var y = int(coords[1])
	
	if player_board[y][x] == 1:
		for ship_index in range(player_ships.size()):
			var ship = player_ships[ship_index]
			for cell in ship["cells"]:
				if cell.x == x and cell.y == y:
					_remove_ship(ship_index)
					return

func _remove_ship(ship_index: int):
	var ship = player_ships[ship_index]
	
	for cell in ship["cells"]:
		player_board[cell.y][cell.x] = 0
		
		var button = player_grid.get_node("%d_%d" % [cell.x, cell.y])
		if button:
			button.modulate = Color(1, 1, 1)
			button.text = ""
	
	for data in ships_data:
		if data["size"] == ship["size"] and data["placed"]:
			data["placed"] = false
			for c in data["hbox"].get_children():
				if c is ColorRect:
					c.color = Color(0.2, 0.4, 0.8)
			break
	
	player_ships.remove_at(ship_index)
	placed_ships_count -= 1
	
	_select_next_ship()
	if ready_button:
		ready_button.disabled = true
		ready_button.modulate = Color(0.5, 0.5, 0.5)
	
	if status_label:
		status_label.text = "Корабль возвращен"

func _select_next_ship():
	for data in ships_data:
		if not data["placed"]:
			_select_ship(data["hbox"], data["size"], data["index"])
			return
	
	selected_ship_hbox = null
	selected_ship_size = 0
	selected_ship_index = -1

func _check_all_placed():
	if placed_ships_count != ship_sizes.size():
		if ready_button:
			ready_button.disabled = true
		return
	
	if status_label:
		status_label.text = "Все корабли расставлены! Нажмите 'ГОТОВО'"
	if ready_button:
		ready_button.disabled = false
		ready_button.modulate = Color(1, 1, 1)

func _on_random_pressed():
	if game_started:
		return
	
	_init_boards()
	
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var button = player_grid.get_node("%d_%d" % [x, y])
			if button:
				button.modulate = Color(1, 1, 1)
				button.text = ""
	
	for data in ships_data:
		data["placed"] = false
		for c in data["hbox"].get_children():
			if c is ColorRect:
				c.color = Color(0.2, 0.4, 0.8)
	
	var temp_board = []
	for y in range(GRID_SIZE):
		temp_board.append([])
		for x in range(GRID_SIZE):
			temp_board[y].append(0)
	
	player_ships.clear()
	placed_ships_count = 0
	
	for ship_size in ship_sizes:
		var placed = false
		var attempts = 0
		
		while not placed and attempts < 100:
			var horizontal = randi() % 2 == 0
			var x = randi() % (GRID_SIZE - (ship_size if horizontal else 0))
			var y = randi() % (GRID_SIZE - (0 if horizontal else ship_size))
			
			var can_place = true
			var ship_cells = []
			
			for i in range(ship_size):
				var cx = x + (i if horizontal else 0)
				var cy = y + (i if not horizontal else 0)
				
				if cx >= GRID_SIZE or cy >= GRID_SIZE:
					can_place = false
					break
				
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						var nx = cx + dx
						var ny = cy + dy
						
						if nx >= 0 and nx < GRID_SIZE and ny >= 0 and ny < GRID_SIZE:
							if temp_board[ny][nx] == 1:
								can_place = false
								break
				
				if not can_place:
					break
				
				ship_cells.append(Vector2(cx, cy))
			
			if can_place:
				for cell in ship_cells:
					temp_board[cell.y][cell.x] = 1
					player_board[cell.y][cell.x] = 1
				
				player_ships.append({
					"x": x,
					"y": y,
					"size": ship_size,
					"horizontal": horizontal,
					"cells": ship_cells,
					"hits": 0
				})
				
				placed = true
				placed_ships_count += 1
			
			attempts += 1
		
		if not placed:
			if status_label:
				status_label.text = "Ошибка при случайной расстановке!"
			return
	
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			if player_board[y][x] == 1:
				var button = player_grid.get_node("%d_%d" % [x, y])
				if button:
					button.modulate = Color(0, 1, 0)
					button.text = "█"
	
	for data in ships_data:
		data["placed"] = true
		for c in data["hbox"].get_children():
			if c is ColorRect:
				c.color = Color(0, 1, 0)
	
	_check_all_placed()
	if status_label:
		status_label.text = "Корабли расставлены случайно!"

func _on_ready_pressed():
	if game_started or placed_ships_count != ship_sizes.size():
		return
	
	player_ready = true
	if ready_button:
		ready_button.text = "ОЖИДАНИЕ..."
		ready_button.disabled = true
	if random_button:
		random_button.visible = false
	if rotate_button:
		rotate_button.visible = false
	if status_label:
		status_label.text = "Ожидание второго игрока..."
	
	if multiplayer.is_server():
		player_ready_changed.rpc(1, true)
	else:
		report_ready.rpc_id(1, multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func report_ready(player_id: int):
	if multiplayer.is_server():
		player_ready_changed.rpc(player_id, true)

@rpc("authority", "call_local", "reliable")
func player_ready_changed(player_id: int, ready: bool):
	if player_id == my_id:
		player_ready = true
	else:
		opponent_ready = true
	
	if status_label:
		if player_ready and not opponent_ready:
			status_label.text = "Вы готовы. Ожидание второго игрока..."
		elif opponent_ready and not player_ready:
			status_label.text = "Противник готов. Расставьте свои корабли и нажмите ГОТОВО"
		elif player_ready and opponent_ready:
			status_label.text = "Оба игрока готовы. Начинаем игру..."
	
	if multiplayer.is_server() and player_ready and opponent_ready:
		collect_boards.rpc()

@rpc("any_peer", "call_local", "reliable")
func collect_boards():
	if multiplayer.is_server():
		player_boards[1] = player_board
		player_ships_data[1] = player_ships
		player_hits[1] = 0
	else:
		send_board.rpc_id(1, multiplayer.get_unique_id(), player_board, player_ships)

@rpc("any_peer", "call_local", "reliable")
func send_board(player_id: int, board: Array, ships: Array):
	if multiplayer.is_server():
		player_boards[player_id] = board
		player_ships_data[player_id] = ships
		player_hits[player_id] = 0
		
		if player_boards.size() >= 2:
			start_game.rpc(1)

@rpc("authority", "call_local", "reliable")
func start_game(starting_player_id: int):
	game_started = true
	current_player_turn = starting_player_id
	my_turn = (my_id == current_player_turn)
	
	if enemy_grid:
		enemy_grid.visible = true
		for button in enemy_grid.get_children():
			button.visible = true
	
	if title_label:
		title_label.text = "МОРСКОЙ БОЙ - ИГРА"
	
	_update_turn_ui()
	_update_enemy_grid_buttons()
	
	if ships_container:
		ships_container.visible = false
	
	start_timer()

func _update_turn_ui():
	var turn_text = "ВАШ ХОД" if my_turn else "Ход противника"
	if status_label:
		status_label.text = "Игра началась! " + turn_text

func _update_enemy_grid_buttons():
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var button = enemy_grid.get_node("%d_%d" % [x, y])
			if button:
				if my_turn:
					button.disabled = false
				else:
					button.disabled = true
				button.text = "?"

func start_timer():
	var time_left = 300
	
	while time_left > 0 and game_started:
		await get_tree().create_timer(1.0).timeout
		time_left -= 1
		
		var minutes = time_left / 60
		var seconds = time_left % 60
		if timer_label:
			timer_label.text = "Время: %02d:%02d" % [minutes, seconds]
		
		if time_left <= 0:
			end_game.rpc("Время вышло!")

func _on_enemy_cell_pressed(button: Button):
	if not game_started:
		if status_label:
			status_label.text = "Игра еще не началась!"
		return
	
	if not my_turn:
		if status_label:
			status_label.text = "Сейчас не ваш ход!"
		return
	
	var coords = button.name.split("_")
	if coords.size() != 2:
		return
	
	var x = int(coords[0])
	var y = int(coords[1])
	
	var shot_key = "shot_" + str(x) + "_" + str(y)
	if my_shots_made.has(shot_key):
		if status_label:
			status_label.text = "Вы уже стреляли сюда!"
		return
	
	if multiplayer.is_server():
		process_shot.rpc(x, y, multiplayer.get_unique_id())
	else:
		request_shot.rpc_id(1, x, y, multiplayer.get_unique_id())

@rpc("any_peer", "call_local", "reliable")
func request_shot(x: int, y: int, shooter_id: int):
	if multiplayer.is_server():
		process_shot.rpc(x, y, shooter_id)

@rpc("authority", "call_local", "reliable")
func process_shot(x: int, y: int, shooter_id: int):
	if not game_started:
		return
	
	if shooter_id != current_player_turn:
		print("Сейчас не ход игрока", shooter_id)
		return
	
	var target_id = 1 if shooter_id != 1 else multiplayer.get_peers()[0]
	var target_board = player_boards.get(target_id, [])
	var target_ships = player_ships_data.get(target_id, [])
	
	var hit = false
	if target_board.size() > y and target_board[y].size() > x:
		hit = (target_board[y][x] == 1)
	
	if hit:
		player_hits[shooter_id] = player_hits.get(shooter_id, 0) + 1
		
		for ship in target_ships:
			for cell in ship["cells"]:
				if cell.x == x and cell.y == y:
					ship["hits"] = ship.get("hits", 0) + 1
					if ship["hits"] >= ship["size"]:
						print("Корабль потоплен!")
					break
	
	shot_result.rpc(x, y, hit, shooter_id, player_hits)
	
	if not hit:
		current_player_turn = target_id
		switch_turn.rpc(current_player_turn, hit)
		print("Передача хода игроку", current_player_turn)
	else:
		switch_turn.rpc(current_player_turn, hit)
	
	if player_hits.get(shooter_id, 0) >= total_ship_cells:
		end_game.rpc("Игрок " + str(shooter_id) + " победил!")

@rpc("authority", "call_local", "reliable")
func shot_result(x: int, y: int, hit: bool, shooter_id: int, new_hits: Dictionary):
	if shooter_id == my_id:
		my_shots_made.append("shot_" + str(x) + "_" + str(y))
		var button = enemy_grid.get_node("%d_%d" % [x, y])
		if button:
			if hit:
				button.text = "X"
				button.modulate = Color(1, 0, 0)
				button.disabled = true
			else:
				button.text = "•"
				button.modulate = Color(0.5, 0.5, 0.5)
				button.disabled = true
	
	if shooter_id != my_id:
		enemy_shots_received.append(Vector2(x, y))
		var my_button = player_grid.get_node("%d_%d" % [x, y])
		if my_button:
			if hit:
				my_button.text = "X"
				my_button.modulate = Color(1, 0, 0)
			else:
				my_button.text = "•"
				my_button.modulate = Color(0.5, 0.5, 0.5)
	
	player_hits = new_hits.duplicate()
	
	if player1_score_label:
		player1_score_label.text = "Попаданий: %d/%d" % [player_hits.get(1, 0), total_ship_cells]
	
	var player2_id = multiplayer.get_peers()[0] if multiplayer.get_peers().size() > 0 else 2
	if player2_score_label:
		player2_score_label.text = "Попаданий: %d/%d" % [player_hits.get(player2_id, 0), total_ship_cells]

@rpc("authority", "call_local", "reliable")
func switch_turn(new_player_id: int, was_hit: bool):
	current_player_turn = new_player_id
	my_turn = (my_id == current_player_turn)
	
	if was_hit:
		print("Игрок", multiplayer.get_unique_id(), "попал, продолжает ход")
	else:
		print("Игрок", multiplayer.get_unique_id(), "промахнулся, передача хода")
	
	_update_turn_ui()
	_update_enemy_grid_buttons()
	
	if status_label:
		var player_num = "1" if current_player_turn == 1 else "2"
		if my_turn:
			status_label.text = "Ход игрока " + player_num + " - ВАШ ХОД"
		else:
			status_label.text = "Ход игрока " + player_num + " - Ход противника"

@rpc("authority", "call_local", "reliable")
func end_game(reason: String):
	if not game_started:
		return
	
	game_started = false
	
	var winner_text = ""
	var max_hits = -1
	var winner_id = 0
	
	for player_id in player_hits:
		if player_hits[player_id] > max_hits:
			max_hits = player_hits[player_id]
			winner_id = player_id
	
	if winner_id == 1:
		winner_text = "ПОБЕДИЛ ИГРОК 1!"
	elif winner_id == multiplayer.get_peers()[0] if multiplayer.get_peers().size() > 0 else 2:
		winner_text = "ПОБЕДИЛ ИГРОК 2!"
	else:
		winner_text = "НИЧЬЯ!"
	
	if status_label:
		status_label.text = "ИГРА ОКОНЧЕНА!\n" + winner_text + "\n" + reason
		status_label.add_theme_color_override("font_color", Color.GOLD)
	
	await get_tree().create_timer(5.0).timeout
	
	game_over.emit()

func _enter_tree():
	if not has_signal("game_over"):
		add_user_signal("game_over")
