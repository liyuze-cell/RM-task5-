extends Area3D

signal target_hit(damage: int) 

@export var move_speed: float = 2.0
@export var move_range: float = 1.5 
# 【新增】增加正负方向选项，适配你不同的模型摆放
@export_enum("X正向", "X反向", "Y正向", "Y反向", "Z正向", "Z反向") var move_axis: int = 0

var time: float = 0.0
var is_active: bool = false 
var start_pos: Vector3 

func _ready() -> void:
	area_entered.connect(_on_hit)
	start_pos = position
	_apply_material_to_all_meshes("dark")

func _process(delta: float) -> void:
	if is_active:
		time += delta
		var offset = sin(time * move_speed) * move_range
		
		# 每次先重置回初始位置
		position = start_pos
		
		# 根据右侧检查器的选项，精准平移
		match move_axis:
			0: position.x += offset # X轴正向
			1: position.x -= offset # X轴反向
			2: position.y += offset # Y轴正向
			3: position.y -= offset # Y轴反向
			4: position.z += offset # Z轴正向
			5: position.z -= offset # Z轴反向

func activate() -> void:
	is_active = true
	print("🔥 Target3 激活并开始移动！")
	_apply_material_to_all_meshes("glow")

func _on_hit(bullet_area: Area3D) -> void:
	if not is_active: return 
	if bullet_area.has_meta("is_hit"): return
	bullet_area.set_meta("is_hit", true)
	
	var dmg_val = bullet_area.get("damage")
	var dmg = 200
	if dmg_val != null: dmg = dmg_val
	
	print("✅ Target3 受到伤害: ", dmg)
	target_hit.emit(dmg)

func _apply_material_to_all_meshes(state: String) -> void:
	var mat = StandardMaterial3D.new()
	if state == "glow":
		mat.albedo_color = Color(1.0, 0.0, 0.0)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED 
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.0, 0.0)
		mat.emission_energy_multiplier = 5.0 
	else:
		mat.albedo_color = Color(0.2, 0.2, 0.2)
	_apply_recursive(self, mat)

func _apply_recursive(node: Node, mat: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_recursive(child, mat)
