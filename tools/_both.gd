extends SceneTree
func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var v: String = Build.variant()
	var m: Main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	root.add_child(m)
	for i in 10: await process_frame
	if m.orb_open: m._close_orb()
	await create_timer(0.4).timeout
	m._action_turn_left(); await create_timer(0.3).timeout
	m._action_forward(); await create_timer(0.4).timeout
	m._show_hud_popup("A test notice.")
	await create_timer(0.3).timeout
	_shot(v + "_explore2")
	m._launch_combat([Enemy.make_from_name("Orc", 3)] as Array[Enemy])
	await create_timer(2.0).timeout
	_shot(v + "_fight2")
	quit()


func _shot(n: String) -> void:
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("S") + "/u_" + n + ".png")
