extends Node3D

# ================= 信号定义 =================
# 当基地被摧毁时，发送此信号给主场景 (rm.gd) 用于判定胜负
signal base_destroyed(base_name: String)

# ================= 基地属性 =================
@export_group("基地属性")
@export var max_health: int = 4500
var current_health: int
var is_dead: bool = false

# ================= UI 设置 =================
@export_group("UI 设置")
# 血条位置偏移量 (如果血条偏左，在检查器里把 X 值改大即可)
@export var bar_offset: Vector3 = Vector3(1, 0, 2) 
@export var bar_width: float = 6.0
@export var bar_height: float = 0.6

# 内部变量（用于动态生成 3D 血条）
var hp_bar_fill: MeshInstance3D
var hp_bar_bg: MeshInstance3D
var hp_bar_pivot: Node3D

# ================= 初始化 =================
func _ready() -> void:
	current_health = max_health
	
	# 1. 生成血条（优先寻找场景里是否摆放了 Marker3D 作为定位点）
	var final_pos = bar_offset
	if has_node("HealthBarPos"):
		final_pos = $HealthBarPos.position
		
	create_3d_health_bar(final_pos)
	
	# 2. 监听靶子 (Target3) 的受击信号
	if has_node("Target3"):
		$Target3.target_hit.connect(take_damage)
		print("✅ ", name, " 成功连接到靶子 Target3")
	else:
		print("⚠️ 警告: ", name, " 下面没有找到 Target3 节点！")

# ================= 扣血与死亡逻辑 =================
# 接收来自 Target3 的伤害
func take_damage(amount: int) -> void:
	if is_dead: return
	
	current_health -= amount
	update_health_bar() 
	
	print(name, " 受到伤害: ", amount, " 剩余血量: ", current_health)
	
	# 血量归零则摧毁基地
	if current_health <= 0:
		destroy_base()

func destroy_base() -> void:
	is_dead = true
	current_health = 0
	update_health_bar()
	print("💥 ", name, " 被摧毁！")
	
	# 销毁前，关闭靶子并隐藏血条
	if has_node("Target3"):
		$Target3.deactivate()
		
	if hp_bar_bg: hp_bar_bg.hide()
	if hp_bar_fill: hp_bar_fill.hide()
		
	# 发送死亡信号给主场景
	base_destroyed.emit(name)

# ================= 靶子激活逻辑 =================
# 当前哨站被摧毁后，主场景会调用此函数来激活移动靶
func activate_target() -> void:
	print(name, " 收到激活指令！")
	if has_node("Target3"):
		$Target3.activate()

# ================= 3D 血条生成与更新 =================
# 动态生成 3D 血条（包含背景、左锚点、填充条）
func create_3d_health_bar(pos: Vector3) -> void:
	# 创建血条根节点并设定位置
	var bar_root = Node3D.new()
	bar_root.position = pos
	add_child(bar_root)
	
	# --- 1. 生成背景底板 ---
	hp_bar_bg = MeshInstance3D.new()
	var quad_bg = QuadMesh.new()
	quad_bg.size = Vector2(bar_width, bar_height)
	hp_bar_bg.mesh = quad_bg
	
	var mat_bg = StandardMaterial3D.new()
	mat_bg.albedo_color = Color(0.1, 0.1, 0.1) # 暗灰色背景
	mat_bg.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
	mat_bg.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED   # 永远面向摄像机
	mat_bg.no_depth_test = true # 穿透墙壁显示
	hp_bar_bg.material_override = mat_bg
	bar_root.add_child(hp_bar_bg)
	
	# --- 2. 生成左锚点 (核心防偏移机制) ---
	# 把锚点定在底板的最左侧，这样血条缩短时只会向右缩，不会上下偏移
	hp_bar_pivot = Node3D.new()
	hp_bar_pivot.position = Vector3(-bar_width / 2.0, 0, 0)
	bar_root.add_child(hp_bar_pivot)
	
	# --- 3. 生成血条填充 ---
	hp_bar_fill = MeshInstance3D.new()
	var quad_fill = QuadMesh.new()
	quad_fill.size = Vector2(bar_width, bar_height)
	hp_bar_fill.mesh = quad_fill
	
	var mat_fill = StandardMaterial3D.new()
	mat_fill.albedo_color = Color(0.0, 1.0, 0.2) # 默认绿色
	mat_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fill.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat_fill.no_depth_test = true
	mat_fill.render_priority = 1 # 渲染层级高于背景，防止闪烁
	hp_bar_fill.material_override = mat_fill
	
	hp_bar_pivot.add_child(hp_bar_fill)
	# 初始位置居中
	hp_bar_fill.position.x = bar_width / 2.0 

# 实时更新血条长度与颜色
func update_health_bar() -> void:
	if hp_bar_fill and hp_bar_bg and not is_dead:
		# 计算血量比例 (0.0 ~ 1.0)
		var ratio = float(current_health) / max_health
		ratio = clamp(ratio, 0.0, 1.0)
		
		# 缩放并调整位置 (因为锚点在左侧，缩放 X 轴即可)
		hp_bar_fill.scale.x = ratio
		hp_bar_fill.position.x = ratio * (bar_width / 2.0)
		
		# 根据血量比例动态变色
		var mat_fill = hp_bar_fill.material_override as StandardMaterial3D
		if mat_fill:
			if ratio > 0.5: 
				mat_fill.albedo_color = Color(0.0, 1.0, 0.2) # 绿色 (健康)
			elif ratio > 0.2: 
				mat_fill.albedo_color = Color(1.0, 1.0, 0.0) # 黄色 (警告)
			else: 
				mat_fill.albedo_color = Color(1.0, 0.0, 0.0) # 红色 (危险)
