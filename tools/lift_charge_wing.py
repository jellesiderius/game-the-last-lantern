"""Keep the relaxed wing tip above the floor in the crouched heavy-charge pose."""
import bpy
from mathutils import Quaternion
r=bpy.data.objects['Crow_Rig'];s=bpy.context.scene
for name in ['heavy_charge','heavy_hold']:
    a=bpy.data.actions[name];r.animation_data.action=a
    correction=.11-float(a.get('charge_wing_lift',0))
    end=round(a.frame_range[1])
    for f in range(end+1):
        s.frame_set(f)
        k=(f/max(1,end)) if name=='heavy_charge' else 1
        b=r.pose.bones['wing_L'];basis=b.bone.matrix_local.to_quaternion()
        b.rotation_quaternion=basis.inverted()@Quaternion((0,1,0),correction*k)@basis@b.rotation_quaternion
        b.keyframe_insert('rotation_quaternion',frame=f,group=b.name)
    a['charge_wing_lift']=.11
r.animation_data.action=bpy.data.actions['idle'];s.frame_set(0)
bpy.ops.wm.save_as_mainfile(filepath='/Users/jelle/Godot-Projects/crow-test/assets/characters/crow/source.blend')
result={'adjusted':['heavy_charge','heavy_hold'],'wing_lift_radians':.11}
