class_name HUDMeter
extends HBoxContainer
## Reusable segmented meter made from editable TextureProgressBar scene children.
var _shown := Vector2(-1, -1)


func display(current: float, maximum: float) -> void:
	# The HUD samples every frame; segments and tooltip only change with the values.
	if _shown == Vector2(current, maximum):
		return
	_shown = Vector2(current, maximum)
	var count := get_child_count()
	var per_segment := maximum / maxf(1, count)
	for i in count:
		var segment: TextureProgressBar = get_child(i)
		segment.value = clampf((current - i * per_segment) / maxf(.001, per_segment), 0, 1)
	tooltip_text = "%s / %s" % [str(current), str(maximum)]
