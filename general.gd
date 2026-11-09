extends Node2D

var current_lane = 1
var input_cooldown = 0.0
var cooldown_time = 0.12
var superscore = 0
var score = 21

@export var envelope_texture: Texture2D
@export var hit_window = 180.0

var bpm = 110.0
var beat_interval = 0.5
var lanes = [100, 350, 600]
var birdlanes = [20, 50, 80]
var bird_x = 235.0
var envelope_speed = 1200.0
var travel_time = 2.2
var offscreen_x = -100.0

var beat_chart = [
	{"beat": 9.5, "lane": 1},
	{"beat": 10.5, "lane": 1},
	{"beat": 12, "lane": 1},
	{"beat": 13, "lane": 1},
	{"beat": 14, "lane": 2},
	{"beat": 15, "lane": 2},
	{"beat": 16, "lane": 2},
	{"beat": 17, "lane": 2},
	{"beat": 18.5, "lane": 1},
	{"beat": 19.5, "lane": 1},
	{"beat": 20.5, "lane": 1},
	{"beat": 21.5, "lane": 1},
	{"beat": 23, "lane": 0},
	{"beat": 24, "lane": 0},
	{"beat": 25, "lane": 2},
	{"beat": 26, "lane": 2},
	{"beat": 27, "lane": 0},
	{"beat": 28, "lane": 2},
	{"beat": 29, "lane": 0},
	{"beat": 30, "lane": 2},
	{"beat": 31, "lane": 2},
	{"beat": 32, "lane": 0},
	{"beat": 33, "lane": 1},
	{"beat": 34, "lane": 0},
	{"beat": 35, "lane": 2},
	{"beat": 36, "lane": 1},
	{"beat": 37, "lane": 2},
	{"beat": 38, "lane": 0},
	{"beat": 39, "lane": 1},

	{"beat": 45, "lane": 1},
	{"beat": 46, "lane": 1},
	{"beat": 47, "lane": 1},
	{"beat": 48, "lane": 0},
	{"beat": 49, "lane": 2},
	{"beat": 50, "lane": 0},
	{"beat": 51, "lane": 2},
	{"beat": 52, "lane": 0},
	{"beat": 53, "lane": 2},
	{"beat": 54, "lane": 0},
	{"beat": 55, "lane": 0},
	{"beat": 56, "lane": 2},
	{"beat": 57, "lane": 1},
	{"beat": 58, "lane": 2},
	{"beat": 59, "lane": 0},
	{"beat": 60, "lane": 1},
	{"beat": 61, "lane": 2},
	{"beat": 62, "lane": 1},
	{"beat": 63, "lane": 0},
	{"beat": 64, "lane": 1},
	{"beat": 65, "lane": 0},
	{"beat": 66, "lane": 1},
	{"beat": 67, "lane": 0},
	{"beat": 68, "lane": 2},
	{"beat": 69, "lane": 0},
	{"beat": 70, "lane": 1},
	{"beat": 71, "lane": 0},
	{"beat": 72, "lane": 2},
	{"beat": 73, "lane": 1},
	{"beat": 74, "lane": 0}
]

var next_envelope = 0
var envelopes = []

var fake_note_indices = {}
var fake_percentage = 0.20

var fake_colors = [
	Color("#C05AFF"),
	Color("#A855F7"),
	Color("#D946EF"),
	Color("#9333EA"),
	Color("#E879F9")
]

var song_position = 0.0
var transitioning = false
var sliding = true

var return_timer = 0.0
var return_delay = 0.25
var move_tween: Tween


func _ready():
	$Black.modulate.a = 1
	beat_interval = 60.0 / bpm

	randomize()
	generate_fake_envelopes()

	if envelope_texture == null:
		print("no envelope texture assigned")

	$Poobert.position.y = birdlanes[current_lane]

	update_emotion()
	update_rat_outline()


func generate_fake_envelopes():
	fake_note_indices.clear()

	var eligible_indices = []

	for i in range(beat_chart.size()):
		if beat_chart[i]["lane"] != 1:
			eligible_indices.append(i)

	eligible_indices.shuffle()

	var fake_count = int(round(beat_chart.size() * fake_percentage))
	fake_count = min(fake_count, eligible_indices.size())

	for i in range(fake_count):
		fake_note_indices[eligible_indices[i]] = true

	print("fake envelopes this run: ", fake_count, "/", beat_chart.size())

func _input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not transitioning:
		transitioning = true
		$AnimationPlayer.play("fade_out")
		$AnimationPlayer2.play("slideup")
		$AudioStreamPlayer.play()
		$PoobertPlayer.play("slidein")

	if not $AudioStreamPlayer.playing:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_UP or event.keycode == KEY_W:
			try_move_up()
		elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
			try_move_down()


func try_move_up():
	if input_cooldown > 0:
		return

	if current_lane > 0:
		change_lane(current_lane - 1, "up")
	else:
		input_cooldown = cooldown_time
		var collected = try_collect_one()
		if not collected:
			apply_spam_penalty()


func try_move_down():
	if input_cooldown > 0:
		return

	if current_lane < 2:
		change_lane(current_lane + 1, "down")
	else:
		input_cooldown = cooldown_time
		var collected = try_collect_one()
		if not collected:
			apply_spam_penalty()


func _process(delta: float):
	if input_cooldown > 0:
		input_cooldown -= delta

	if current_lane != 1:
		return_timer += delta
		if return_timer >= return_delay:
			return_to_middle()
	else:
		return_timer = 0.0

	if $AudioStreamPlayer.playing:
		update_music_clock()
		spawn_envelopes()
		move_envelopes()
		print(song_position)

		if floor(song_position) > 20 and sliding:
			$PoobertPlayer.play("slidein_2")
			sliding = false

		if floor(song_position) > 40 and not sliding:
			$PoobertPlayer.play("finish")
			sliding = true

		if song_position > 43 and sliding:
			$AudioStreamPlayer2D.play()
			await get_tree().create_timer(6.5).timeout

			if score > 50:
				$TADA.play()
				$Blargh.play("happy")
				$Blargh.play("sad")
				$Blargh.play("happy")
				$Blargh.play("sad")
				$Blargh.play("happy")
			else:
				$LMAO.play()
				$Blargh.play("sad")
				$Blargh.play("happy")
				$Blargh.play("sad")
				$Blargh.play("happy")
				$Blargh.play("sad")


func change_lane(new_lane: int, anim_name: String):
	current_lane = new_lane
	return_timer = 0.0
	input_cooldown = cooldown_time

	if move_tween:
		move_tween.kill()

	move_tween = create_tween()
	move_tween.set_trans(Tween.TRANS_SINE)
	move_tween.set_ease(Tween.EASE_OUT)
	move_tween.tween_property($Poobert, "position:y", birdlanes[current_lane], 0.12)

	if current_lane != 1:
		var collected = try_collect_one()
		if not collected:
			apply_spam_penalty()


func try_collect_one() -> bool:
	var best_index = -1
	var best_x = 99999.0

	for i in range(envelopes.size()):
		var note = envelopes[i]

		if note["scored"] or note["passed"]:
			continue

		if note["lane"] != current_lane:
			continue

		var time_offset = song_position - note["hit_time"]
		var current_x = bird_x - (time_offset * envelope_speed)

		if abs(current_x - bird_x) > hit_window:
			continue

		if current_x < best_x:
			best_x = current_x
			best_index = i

	if best_index != -1:
		collect_envelope(best_index)
		return true

	return false


func apply_spam_penalty():
	score = max(score - 15.0, 0.0)

	print("Spiced ham penalty! Score: ", score)

	update_emotion()
	update_rat_outline()


func collect_envelope(index: int):
	var note = envelopes[index]
	var envelope = note["node"]

	if note.get("fake", false):
		score = max(score - 15.0, 0.0)

		print("LMAOOOO! Fake envelope! Score: ", score)

		update_emotion()
		update_rat_outline()

		envelopes.remove_at(index)

		var tween = create_tween().set_parallel(true)
		tween.tween_property(envelope, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(envelope, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(envelope.queue_free)

		return

	if score >= 100:
		score = 100
		superscore += 3.0
	else:
		score = min(score + 3.0, 100.0)

	note["scored"] = true

	print("HIT! Score: ", score)

	update_emotion()
	update_rat_outline()

	var tween = create_tween().set_parallel(true)
	tween.tween_property(envelope, "scale", Vector2(1.1, 1.1), 0.15)
	tween.tween_property(envelope, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(envelope.queue_free)

	envelopes.remove_at(index)


func return_to_middle():
	if current_lane == 1:
		return

	change_lane(1, "down" if current_lane == 0 else "up")

func update_music_clock():
	song_position = $AudioStreamPlayer.get_playback_position()


func update_emotion():
	var emotion = ""

	if score < 20:
		emotion = "below20"
	elif score < 40:
		emotion = "20-40"
	elif score < 60:
		emotion = "40-60"
	elif score < 80:
		emotion = "60-80"
	else:
		emotion = "above80"

	if $Rat.animation != emotion:
		$Rat.play(emotion)


func update_rat_outline():
	var material = $Rat.material

	if material == null:
		print("ERROR: No material assigned to ratty")
		return

	if not material is ShaderMaterial:
		print("ERROR: Rat material is not a ShaderMaterial")
		return

	if score >= 100:
		material.set_shader_parameter("outline_color", Color("#FFD700"))
		material.set_shader_parameter("outline_width", 30.0)
	if score <= 20:
		material.set_shader_parameter("outline_color", Color("ff0000ff"))
		material.set_shader_parameter("outline_width", 30.0)
	else:
		material.set_shader_parameter("outline_color", Color("ffffffff"))
		material.set_shader_parameter("outline_width", 25.0)


func spawn_envelopes():
	while next_envelope < beat_chart.size():
		var note = beat_chart[next_envelope]
		var hit_time = note["beat"] * beat_interval
		var spawn_time = hit_time - travel_time

		if song_position >= spawn_time:
			var is_fake = fake_note_indices.has(next_envelope)

			var envelope = Sprite2D.new()
			envelope.texture = envelope_texture
			envelope.scale = Vector2(0.67, 0.67)
			envelope.z_index = 10

			if is_fake:
				envelope.modulate = fake_colors[randi() % fake_colors.size()]
				envelope.rotation_degrees = randf_range(-8.0, 8.0)
			else:
				envelope.modulate = Color.WHITE

			$Envelopes.add_child(envelope)

			var spawn_x = bird_x + (envelope_speed * travel_time)
			envelope.global_position = Vector2(spawn_x, lanes[note["lane"]])

			envelopes.append({
				"node": envelope,
				"hit_time": hit_time,
				"lane": note["lane"],
				"scored": false,
				"passed": false,
				"fake": is_fake
			})

			next_envelope += 1
		else:
			break


func move_envelopes():
	for i in range(envelopes.size() - 1, -1, -1):
		var note = envelopes[i]
		var envelope = note["node"]
		var time_offset = song_position - note["hit_time"]
		var current_x = bird_x - (time_offset * envelope_speed)
		if not note["scored"]:
			envelope.global_position = Vector2(current_x, lanes[note["lane"]])
		if current_lane == 1 and not note["scored"] and not note["passed"]:
			if abs(current_x - bird_x) <= hit_window and note["lane"] == 1:
				collect_envelope(i)
				continue
		if not note["scored"] and not note["passed"]:
			if current_x < (bird_x - hit_window):
				note["passed"] = true

		if current_x < offscreen_x:
			if not note["scored"]:
				if not note.get("fake", false):
					score = max(score - 15.0, 0.0)
					print("MISS! Score: ", score)

					update_emotion()
					update_rat_outline()

			envelope.queue_free()
			envelopes.remove_at(i)
