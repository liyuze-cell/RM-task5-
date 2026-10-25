extends CanvasLayer

# ================= 节点引用 =================
@onready var health_bar: ProgressBar = $Control/HealthBar
@onready var health_label: Label = $Control/HealthLabel
@onready var mini_map_cam: Camera3D = $Control/SubViewportContainer/SubViewport/Camera3D
@onready var timer_label: Label = $Control/TimerLabel
@onready var ammo_label: Label = $Control/AmmoLabel
@onready var help_panel: Panel = $Control/HelpPanel

# 结算与增益 UI
@onready var game_over_panel: ColorRect = $Control/GameOverPanel
@onready var result_label: Label = $Control/GameOverPanel/ResultLabel
@onready var atk_label: Label = $Control/VBoxContainer/AtkLabel
@onready var def_label: Label = $Control/VBoxContainer/DefLabel
@onready var fire_rate_label: Label = $Control/VBoxContainer/FireRateLabel
@onready var heat_bar: ProgressBar = $Control/HeatBar
@onready var level_label: Label = $Control/LevelLabel
@onready var economy_label: Label = $Control/EconomyLabel

# ================= 状态变量 =================
var player_node: Node3D = null
var is_game_over: bool = false # 记录游戏是否结束，防止重复触发

# 比赛计时变量
@export var match_duration: int = 840 # 比赛总时长 14 分钟
var time_remaining: float = 0.0
var is_match_running: bool = true

# ================= 初始化 =================
func _ready() -> void:
	# 隐藏结算面板
	game_over_panel.hide()
	
	# 获取玩家节点
	player_node = get_tree().current_scene.get_node_or_null("Infantry")
	
	# 初始化时间与面板
	time_remaining = match_duration
	help_panel.hide() # 默认隐藏帮助面板

# ================= 帧循环更新 =================
func _process(delta: float) -> void:
	
	# 1. 小地图摄像机跟随
	if player_node and mini_map_cam:
		mini_map_cam.global_position = Vector3(
			player_node.global_position.x,
			50.0,
			player_node.global_position.z
		)
		# 射速更新
		var current_cd = player_node.base_shoot_cooldown
		if player_node.cd_buff_time > 0:
			current_cd = current_cd * (1.0 - player_node.cd_magnitude)
			current_cd = max(current_cd, 0.05)
		fire_rate_label.text = "🔫 射速: %.1f 发/秒" % (1.0 / current_cd)

		# 热量更新
		heat_bar.value = player_node.current_heat
		heat_bar.max_value = player_node.max_heat
		# 过热时进度条变红，正常时变橙
		heat_bar.modulate = Color.RED if player_node.is_overheated else Color.ORANGE

		# 等级和经验更新
		level_label.text = "Lv.%d | XP: %d/%d" % [
			player_node.level, 
			player_node.current_xp, 
			player_node.max_xp
		]
		
	# 2. 比赛倒计时逻辑
	if is_match_running and time_remaining > 0:
		time_remaining -= delta
		_update_timer_label()
		
		# 倒计时归零触发结算
		if time_remaining <= 0:
			is_match_running = false
			timer_label.text = "00:00"
			show_game_over(false, "时间到，未能摧毁基地")
			
	# 3. 实时更新射速与弹药状态
	if player_node and not is_game_over:
		# --- 计算射速 ---
		var current_cd = player_node.base_shoot_cooldown
		if player_node.cd_buff_time > 0:
			current_cd = current_cd * (1.0 - player_node.cd_magnitude)
			current_cd = max(current_cd, 0.05) # 极限保护，最快 0.05 秒一发
			
		var fire_rate = 1.0 / current_cd
		fire_rate_label.text = "🔫 射速: %.1f 发/秒" % fire_rate
		
		# 冷却 Buff 变色提示
		if player_node.cd_buff_time > 0:
			fire_rate_label.modulate = Color.CYAN
		else:
			fire_rate_label.modulate = Color.WHITE
			
		# --- 更新弹药文字 ---
		_update_ammo_ui()
		
		# --- 更新攻击/防御 Buff 文字 ---
		if player_node.atk_buff_time > 0:
			atk_label.text = "⚔️ 攻击强化: %.1fs" % player_node.atk_buff_time
			atk_label.show()
		else:
			atk_label.hide()
			
		if player_node.def_buff_time > 0:
			def_label.text = "🛡️ 防御强化: %.1fs" % player_node.def_buff_time
			def_label.show()
		else:
			def_label.hide()
		
	if player_node and not is_game_over:
		# 更新经济显示
		economy_label.text = "💰 经济: %d" % int(player_node.economy)
		
		# 更新弹药显示
		var current_type = "大球" if player_node.is_large_bullet else "小球"
		ammo_label.text = "子弹: 小 %d | 大 %d | 当前: %s" % [
			player_node.small_ammo, 
			player_node.large_ammo, 
			current_type
		]
# ================= 更新 UI 的函数 =================
# 1. 血量更新接口（被 Infantry 的信号调用）
func update_health_ui(current: int, max_value: int) -> void:
	health_bar.max_value = max_value
	health_bar.value = current
	health_label.text = "血量值: %d / %d" % [current, max_value]

# 2. 格式化时间更新（如 150 秒显示为 02:30）
func _update_timer_label() -> void:
	# 注意：必须除以 60.0 浮点数，否则会报黄色警告
	var minutes = int(time_remaining / 60.0) 
	var seconds = int(time_remaining) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

# 3. 获取玩家当前子弹状态并更新文字
func _update_ammo_ui() -> void:
	if player_node and "is_large_bullet" in player_node:
		# 如果当前是大球
		if player_node.is_large_bullet:
			ammo_label.text = "当前弹药: 42mm 大 (%d 发)" % player_node.large_ammo
			ammo_label.modulate = Color.ORANGE # 大球保持橙色警告色
		# 如果当前是小球
		else:
			ammo_label.text = "当前弹药: 17mm 小 (%d 发)" % player_node.small_ammo
			ammo_label.modulate = Color.WHITE # 小球保持白色

# ================= 按键输入处理 =================
func _unhandled_input(event: InputEvent) -> void:
	# 1. 如果游戏结束了，并且按下了 R 键
	if is_game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		# 恢复时间，重新加载当前场景
		get_tree().paused = false
		get_tree().reload_current_scene()
		return # 重开逻辑执行完后，直接 return 结束当前输入处理
		
	# 2. 按下 H 键显示/隐藏帮助面板
	if event is InputEventKey and event.pressed and event.keycode == KEY_H:
		help_panel.visible = !help_panel.visible

# ================= 游戏结算控制 =================
# 显示结算界面（供外部调用：比如基地被摧毁、或时间归零）
func show_game_over(is_victory: bool, reason: String) -> void:
	if is_game_over: return # 防止重复触发
	is_game_over = true
	
	# 1. 显示面板
	game_over_panel.show()
	
	# 2. 设置文本和颜色
	if is_victory:
		result_label.text = "VICTORY\n" + reason
		result_label.modulate = Color(0.2, 1.0, 0.2) # 绿色
	else:
		result_label.text = "DEFEAT\n" + reason
		result_label.modulate = Color(1.0, 0.2, 0.2) # 红色
		
	# 3. 暂停游戏并释放鼠标，方便玩家点击 UI 或按 R 键
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
