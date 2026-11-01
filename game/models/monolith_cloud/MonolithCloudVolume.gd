extends Node3D
## Portable opaque B-volume adapter. No file writes or consumer-specific resource paths.

var initialized := false
var body: MeshInstance3D
var height_texture: ImageTexture
var metadata: Dictionary
var bound_materials: Array[ShaderMaterial] = []
var haze := Color(0.018,0.018,0.018)

func _ready():
    set_notify_transform(true)
    var error = initialize()
    if error != OK:
        push_error("MonolithCloudVolume initialization failed: %s" % error)

func supported_transform(value: Transform3D) -> bool:
    return value.basis.is_equal_approx(value.basis.orthonormalized()) and value.basis.y.is_equal_approx(Vector3.UP) and value.basis.determinant()>0.0

func initialize() -> Error:
    if initialized:
        return OK
    if not supported_transform(global_transform):
        return ERR_INVALID_PARAMETER
    var directory = get_script().resource_path.get_base_dir()
    var parsed = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("heightfield.json")))
    if not parsed is Dictionary:
        return ERR_FILE_CORRUPT
    metadata = parsed
    var size = int(metadata.resolution)
    if not [256,512,1024].has(size):
        return ERR_FILE_CORRUPT
    var bytes = FileAccess.get_file_as_bytes(directory.path_join("heightfield.bin"))
    if bytes.size() != size*size*4:
        return ERR_FILE_CORRUPT
    var image = Image.create_from_data(size,size,false,Image.FORMAT_RGBA8,bytes)
    height_texture = ImageTexture.create_from_image(image)
    # Load the imported scene so normal Godot export remapping remains available.
    var packed = load(directory.path_join("cloud.glb")) as PackedScene
    if packed == null:
        return ERR_CANT_OPEN
    var scene = packed.instantiate()
    if scene == null:
        return ERR_FILE_CORRUPT
    var pending = [scene]
    var bodies = []
    while not pending.is_empty():
        var node = pending.pop_back()
        pending.append_array(node.get_children())
        if node is MeshInstance3D:
            bodies.append(node)
    if bodies.size() != 1:
        scene.free()
        return ERR_FILE_CORRUPT
    body = bodies[0]
    var material := ShaderMaterial.new()
    material.shader = load(directory.path_join("cloud_body.gdshader"))
    body.material_override = material
    body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(scene)
    initialized = true
    return bind_material(material)

func bind_material(material: ShaderMaterial) -> Error:
    if not initialized or material == null or material.shader == null:
        return ERR_INVALID_PARAMETER
    var names = []
    for uniform in material.shader.get_shader_uniform_list():
        names.append(String(uniform.name))
    for required in ["mcloud_surface_map","mcloud_bounds","mcloud_height_range","mcloud_world_to_local","mcloud_haze"]:
        if not names.has(required):
            return ERR_INVALID_PARAMETER
    if not bound_materials.has(material):
        bound_materials.append(material)
    sync_materials()
    return OK

func set_haze(value: Color) -> Error:
    if not is_finite(value.r) or not is_finite(value.g) or not is_finite(value.b) or min(value.r,min(value.g,value.b))<0:
        return ERR_INVALID_PARAMETER
    if haze == value:
        return OK
    haze = value
    if initialized:
        for material in bound_materials:
            material.set_shader_parameter("mcloud_haze",Vector3(haze.r,haze.g,haze.b))
    return OK

func sync_materials():
    if not supported_transform(global_transform):
        push_error("Cloud volume supports translation and yaw only; no scale or tilt")
        return
    var bounds = metadata.bounds_xz_m
    var heights = metadata.height_range_m
    for material in bound_materials:
        material.set_shader_parameter("mcloud_surface_map",height_texture)
        material.set_shader_parameter("mcloud_bounds",Vector4(bounds[0],bounds[1],bounds[2],bounds[3]))
        material.set_shader_parameter("mcloud_height_range",Vector2(heights[0],heights[1]))
        material.set_shader_parameter("mcloud_world_to_local",global_transform.affine_inverse())
        material.set_shader_parameter("mcloud_haze",Vector3(haze.r,haze.g,haze.b))

func _notification(what):
    if what == NOTIFICATION_TRANSFORM_CHANGED and initialized:
        sync_materials()
