extends Node


func _ready() -> void:
	call_deferred("inspect")


func inspect() -> void:
	var a = get_tree().current_scene
	var p = a.player
	a.get_node("PracticeEnemy").disabled = true
	p.respawn(Vector3.ZERO)
	p.set_physics_process(false)
	p.pivot.rotation.y = 0
	var result = {}
	for clip in ["idle", "attack_1", "attack_2", "attack_3", "heavy_release", "dodge_roll"]:
		var samples = []
		for t in [0.0, 0.08, 0.13, 0.18, 0.25, 0.35]:
			p.visual.stowed = clip in ["idle", "dodge_roll"]
			p.visual.sample(clip, t, 0, 0)
			samples.append(
				{
					"t": t,
					"base":
					p.visual.weapon.get_node("BladeBase").global_position - p.global_position,
					"tip": p.visual.weapon.get_node("BladeTip").global_position - p.global_position
				}
			)
		result[clip] = samples
	print("SWORD_PATHS ", JSON.stringify(result))
	var f = FileAccess.open("res://captures/sword_paths.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "\t"))
