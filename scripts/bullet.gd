extends Area3D

var damage: int = 5
var velocity: Vector3 = Vector3.ZERO

@export var life_time: float = 10.0 
#@export var gravity: float = 2.0 

var has_hit: bool = false 

@onready var mesh = $MeshInstance3D
@onready var collision = $CollisionShape3D

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)
	
	# 防自爆：出生 0.05 秒后再开启物理检测，飞出枪管
	monitoring = false
	await get_tree().create_timer(0.05).timeout
	if is_instance_valid(self):
		monitoring = true

func _physics_process(delta: float) -> void:
	if has_hit: return
	
	# 应用重力与移动
	velocity.y -= gravity * delta
	global_position += velocity * delta
	
	life_time -= delta
	if life_time <= 0:
		queue_free()

# 【核心修改】根据大小精确设置半径与碰撞体
func set_bullet_size(is_large: bool) -> void:
	# 大球半径0.2，小球半径0.1
	var radius = 0.2 if is_large else 0.1
	
	# 设置视觉大小
	if mesh and mesh.mesh is SphereMesh:
		mesh.mesh.radius = radius
		mesh.mesh.height = radius * 2
		
	# 设置物理碰撞箱大小（保留防穿模的 Z 轴拉长）
	if collision and collision.shape is BoxShape3D:
		collision.shape.size = Vector3(radius * 2, radius * 2, 1.5)

# ================= 击中 Area3D（靶子） =================
func _on_area_entered(area: Area3D) -> void:
	if area.name == "Infantry" or area.name == "SupplyZone" or area.name == "Shop": return
	if has_hit: return
	
	if "Target" in area.name or "Ring" in area.name:
		has_hit = true
		if area.has_method("_on_hit"):
			area._on_hit(self)
		
		set_deferred("monitoring", false) 
		queue_free()

# ================= 击中 Body3D（墙壁） =================
func _on_body_entered(body: Node3D) -> void:
	if body.name == "Infantry": return
	if has_hit: return
	
	has_hit = true
	set_deferred("monitoring", false)
	queue_free()
