extends Area2D

class_name PlayerCart

var player_id: int
var is_local: bool
var game_node: Node
var speed: float = 3.0
var screen_height: float = 600.0
var moving_up: bool = true
var fire_cooldown: float = 0.0
var is_active: bool = true
var player_instance: Node2D  # Ссылка на игрока

func init(id: int, local: bool, game: Node, container_height: float):
	player_id = id
	is_local = local
	game_node = game
	screen_height = container_height
	
	# 1. Загружаем текстуру вагонетки
	var cart_sprite = get_node_or_null("CartBody")
	if not cart_sprite:
		cart_sprite = Sprite2D.new()
		cart_sprite.name = "CartBody"
		add_child(cart_sprite)
	
	var cart_texture = load("res://Assets/Minigames/Shooting/cart_red.png" if player_id == 1 else "res://Assets/Minigames/Shooting/cart_blue.png")
	if cart_texture:
		cart_sprite.texture = cart_texture
	
	# 2. Загружаем сцену игрока
	var player_scene = preload("res://Player/Player.tscn")
	if player_scene:
		player_instance = player_scene.instantiate()
		player_instance.name = "PlayerCharacter"
		player_instance.position = Vector2(0, -25)  # Над вагонеткой
		
		# Отключаем управление WASD у игрока
		disable_player_controls(player_instance)
		
		# Поворачиваем игрока к центру экрана
		if player_id == 1:
			player_instance.rotation_degrees = 0  # Смотрит вправо
		else:
			player_instance.rotation_degrees = 180  # Смотрит влево
		
		add_child(player_instance)
	
	# 3. Коллизия
	var collision = get_node_or_null("CollisionShape2D")
	if not collision:
		collision = CollisionShape2D.new()
		collision.shape = CircleShape2D.new()
		collision.shape.radius = 25
		add_child(collision)
	
	if is_local:
		set_process(true)
		set_physics_process(true)

func disable_player_controls(player_node):
	# Отключаем скрипт управления
	var player_script = player_node.get_script()
	if player_script:
		# Можно отключить обработку ввода
		player_node.set_process(false)
		player_node.set_physics_process(false)
	
	# Останавливаем анимации если есть
	var anim = player_node.get_node_or_null("AnimatedSprite2D")
	if anim:
		anim.play("IDLE_FRONT2")  # Или любая idle анимация

func _process(delta):
	if not is_local or not is_active:
		return
	
	if fire_cooldown > 0:
		fire_cooldown -= delta
	
	if Input.is_action_just_pressed("ui_accept") and fire_cooldown <= 0:
		fire_dart()
		fire_cooldown = 1.0

func _physics_process(delta):
	if not is_active:
		return
	
	# Автоматическое движение вверх-вниз
	if moving_up:
		position.y -= speed * delta
		if position.y <= 50:
			position.y = 50
			moving_up = false
	else:
		position.y += speed * delta
		if position.y >= screen_height - 50:
			position.y = screen_height - 50
			moving_up = true

func fire_dart():
	if game_node and game_node.has_method("create_dart"):
		game_node.create_dart(player_id, global_position)

func set_active(active: bool):
	is_active = active
	if not active:
		set_process(false)
		set_physics_process(false)
