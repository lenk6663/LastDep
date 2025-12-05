extends Node2D

const GRID_SIZE = 10
var ship_sizes := [4,3,3,2,2,2,1,1,1,1]

var player_board : Array = []
var enemy_board : Array = []

@onready var title_label: Label = $TitleLabel
@onready var back_button: Button = $BackButton
@onready var ready_button: Button = $ReadyButton
@onready var random_button: Button = $RandomButton
@onready var ships_container: VBoxContainer = $ShipsContainer
@onready var player_grid: GridContainer = $PlayerGrid
@onready var enemy_grid: GridContainer = $EnemyGrid
@onready var message_label: Label = $MessageLabel

var placing_horizontal := true
var placed_ship_cells := []   # массив массивов координат
var highlight_cells := []     # для подсветки
var ships_data := []          # массив словарей {size, hbox, placed}

var selected_ship_size: int = 4
var selected_ship_hbox: HBoxContainer = null

func _ready():
	title_label.text = "Расстановка кораблей"
	ready_button.visible = false
	random_button.visible = true
	enemy_grid.visible = false
	message_label.text = ""
	
	back_button.pressed.connect(_on_back_pressed)
	ready_button.pressed.connect(_on_ready_pressed)
	random_button.pressed.connect(_on_random_pressed)

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
func _init_boards():
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
func _create_ships_preview():
	for child in ships_container.get_children():
		child.queue_free()
	ships_data.clear()

	for size in ship_sizes:
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(40*size, 40)
		hbox.mouse_filter = Control.MOUSE_FILTER_PASS

		var ship_size = size
		hbox.gui_input.connect(func(event, h=hbox, s=ship_size):
			if event is InputEventMouseButton and event.pressed:
				_select_ship(h, s)
		)

		for i in range(size):
			var cell = ColorRect.new()
			cell.color = Color(0.4,0.4,0.9)
			cell.custom_minimum_size = Vector2(20,20)
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hbox.add_child(cell)

		ships_container.add_child(hbox)
		ships_data.append({"size": size, "hbox": hbox, "placed": false})


# -----------------------------
# ВЫБОР КОРАБЛЯ
# -----------------------------
func _select_ship(hbox, size):
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
func _can_place_ship(board: Array, x: int, y: int, length: int, horizontal: bool) -> bool:
	if x < 0 or x >= GRID_SIZE or y < 0 or y >= GRID_SIZE:
		return false
	for i in range(length):
		var nx = x + (i if horizontal else 0)
		var ny = y + (0 if horizontal else i)
		if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
			return false
		for dx in [-1,0,1]:
			for dy in [-1,0,1]:
				var sx = nx + dx
				var sy = ny + dy
				if sx >= 0 and sx < GRID_SIZE and sy >= 0 and sy < GRID_SIZE:
					if board[sy][sx] == 1:
						return false
	return true


# -----------------------------
# ОБЩАЯ ФУНКЦИЯ УСТАНОВКИ КОРАБЛЯ
# -----------------------------
func _set_ship(board: Array, x: int, y: int, length: int, horizontal: bool, mark_hbox: HBoxContainer = null) -> bool:
	if not board:
		return false
	if not _can_place_ship(board, x, y, length, horizontal):
		return false
	if mark_hbox != null:
		for data in ships_data:
			if data.hbox == mark_hbox and data.placed:
				return false  # корабль уже установлен

	var ship_cells := []
	for i in range(length):
		var nx = x + (i if horizontal else 0)
		var ny = y + (0 if horizontal else i)
		if nx < 0 or nx >= GRID_SIZE or ny < 0 or ny >= GRID_SIZE:
			return false
		board[ny][nx] = 1
		ship_cells.append(Vector2i(nx, ny))
		var b = player_grid.get_node("%d_%d" % [nx, ny])
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
func _create_grid(grid: GridContainer, board: Array, is_player: bool):
	if not grid or not board:
		return
	grid.columns = GRID_SIZE
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var b = Button.new()
			if not b:
				continue
			b.name = "%d_%d" % [x, y]
			b.custom_minimum_size = Vector2(40,40)
			if is_player and board[y][x]==1:
				b.modulate = Color(0,0.5,1)

			b.mouse_entered.connect(func(): _on_cell_hover(b, is_player))
			b.mouse_exited.connect(func(): _clear_highlight())
			b.pressed.connect(func(): _on_cell_pressed(b, board, is_player))
			b.gui_input.connect(func(event):
				if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
					placing_horizontal = !placing_horizontal
					if highlight_cells.size()>0:
						_on_cell_hover(highlight_cells[0], true)
			)
			grid.add_child(b)


# -----------------------------
# ПОДСВЕТКА
# -----------------------------
func _on_cell_hover(button: Button, is_player: bool):
	if not is_player or selected_ship_size==0 or not button:
		return
	var coords = button.name.split("_")
	if coords.size() != 2:
		return
	var x = int(coords[0])
	var y = int(coords[1])
	var length = selected_ship_size

	_clear_highlight()
	highlight_cells.clear()
	var can_place = _can_place_ship(player_board, x, y, length, placing_horizontal)

	for i in range(length):
		var nx = x + (i if placing_horizontal else 0)
		var ny = y + (0 if placing_horizontal else i)
		if nx<0 or nx>=GRID_SIZE or ny<0 or ny>=GRID_SIZE:
			can_place=false
			continue
		var b = player_grid.get_node("%d_%d" % [nx, ny])
		if b:
			b.modulate = Color(0,1,0) if can_place else Color(1,0,0)
			highlight_cells.append(b)

func _clear_highlight():
	for b in highlight_cells:
		if not b:
			continue
		var coords = b.name.split("_")
		if coords.size() != 2:
			continue
		var x = int(coords[0])
		var y = int(coords[1])
		if y >= player_board.size() or x >= player_board[y].size():
			continue
		if player_board[y][x]==1:
			b.modulate = Color(0,0.5,1)
		else:
			b.modulate = Color(1,1,1)
	highlight_cells.clear()


# -----------------------------
# ЛКМ
# -----------------------------
func _on_cell_pressed(button: Button, board: Array, is_player: bool):
	if not is_player or selected_ship_size==0 or not button:
		if is_player:
			message_label.text = "Выберите корабль слева!"
		return
	var coords = button.name.split("_")
	if coords.size() != 2:
		return
	var x = int(coords[0])
	var y = int(coords[1])
	_set_ship(board, x, y, selected_ship_size, placing_horizontal, selected_ship_hbox)


# -----------------------------
# АВТОВЫБОР СЛЕДУЮЩЕГО КОРАБЛЯ
# -----------------------------
func _select_next_ship():
	for data in ships_data:
		if not data.placed:
			_select_ship(data.hbox, data.size)
			break


# -----------------------------
# ПРОВЕРКА ВСЕХ КОРАБЛЕЙ
# -----------------------------
func _check_all_placed():
	if ships_data.is_empty():
		return
	var all_placed = true
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
func _on_random_pressed():
	if ships_data.is_empty():
		return
	for data in ships_data:
		if not data.placed:
			while true:
				var horizontal = (randi()%2==0)
				var x = randi()%GRID_SIZE
				var y = randi()%GRID_SIZE
				if _set_ship(player_board, x, y, data.size, horizontal, data.hbox):
					break


# -----------------------------
# Клавиши для поворота
# -----------------------------
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_R:
			placing_horizontal = !placing_horizontal
			if highlight_cells.size()>0:
				_on_cell_hover(highlight_cells[0], true)


# -----------------------------
# Отмена последнего корабля
# -----------------------------
func _on_back_pressed():
	if placed_ship_cells.is_empty():
		return

	var last_ship = placed_ship_cells.pop_back()
	for cell in last_ship:
		var x = cell.x
		var y = cell.y
		if y < player_board.size() and x < player_board[y].size():
			player_board[y][x] = 0
			var b = player_grid.get_node("%d_%d" % [x, y])
			if b:
				b.modulate = Color(1,1,1)

	# вернуть корабль в список
	for data in ships_data:
		if data.size==last_ship.size() and data.placed:
			data.placed=false
			for c in data.hbox.get_children():
				if c: c.color = Color(0.4,0.4,0.9)
			break

	ready_button.visible = false
	message_label.text = ""


# -----------------------------
# Готово
# -----------------------------
func _on_ready_pressed():
	title_label.text = "Морской бой"
	ready_button.visible = false
	random_button.visible = false
	enemy_grid.visible = true
	ships_container.visible = false
	back_button.visible = false
	message_label.text = ""
	print("Переход к бою")
