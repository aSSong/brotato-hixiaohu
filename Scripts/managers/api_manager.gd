extends Node

const HOST: String = "https://minigame2025.run.ingarena.net"
const TIMEOUT: float = 5.0

var http_client = HTTPClient.new()

func _http_get(path: String) -> Dictionary:
	return await _http_request(path, HTTPClient.METHOD_GET)

func _http_post(path: String, body: String) -> Dictionary:
	return await _http_request(path, HTTPClient.METHOD_POST, body)

## Common Request Method
## Return: {"data": Dictionary, "error": String}
func _http_request(path: String, method: int, body: String = "") -> Dictionary:
	var api_url = _get_api_url(path)
	
	if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
		# Connect to host
		var error = http_client.connect_to_host(HOST)
		if error != OK:
			return {"data": {}, "error": "HTTPClient Connection Failure"}
		
		# Wait for connection
		while http_client.get_status() == HTTPClient.STATUS_CONNECTING or http_client.get_status() == HTTPClient.STATUS_RESOLVING:
			http_client.poll()
			await get_tree().process_frame

		# Check connection status
		if http_client.get_status() != HTTPClient.STATUS_CONNECTED:
			return {"data": {}, "error": "HTTPClient Connection Failure"}

	# Send request
	var headers = []
	if method == HTTPClient.METHOD_POST:
		headers.append("Content-Type: application/json")
	
	var error = http_client.request(method, api_url, headers, body)
	if error != OK:
		return {"data": {}, "error": "Request failed: %s" % error_string(error)}
	
	# Wait for response
	var start_time = Time.get_ticks_msec()
	while http_client.get_status() == HTTPClient.STATUS_REQUESTING:
		http_client.poll()
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > TIMEOUT * 1000:
			return {"data": {}, "error": "Request timeout"}
	
	# Read response
	var response_body = PackedByteArray()
	while http_client.get_status() == HTTPClient.STATUS_BODY:
		http_client.poll()
		var chunk = http_client.read_response_body_chunk()
		if chunk.size() == 0:
			await get_tree().process_frame
		else:
			response_body.append_array(chunk)
	
	# Check status code
	var response_code = http_client.get_response_code()
	if response_code < 200 or response_code >= 300:
		var body_text = response_body.get_string_from_utf8()
		return {"data": {}, "error": "HTTP error %d: %s" % [response_code, body_text]}
	
	# Parse JSON
	var body_text = response_body.get_string_from_utf8()
	if body_text.is_empty():
		return {"data": {}, "error": "Response body is empty"}
	
	var json = JSON.new()
	var parse_error = json.parse(body_text)
	if parse_error != OK:
		return {"data": {}, "error": "JSON parse failed: %s" % json.get_error_message()}
	
	var response_data = json.data
	if not response_data is Dictionary:
		response_data = {"result": response_data}
	
	return {"data": response_data}

func _get_api_url(path: String) -> String:
	var player_name = SaveManager.get_player_name()
	if player_name:
		player_name = player_name.md5_text()
	else:
		player_name = "0"
	
	var floor_id = SaveManager.get_floor_id()
	if floor_id < 0:
		floor_id = 0
	
	var api_url = path.replace("{player_id}", player_name).replace("{floor_id}", str(floor_id))
	return api_url

func load_ghost_data() -> Dictionary:
	var res = await _http_get("/api/game/ghosts/{floor_id}/{player_id}")
	if res.has("error"):
		return {error = res["error"]}
	return res["data"]

func save_ghost_data(data: String) -> Dictionary:
	var res = await _http_post("/api/game/ghosts/{floor_id}/{player_id}", data)
	if res.has("error"):
		return {error = res["error"]}
	return {success = true}

func load_leaderboard_data() -> Dictionary:
	var res = await _http_get("/api/game/leaderboards")
	if res.has("error"):
		return {error = res["error"]}
	return res["data"]

func save_leaderboard_data(type: int, data: String) -> Dictionary:
	var res = await _http_post("/api/game/leaderboards/" + str(type) + "/{player_id}", data)
	if res.has("error"):
		return {error = res["error"]}
	return {success = true}

## Ping 服务器检测连接状态
## 返回: bool - true 表示连接成功，false 表示连接失败
func ping_server() -> bool:
	var ping_client = HTTPClient.new()
	
	# 连接到主机
	var error = ping_client.connect_to_host(HOST)
	if error != OK:
		return false
	
	# 等待连接（最多3秒）
	var start_time = Time.get_ticks_msec()
	while ping_client.get_status() == HTTPClient.STATUS_CONNECTING or ping_client.get_status() == HTTPClient.STATUS_RESOLVING:
		ping_client.poll()
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > 3000:
			return false
	
	# 检查连接状态
	if ping_client.get_status() != HTTPClient.STATUS_CONNECTED:
		return false
	
	# 发送简单的 HEAD 请求
	error = ping_client.request(HTTPClient.METHOD_HEAD, "/", [])
	if error != OK:
		return false
	
	# 等待响应
	start_time = Time.get_ticks_msec()
	while ping_client.get_status() == HTTPClient.STATUS_REQUESTING:
		ping_client.poll()
		await get_tree().process_frame
		if Time.get_ticks_msec() - start_time > 3000:
			return false
	
	# 任何响应都表示服务器可达
	var response_code = ping_client.get_response_code()
	return response_code > 0
