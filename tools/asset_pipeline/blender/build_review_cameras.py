# Run in Blender. Cameras assume the asset's origin is near its center; adjust targets/scales as needed.
import bpy
from mathutils import Vector

def aim(obj, target):
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat('-Z', 'Y').to_euler()

def make_camera(name, location, target=(0,0,0), ortho=True, scale=4.0):
    obj = bpy.data.objects.get(name)
    if obj and obj.type == 'CAMERA':
        obj.location = location
        aim(obj, target)
        return obj
    data = bpy.data.cameras.new(name)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = location
    data.type = 'ORTHO' if ortho else 'PERSP'
    data.ortho_scale = scale
    aim(obj, target)
    return obj

make_camera('REVIEW_FRONT', (0,-8,0), ortho=True)
make_camera('REVIEW_SIDE', (8,0,0), ortho=True)
make_camera('REVIEW_TOP', (0,0,8), ortho=True)
make_camera('REVIEW_3Q', (6,-8,5), ortho=False)
print('Review cameras ready; adjust scale and target for this asset.')
