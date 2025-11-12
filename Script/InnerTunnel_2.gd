extends Node2D

# Настройки мира
@export var segment_count: int = 900
@export var segment_length: float = 10.0
@export var tunnel_radius: float = 400.0
@export var movement_speed: float = 500.0
@export var rotation_sensitivity_mobile: float = -1.0
@export var rotation_sensitivity_desktop: float = 0.1

# Настройки препятствий
@export var obstacle_spawn_interval: float = 1.7
@export var min_obstacle_distance: float = 600.0
@export var max_obstacle_distance: float = 2000.0
@export var max_obstacles: int = 20
@export var obstacle_length: float = 150.0

# Настройки зоны смерти
@export var collision_distance_threshold: float = 50.0  # Дистанция для столкновения

var segments: Array = []
var obstacles: Array = []
var player_distance: float = 0.0  # Абсолютное расстояние игрока
var rotation_angle: float = 0.0  # Начальный поворот 0°
var center: Vector2
var is_game_running: bool = true
var current_tilt: float = 0.0
var obstacle_timer: float = 0.0
var game_time: float = 0.0
var restart_button_rect: Rect2

# Добавляем переменные для расчета видимой области
var screen_size: Vector2
var max_visible_distance: float

# Настройки зеленой полоски (зоны смерти)
@export var death_strip_width: float = 20.0  # Ширина зеленой полоски

var time_out = 0.0

func _ready():
	$"/root/SceneVR/HBoxContainer/SubViewportContainer/SubViewport/MarginContainer".visible = false
	MenuMusic.stop()
	# Устанавливаем альбомный режим для мобильных устройств
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	
	# Устанавливаем размер окна для горизонтального режима
	get_window().size = Vector2i(1280, 720)
	
	# Ждем готовности viewport
	await get_tree().process_frame
	screen_size = get_viewport().get_visible_rect().size
	center = screen_size / 2
	position = center
	
	# Рассчитываем максимальное расстояние видимости на основе размера экрана
	max_visible_distance = max(screen_size.x, screen_size.y) * 2.0  # Увеличили видимую область
	
	initialize_segments()
	$AudioStreamPlayer.play()

func initialize_segments():
	segments.clear()
	for i in range(segment_count):
		var distance = float(i) * segment_length
		var alpha = 1.0 - (float(i) / segment_count) * 0.9
		
		segments.append({
			"distance": distance,  # Абсолютное расстояние сегмента
			"radius": tunnel_radius,  # Постоянный радиус
			"alpha": alpha
		})

func _process(delta):
	if not is_game_running:
		return
		
	game_time += delta
	var minute = int(game_time) / 60
	var second = int(game_time) % 60
	if minute == 3 and second == 0:
		game_over()
	handle_input(delta)
	update_tunnel(delta)
	update_obstacles(delta)
	handle_obstacle_spawning(delta)
	queue_redraw()

func _input(event):
	# Обработка рестарта по нажатию R или пробела
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			restart_game()
		if event.keycode == KEY_SPACE and not is_game_running:
			restart_game()
			

func handle_input(delta):
	# Движение вперед - увеличиваем абсолютное расстояние
	player_distance += movement_speed * delta
	
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		# Используем гироскоп для мобильных устройств
		var accelerometer = Input.get_accelerometer() 
		if accelerometer:
			current_tilt = accelerometer.x * rotation_sensitivity_mobile 
			rotation_angle += current_tilt * delta * 0.7
	else:
		var keyboard_input = Input.get_axis("ui_right", "ui_left")
		current_tilt = keyboard_input
		rotation_angle += keyboard_input * delta * 30.0 * rotation_sensitivity_desktop

func update_tunnel(_delta):
	# Обновляем позиции сегментов для создания бесконечного туннеля
	for i in range(segments.size()):
		var segment = segments[i]
		
		# Если сегмент слишком далеко позади, перемещаем его вперед
		if segment.distance < player_distance - segment_length:
			segment.distance += segment_count * segment_length

func handle_obstacle_spawning(delta):
	obstacle_timer -= delta
	
	# Спавним новое препятствие, если пришло время и не превышен лимит
	if (obstacle_timer <= 0 and obstacles.size() < max_obstacles and time_out >= 700.0):
		spawn_obstacle()
		# Случайный интервал для разнообразия
		obstacle_timer = obstacle_spawn_interval * randf_range(0.8, 1.2)

func spawn_obstacle():
	# Случайная сторона туннеля (0-5)
	var side = randi() % 6
	
	# Фиксированное расстояние спавна от текущей позиции игрока
	var spawn_distance = player_distance + randf_range(min_obstacle_distance, max_obstacle_distance)
	
	# Создаем препятствие
	var obstacle = {
		"start_distance": spawn_distance,
		"end_distance": spawn_distance + obstacle_length,
		"side": side
	}
	
	obstacles.append(obstacle)

func update_obstacles(delta):
	# Обновляем позиции препятствий и проверяем столкновения
	for i in range(obstacles.size() - 1, -1, -1):
		var obstacle = obstacles[i]
		
		# Двигаем препятствия навстречу игроку
		# Это исправляет проблему с движением препятствий назад
		obstacle.start_distance -= movement_speed * delta
		obstacle.end_distance -= movement_speed * delta
		
		# Удаляем препятствия, которые остались позади
		if obstacle.end_distance < player_distance - obstacle_length:
			obstacles.remove_at(i)
			continue
		
		# Проверяем столкновение с игроком
		if check_collision(obstacle):
			game_over()
			break

func check_collision(obstacle) -> bool:
	# Проверяем, находится ли препятствие достаточно близко к игроку
	var distance_to_obstacle = obstacle.start_distance - player_distance
	if distance_to_obstacle > collision_distance_threshold:
		return false
	
	# Определяем сторону, которая в данный момент находится внизу экрана (опасная сторона)
	var bottom_side = get_current_bottom_side()
	
	# Проверяем, находится ли препятствие на опасной стороне
	if obstacle.side == bottom_side:
		return true
	
	return false

# Функция для определения текущей стороны, которая находится внизу экрана
func get_current_bottom_side() -> int:
	# Угол, соответствующий низу экрана в системе координат туннеля
	var bottom_angle = -PI/2
	
	# Вычисляем угол с учетом вращения туннеля
	var adjusted_angle = fmod(bottom_angle - rotation_angle, TAU)
	if adjusted_angle < 0:
		adjusted_angle += TAU
	
	# Определяем сторону на основе скорректированного угла
	return int(adjusted_angle / (TAU / 6)) % 6

func _draw():
	time_out += 1.0
	# Рисуем фон (серый)
	draw_rect(get_viewport().get_visible_rect(), Color(0.3, 0.3, 0.3))
	
	# Рисуем туннель - белые границы сторон и чередующиеся синие/желтые поперечные линии
	draw_tunnel()
	
	# Рисуем зеленую полоску (зону смерти) в начале туннеля
	draw_death_strip()
	
	
	# Рисуем препятствия
	for obstacle in obstacles:
		draw_obstacle(obstacle)


func draw_tunnel():
	# Рисуем белые продольные линии (границы сторон) - сплошные
	for side in range(6):
		var points = PackedVector2Array()
		
		# Собираем точки для каждой стороны туннеля
		for segment in segments:
			var depth = segment.distance - player_distance
			
			# Пропускаем сегменты, которые слишком далеко
			if abs(depth) > max_visible_distance:
				continue
				
			# Перспектива с учетом расстояния - улучшенная формула
			var perspective = 1.0 / (1.0 + max(0, depth) * 0.003)  # Используем только положительную глубину
			var radius = segment.radius * perspective
			
			# Используем стандартную математическую систему координат (0° справа, увеличение против часовой стрелки)
			var angle = side * TAU / 6 + rotation_angle
			var point = Vector2(
				cos(angle) * radius,
				-sin(angle) * radius  # Инвертируем Y для Godot (ось Y вниз)
			)
			points.append(point)
		
		# Рисуем сплошную линию для каждой стороны
		if points.size() > 1:
			draw_polyline(points, Color.WHITE, 2.0)
	
	# Рисуем поперечные линии с чередованием синего и желтого цветов
	for i in range(0, segments.size(), 3):
		var segment = segments[i]
		var depth = segment.distance - player_distance
		
		# Пропускаем сегменты, которые слишком далеко
		if abs(depth) > max_visible_distance:
			continue
			
		# Перспектива с учетом расстояния - улучшенная формула
		var perspective = 1.0 / (1.0 + max(0, depth) * 0.003)  # Используем только положительную глубину
		var radius = segment.radius * perspective
		
		# Чередуем синий и желтый цвета
		var line_color = Color(0.316, 0.744, 0.441, 1.0) if (i / 3) % 2 == 0 else Color(0.712, 0.484, 0.613, 1.0)
		
		var points = PackedVector2Array()
		for side in range(7):  # 7 точек чтобы замкнуть шестиугольник
			var angle = (side % 6) * TAU / 6 + rotation_angle
			var point = Vector2(
				cos(angle) * radius,
				-sin(angle) * radius  # Инвертируем Y для Godot
			)
			points.append(point)
		
		if points.size() > 1:
			draw_polyline(points, line_color, 1.5)

func draw_death_strip():
	# Определяем сторону, которая в данный момент находится внизу экрана
	var bottom_side = get_current_bottom_side()
	
	# Зеленая полоска на стороне, которая в данный момент внизу
	var depth_start = 0.0  # Начинаем прямо у игрока
	var depth_end = death_strip_width  # Заканчиваем на небольшом расстоянии
	
	# Перспектива с учетом расстояния
	var perspective_start = 1.0 / (1.0 + depth_start * 0.003)
	var perspective_end = 1.0 / (1.0 + depth_end * 0.003)
	var radius_start = tunnel_radius * perspective_start
	var radius_end = tunnel_radius * perspective_end
	
	# Рисуем зеленую полоску только на стороне, которая в данный момент внизу
	# Используем углы, соответствующие текущей позиции этой стороны в туннеле
	var angle1 = bottom_side * TAU / 6 + rotation_angle
	var angle2 = (bottom_side + 1) * TAU / 6 + rotation_angle
	
	# Точки для внешнего края полоски
	var point1_start = Vector2(
		cos(angle1) * radius_start,
		-sin(angle1) * radius_start
	)
	var point2_start = Vector2(
		cos(angle2) * radius_start,
		-sin(angle2) * radius_start
	)
	
	# Точки для внешнего края полоски на конце
	var point1_end = Vector2(
		cos(angle1) * radius_end,
		-sin(angle1) * radius_end
	)
	var point2_end = Vector2(
		cos(angle2) * radius_end,
		-sin(angle2) * radius_end
	)
	
	# Создаем полигон для полоски (трапеция)
	var strip_points = PackedVector2Array()
	strip_points.append(point1_start)
	strip_points.append(point2_start)
	strip_points.append(point2_end)
	strip_points.append(point1_end)
	
	# Рисуем зеленую полоску
	draw_colored_polygon(strip_points, Color(0.0, 1.0, 0.0, 0.5))
	
	# Контур зеленой полоски
	draw_polyline(strip_points, Color(0.0, 0.8, 0.0), 3.0)

func draw_obstacle(obstacle: Dictionary):
	# Вычисляем расстояние для начала и конца препятствия
	var depth_start = obstacle.start_distance - player_distance
	var depth_end = obstacle.end_distance - player_distance
	
	# Пропускаем препятствия, которые слишком далеко
	if abs(depth_start) > max_visible_distance and abs(depth_end) > max_visible_distance:
		return
	
	# Перспектива с учетом расстояния - улучшенная формула
	var perspective_start = 1.0 / (1.0 + max(0, depth_start) * 0.003)  # Используем только положительную глубину
	var perspective_end = 1.0 / (1.0 + max(0, depth_end) * 0.003)      # Используем только положительную глубину
	
	# Вычисляем радиусы для начала и конца препятствия с учетом перспективы
	var radius_start = tunnel_radius * perspective_start
	var radius_end = tunnel_radius * perspective_end
	
	# Вычисляем углы для сторон препятствия
	var angle1 = obstacle.side * TAU / 6 + rotation_angle
	var angle2 = (obstacle.side + 1) * TAU / 6 + rotation_angle
	
	# Создаем точки для прямоугольника
	var points = PackedVector2Array()
	
	# Точка A: начало препятствия, угол1
	points.append(Vector2(
		cos(angle1) * radius_start,
		-sin(angle1) * radius_start  # Инвертируем Y для Godot
	))
	
	# Точка B: начало препятствия, угол2
	points.append(Vector2(
		cos(angle2) * radius_start,
		-sin(angle2) * radius_start  # Инвертируем Y для Godot
	))
	
	# Точка C: конец препятствия, угол2
	points.append(Vector2(
		cos(angle2) * radius_end,
		-sin(angle2) * radius_end  # Инвертируем Y для Godot
	))
	
	# Точка D: конец препятствия, угол1
	points.append(Vector2(
		cos(angle1) * radius_end,
		-sin(angle1) * radius_end  # Инвертируем Y для Godot
	))
	
	# Рисуем красное препятствие
	var obstacle_color = Color(1.0, 0.0, 0.0, 0.8)
	draw_colored_polygon(points, obstacle_color)
	
	# Контур препятствия
	draw_polyline(points, Color(0.5, 0.0, 0.0), 2.0)

func game_over():
	$"/root/SceneVR/HBoxContainer/SubViewportContainer/SubViewport/MarginContainer".visible = true
	is_game_running = false
	movement_speed = 0.0
	$AudioStreamPlayer.stop()

func restart_game():
	# Сброс всех переменных игры
	player_distance = 0.0
	rotation_angle = 0.0  # Сбрасываем на начальный поворот 0°
	obstacles.clear()
	is_game_running = true
	current_tilt = 0.0
	obstacle_timer = 0.0
	game_time = 0.0
	movement_speed = 400.0
	$AudioStreamPlayer.play()
	
	# Сброс сегментов туннеля
	for i in range(segments.size()):
		segments[i].distance = float(i) * segment_length
