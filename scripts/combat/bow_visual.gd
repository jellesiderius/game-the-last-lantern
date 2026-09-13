class_name BowVisual
extends Node3D
## Saved meshes; only transforms/materials are animated at runtime.
@onready var held_arrow: Node3D = $HeldArrow
var appearance: WeaponDefinition


func apply_appearance(value: WeaponDefinition) -> void:
	appearance = value
	appearance.tint_emissive_meshes(self)
	appearance.tint_shader($ChargePulse)
	$ChargeLight.light_color = appearance.glow_color


func present(draw_hand: Vector3, show_arrow: bool, charged: bool, pulse_time: float) -> void:
	var local_pull := to_local(draw_hand)
	_segment($StringTop, Vector3(0, .42, .13), local_pull)
	_segment($StringBottom, Vector3(0, -.42, .13), local_pull)
	held_arrow.global_position = draw_hand
	held_arrow.global_basis = global_basis.orthonormalized()
	held_arrow.visible = show_arrow
	$ChargeLight.light_energy = .25 + (.8 + .5 * sin(pulse_time * 24) if charged else 0.0)


func muzzle() -> Vector3:
	return $HeldArrow/Tip.global_position


func _segment(mesh: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var difference := to - from
	mesh.position = (from + to) * .5
	mesh.basis = Basis(Quaternion(Vector3.UP, difference.normalized()))
	mesh.scale = Vector3(1, difference.length(), 1)


func energy(draw_amount: float, release_progress: float, charged: bool) -> void:
	var burst := (1.0 - release_progress) if release_progress >= 0.0 else 0.0
	var intensity := maxf(draw_amount * .38 + (0.35 if charged else 0.0), burst)
	$ChargePulse.material_override.set_shader_parameter("intensity", intensity)
	$ChargePulse.material_override.set_shader_parameter(
		"phase", release_progress if release_progress >= 0.0 else draw_amount * .25
	)
