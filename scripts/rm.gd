extends Node3D

# ================= 节点精准获取 =================
# 基地
@onready var blue_base = $world/blue_base
@onready var red_base = $world/red_base

# 前哨站 (包在 outpost 下面的 Target2)
@onready var blue_outpost = $world/blue_outpost
@onready var red_outpost = $world/red_outpost

# 能量机关 (假设放在 rune 节点下)
@onready var energy_mechanism = $world/rune/Target1
# 玩家
@onready var player = $Infantry

# ================= 初始化 =================
func _ready() -> void:
	if player and player.has_method("update_health_ui"):
		player.health_changed.connect($HUD.update_health_ui)
	
	# 1. 连接基地死亡信号 (判断胜负)
	if blue_base: 
		blue_base.base_destroyed.connect(_on_base_destroyed)
	if red_base: 
		red_base.base_destroyed.connect(_on_base_destroyed)
		
	# 2. 连接前哨站死亡信号 (蓝方)
	if blue_outpost:
		if blue_outpost.has_signal("sentry_destroyed"):
			blue_outpost.sentry_destroyed.connect(_on_blue_sentry_destroyed)
			print("✅ 蓝方前哨站信号连接成功！")
		else:
			print("❌ 蓝方前哨站没有 sentry_destroyed 信号！")
	else:
		print("❌ 找不到蓝方前哨站路径！")
		
	# 3. 连接前哨站死亡信号 (红方)
	if red_outpost:
		if red_outpost.has_signal("sentry_destroyed"):
			red_outpost.sentry_destroyed.connect(_on_red_sentry_destroyed)
			print("✅ 红方前哨站信号连接成功！")
		else:
			print("❌ 红方前哨站没有 sentry_destroyed 信号！")
	else:
		print("❌ 找不到红方前哨站路径！")
		
	# 4. 连接能量机关结束信号 (放在这里统一连接一次即可)
	if energy_mechanism:
		if not energy_mechanism.energy_finished.is_connected(_on_energy_finished):
			energy_mechanism.energy_finished.connect(_on_energy_finished)
			
	# 将步兵的血量变化，连接到 HUD 的更新函数
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	var infantry = get_tree().current_scene.get_node_or_null("Infantry")
	
	if hud and infantry:
		# 检查步兵有没有这个信号，HUD有没有这个函数
		if infantry.has_signal("health_changed") and hud.has_method("update_health_ui"):
			# 先断开旧的（防止重复报错），再重新连上
			if infantry.health_changed.is_connected(hud.update_health_ui):
				infantry.health_changed.disconnect(hud.update_health_ui)
				
			infantry.health_changed.connect(hud.update_health_ui)
			print("✅ 血条信号连接成功！")

# ================= 前哨站被毁 -> 激活基地靶子 =================

func _on_blue_sentry_destroyed() -> void:
	print("💥 蓝方前哨站已毁！正在激活蓝方基地靶子...")
	if blue_base and blue_base.has_method("activate_target"):
		blue_base.activate_target()
	# 给玩家加 150 点经验
	if player and player.has_method("add_xp"):
		player.add_xp(150)

func _on_red_sentry_destroyed() -> void:
	print("💥 红方前哨站已毁！正在激活红方基地靶子...")
	if red_base and red_base.has_method("activate_target"):
		red_base.activate_target()
	# 给玩家加 150 点经验
	if player and player.has_method("add_xp"):
		player.add_xp(150)

# ================= 基地被毁 -> 游戏结算 =================
func _on_base_destroyed(base_name: String) -> void:
	# 假设你是红方视角，如果蓝方基地炸了，你胜利
	if "blue" in base_name:
		$HUD.show_game_over(true, "红方基地被摧毁")
	else:
		$HUD.show_game_over(false, "蓝方基地被摧毁")

# ================= 按键控制能量机关 =================
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# 按 1 开启：一轮亮 1 个
		if event.keycode == KEY_1:
			if energy_mechanism:
				energy_mechanism.start_energy_mechanism(1)
				
		# 按 2 开启：一轮亮 2 个
		if event.keycode == KEY_2:
			if energy_mechanism:
				energy_mechanism.start_energy_mechanism(2)

# ================= 能量机关打完后发放奖励 =================
func _on_energy_finished() -> void:
	print("🎁 机关结束，发放攻击加成！")
	if player and player.has_method("receive_buff"):
		# 调用最新设计的接口：类型，持续时间，幅度
		# 发 10 秒攻击加成，幅度 0.5 (伤害增加 50%)
		player.receive_buff("attack", 10.0, 0.5)
