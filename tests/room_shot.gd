extends Node
## Renders the bedroom from a chosen pose and saves a PNG. Usage:
## godot --path . res://tests/room_shot.tscn -- --out=/tmp/x.png --pos=1.6,0,0 --yaw=180 --pitch=0 --day=1
func _ready() -> void:
	var out := "/tmp/room.png"
	var pos := Vector3(1.6, 0, 0.2)
	var yaw := 0.0
	var pitch := 0.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.get_slice("=", 1)
		elif a.begins_with("--pos="):
			var p := a.get_slice("=", 1).split(",")
			pos = Vector3(float(p[0]), float(p[1]), float(p[2]))
		elif a.begins_with("--yaw="): yaw = float(a.get_slice("=", 1))
		elif a.begins_with("--pitch="): pitch = float(a.get_slice("=", 1))
		elif a.begins_with("--day="): GameState.day = int(a.get_slice("=", 1))
		elif a.begins_with("--press="): GameState.set_psy("pressure", float(a.get_slice("=", 1)))
	Settings.master_volume = 0.0
	UI.set_black()
	await UI.fade_clear(0.01)
	var player := Player.new()
	add_child(player)
	if "--world=hood" in OS.get_cmdline_user_args():
		var hood := Neighborhood.new()
		add_child(hood)
		hood.player = player
	else:
		var room := Bedroom.new()
		add_child(room)
		room.player = player
		room.mirror.setup(player, room, Vector2(0.8, 1.7))
	player.set_pose(pos, deg_to_rad(yaw))
	player.pitch = deg_to_rad(pitch)
	for i in 20:
		await get_tree().process_frame
	print("player y=", player.global_position.y, " floor=", player.is_on_floor())
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	get_tree().quit()
