# PlayerCart.gd
extends Area2D

class_name PlayerCart

var player_id: int
var is_local: bool
var game_node: Node
var speed: float = 100.0
var moving_up: bool = randf() > 0.5

# Будем получать параметры из игры
var move_range_y = Vector2(100, 500)  # Диапазон движения по Y
var player_scene_instance = null  # Ссылка на модельку игрока

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
	else:
		# Запасной вариант
		var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
		image.fill(Color.RED if player_id == 1 else Color.BLUE)
		sprite.texture = ImageTexture.create_from_image(image)
	
	add_child(sprite)
	
	# Коллизия
	var collision = CollisionShape2D.new()
	collision.shape = RectangleShape2D.new()
	collision.shape.size = Vector2(40, 60)
	add_child(collision)
	
	set_physics_process(true)
	
	# Добавляем игрока в вагонетку
	call_deferred("spawn_player_in_cart")

func spawn_player_in_cart():
	# Загружаем сцену игрока
	var player_scene = load("res://Player/Player.tscn")
	if player_scene:
		player_scene_instance = player_scene.instantiate()
		
		print("Добавляю игрока в вагонетку ID:", player_id)
		
		# Отключаем управление и коллизию у игрока
		player_scene_instance.set_process(false)
		player_scene_instance.set_physics_process(false)
		
		# Отключаем коллизию если это CharacterBody2D
		if player_scene_instance is CharacterBody2D:
			player_scene_instance.set_collision_layer_value(1, false)
			player_scene_instance.set_collision_mask_value(1, false)
		
		# Настраиваем позицию игрока (сидит в вагонетке)
		player_scene_instance.position = Vector2(0, 0)  # Немного выше центра вагонетки
		player_scene_instance.scale = Vector2(1.2, 1.2)
		
		# Устанавливаем мета-данные чтобы player.gd знал, что он в вагонетке
		player_scene_instance.set_meta("in_cart", true)
		player_scene_instance.set_meta("cart_player_id", player_id)
		
		add_child(player_scene_instance)
		
		# Настраиваем анимацию один раз
		await get_tree().process_frame
		setup_player_animation_once()
	else:
		print("Ошибка: не удалось загрузить сцену игрока")

func setup_player_animation_once():
	if not player_scene_instance:
		return
	
	# Устанавливаем анимацию один раз при создании
	if player_scene_instance.has_method("set_cart_animation"):
		# Левый игрок (ID 1) смотрит вправо, правый игрок (ID 2) смотрит влево
		var flip = (player_id == 1)
		player_scene_instance.set_cart_animation(flip)
	else:
		var anim = player_scene_instance.find_child("AnimatedSprite2D")
		if anim:
			anim.animation = "IDLE_SIDE2"
			anim.flip_h = (player_id == 1)  # Игрок 2 смотрит влево
			anim.play()

func _physics_process(delta):
	# Только движение вагонетки, анимацию не трогаем
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

func set_active(active: bool):
	set_physics_process(active)
