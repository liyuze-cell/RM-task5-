extends Area3D

# --- 信号 ---
signal target_hit(damage: int)

# --- 配置参数 ---
@export var move_speed: float = 2.0
@export var move_range: float = 0.5
# 在右侧检查器下拉选择平移方向：0=X轴, 1=Y轴, 2=Z轴
@export_enum("X轴", "Y轴", "Z轴") var move_axis: int = 0

# --- 状态变量 ---
var time: float = 0.0
var is_active: bool = false
var start_pos: Vector3

@onready var mesh = $MeshInstance3D

# --- 初始化 ---
func _ready() -> void:
	area_entered.connect(_on_hit)
	start_pos = position

	# 确保网格有基础材质
	if mesh.material_override == null:
		mesh.material_override = StandardMaterial3D.new()
	
	# 初始状态：关闭发光
	mesh.material_override.emission_enabled = false

# --- 帧循环 ---
func _process(delta: float) -> void:
	if is_active:
		time += delta
		# 正弦波计算平移偏移量
		var offset = sin(time * move_speed) * move_range
		
		position = start_pos
		if move_axis == 0:
			position.x += offset
		elif move_axis == 1:
			position.y += offset
		elif move_axis == 2:
			position.z += offset

# --- 激活靶子 ---
func activate() -> void:
	is_active = true
	
	# 创建高亮红色发光材质（无视光照，双重保险）
	var glow_mat = StandardMaterial3D.new()
	glow_mat.albedo_color = Color(1.0, 0.0, 0.0)
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(1.0, 0.0, 0.0)
	glow_mat.emission_energy_multiplier = 5.0
	
	# 强制覆盖给网格
	if mesh:
		mesh.material_override = glow_mat
		
	print(name, " 已激活并发光！")

# --- 受击处理 ---
func _on_hit(bullet_area: Area3D) -> void:
	if not is_active: return
	if bullet_area.has_meta("is_hit"): return # 防连发锁
	bullet_area.set_meta("is_hit", true)
	
	# 安全获取伤害
	var dmg_val = bullet_area.get("damage")
	var dmg = 5
	if dmg_val != null: 
		dmg = dmg_val
		
	# 将伤害发送给基地
	target_hit.emit(dmg)
