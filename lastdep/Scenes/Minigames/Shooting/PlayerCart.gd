# PlayerCart.gd
extends Area2D

class_name PlayerCart

var player_id: int
var is_local: bool
var game_node: Node
var speed: float = 100.0
var moving_up: bool = randf() > 0.5
var move_range_y = Vector2(100, 500)
var player_scene_instance = null

func init(id: int, local: bool, game: Node, move_range: Vector2):
	player_id = id
	is_local = local
	game_node = game
	move_range_y = move_range
	
	# Настраиваем спрайт вагонетки
	var sprite = Sprite2D.new()
	var texture_path = "res://Assets/Minigames/Shooting/cart_red.png" if player_id == 1 else "res://Assets/Minigames/Shooting/cart_blue.png"
	var texture = load(texture_path)
	
	if texture:
		sprite.texture = texture
		sprite.scale = Vector2(1.5, 1.5)
	else:
		# Запасной вариант
		var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color.RED if player_id == 1 else Color.BLUE)
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.scale = Vector2(1.0, 1.0)
	
	add_child(sprite)
	
	# Коллизия
	var collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = Vector2(40, 60)
	add_child(collision)
	
	# Добавляем игрока в вагонетку (сидит внутри)
	call_deferred("spawn_player_in_cart")
	
	# Включаем физику
	set_physics_process(true)

func spawn_player_in_cart():
	# Загружаем сцену игрока
	var player_scene = load("res://Player/Player.tscn")
	if player_scene:
		player_scene_instance = player_scene.instantiate()
		
		print("Добавляю игрока в вагонетку ID:", player_id, " Авторитет:", player_scene_instance.is_multiplayer_authority())
		
		# Устанавливаем метаданные ДО добавления
		player_scene_instance.set_meta("in_cart", true)
		player_scene_instance.set_meta("cart_player_id", player_id)
		
		# Добавляем как дочерний узел
		add_child(player_scene_instance)
		
		# Ждем, пока узел полностью инициализируется
		await get_tree().process_frame
		
		# Настраиваем позицию и размер
		player_scene_instance.position = Vector2(0, 0)
		player_scene_instance.scale = Vector2(1.5, 1.5)
		
		# Вызываем set_cart_animation с задержкой
		await get_tree().create_timer(0.1).timeout
		
		if player_scene_instance.has_method("set_cart_animation"):
			var should_flip = (player_id == 1)  # Игрок 2 смотрит влево
			print("Вызываю set_cart_animation для игрока", player_id, " flip_h=", should_flip)
			player_scene_instance.set_cart_animation(should_flip)
		else:
			print("Ошибка: игрок не имеет метода set_cart_animation")
	else:
		print("Ошибка: не удалось загрузить сцену игрока")

func setup_player_animation():
	if not player_scene_instance:
		return
	
	# Игрок 1 смотрит ВПРАВО (flip_h = false)
	# Игрок 2 смотрит ВЛЕВО (flip_h = true)
	var should_flip = (player_id == 1)
	
	print("Устанавливаю анимацию для игрока", player_id, " в вагонетке, flip_h=", should_flip)
	
	# Пробуем вызвать метод set_cart_animation
	if player_scene_instance.has_method("set_cart_animation"):
		player_scene_instance.set_cart_animation(should_flip)
	else:
		# Альтернативный способ
		var anim = player_scene_instance.find_child("AnimatedSprite2D")
		if anim:
			print("Нашел AnimatedSprite2D, устанавливаю анимацию")
			anim.play("IDLE_SIDE2")
			anim.flip_h = should_flip
		else:
			print("Ошибка: не найден AnimatedSprite2D у игрока")


func _physics_process(delta):
	# Движение вагонетки вверх-вниз
	if moving_up:
		position.y -= speed * delta
		if position.y <= move_range_y.x:
			position.y = move_range_y.x
			moving_up = false
	else:
		position.y += speed * delta
		if position.y >= move_range_y.y:
			position.y = move_range_y.y
			moving_up = true

func get_position_for_dart() -> Vector2:
	# Возвращает позицию для вылета дротика из вагонетки
	var dart_offset = Vector2(30, 0) if player_id == 1 else Vector2(-30, 0)
	return position + dart_offset

func set_active(active: bool):
	set_physics_process(active)
