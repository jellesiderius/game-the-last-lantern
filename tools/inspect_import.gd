extends SceneTree
func _initialize():
	var model = load('res://assets/characters/crow/model.glb').instantiate()
	root.add_child(model)
	model.print_tree_pretty()
	var anim = model.find_children('*', 'AnimationPlayer', true, false)[0]
	var clips = {}
	for n in anim.get_animation_list():
		clips[n] = anim.get_animation(n).length
	print('CLIPS ', JSON.stringify(clips))
	var sk = model.find_children('*','Skeleton3D',true,false)[0]
	print('SOCKET ', sk.get_bone_global_rest(sk.find_bone('sword_socket')))
	quit()
