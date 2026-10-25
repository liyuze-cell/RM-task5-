extends Area3D

var player_in_zone: Node3D = null
var heal_timer: float = 0.0
@export var heal_interval: float = 1.0 
@export var heal_percent: float = 0.05 

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(delta: float) -> void:
	# 每秒 5% 回血逻辑
	if player_in_zone:
		heal_timer -= delta
		if heal_timer <= 0:
			heal_timer = heal_interval
			player_in_zone.heal_percent(heal_percent)

func _on_body_entered(body: Node3D) -> void:
	if body.name == "Infantry":
		player_in_zone = body
		heal_timer = 0 
		print("🔵 进入商店。按 E 买小球(1块/发)，按 Q 买大球(10块/发)")

func _on_body_exited(body: Node3D) -> void:
	if body.name == "Infantry":
		player_in_zone = null

func _unhandled_input(event: InputEvent) -> void:
	if player_in_zone and event is InputEventKey and event.pressed:
		# 按 E 买 10 发小球（花费 10 经济）
		if event.keycode == KEY_E:
			if player_in_zone.has_method("buy_ammo"):
				player_in_zone.buy_ammo("small", 10, 1)
				
		# 按 Q 买 10 发大球（花费 100 经济）
		if event.keycode == KEY_Q:
			if player_in_zone.has_method("buy_ammo"):
				player_in_zone.buy_ammo("large", 10, 10)
