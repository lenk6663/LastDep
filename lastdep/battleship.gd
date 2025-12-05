extends Node2D

const GRID_SIZE : int = 10
var ship_sizes : Array = [4,3,3,2,2,2,1,1,1,1]

var player_board : Array = []
var enemy_board : Array = []

@onready var title_label : Label = $TitleLabel
@onready var back_button : Button = $BackButton
@onready var ready_button : Button = $ReadyButton
@onready var random_button : Button = $RandomButton
@onready var ships_container : VBoxContainer = $ShipsContainer
@onready var player_grid : GridContainer = $PlayerGrid
@onready var enemy_grid : GridContainer = $EnemyGrid
@onready var message_label : Label = $MessageLabel
@onready var http_request : HTTPRequest = $HTTPRequest

var placing_horizontal : bool = true
var placed_ship_cells : Array = []   # массив массивов координат
var highlight_cells : Array = []     # для подсветки
var ships_data : Array = []          # массив словарей {size, hbox, placed}

var selected_ship_size : int = 4
var selected_ship_hbox : HBoxContainer = null

var server_url : String = "http://127.0.0.1:5000"  # адрес сервера
var player_ready : bool = false

func _ready() -> void:
	title_label.text = "Расстановка кораблей"
	ready_button.visible = false
	random_button.visible = true
	enemy_grid.visible = false
	message_label.text = ""
	
	back_button.pressed.connect(Callable(self, "_on_back_pressed"))
	ready_button.pressed.connect(Callable(self, "_on_ready_pressed"))
	random_button.pressed.connect(Callable(self, "_on_random_pressed"))
	http_request.request_completed.connect(Callable(self, "_on_http_request_completed"))

	_init_boards()
	_create_ships_preview()
	_create_grid(player_grid, player_board, true)
	_create_grid(enemy_grid, enemy_board, false)

	# выбрать первый корабль длиной 4
	for data in ships_data:
		if data.size == 4 and not data.placed:
			_select_ship(data.hbox, 4)
			break
	print("Выставляем корабль длиной: ", selected_ship_size)


# -----------------------------
# ИНИЦИАЛИЗАЦИЯ ДОСОК
# -----------------------------
func _init_boards() -> void:
	player_board.clear()
	enemy_board.clear()
	for y in range(GRID_SIZE):
		player_board.append([])
		enemy_board.append([])
		for x in range(GRID_SIZE):
			player_board[y].append(0)
			enemy_board[y].append(0)


# -----------------------------
# СПИСОК КОРАБЛЕЙ
# -----------------------------
func _create_ships_preview() -> void:
	for child in ships_container.get_children():
		child.queue_free()
	ships_data.clear()

	for size in ship_sizes:
		var hbox : HBoxContainer = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(40*size, 40)
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS

		var ship_size : int = size
		hbox.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed:
				_select_ship(hbox, ship_size)
		)

		for i in range(size):
			var cell : ColorRect = ColorRect.new()
			cell.color = Color(0.4,0.4,0.9)
			cell.custom_minimum_size = Vector2(20,20)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(cell)

		ships_container.add_child(hbox)
		ships_data.append({"size": size, "hbox": hbox, "placed": false})


# -----------------------------
# ВЫБОР КОРАБЛЯ
# -----------------------------
func _select_ship(hbox : HBoxContainer, size : int) -> void:
	if not hbox:
		return
	if selected_ship_hbox:
		for c in selected_ship_hbox.get_children():
			if c: c.color = Color(0.4,0.4,0.9)
	selected_ship_hbox = hbox
	selected_ship_size = size
	for c in hbox.get_children():
		if c: c.color = Color(0.6,0.9,0.6)
	message_label.text = "Выбран корабль длиной: %d" % size


# -----------------------------
# ПРОВЕРКА РАССТАНОВКИ
# -----------------------------
func _can_place_ship(board : Array, x : int, y : int, length : int, horizontal : bool) -> bool:
	if x < 0 or x >= GRID_SIZE or y < 0 or y >= GRID_SIZE:
		return false
	for i in range(length):
		var nx : int = x + (i if horizontal else 0)
		var ny : int = y + (0 if horizontal else i)
		if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
			return false
		for dx in [-1,0,1]:
			for dy in [-1,0,1]:
				var sx : int = nx + dx
				var sy : int = ny + dy
				if sx >= 0 and sx < GRID_SIZE and sy >= 0 and sy < GRID_SIZE:
					if board[sy][sx] == 1:
						return false
	return true


# -----------------------------
# УСТАНОВКА КОРАБЛЯ
# -----------------------------
func _set_ship(board : Array, x : int, y : int, length : int, horizontal : bool, mark_hbox : HBoxContainer = null) -> bool:
	if not board:
		return false
	if not _can_place_ship(board, x, y, length, horizontal):
		return false
	if mark_hbox != null:
		for data in ships_data:
			if data.hbox == mark_hbox and data.placed:
				return false

	var ship_cells : Array = []
	for i in range(length):
		var nx : int = x + (i if horizontal else 0)
		var ny : int = y + (0 if horizontal else i)
		if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
			return false
		board[ny][nx] = 1
		ship_cells.append(Vector2i(nx, ny))
		var b : Button = player_grid.get_node_or_null("%d_%d" % [nx, ny])
		if b:
			b.modulate = Color(0,0.5,1)

	placed_ship_cells.append(ship_cells)

	if mark_hbox != null:
		for data in ships_data:
			if data.hbox == mark_hbox:
				data.placed = true
				for c in mark_hbox.get_children():
					if c: c.color = Color(0.2,0.2,0.2)
				break

	selected_ship_hbox = null
	selected_ship_size = 0
	placing_horizontal = true
	_select_next_ship()
	_check_all_placed()
	_clear_highlight()
	return true


# -----------------------------
# СЕТКА КЛЕТОК
# -----------------------------
func _create_grid(grid : GridContainer, board : Array, is_player : bool) -> void:
	if not grid or not board:
		return
	grid.columns = GRID_SIZE
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var b : Button = Button.new()
			b.name = "%d_%d" % [x, y]
			b.custom_minimum_size = Vector2(40,40)
			if is_player and board[y][x] == 1:
				b.modulate = Color(0,0.5,1)

			b.mouse_entered.connect(func(): _on_cell_hover(b, is_player))
			b.mouse_exited.connect(func(): _clear_highlight())
			b.pressed.connect(func(): _on_cell_pressed(b, board, is_player))
			b.gui_input.connect(func(event: InputEvent) -> void:
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
					placing_horizontal = !placing_horizontal
					if highlight_cells.size() > 0:
						_on_cell_hover(highlight_cells[0], true)
			)
			grid.add_child(b)


# -----------------------------
# ПОДСВЕТКА
# -----------------------------
func _on_cell_hover(button : Button, is_player : bool) -> void:
	if not is_player or selected_ship_size == 0 or not button:
		return
	var coords : Array = button.name.split("_")
	if coords.size() != 2:
		return
	var x : int = int(coords[0])
	var y : int = int(coords[1])
	var length : int = selected_ship_size

	_clear_highlight()
	highlight_cells.clear()
	var can_place : bool = _can_place_ship(player_board, x, y, length, placing_horizontal)

	for i in range(length):
		var nx : int = x + (i if placing_horizontal else 0)
		var ny : int = y + (0 if placing_horizontal else i)
		if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
			can_place = false
			continue
		var b : Button = player_grid.get_node_or_null("%d_%d" % [nx, ny])
		if b:
			b.modulate = Color(0,1,0) if can_place else Color(1,0,0)
			highlight_cells.append(b)

func _clear_highlight() -> void:
	for b in highlight_cells:
		if not b:
			continue
		var coords : Array = b.name.split("_")
		if coords.size() != 2:
			continue
		var x : int = int(coords[0])
		var y : int = int(coords[1])
		if y >= player_board.size() or x >= player_board[y].size():
			continue
		if player_board[y][x] == 1:
			b.modulate = Color(0,0.5,1)
		else:
			b.modulate = Color(1,1,1)
	highlight_cells.clear()


# -----------------------------
# ЛКМ
# -----------------------------
func _on_cell_pressed(button : Button, board : Array, is_player : bool) -> void:
	if not is_player or selected_ship_size == 0 or not button:
		if is_player:
			message_label.text = "Выберите корабль слева!"
		return
	var coords : Array = button.name.split("_")
	var x : int = int(coords[0])
	var y : int = int(coords[1])
	_set_ship(board, x, y, selected_ship_size, placing_horizontal, selected_ship_hbox)


# -----------------------------
# АВТОВЫБОР СЛЕДУЮЩЕГО КОРАБЛЯ
# -----------------------------
func _select_next_ship() -> void:
	for data in ships_data:
		if not data.placed:
			_select_ship(data.hbox, data.size)
			break


# -----------------------------
# ПРОВЕРКА ВСЕХ КОРАБЛЕЙ
# -----------------------------
func _check_all_placed() -> void:
	if ships_data.is_empty():
		return
	var all_placed : bool = true
	for data in ships_data:
		if not data.placed:
			all_placed = false
			break
	if all_placed:
		ready_button.visible = true
		message_label.text = "Все корабли расставлены!"


# -----------------------------
# Случайная расстановка оставшихся
# -----------------------------
func _on_random_pressed() -> void:
	for data in ships_data:
		if not data.placed:
			while true:
				var horizontal : bool = (randi() % 2 == 0)
				var x : int = randi() % GRID_SIZE
				var y : int = randi() % GRID_SIZE
				if _set_ship(player_board, x, y, data.size, horizontal, data.hbox):
					break


# -----------------------------
# Клавиши для поворота
# -----------------------------
func _input(event : InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			placing_horizontal = !placing_horizontal
			if highlight_cells.size() > 0:
				_on_cell_hover(highlight_cells[0], true)


# -----------------------------
# Отмена последнего корабля
# -----------------------------
func _on_back_pressed() -> void:
	if placed_ship_cells.is_empty():
		return

	var last_ship : Array = placed_ship_cells.pop_back()
	for cell in last_ship:
		var x : int = cell.x
		var y : int = cell.y
		if y < player_board.size() and x < player_board[y].size():
			player_board[y][x] = 0
			var b : Button = player_grid.get_node_or_null("%d_%d" % [x, y])
			if b:
				b.modulate = Color(1,1,1)

	# вернуть корабль в список
	for data in ships_data:
		if data.size == last_ship.size() and data.placed:
			data.placed = false
			for c in data.hbox.get_children():
				if c: c.color = Color(0.4,0.4,0.9)
			break

	ready_button.visible = false
	message_label.text = ""


# -----------------------------
# ГОТОВО / МУЛЬТИПЛЕЕР
# -----------------------------
func _on_ready_pressed() -> void:
	player_ready = true
	ready_button.visible = false
	random_button.visible = false
	ships_container.visible = false
	back_button.visible = false
	message_label.text = "Ожидаем второго игрока..."

	var data : Dictionary = {
		"board": player_board,
		"ready": true
	}
	var json_body : String = JSON.stringify(data)
	var body_bytes : PackedByteArray = json_body.to_utf8_buffer()
	var headers : Array = ["Content-Type: application/json"]

	var err : int = http_request.request_raw(
		server_url + "/player_ready",
		headers,
		HTTPClient.METHOD_POST,
		body_bytes
	)
	if err != OK:
		message_label.text = "Ошибка отправки запроса на сервер"

func _on_http_request_completed(result : int, response_code : int, headers : Array, body : PackedByteArray) -> void:
	if response_code == 200:
		var resp_text : String = body.get_string_from_utf8()
		if resp_text == "both_ready":
			title_label.text = "Морской бой"
			enemy_grid.visible = true
			message_label.text = ""
			print("Оба игрока готовы, начинаем игру")
		else:
			message_label.text = "Ждем второго игрока..."
	else:
		message_label.text = "Ошибка связи с сервером"
