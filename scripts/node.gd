extends Node

# ================= 网络与推流状态 =================
var server = TCPServer.new()
var clients: Array = []

@export var send_fps: float = 10.0 # 降低一点帧率，保证网络不卡 (10帧/秒)
var timer: Timer

@onready var stream_viewport = $"../StreamViewport" # 获取纯净视角的子视口

# ================= 初始化 =================
func _ready() -> void:
	# 用 Timer 代替 _process 累加器，更稳定地控制推流帧率
	timer = Timer.new()
	timer.wait_time = 1.0 / send_fps
	timer.autostart = true
	timer.timeout.connect(_on_send_timer)
	add_child(timer)
	
	# 启动本地 TCP 服务器，监听 8080 端口
	var err = server.listen(8080)
	if err == OK:
		print("🚀 推流服务已启动！请浏览器访问 http://127.0.0.1:8080")
	else:
		print("❌ 端口启动失败，可能 8080 被占用了")

# ================= 帧循环：仅处理连接管理 =================
func _process(_delta: float) -> void:
	# 1. 接收新连接 (保证主线程绝不阻塞)
	while server.is_connection_available():
		var peer = server.take_connection()
		clients.append(peer)
		# 发送标准的 HTTP MJPEG 流响应头
		var header = "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=frame\r\n\r\n"
		peer.put_data(header.to_utf8_buffer())

	# 2. 清理断开连接的客户端 (必须倒序遍历，否则会索引错乱)
	for i in range(clients.size() - 1, -1, -1):
		var client = clients[i]
		if client.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			client.disconnect_from_host()
			clients.remove_at(i)

# ================= 定时器触发：抓图与推流 =================
func _on_send_timer() -> void:
	if clients.is_empty(): 
		return
		
	# 1. 等待当前帧渲染完成，防止抓到纯灰/纯黑的画面
	await RenderingServer.frame_post_draw
	
	# 2. 从纯净视口获取画面并压缩
	var img = stream_viewport.get_texture().get_image()
	if not img: return
	
	# 3. 压缩 JPEG (质量 0.5 足够肉眼看，体积能小一半)
	var buffer = img.save_jpg_to_buffer(0.5)
	
	# 4. 构造 MJPEG 视频流的数据包
	var frame_header = "--frame\r\nContent-Type: image/jpeg\r\nContent-Length: %d\r\n\r\n" % buffer.size()
	var full_frame = frame_header.to_utf8_buffer() + buffer + "\r\n".to_utf8_buffer()
	
	# 5. 发送数据给所有客户端
	for client in clients:
		# 如果网络缓冲区里积压的数据太多，就跳过这一帧，防止彻底卡死
		if client.get_available_bytes() > 1024 * 1024: 
			continue
		client.put_data(full_frame)
