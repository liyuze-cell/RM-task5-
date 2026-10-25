extends Area3D

# ================= 子弹属性 =================
var damage: int = 20                         # 子弹伤害（由玩家发射时赋予）
@export var life_time: float = 5.0          # 存活时间（防止无限飞占用内存）
#@export var gravity: float = 9.8            # 【补充】重力影响，让子弹有抛物线弹道
var velocity: Vector3 = Vector3.ZERO        # 由玩家脚本赋予的初速度向量

# 节点引用
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision: CollisionShape3D = $CollisionShape3D

# ================= 初始化 =================
func _ready() -> void:
	# 连接物理信号
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

# ================= 物理帧循环 =================
func _physics_process(delta: float) -> void:
	# 1. 重力影响（让子弹在飞行过程中下坠）
	velocity.y -= gravity * delta
	
	# 2. 实际移动
	global_position += velocity * delta
	
	# 3. 寿命倒计时销毁
	life_time -= delta
	if life_time <= 0:
		queue_free()

# ================= 核心：子弹大小切换函数 =================
func set_bullet_size(is_large: bool) -> void:
	# 根据布尔值决定半径
	var radius = 0.4 if is_large else 0.2
	
	# 修改视觉网格大小
	if mesh and mesh.mesh is SphereMesh:
		mesh.mesh.radius = radius
		mesh.mesh.height = radius * 2
		
	# 修改碰撞体大小
	if collision and collision.shape is SphereShape3D:
		collision.shape.radius = radius 

# ================= 击中 Area3D（靶子、基地受击区） =================
func _on_area_entered(_area: Area3D) -> void: # 参数加下划线，消除未使用的警告
	# 防止一颗子弹打中多个部位触发多次结算
	if has_meta("is_hit"): return
	set_meta("is_hit", true)
	
	# 击中后立刻销毁自己，防止残留
	queue_free()

# ================= 击中物理角色（如敌方车体） =================
func _on_body_entered(body: Node3D) -> void:
	# 防止打中自己（假设你的玩家节点名字叫 Infantry）
	if body is CharacterBody3D and body.name == "Infantry":
		return
		
	# 防止重复结算
	if has_meta("is_hit"): return
	set_meta("is_hit", true)
	
	# 如果对方有 take_damage 方法，可以在这里调用扣血
	# if body.has_method("take_damage"): 
	#	body.take_damage(damage)
	
	queue_free()
