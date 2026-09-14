@tool
class_name LevelChecks
extends RefCounted


static func nodes(root: Node) -> Array[Node]:
	var result: Array[Node] = [root]
	for child in root.get_children():
		result.append_array(nodes(child))
	return result


static func has_property(node: Object, name: StringName) -> bool:
	for property in node.get_property_list():
		if property.name == name:
			return true
	return false


static func ensure_enemy_ids(root: Node, claims: Dictionary) -> bool:
	var changed := false
	for node in nodes(root):
		if node == root or node.owner != root or not has_property(node, &"persistent_id"):
			continue
		if not node.get("enemy") or node.get("respawn_rule") == 0:
			continue
		var code := String(node.get("persistent_id"))
		var previous: Node = claims[code].get_ref() if claims.has(code) else null
		var origin := String(node.get_meta("identity_scene", ""))
		var copied := (
			not origin.is_empty()
			and origin != root.scene_file_path
			and FileAccess.file_exists(origin)
		)
		if (
			code.is_empty()
			or (is_instance_valid(previous) and previous != node and root.is_ancestor_of(previous))
			or copied
		):
			code = "enemy." + Crypto.new().generate_random_bytes(16).hex_encode()
			node.set("persistent_id", StringName(code))
			changed = true
		claims[code] = weakref(node)
		if not root.scene_file_path.is_empty() and origin != root.scene_file_path:
			node.set_meta("identity_scene", root.scene_file_path)
			changed = true
	return changed


static func spawn_ids(path: String) -> PackedStringArray:
	var result := PackedStringArray()
	if not ResourceLoader.exists(path, "PackedScene"):
		return result
	var root := (load(path) as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	for node in nodes(root):
		if has_property(node, &"spawn_id"):
			result.append(String(node.get("spawn_id")))
	root.free()
	return result


static func validate(root: Node) -> PackedStringArray:
	var messages := PackedStringArray()
	if not root.has_node("Player"):
		messages.append("Player ontbreekt; maak een level via Nieuw level.")
	if not root.has_node("CameraRig/Camera3D"):
		messages.append("De gameplaycamera ontbreekt.")
	var ids := {}
	var spawn_names := {}
	var destinations := {}
	for node in nodes(root):
		if node is LevelTerrain:
			messages.append_array(node.validate())
			if node.signature() != node.baked_signature:
				messages.append("%s: grond moet opnieuw worden opgeslagen/gebakken." % node.name)
		if node is ScenePortal and node.enabled:
			if node.target_scene.is_empty():
				messages.append("%s: kies een doelgebied." % node.name)
			else:
				if not destinations.has(node.target_scene):
					destinations[node.target_scene] = spawn_ids(node.target_scene)
				if not String(node.target_spawn) in destinations[node.target_scene]:
					messages.append(
						(
							"%s: aankomstpunt '%s' ontbreekt in de bestemming."
							% [node.name, node.target_spawn]
						)
					)
		if node is LevelEncounter:
			if node.enemies.is_empty():
				messages.append("%s: wijs vijanden toe aan de encounter." % node.name)
			for path in node.enemies + node.unlock_portals:
				if node.get_node_or_null(path) == null:
					messages.append("%s: ontbrekende verwijzing %s." % [node.name, path])
		if node is EnemyPatrol:
			if node.get_node_or_null(node.enemy) == null:
				messages.append("%s: wijs een enemy toe." % node.name)
		if has_property(node, &"spawn_id"):
			var code := String(node.get("spawn_id"))
			if spawn_names.has(code):
				messages.append("Dubbel aankomstpunt: " + code)
			spawn_names[code] = node
		for property in ["persistent_id", "checkpoint_id", "gate_id"]:
			if not has_property(node, property):
				continue
			var code := String(node.get(property))
			if code.is_empty():
				if property != "persistent_id" or node.get("respawn_rule") != 0:
					messages.append("%s: blijvende code ontbreekt." % node.name)
			elif ids.has(code):
				messages.append("Dubbele blijvende code: " + code)
			ids[code] = node
	return messages
