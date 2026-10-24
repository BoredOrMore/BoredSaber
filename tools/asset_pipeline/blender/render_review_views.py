# Usage: blender --background model.blend --python render_review_views.py -- --out /tmp/review
import bpy, sys, os
args = sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
out = args[args.index('--out')+1] if '--out' in args else '//review'
out = os.path.abspath(out); os.makedirs(out, exist_ok=True)
scene = bpy.context.scene
scene.render.resolution_x, scene.render.resolution_y = 1280, 720
scene.render.resolution_percentage = 100
scene.render.image_settings.file_format = 'PNG'
for name in ['REVIEW_FRONT','REVIEW_SIDE','REVIEW_TOP','REVIEW_3Q']:
    cam = bpy.data.objects.get(name)
    if not cam or cam.type != 'CAMERA':
        print('WARNING: missing camera', name); continue
    scene.camera = cam
    scene.render.filepath = os.path.join(out, name.lower()+'.png')
    bpy.ops.render.render(write_still=True)
    print('RENDERED', scene.render.filepath)
