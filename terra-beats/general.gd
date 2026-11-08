extends Node2D

var current_lane = 1
var input_cooldown = 0.0
var cooldown_time = 0.12
var superscore = 0
var score = 0.5

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
]

# FAKE ENVELOPE CHART
# Seven psychological traps.

var fake_envelope_chart = [

	# 1. Interrupted Streak
	{"beat": 11.5, "lane": 0},

	# 2. Lane-Switch Ambush
	{"beat": 17.5, "lane": 0},

	# 3. False Invitation
	{"beat": 22.0, "lane": 2},

	# 4. Premature Reward
	{"beat": 24.5, "lane": 2},

	# 5. Alternating Rhythm Trap
	{"beat": 28.5, "lane": 0},

	# 6. Distraction Before the Finish
	{"beat": 31.5, "lane": 2},

	# 7. Fake Finale
	{"beat": 39.5, "lane": 0},
	{"beat": 40.5, "lane": 2},
]

var next_envelope = 0
var next_fake_envelope = 0
var envelopes = []

var song_position = 0.0
var transitioning = false

var return_timer = 0.0
var return_delay = 0.25
var move_tween: Tween


func _ready():
	$Black.modulate.a = 1
	beat_interval = 60.0 / bpm

	if envelope_texture == null:
		print("ERROR: NO ENVELOPE TEXTURE ASSIGNED!")

	$Poobert.position.y = birdlanes[current_lane]

	update_poobert_emotion()
	update_rat_outline()


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
		spawn_fake_envelopes()
		move_envelopes()


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

	$PoobertPlayer.play(anim_name)

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

	print("Spam penalty! Score: ", score)

	update_poobert_emotion()
	update_rat_outline()


func collect_envelope(index: int):
	var note = envelopes[index]
	var envelope = note["node"]

	# FAKE ENVELOPE: PENALTY
	if note.get("fake", false):
		score = max(score - 15.0, 0.0)

		print("TRICKED! Fake envelope! Score: ", score)

		update_poobert_emotion()
		update_rat_outline()

		envelopes.remove_at(index)

		var tween = create_tween().set_parallel(true)
		tween.tween_property(envelope, "scale", Vector2(1.1, 1.1), 0.15)
		tween.tween_property(envelope, "modulate:a", 0.0, 0.15)
		tween.chain().tween_callback(envelope.queue_free)

		return

	# NORMAL ENVELOPE: REWARD
	if score >= 100:
		score = 100
		superscore += 3.0
	else:
		score = min(score + 3.0, 100.0)

	note["scored"] = true

	print("HIT! Score: ", score)

	update_poobert_emotion()
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


func update_poobert_emotion():
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
		print("ERROR: No material assigned to Rat!")
		return

	if not material is ShaderMaterial:
		print("ERROR: Rat material is not a ShaderMaterial!")
		return

	if score >= 100:
		material.set_shader_parameter("outline_color", Color("#FFD700"))
		material.set_shader_parameter("outline_width", 30.0)
	else:
		material.set_shader_parameter("outline_color", Color("ffffffff"))
		material.set_shader_parameter("outline_width", 25.0)


# NORMAL ENVELOPE SPAWNING
func spawn_envelopes():
	while next_envelope < beat_chart.size():
		var note = beat_chart[next_envelope]
		var hit_time = note["beat"] * beat_interval
		var spawn_time = hit_time - travel_time

		if song_position >= spawn_time:
			var envelope = Sprite2D.new()
			envelope.texture = envelope_texture
			envelope.scale = Vector2(0.67, 0.67)
			envelope.z_index = 10
			$Envelopes.add_child(envelope)

			var spawn_x = bird_x + (envelope_speed * travel_time)
			envelope.global_position = Vector2(spawn_x, lanes[note["lane"]])

			envelopes.append({
				"node": envelope,
				"hit_time": hit_time,
				"lane": note["lane"],
				"scored": false,
				"passed": false,
				"fake": false
			})

			next_envelope += 1
		else:
			break


# FAKE ENVELOPE SPAWNING
func spawn_fake_envelopes():
	while next_fake_envelope < fake_envelope_chart.size():
		var note = fake_envelope_chart[next_fake_envelope]
		var hit_time = note["beat"] * beat_interval
		var spawn_time = hit_time - travel_time

		if song_position >= spawn_time:
			var envelope = Sprite2D.new()
			envelope.texture = envelope_texture
			envelope.scale = Vector2(0.67, 0.67)

			# Purple tint distinguishes fake envelopes
			envelope.modulate = Color("#C05AFF")

			envelope.z_index = 10
			$Envelopes.add_child(envelope)

			var spawn_x = bird_x + (envelope_speed * travel_time)
			envelope.global_position = Vector2(spawn_x, lanes[note["lane"]])

			envelopes.append({
				"node": envelope,
				"hit_time": hit_time,
				"lane": note["lane"],
				"scored": false,
				"passed": false,
				"fake": true
			})

			next_fake_envelope += 1
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

		# Center lane only: collect all
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

					update_poobert_emotion()
					update_rat_outline()

			envelope.queue_free()
			envelopes.remove_at(i)
