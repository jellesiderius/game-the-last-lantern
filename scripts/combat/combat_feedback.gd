class_name CombatFeedback
extends Node
## Presentation consumes the player's action clock; it never starts attacks or damage.
@onready var player: PlayerCharacter = get_parent()
@onready var slash: MeshInstance3D = player.get_node("VisualPivot/ForwardSlash")
@onready var charge: MeshInstance3D = player.get_node("VisualPivot/ChargeAura")
@onready var burst: MeshInstance3D = player.get_node("VisualPivot/HeavyBurst")
var heavy_impact_played := false


func configure(palette: WeaponDefinition) -> void:
	charge.material_override.set_shader_parameter("charging", true)
	for effect in [slash, charge, burst]:
		effect.material_override.set_shader_parameter("slash_color", palette.slash_color)
		effect.material_override.set_shader_parameter("hot_color", palette.hot_color())


func clear() -> void:
	heavy_impact_played = false
	slash.hide()
	charge.hide()
	burst.hide()


func sample(active_started: bool) -> void:
	var powerful := player.state == "heavy_attack" and player.charge_amount >= .999
	charge.visible = player.state == "charge"
	charge.material_override.set_shader_parameter("progress", player.charge_amount)
	player.visual.weapon.set_charge(
		player.charge_amount if player.state == "charge" else (1.0 if powerful else 0.0)
	)
	slash.hide()
	burst.hide()
	if not player.is_attack():
		return
	var attack := player.moveset.find(player.clip)
	var phase := (player.action_time - attack.windup) / attack.active_duration
	if active_started:
		var sound: AudioStreamPlayer3D = player.get_node("SwingSound")
		sound.pitch_scale = (
			.68
			if powerful
			else (.85 if player.state == "heavy_attack" else .93 + player.combo_step * .06)
		)
		sound.volume_db = -5.0 if powerful else -9.0
		sound.play()
	if powerful and phase >= .50 and not heavy_impact_played:
		heavy_impact_played = true
		player.get_node("HeavySound").play()
		InputRouter.feedback(.25, .32, .11)
	# A short fading tail continues into recovery; only the leading edge during the
	# active window deals damage. The weapon owns that head's angle and radius.
	# Energy weapons draw the short history of their real blade in MeleeWeapon.
	# The legacy planar effect remains available to physical-only weapon profiles.
	slash.visible = player.visual.weapon.energy_radius() <= 0.0 and phase >= 0.0 and phase < 1.55
	if slash.visible:
		var weapon: MeleeWeapon = player.visual.weapon
		var energy := weapon.energy_radius() > 0.0
		var direction := (
			weapon.swing_direction if energy else (1.0 if player.clip == "attack_2" else -1.0)
		)
		slash.basis = weapon.swing_basis if energy else Basis.IDENTITY
		slash.position.y = weapon.energy_height() if energy else .5
		var tip := (
			player.pivot.to_local(player.visual.weapon.get_node("BladeTip").global_position)
			- slash.position
		)
		slash.material_override.set_shader_parameter("progress", phase)
		slash.material_override.set_shader_parameter("direction", direction)
		slash.material_override.set_shader_parameter(
			"blade_angle", weapon.energy_angle(phase) if energy else atan2(tip.x, -tip.z)
		)
		slash.material_override.set_shader_parameter(
			"radius", weapon.energy_radius() if energy else 1.5
		)
		slash.material_override.set_shader_parameter("energy_extension", 1.0 if energy else 0.0)
		slash.material_override.set_shader_parameter("half_angle", weapon.swing_half_angle)
		slash.material_override.set_shader_parameter("width_scale", weapon.swing_width)
		slash.material_override.set_shader_parameter("power", 1.0 if powerful else 0.0)
	# The floor wake is cosmetic; the weapon owns physical and visible energy sweeps.
	burst.visible = powerful and phase >= .50 and phase < 2.0
	if burst.visible:
		burst.material_override.set_shader_parameter("progress", (phase - .50) / 1.5)
		burst.material_override.set_shader_parameter(
			"impact_radius", maxf(1.5, player.visual.weapon.energy_radius())
		)
