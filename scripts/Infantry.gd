extends CharacterBody3D

# ================= 信号与基础属性 =================
signal health_changed(current_health: int, max_health: int)

@export_group("基础属性")
@export var base_max_health: int = 100
var max_health: int
var current_health: int

@export var base_speed: float = 3.0
@export var speed: float = 3.0
@export var jump_speed: float = 4.0
@export var gravity: float = 9.8

# 节点引用
@onready var bullet_scene = preload("res://scenes/bullet.tscn")
@onready var muzzle = $GimbalYaw/GimbalPitch/Muzzle
var is_large_bullet: bool = false

@onready var gimbal_yaw = $GimbalYaw
@onready var gimbal_pitch = $GimbalYaw/GimbalPitch
@onready var camera = $GimbalYaw/GimbalPitch/Camera3D

@export_group("控制参数")
@export var mouse_sensitivity: float = 0.002
@export var min_pitch: float = -80.0
@export var max_pitch: float = 80.0
@export var small_bullet_speed: float = 10.0
@export var large_bullet_speed: float = 13.0

@export_group("底盘物理")
@export var acceleration: float = 15.0
@export var deceleration: float = 10.0
@export var base_max_power_speed: float = 8.0
var max_power_speed: float = 8.0
@export var collision_loss_rate: float = 0.6
@export var bounce_factor: float = 0.2

@export_group("热量系统")
@export var max_heat: float = 100.0
var current_heat: float = 0.0
@export var base_cooling_rate: float = 15.0 # 每秒基础散热
var is_overheated: bool = false 
@export var overheat_release_ratio: float = 0.7 # 降到70%解除过热
@export var heat_add_small: float = 10.0
@export var heat_add_large: float = 30.0

@export_group("等级系统")
var level: int = 1
var current_xp: int = 0
var max_xp: int = 100
var level_bonus: float = 1.0 # 属性倍率

# 状态与Buff
var current_shoot_cooldown: float = 0.0
@export var base_shoot_cooldown: float = 0.3
var atk_buff_time: float = 0.0
var atk_magnitude: float = 0.0
var def_buff_time: float = 0.0
var def_magnitude: float = 0.0
var cd_buff_time: float = 0.0
var cd_magnitude: float = 0.0

@export var spawn_position: Vector3 = Vector3(12, 2.5, -1)
var yaw_angle: float = 0.0
var pitch_angle: float = 0.0

# ================= 经济系统 =================
var economy: float = 0.0 # 当前经济
@export var economy_per_second: float = 5.0 # 每秒自动获得的经济

# 初始弹药量
var small_ammo: int = 100 
var large_ammo: int = 20

# ================= 初始化 =================
func _ready() -> void:
	update_level_stats()
	current_health = max_health
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# 强制视角正定
	gimbal_yaw.rotation = Vector3.ZERO
	gimbal_pitch.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	health_changed.emit.call_deferred(current_health, max_health)

# 更新属性函数 (每级全属性+5%)
func update_level_stats() -> void:
	level_bonus = 1.0 + (level - 1) * 0.05
	max_health = int(base_max_health * level_bonus)
	speed = base_speed * level_bonus
	max_power_speed = base_max_power_speed * level_bonus
	
# ================= 帧循环 =================
func _process(delta: float) -> void:
	if current_shoot_cooldown > 0: current_shoot_cooldown -= delta
	if atk_buff_time > 0: atk_buff_time -= delta
	if def_buff_time > 0: def_buff_time -= delta
	if cd_buff_time > 0: cd_buff_time -= delta

	# 热量冷却计算 (受冷却Buff和等级加成影响)
	if current_heat > 0:
		var actual_cooling = base_cooling_rate * (1.0 + cd_magnitude) * level_bonus
		current_heat -= actual_cooling * delta
		current_heat = max(current_heat, 0.0)
		
		if is_overheated and current_heat <= (max_heat * overheat_release_ratio):
			is_overheated = false

# ================= 输入与视角 =================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		yaw_angle -= event.relative.x * mouse_sensitivity
		pitch_angle -= event.relative.y * mouse_sensitivity
		pitch_angle = clamp(pitch_angle, deg_to_rad(min_pitch), deg_to_rad(max_pitch))
		gimbal_yaw.rotation.y = yaw_angle
		gimbal_pitch.rotation.x = pitch_angle

	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if event.keycode == KEY_K: take_damage(10)
		if event.keycode == KEY_R: reset_vehicle()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT: shoot()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			is_large_bullet = !is_large_bullet

# ================= 物理移动 =================
func _physics_process(delta: float) -> void:
	var forward_input = Input.get_axis("move_back", "move_forward")
	var right_input = Input.get_axis("move_left", "move_right")

	var cam_forward = -camera.global_transform.basis.z
	var cam_right = camera.global_transform.basis.x
	cam_forward.y = 0; cam_right.y = 0
	cam_forward = cam_forward.normalized(); cam_right = cam_right.normalized()

	var direction = ((cam_forward * forward_input) + (cam_right * right_input)).normalized()

	if direction.length() > 0.1:
		velocity.x = move_toward(velocity.x, direction.x * max_power_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, direction.z * max_power_speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0, deceleration * delta)

	var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed > max_power_speed:
		var scale_factor = max_power_speed / horizontal_speed
		velocity.x *= scale_factor; velocity.z *= scale_factor

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed

	var pre_collision_velocity = velocity
	move_and_slide()
	
	# 碰撞反弹
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var normal = collision.get_normal()
		if abs(normal.y) < 0.5:
			var impact_speed = pre_collision_velocity.dot(normal)
			if impact_speed < -2.0:
				var slide_velocity = velocity.slide(normal)
				var bounce_velocity = normal * abs(impact_speed) * bounce_factor
				velocity = slide_velocity + bounce_velocity
				
	# 每秒自动产钱
	economy += economy_per_second * delta

# ================= 射击与战斗 =================
func shoot() -> void:
	if current_shoot_cooldown > 0 or is_overheated: return
	
	# --- 弹药与热量结算（保留你原本的逻辑） ---
	if is_large_bullet:
		if large_ammo <= 0: return
		large_ammo -= 1
	else:
		if small_ammo <= 0: return
		small_ammo -= 1
		
	var actual_cd = base_shoot_cooldown * (1.0 - cd_magnitude) if cd_buff_time > 0 else base_shoot_cooldown
	current_shoot_cooldown = actual_cd
	
	current_heat += heat_add_large if is_large_bullet else heat_add_small
	if current_heat >= max_heat:
		current_heat = max_heat
		is_overheated = true
		
	# ================= 实例化子弹 =================
	var b = bullet_scene.instantiate()
	get_tree().current_scene.add_child(b)
	
	# 坐标定位到枪口
	b.global_position = muzzle.global_position
	
	# 设置大小（这会触发 bullet.gd 里的半径设置）
	b.set_bullet_size(is_large_bullet)
	
	# 【核心修改】决定速度与伤害
	var current_speed = 15.0 if is_large_bullet else 10.0
	var base_dmg = 200 if is_large_bullet else 20
	
	# 计算最终伤害（含等级和 Buff 加成）
	var final_dmg = base_dmg * level_bonus
	if atk_buff_time > 0: final_dmg *= (1.0 + atk_magnitude)
	b.damage = int(final_dmg)
	
	# 赋予初速度（沿着相机正前方）
	var shoot_dir = -camera.global_transform.basis.z.normalized()
	b.velocity = shoot_dir * current_speed

func take_damage(amount: int) -> void:
	if def_buff_time > 0: amount = int(amount * (1.0 - def_magnitude))
	current_health = clampi(current_health - amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	if current_health <= 0: print("you die")
	
# ================= 交互与Buff =================
func add_xp(amount: int) -> void:
	if level >= 10: return
	current_xp += amount
	if current_xp >= max_xp:
		current_xp -= max_xp
		level += 1
		update_level_stats() # 升级重新计算属性
		current_health = max_health # 回满血
		health_changed.emit(current_health, max_health)
		print("⭐ 升级！当前等级: ", level)

func receive_buff(type: String, duration: float, magnitude: float) -> void:
	match type:
		"attack": atk_buff_time = duration; atk_magnitude = magnitude
		"defense": def_buff_time = duration; def_magnitude = magnitude
		"cooldown": cd_buff_time = duration; cd_magnitude = magnitude

func reset_vehicle() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	current_health = max_health
	current_heat = 0.0
	is_overheated = false
	health_changed.emit(current_health, max_health)
	gimbal_yaw.rotation = Vector3.ZERO
	gimbal_pitch.rotation = Vector3.ZERO
	reset_physics_interpolation()
	
func buy_ammo(type: String, amount: int, cost_per_bullet: int) -> bool:
	var total_cost = amount * cost_per_bullet
	
	if economy < total_cost:
		print("❌ 经济不足！买 %d 发需要 %d 经济。" % [amount, total_cost])
		return false
		
	economy -= total_cost
	if type == "small":
		small_ammo += amount
		print("🛒 购买成功！小球补充 %d 发，剩余经济: %d" % [amount, int(economy)])
	else:
		large_ammo += amount
		print("🛒 购买成功！大球补充 %d 发，剩余经济: %d" % [amount, int(economy)])
		
	return true
# 按百分比恢复血量（供 Shop 区域调用）
func heal_percent(percent: float) -> void:
	var heal_amount = int(max_health * percent)
	current_health = clampi(current_health + heal_amount, 0, max_health)
	health_changed.emit(current_health, max_health)
	print("💚 恢复 ", heal_amount, " 点血量，当前血量: ", current_health)
