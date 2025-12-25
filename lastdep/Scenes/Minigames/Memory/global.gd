# global.gd
extends Node

var card_textures = []
var card_back_texture: Texture2D

func _ready():
	load_card_textures()

func load_card_textures():
	print("Global: Загрузка текстур карточек...")
	
	# Загружаем атлас текстур
	var atlas_texture = preload("res://Assets/Minigames/MemoryGame/pixel_card_atlas.png")
	
	if not atlas_texture:
		print("ОШИБКА: Не удалось загрузить pixel_card_atlas.png")
		return
	
	print("Global: Атлас загружен, размер: ", atlas_texture.get_size())
	
	# Размеры карточек в атласе
	const CARD_WIDTH = 16
	const CARD_HEIGHT = 16
	const ATLAS_COLUMNS = 8
	
	# Создаем AtlasTexture для каждой карточки
	for i in range(22):  # 21 уникальных карт + 1 рубашка
		var row = i / ATLAS_COLUMNS
		var col = i % ATLAS_COLUMNS
		
		var atlas_tex = AtlasTexture.new()
		atlas_tex.atlas = atlas_texture
		atlas_tex.region = Rect2(
			col * CARD_WIDTH,
			row * CARD_HEIGHT,
			CARD_WIDTH,
			CARD_HEIGHT
		)
		
		card_textures.append(atlas_tex)
	
	# Сохраняем рубашку
	if card_textures.size() > 21:
		card_back_texture = card_textures[21]
	
	print("Global: Загружено ", card_textures.size(), " текстур")
