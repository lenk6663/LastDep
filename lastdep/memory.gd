extends GridContainer

# Переменные
var opened_buttons = []        # 1–2 открытые кнопки
var score = 0                  # счёт
var textures = []              # массив картинок

# Ссылка на Label "Score" внутри сцены Memory
@onready var score_label = $"../Score"  # замените путь, если Label на другом уровне

func _ready():
	columns = 7

	var cell_width  = size.y / 6 - 5
	var cell_height = cell_width

	# Загружаем картинки
	for i in range(1, 22):
		textures.append(load("res://Assets/MemoryGame/%d.png" % i))

	var values = []
	for i in range(1, 22):
		values.append(i)
		values.append(i)
	values.shuffle()

	# Создаём кнопки
	for i in range(42):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(cell_width, cell_height)
		btn.name = "btn_%d" % i
		btn.text = ""
		btn.set_meta("value", values[i])
		btn.set_meta("flipped", false)

		# Подключаем сигнал нажатия
		btn.pressed.connect(_on_button_pressed.bind(btn))

		add_child(btn)


func _on_button_pressed(btn):
	if btn.get_meta("flipped") or opened_buttons.size() >= 2:
		return

	# Показываем картинку или цифру
	var idx = btn.get_meta("value") - 1
	var tex = textures[idx]
	if tex != null:
		btn.icon = tex
		btn.text = ""
	else:
		btn.icon = null
		btn.text = str(btn.get_meta("value"))

	btn.set_meta("flipped", true)
	opened_buttons.append(btn)

	if opened_buttons.size() < 2:
		return

	var a = opened_buttons[0]
	var b = opened_buttons[1]

	if a.get_meta("value") == b.get_meta("value"):
		# Совпали
		score += 1
		if score_label != null:
			score_label.text = "Счёт: %d" % score
		opened_buttons.clear()
	else:
		# Не совпали — закрываем через паузу
		await get_tree().create_timer(0.6).timeout
		a.icon = null
		a.text = ""
		b.icon = null
		b.text = ""
		a.set_meta("flipped", false)
		b.set_meta("flipped", false)
		opened_buttons.clear()
