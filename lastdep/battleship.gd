extends Node2D

const GRID_SIZE = 10
var ship_sizes := [4,3,3,2,2,2,1,1,1,1]

var player_board := []
var enemy_board := []

@onready var player_grid: GridContainer = $PlayerGrid
@onready var enemy_grid: GridContainer = $EnemyGrid

# Переменные для ручной расстановки
var current_ship_index := 0
var placing_horizontal := true  # true = горизонтально, false = вертикально

func _ready():
	_init_boards()
	_place_ships_randomly(enemy_board)
	_create_grid(player_grid, player_board, true)
	_create_grid(enemy_grid, enemy_board, false)
	print("Выставляем корабль длиной: ", ship_sizes[current_ship_index])

func _init_boards():
	player_board.clear()
	enemy_board.clear()
	for y in range(GRID_SIZE):
		player_board.append([])
		enemy_board.append([])
		for x in range(GRID_SIZE):
			player_board[y].append(0)
			enemy_board[y].append(0)

# Рандомная расстановка противника
func _place_ships_randomly(board: Array):
	for size in ship_sizes:
		_place_ship(board, size)

func _can_place_ship(board: Array, x: int, y: int, length: int, horizontal: bool) -> bool:
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

func _place_ship(board: Array, length: int):
	var placed = false
	while not placed:
		var horizontal = randi() % 2 == 0
		var x = randi() % GRID_SIZE
		var y = randi() % GRID_SIZE
		if _can_place_ship(board, x, y, length, horizontal):
			for i in range(length):
				var nx = x + (i if horizontal else 0)
				var ny = y + (0 if horizontal else i)
				board[ny][nx] = 1
			placed = true

func _create_grid(grid: GridContainer, board: Array, is_player: bool):
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var button = Button.new()
			button.name = str(x) + "_" + str(y)
			button.custom_minimum_size = Vector2(40, 40)
			if is_player and board[y][x] == 1:
				button.modulate = Color(0,0.5,1)
			button.pressed.connect(func():
				_on_cell_pressed(button, board, is_player))
			grid.add_child(button)

func _on_cell_pressed(button: Button, board: Array, is_player: bool):
	var coords = button.name.split("_")
	var x = int(coords[0])
	var y = int(coords[1])

	if is_player:
		if current_ship_index >= ship_sizes.size():
			print("Все корабли расставлены")
			return
		var length = ship_sizes[current_ship_index]
		if _can_place_ship(board, x, y, length, placing_horizontal):
			for i in range(length):
				var nx = x + (i if placing_horizontal else 0)
				var ny = y + (0 if placing_horizontal else i)
				board[ny][nx] = 1
				# находим кнопку и красим в синий
				var b = player_grid.get_node(str(nx) + "_" + str(ny))
				if b:
					b.modulate = Color(0,0.5,1)
			current_ship_index += 1
			if current_ship_index < ship_sizes.size():
				print("Выставляем корабль длиной: ", ship_sizes[current_ship_index])
			else:
				print("Все корабли расставлены")
		else:
			print("Невозможно поставить здесь корабль")
	else:
		# выстрел по противнику
		if board[y][x] == 1:
			print("Попадание!")
			button.text = "X"
			button.modulate = Color(1,0,0)
		else:
			print("Промах")
			button.text = "•"
			button.modulate = Color(0.7,0.7,0.7)
		button.disabled = true

# Можно переключать горизонтально/вертикально (через кнопку или клавишу)
func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:  # например, клавиша R
			placing_horizontal = not placing_horizontal
			print("Горизонтально: ", placing_horizontal)
