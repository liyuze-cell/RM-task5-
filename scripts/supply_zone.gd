extends Area3D

@export var buff_duration: float = 10.0 # 每次续费增加 5 秒持续时间
@export var buff_magnitude: float = 0.5 # 增益幅度（固定 0.5，不叠加）

var player_in_zone: Node3D = null
var tick_timer: Timer

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# 创建一个每秒触发一次的定时器
	tick_timer = Timer.new()
	tick_timer.wait_time = 1.0
	tick_timer.autostart = false
	tick_timer.timeout.connect(_on_tick)
	add_child(tick_timer)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Infantry":
		player_in_zone = body
		_give_buff() # 进来的瞬间给一次
		tick_timer.start() # 开始每秒续杯
		print("进入补给区，开始持续获得增益！")

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Infantry":
		player_in_zone = null
		tick_timer.stop() # 离开区域，停止续杯
		print("离开补给区，停止获得增益。")

# 定时器每秒调用一次
func _on_tick() -> void:
	_give_buff()

# 实际发放增益的函数
func _give_buff() -> void:
	if is_instance_valid(player_in_zone) and player_in_zone.has_method("receive_buff"):
		# 传入固定的幅度 (0.5)
		player_in_zone.receive_buff("attack", buff_duration, buff_magnitude)
		player_in_zone.receive_buff("cooldown", buff_duration, buff_magnitude)
