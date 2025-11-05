extends CharacterBody2D

const SPEED = 100.0
@onready var anim = $AnimatedSprite2D

var last_direction := Vector2.DOWN  # Направление по умолчанию (лицом к игроку)

func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	# Устанавливаем velocity для обеих осей
	if direction:
		velocity.x = direction.x * SPEED
		velocity.y = direction.y * SPEED
		last_direction = direction  # Запоминаем последнее направление
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)
	
	# Управление анимациями и поворотом спрайта
	if direction != Vector2.ZERO:
		# Горизонтальное движение
		if abs(direction.x) > abs(direction.y):
			anim.play("WALK_SIDE")
			# Поворот спрайта для лево/право
			if direction.x < 0:
				$AnimatedSprite2D.flip_h = false
			elif direction.x > 0:
				$AnimatedSprite2D.flip_h = true
		
		# Движение вверх (спиной к игроку)
		elif direction.y < 0:
			anim.play("WALK_BACK")
			$AnimatedSprite2D.flip_h = false  
		
		# Движение вниз (лицом к игроку)
		elif direction.y > 0:
			anim.play("WALK_FRONT")
			$AnimatedSprite2D.flip_h = false 
	
	else:
		# IDLE анимация в зависимости от последнего направления
		if abs(last_direction.x) > abs(last_direction.y):
			# Последнее движение было горизонтальным
			anim.play("IDLE_SIDE2")
			$AnimatedSprite2D.flip_h = last_direction.x < 0
		elif last_direction.y < 0:
			# Последнее движение было вверх
			anim.play("IDLE_BACK2")
			$AnimatedSprite2D.flip_h = false
		elif last_direction.y > 0:
			# Последнее движение было вниз
			anim.play("IDLE_FRONT2")
			$AnimatedSprite2D.flip_h = false
	
	move_and_slide()
