extends Node3D

signal energy_finished

@export var total_duration: float = 30.0  # 总持续时间 30 秒
@export var round_duration: float = 2.5   # 每轮持续时间 2.5 秒
@export var rotate_speed: float = 60.0    # 旋转速度

var is_playing: bool = false
var current_mode: int = 1
var total_time_left: float = 0.0
var round_time_left: float = 0.0
var total_hits: int = 0
var total_spawned: int = 0

@onready var point = $Point

# 用二维数组存储成对的靶子和材质
# pair_areas[0] 里面装的是 [Ring1 的 Area, 1-1 的 Area]
var pair_areas: Array = []
var pair_materials: Array = []
var active_rings: Array = []

func _ready() -> void:
	# 收集 5 组靶子（前+后，如 Ring1 对应 1-1）
	for i in range(1, 6):
		var front_ring = point.get_node("Ring" + str(i))
		var back_ring = point.get_node(str(i) + "-1")
		
		# 1. 收集 Area3D 节点对
		pair_areas.append([front_ring, back_ring])
		
		# 2. 收集材质对，如果没材质自动生成
		var mats = []
		for ring_node in [front_ring, back_ring]:
			var mesh = ring_node.get_node("MeshInstance3D")
			if mesh.material_override == null:
				mesh.material_override = StandardMaterial3D.new()
				
			var mat = mesh.material_override
			mat.emission_enabled = true
			mat.emission = Color(1.0, 0.75, 0.0) # 金黄色光效
			mat.emission_energy_multiplier = 0.0 # 默认熄灭
			mats.append(mat)
			
		pair_materials.append(mats)
		
		# 3. 绑定受击信号 (前后两个 Area 都要绑定，传入的索引 i-1 是一样的)
		front_ring.area_entered.connect(_on_ring_hit.bind(i - 1))
		back_ring.area_entered.connect(_on_ring_hit.bind(i - 1))
		
	# 初始不处理帧循环，等被激活
	set_process(false)

# ================= 核心流程控制 =================
func start_energy_mechanism(mode: int) -> void:
	current_mode = mode
	is_playing = true
	total_time_left = total_duration
	round_time_left = round_duration
	total_hits = 0
	total_spawned = 0
	
	set_process(true)
	start_next_round()
	
	var mode_str = "亮1对" if mode == 1 else "亮2对"
	print("⚡ 能量机关启动！模式：", mode_str)

func _process(delta: float) -> void:
	if not is_playing: 
		return
		
	# 1. 靶子整体旋转
	point.rotate_y(deg_to_rad(rotate_speed) * delta)
	
	# 2. 总时间倒计时
	total_time_left -= delta
	if total_time_left <= 0:
		finish_energy_mechanism()
		return
		
	# 3. 单轮时间倒计时
	round_time_left -= delta
	if round_time_left <= 0:
		start_next_round()

# ================= 开启新一轮 =================
func start_next_round() -> void:
	turn_off_all()
	active_rings.clear()
	
	# 随机打乱 0-4 的索引
	var available = [0, 1, 2, 3, 4]
	available.shuffle()
	
	# 成对点亮
	for i in range(current_mode):
		var idx = available[i]
		active_rings.append(idx)
		
		# 同时点亮前后两面
		pair_materials[idx][0].emission_energy_multiplier = 5.0
		pair_materials[idx][1].emission_energy_multiplier = 5.0
		
	total_spawned += current_mode
	round_time_left = round_duration

# ================= 受击判定 =================
func _on_ring_hit(bullet_area: Area3D, ring_index: int) -> void:
	# 【第一道锁】：如果子弹已经被判定过了（比如打中前面的环，后面的环又触发信号），直接拦截
	if bullet_area.has_meta("is_hit"): 
		return
		
	# 【第二道锁】：立刻给子弹打上“已命中”标签，防止同一颗子弹在一帧内触发多次
	bullet_area.set_meta("is_hit", true)
	
	# 如果没激活，或者打中的环不在当前激活列表里，无效（打到暗靶了）
	if not is_playing or not ring_index in active_rings:
		return 
		
	total_hits += 1
	print("🎯 命中第 ", ring_index + 1, " 组靶子")
	
	# 给玩家加 15 点经验
	var player = get_tree().current_scene.get_node_or_null("Infantry")
	if player and player.has_method("add_xp"):
		player.add_xp(15)
	
	
	# 同时熄灭前后两面
	pair_materials[ring_index][0].emission_energy_multiplier = 0.0
	pair_materials[ring_index][1].emission_energy_multiplier = 0.0
	
	active_rings.erase(ring_index)
	
	# 如果本轮的靶子都被打完了，提前进入下一轮
	if active_rings.is_empty():
		start_next_round()

# ================= 结束与结算 =================
func finish_energy_mechanism() -> void:
	is_playing = false
	set_process(false)
	turn_off_all()
	
	# 计算命中率
	var hit_rate = 0.0
	if total_spawned > 0:
		hit_rate = float(total_hits) / float(total_spawned)
		
	print("🛑 结束！命中数: ", total_hits, "/", total_spawned, "，命中率: ", hit_rate * 100, "%")
	
	# 发送信号给主场景 (rm.gd)
	energy_finished.emit()

# ================= 辅助函数 =================
func turn_off_all() -> void:
	for i in range(5):
		pair_materials[i][0].emission_energy_multiplier = 0.0
		pair_materials[i][1].emission_energy_multiplier = 0.0
