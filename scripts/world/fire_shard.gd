class_name FireShard
extends Interactable
## Saved shard pile that holds fireshards until the player comes close enough to pull it in.
## Fireshards owns the amounts; this node presents one pile and reports the absorption.
signal absorbed(amount: int)
## A freshly dropped pile first surfaces and swells, then flies into the character.
const SPAWN_HOLD := .3
const RISE_DURATION := .22
const FLY_DURATION := .5
var entry_id := ""
var amount := 0
var kind := "enemy"
var absorbing := false
## A pile from the player's own death does not bind to a body that is already standing on
## it: after a respawn on top of your loss you first step clear and walk back into it.
var armed := true
var age := 0.0
var absorb_time := 0.0
var drift_time := 0.0
var absorb_from := Vector3.ZERO
@onready var visual: Node3D = $Visual
@onready var core: MeshInstance3D = $Visual/Core
@onready var light: OmniLight3D = $Visual/Light


func _ready() -> void:
	super._ready()
	$PickupZone/Shape.shape = $PickupZone/Shape.shape.duplicate()
	$PickupZone/Shape.shape.radius = interaction_radius
	$PickupZone.body_entered.connect(_on_body_entered)


## Called by Fireshards right after the scene is added; the values come from the save.
func place(entry: Dictionary) -> void:
	entry_id = String(entry.get("id", ""))
	amount = maxi(0, int(entry.get("amount", 0)))
	kind = String(entry.get("kind", "enemy"))
	armed = kind != Fireshards.KIND_LOST
	var position: Array = entry.get("position", [])
	if position.size() == 3:
		global_position = Vector3(float(position[0]), float(position[1]), float(position[2]))
	# The player's own loss reads paler than the amber shards an enemy leaves behind.
	light.light_color = Color(1, .82, .48) if kind == Fireshards.KIND_LOST else Color(1, .72, .3)
	drift_time = randf() * TAU
	$Visual/Fireflies.seed = randi()


func can_interact(actor: Node3D) -> bool:
	return armed and not absorbing and super.can_interact(actor) and can_be_absorbed_by(actor)


func interact(actor: Node3D) -> void:
	if can_be_absorbed_by(actor):
		collect()


func collect() -> void:
	if absorbing:
		return
	var absorbed_amount := Fireshards.absorb(entry_id)
	if absorbed_amount <= 0:
		queue_free()
		return
	absorbing = true
	absorb_time = 0.0
	absorb_from = visual.position
	enabled = false
	# Leaving/entering a signal callback cannot toggle monitoring directly.
	$PickupZone.set_deferred("monitoring", false)
	absorbed.emit(absorbed_amount)


func _physics_process(_delta: float) -> void:
	var step := GameClock.dt
	if step <= 0.0:
		return
	if absorbing:
		_absorb(step)
		return
	age += step
	drift_time += step
	visual.position.y = .16 + sin(drift_time * 2.1) * .07
	# A slow breathing glow reads as fireflies instead of a beacon across the level.
	core.scale = Vector3.ONE * (1.0 + sin(drift_time * 1.7) * .16)
	light.light_energy = .32 + sin(drift_time * 1.7) * .1
	if not armed:
		if not body_reached():
			armed = true
		return
	# A pile that surfaces under a standing player is picked up once it has shown itself.
	if age >= SPAWN_HOLD and body_reached():
		collect()


## Two beats: the pile rises out of the ground, then it streams into the character.
func _absorb(step: float) -> void:
	absorb_time += step
	if absorb_time < RISE_DURATION:
		var rise := absorb_time / RISE_DURATION
		visual.position = absorb_from + Vector3.UP * (.4 * rise)
		visual.scale = Vector3.ONE * (1.0 + .45 * rise)
		light.light_energy = .4 + rise * 1.4
		return
	var flight := (absorb_time - RISE_DURATION) / FLY_DURATION
	if flight >= 1.0:
		queue_free()
		return
	var origin := absorb_from + Vector3.UP * .4
	visual.position = origin.lerp(absorb_target(), flight * flight)
	visual.scale = Vector3.ONE * (1.45 - flight * 1.45)
	visual.rotation.y += step * 7.0
	light.light_energy = 1.8 - flight * 1.7


func _on_body_entered(body: Node3D) -> void:
	if armed and age >= SPAWN_HOLD and can_be_absorbed_by(body):
		collect()


func body_reached() -> bool:
	for body in $PickupZone.get_overlapping_bodies():
		if can_be_absorbed_by(body):
			return true
	return false


## A dead player neither walks into shards nor pulls them in from the death pose.
func can_be_absorbed_by(actor: Node3D) -> bool:
	return actor.is_in_group("player") and String(actor.get("state")) != "dead"


func absorb_target() -> Vector3:
	var player := GameSession.player
	if not is_instance_valid(player):
		return absorb_from
	return to_local(player.global_position + Vector3.UP * .55)
