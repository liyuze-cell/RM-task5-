extends Node3D

# 将受到的伤害广播给父节点 (Outpost)
signal hit_received(damage: int)

@export var speed: float = 60.0
@export var stop_time: float = 180.0
var time_passed: float = 0.0
var is_playing: bool = true

@onready var point = $Point
var target_materials: Array = []

func _ready() -> void:
	# 收集 3 个装甲板的材质，并绑定受击事件
	for i in range(1, 4):
		var arm = point.get_node("Arm" + str(i))
		if not arm: continue
			
		var blade = null
		for child in arm.get_children():
			if child is Area3D:
				blade = child
				break
		if blade == null: continue
		
		var mesh = blade.get_node("MeshInstance3D")
		if mesh.material_override == null:
			mesh.material_override = StandardMaterial3D.new()
			
		var mat = mesh.material_override
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.75, 0.0)
		mat.emission_energy_multiplier = 2.5
		target_materials.append(mat)
		
		blade.area_entered.connect(_on_blade_hit)

func _process(delta: float) -> void:
	if is_playing:
		time_passed += delta
		# 180秒后停转
		if time_passed < stop_time:
			point.rotate_y(deg_to_rad(speed) * delta)

func _on_blade_hit(bullet_area: Area3D) -> void:
	if not is_playing: return
	if bullet_area.has_meta("is_hit"): return # 防连发
	bullet_area.set_meta("is_hit", true)
	
	var dmg_val = bullet_area.get("damage")
	var dmg = 5 if dmg_val == null else dmg_val
	
	# 把伤害上报给父节点 (Outpost)
	hit_received.emit(dmg)

# 被父节点调用的关闭函数
func deactivate() -> void:
	is_playing = false
	# 彻底熄灭装甲板发光
	for mat in target_materials:
		mat.emission_enabled = false
		mat.emission_energy_multiplier = 0.0
		mat.albedo_color = Color(0.1, 0.1, 0.1)
