extends Node3D

# 当前哨站被摧毁时，通知主场景
signal sentry_destroyed

@export var max_health: int = 1500
var current_health: int

# 节点引用
@onready var target_2 = $Target2 # 获取下面的旋转靶子

var hp_bar_fill: MeshInstance3D
var hp_bar_bg: MeshInstance3D

func _ready() -> void:
	current_health = max_health
	create_3d_health_bar()
	
	# 监听下方 Target2 受到的伤害
	if target_2 and target_2.has_signal("hit_received"):
		target_2.hit_received.connect(take_damage)

# 扣血逻辑（由靶子受击触发）
func take_damage(amount: int) -> void:
	if current_health <= 0: return
	
	current_health -= amount
	update_health_bar()
	print(name, " 受到伤害: ", amount, " 剩余血量: ", current_health)
	
	if current_health <= 0:
		destroy_outpost()

# 摧毁逻辑
func destroy_outpost() -> void:
	current_health = 0
	update_health_bar()
	print("💥 ", name, " 已被摧毁！")
	
	# 1. 关闭靶子的发光并停转
	if target_2 and target_2.has_method("deactivate"):
		target_2.deactivate()
		
	# 2. 隐藏血条
	if hp_bar_bg: hp_bar_bg.queue_free()
	if hp_bar_fill: hp_bar_fill.queue_free()
	
	# 3. 发送信号给主场景 (rm.gd)
	sentry_destroyed.emit()

# ================= 3D 血条 =================
func create_3d_health_bar() -> void:
	var bar_root = Node3D.new()
	# 高度
	bar_root.position = Vector3(0, 2, 0)
	add_child(bar_root)
	
	# 1. 背景底板
	hp_bar_bg = MeshInstance3D.new()
	var quad_bg = QuadMesh.new()
	quad_bg.size = Vector2(2.0, 0.2)
	hp_bar_bg.mesh = quad_bg
	
	var mat_bg = StandardMaterial3D.new()
	mat_bg.albedo_color = Color(0.1, 0.1, 0.1)
	mat_bg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_bg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat_bg.no_depth_test = true # 穿透显示
	hp_bar_bg.material_override = mat_bg
	bar_root.add_child(hp_bar_bg)
	
	# 2. 血条填充
	hp_bar_fill = MeshInstance3D.new()
	var quad_fill = QuadMesh.new()
	quad_fill.size = Vector2(2.0, 0.2)
	hp_bar_fill.mesh = quad_fill
	
	var mat_fill = StandardMaterial3D.new()
	mat_fill.albedo_color = Color(0.0, 1.0, 0.2)
	mat_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fill.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat_fill.no_depth_test = true
	mat_fill.render_priority = 1
	hp_bar_fill.material_override = mat_fill
	bar_root.add_child(hp_bar_fill)

func update_health_bar() -> void:
	if hp_bar_fill and hp_bar_bg:
		var ratio = float(current_health) / max_health
		ratio = clamp(ratio, 0.0, 1.0)
		
		var mesh = hp_bar_fill.mesh as QuadMesh
		if mesh: mesh.size.x = 2.0 * ratio
		hp_bar_fill.position.x = -1.0 + ratio
		
		# 变色逻辑
		var mat_fill = hp_bar_fill.material_override as StandardMaterial3D
		if mat_fill:
			if ratio > 0.5: mat_fill.albedo_color = Color(0.0, 1.0, 0.2) # 绿
			elif ratio > 0.2: mat_fill.albedo_color = Color(1.0, 1.0, 0.0) # 黄
			else: mat_fill.albedo_color = Color(1.0, 0.0, 0.0) # 红
