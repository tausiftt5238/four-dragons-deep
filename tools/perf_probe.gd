extends "res://tools/store_shots.gd"
# Measures how the game runs, for the store page's system requirements. Plays
# three of the heaviest things in the Steam build, for a fixed stretch of real
# time each, with vsync off so the frame rate is not capped at the screen's:
#
#   explore   walking a floor-12 maze (the 3D corridor and the map)
#   fight     four monsters on floor 17, in the battle room
#   abyss     four monsters in Abyss colours (the recolour shader on each)
#
# and prints, per scene, the average frame rate, the slowest 1% of frames, the
# worst single frame and memory. Run it on the hardware in question, or make
# this machine a weaker one:
#
#   tools/run.sh steam --script tools/perf_probe.gd
#   LIBGL_ALWAYS_SOFTWARE=1 __GLX_VENDOR_LIBRARY_NAME=mesa \
#       tools/run.sh steam --script tools/perf_probe.gd      no graphics card
#   taskset -c 0,1 tools/run.sh steam --script tools/perf_probe.gd   two threads
#
# Needs a display. Puts this machine's autosave and records back afterwards.

const SECONDS: float = 12.0

var _times: Array[float] = []
var _recording: bool = false


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# As a player runs it: a tool run otherwise keeps a small window (Boot).
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	var kept: Dictionary = {}
	for path: String in [SaveSystem.slot_path(SaveSystem.AUTO_SLOT), Records.PATH]:
		kept[path] = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else null
	await process_frame
	await process_frame
	print("PROBE device: %s | %s | %d threads | window %s" % [
			RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(),
			OS.get_processor_count(), DisplayServer.window_get_size()])
	GameBoot.pending_slot = 0
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Main
	root.add_child(main)
	await _frames(10)
	main._encounters_enabled = false
	_dress_party()
	process_frame.connect(_tick)

	await _go_to_floor(12)
	var lvl: Level = main.current_level
	_stand(lvl.player_start, lvl.player_start_facing)
	var route: Array[Vector2i] = _path_away(main.player_pos, 200)
	_start()
	var step: int = 0
	var clock: float = 0.0
	while clock < SECONDS:
		if step < route.size():
			for d: int in 4:
				if main.player_pos + Main.DIR_OFFSET[d] == route[step]:
					main.player_facing = d
			main._snap_cam_yaw()
			main._action_forward()
			if main.orb_open:
				main._close_orb()
			step += 1
		var t0: int = Time.get_ticks_msec()
		await _wait(0.25)
		clock += float(Time.get_ticks_msec() - t0) / 1000.0
	_report("explore")

	await _fight(17, ["Mature Bronze Dragon", "Dark Demoness", "Warlock", "Mature Blue Dragon"], "", "fight")
	await _fight(22, ["Demon", "Young Red Dragon", "Orc", "Ghostfire"], "mixed", "abyss")

	print("PROBE memory: static peak %.0f MB, video %.0f MB" % [
			float(OS.get_static_memory_peak_usage()) / 1048576.0,
			Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0])
	process_frame.disconnect(_tick)
	Records.flush()
	for path: String in kept:
		if kept[path] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			FileAccess.open(path, FileAccess.WRITE).store_string(kept[path] as String)
	quit()


func _fight(floor_n: int, names: Array, abyss: String, label: String) -> void:
	await _go_to_floor(floor_n)
	var group: Array[Enemy] = []
	var elements: Array[String] = ["ice", "dark", "fire", "thunder"]
	for i: int in names.size():
		var e: Enemy = Enemy.make_from_name(names[i] as String, floor_n)
		if abyss != "":
			Abyss.apply_variant(e, elements[i % elements.size()])
		group.append(e)
	main._launch_combat(group)
	await _wait(1.0)
	_start()
	await _wait(SECONDS)
	_report(label)
	await _end_fight(_combat_scene())


func _start() -> void:
	_times.clear()
	_recording = true


# Each frame's length in milliseconds, wall clock, while a scene is being
# measured.
var _last_us: int = 0


func _tick() -> void:
	var now: int = Time.get_ticks_usec()
	if _recording and _last_us != 0:
		_times.append(float(now - _last_us) / 1000.0)
	_last_us = now


func _report(label: String) -> void:
	_recording = false
	var t: Array[float] = _times.filter(func(x: float) -> bool: return x > 0.0)
	if t.is_empty():
		print("PROBE %s: no frames" % label)
		return
	var total: float = 0.0
	for x: float in t:
		total += x
	var sorted: Array[float] = t.duplicate()
	sorted.sort()
	var p99: float = sorted[mini(sorted.size() - 1, int(sorted.size() * 0.99))]
	print("PROBE %-8s %5d frames  avg %6.1f fps  1%% low %6.1f fps  worst %6.1f ms" % [
			label, t.size(), 1000.0 * t.size() / total, 1000.0 / p99, sorted.back()])
