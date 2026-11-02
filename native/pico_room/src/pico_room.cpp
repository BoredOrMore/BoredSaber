#include "pico_room.h"

#include <godot_cpp/classes/open_xrapi_extension.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/transform3d.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <cstring>

using namespace godot;

// Most anchors to load: a room has a floor, a ceiling, a few walls, doors, windows and furniture boxes.
static const uint32_t MAX_ANCHORS = 64;
// Load timeout handed to the runtime (unit undocumented).
static const uint64_t LOAD_TIMEOUT = 5000;
// PxrPersistLocation.Local: anchors saved on the headset.
static const uint32_t LOCATION_LOCAL = 1;
// The loaded event's type.
static const uint32_t TYPE_EVENT_ANCHOR_ENTITY_LOADED = 1200006350;
// The spatial scene filter (type 1200006362 from the runtime's code) with every surface kind (PICO's Unity SDK flags:
// unknown, floor, ceiling, wall, door, window, opening, object).
static const uint32_t TYPE_SPATIAL_SCENE_FILTER = 1200006362;
static const uint64_t ALL_SCENE_TYPES = 0xFF;
// PICO refused to switch to its scene capture when asked the moment the session got focus (710b57e log:
// checkAppSwitchAllowed false) and allowed it 3 s later (9dd67b0). So ask once the app has had focus this long, and
// ask again if focus hasn't gone to the capture this long after, up to CAPTURE_TRIES times (frames at 72 Hz).
static const int CAPTURE_DELAY_FRAMES = 72 * 3;
static const int CAPTURE_CHECK_FRAMES = 72 * 5;
static const int CAPTURE_TRIES = 6;
// A load right after the capture can still find nothing while the headset settles: try this many times, this many
// frames apart, before telling the game the room wasn't found.
static const int LOAD_TRIES = 3;
static const int LOAD_RETRY_FRAMES = 72 * 3;
// After a recenter, wait this long (half a second) before reading the room so the runtime has moved the play space.
static const int RELOAD_DELAY_FRAMES = 36;
// 64-bit words in each buffer handed to a getter. Bigger than any struct the runtime writes, so a runtime that writes
// a larger struct than measured stays inside it.
static const int SCRATCH_WORDS = 64;
// One result entry as the runtime writes it: OpenXR-style header (type, next), the anchor id at +0x10, then the
// 16-byte UUID: 40 bytes, five 64-bit words.
static const int RESULT_STRIDE_WORDS = 5;
static const int RESULT_ANCHOR_WORD = 2;
// Float indices in the plane and box structs (8a75f76 log): centre at 4-6, then the plane's width and height at 7-8,
// or the box's extent at 7-9.
static const int SHAPE_CENTER_FLOAT = 4;
static const int SHAPE_SIZE_FLOAT = 7;
// The anchor id's place in xrCreateAnchorSpaceBD's info (64-bit word 2, +0x10).
static const int SPACE_INFO_ANCHOR_WORD = 2;
// What the plane getter returns for an anchor without a plane (a furniture box).
static const XrResult RESULT_NO_COMPONENT = (XrResult)-503;

/// Resolves one runtime function by name, or returns nullptr when the runtime lacks it.
template <typename T>
static T resolve(const Ref<OpenXRAPIExtension> &p_api, const char *p_name) {
	T function = (T)p_api->get_instance_proc_addr(p_name);
	if (function == nullptr) {
		UtilityFunctions::print("PicoRoom: runtime lacks ", p_name);
	}
	return function;
}

void PicoRoom::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_supported"), &PicoRoom::is_supported);
	ClassDB::bind_method(D_METHOD("scan_room"), &PicoRoom::scan_room);
	ClassDB::bind_method(D_METHOD("reload_room"), &PicoRoom::reload_room);
	// Each piece: {"label": int (1 floor, 2 ceiling, 3 wall, 4 door, 5 window, 6 opening, 7 furniture),
	// "transform": Transform3D of its centre in the play space (XROrigin3D's space), "size": Vector3}. A plane lies in
	// its local XY (size x, y, z = 0) with local +Z pointing out of the room; a box's local Z is vertical.
	ADD_SIGNAL(MethodInfo("room_loaded", PropertyInfo(Variant::ARRAY, "pieces")));
	ADD_SIGNAL(MethodInfo("room_not_found"));
}

Dictionary PicoRoom::_get_requested_extensions() {
	Dictionary requested;
	requested["XR_BD_spatial_scene"] = (uint64_t)&spatial_scene;
	requested["XR_BD_room_scene"] = (uint64_t)&room_scene;
	requested["XR_BD_semi_auto_room_capture"] = (uint64_t)&semi_auto_room_capture;
	requested["XR_BD_spatial_anchor"] = (uint64_t)&spatial_anchor;
	requested["XR_BD_anchor_entity"] = (uint64_t)&anchor_entity;
	requested["XR_BD_anchor_entity_persistence"] = (uint64_t)&anchor_entity_persistence;
	requested["XR_BD_mr_management"] = (uint64_t)&mr_management;
	requested["XR_BD_async_task"] = (uint64_t)&async_task;
	return requested;
}

void PicoRoom::_on_instance_created(uint64_t p_instance) {
	if (!anchor_entity || !spatial_scene) {
		UtilityFunctions::print("PicoRoom: runtime has no PICO scene extensions");
		return;
	}
	Ref<OpenXRAPIExtension> api = get_openxr_api();
	if (api.is_null()) {
		UtilityFunctions::push_error("PicoRoom: no OpenXR API");
		return;
	}
	load_anchor_entity = resolve<LoadAnchorEntity>(api, "xrLoadAnchorEntityBD");
	get_load_results = resolve<GetAnchorEntityLoadResults>(api, "xrGetAnchorEntityLoadResultsBD");
	get_scene_label = resolve<GetAnchorValue>(api, "xrGetAnchorSceneLabelBD");
	get_plane_boundary = resolve<GetAnchorValue>(api, "xrGetAnchorPlaneBoundaryInfoBD");
	get_box = resolve<GetAnchorValue>(api, "xrGetAnchorBoxInfoBD");
	create_anchor_space = resolve<CreateAnchorSpace>(api, "xrCreateAnchorSpaceBD");
	locate_space = resolve<PFN_xrLocateSpace>(api, "xrLocateSpace");
	destroy_space = resolve<PFN_xrDestroySpace>(api, "xrDestroySpace");
	start_scene_capture = resolve<StartSpatialSceneCapture>(api, "xrStartSpatialSceneCaptureBD");
}

void PicoRoom::_on_session_created(uint64_t p_session) {
	session = (XrSession)p_session;
}

bool PicoRoom::is_supported() const {
	return load_anchor_entity != nullptr && get_load_results != nullptr && get_scene_label != nullptr &&
			get_plane_boundary != nullptr && get_box != nullptr && create_anchor_space != nullptr &&
			locate_space != nullptr && destroy_space != nullptr && start_scene_capture != nullptr;
}

void PicoRoom::scan_room() {
	if (!is_supported() || session == XR_NULL_HANDLE) {
		call_deferred("emit_signal", "room_not_found");
		return;
	}
	if (scanning) {
		return;
	}
	scanning = true;
	capture_asked = false;
	capture_opened = false;
	capture_tries = 0;
	capture_frames = 0;
	loading = false;
}

void PicoRoom::reload_room() {
	if (!is_supported() || session == XR_NULL_HANDLE) {
		call_deferred("emit_signal", "room_not_found");
		return;
	}
	if (scanning) {
		return;
	}
	scanning = true;
	capture_opened = false;
	loading = true;
	load_tries = 0;
	load_frames = LOAD_RETRY_FRAMES - RELOAD_DELAY_FRAMES;
}

void PicoRoom::_on_state_focused() {
	focused = true;
	if (scanning && capture_opened) {
		// Back from PICO's scene capture: the room should be recognised now.
		capture_opened = false;
		load_tries = 0;
		loading = true;
		_start_load();
	}
}

void PicoRoom::_on_state_visible() {
	focused = false;
	if (scanning && capture_asked) {
		capture_opened = true;
	}
}

void PicoRoom::_on_process() {
	if (!scanning || !focused || task_id != 0) {
		return;
	}
	if (loading) {
		load_frames++;
		if (load_frames >= LOAD_RETRY_FRAMES) {
			_start_load();
		}
		return;
	}
	capture_frames++;
	if (capture_frames < (capture_asked ? CAPTURE_CHECK_FRAMES : CAPTURE_DELAY_FRAMES)) {
		return;
	}
	capture_frames = 0;
	if (capture_tries == CAPTURE_TRIES) {
		// PICO never opened its capture; the headset may still know the room, so try loading it anyway.
		UtilityFunctions::print("PicoRoom: the scene capture never opened, loading anyway");
		load_tries = 0;
		loading = true;
		_start_load();
		return;
	}
	capture_tries++;
	_start_capture();
}

void PicoRoom::_start_capture() {
	uint64_t info[SCRATCH_WORDS] = {};
	uint64_t task = 0;
	XrResult result = start_scene_capture(session, info, &task);
	capture_asked = capture_asked || XR_SUCCEEDED(result);
	UtilityFunctions::print("PicoRoom: asked for the scene capture, try ", capture_tries, ", result ", (int64_t)result);
}

void PicoRoom::_start_load() {
	load_frames = 0;
	load_tries++;
	PicoAnchorEntityLoadFilter filter = { TYPE_SPATIAL_SCENE_FILTER, nullptr, ALL_SCENE_TYPES };
	PicoAnchorEntityLoadInfo info = { 0, nullptr, MAX_ANCHORS, LOAD_TIMEOUT, LOCATION_LOCAL, &filter };
	uint64_t task = 0;
	XrResult result = load_anchor_entity(session, &info, &task);
	if (XR_FAILED(result)) {
		UtilityFunctions::print("PicoRoom: load failed ", (int64_t)result);
		_not_found();
		return;
	}
	task_id = task;
}

bool PicoRoom::_on_event_polled(const void *p_event) {
	const XrEventDataBaseHeader *header = (const XrEventDataBaseHeader *)p_event;
	if ((uint32_t)header->type != TYPE_EVENT_ANCHOR_ENTITY_LOADED) {
		return false;
	}
	const PicoEventAnchorEntityLoaded *loaded = (const PicoEventAnchorEntityLoaded *)p_event;
	if (task_id == 0 || loaded->task_id != task_id) {
		return false;
	}
	task_id = 0;
	UtilityFunctions::print("PicoRoom: load ", load_tries, " found ", (int64_t)loaded->total);
	if (loaded->result == XR_SUCCESS && loaded->total > 0) {
		_read_results(loaded->task_id);
	} else if (load_tries >= LOAD_TRIES) {
		_not_found();
	}
	return true;
}

void PicoRoom::_read_results(uint64_t p_task) {
	// The results struct as the runtime fills it: OpenXR-style header, u32 capacity at +0x10, u32 count written at
	// +0x14, entries pointer at +0x18.
	static uint64_t entries[MAX_ANCHORS * RESULT_STRIDE_WORDS];
	uint64_t buffer[SCRATCH_WORDS];
	memset(entries, 0, sizeof(entries));
	memset(buffer, 0, sizeof(buffer));
	buffer[2] = MAX_ANCHORS;
	buffer[3] = (uint64_t)entries;
	XrResult result = get_load_results(session, p_task, buffer);
	uint32_t count = (uint32_t)(buffer[2] >> 32);
	if (XR_FAILED(result) || count == 0) {
		UtilityFunctions::print("PicoRoom: results failed ", (int64_t)result);
		_not_found();
		return;
	}
	Array pieces;
	for (uint32_t i = 0; i < count && i < MAX_ANCHORS; i++) {
		Dictionary piece = _read_piece(entries[i * RESULT_STRIDE_WORDS + RESULT_ANCHOR_WORD]);
		if (!piece.is_empty()) {
			pieces.append(piece);
		}
	}
	scanning = false;
	loading = false;
	UtilityFunctions::print("PicoRoom: room has ", pieces.size(), " pieces");
	call_deferred("emit_signal", "room_loaded", pieces);
}

Dictionary PicoRoom::_read_piece(uint64_t p_anchor) {
	Ref<OpenXRAPIExtension> api = get_openxr_api();
	uint64_t label[SCRATCH_WORDS] = {};
	uint64_t info[SCRATCH_WORDS] = {};
	info[SPACE_INFO_ANCHOR_WORD] = p_anchor;
	XrSpace space = XR_NULL_HANDLE;
	if (XR_FAILED(get_scene_label(session, p_anchor, label)) ||
			XR_FAILED(create_anchor_space(session, info, &space))) {
		return Dictionary();
	}
	XrSpaceLocation location = { XR_TYPE_SPACE_LOCATION };
	XrResult located = locate_space(space, (XrSpace)api->get_play_space(),
			(XrTime)api->get_predicted_display_time(), &location);
	destroy_space(space);
	const XrSpaceLocationFlags valid = XR_SPACE_LOCATION_POSITION_VALID_BIT | XR_SPACE_LOCATION_ORIENTATION_VALID_BIT;
	if (XR_FAILED(located) || (location.locationFlags & valid) != valid) {
		return Dictionary();
	}
	const XrPosef &pose = location.pose;
	Transform3D transform(Basis(Quaternion(pose.orientation.x, pose.orientation.y, pose.orientation.z,
								  pose.orientation.w)),
			Vector3(pose.position.x, pose.position.y, pose.position.z));

	uint64_t shape[SCRATCH_WORDS] = {};
	const float *floats = (const float *)shape;
	Vector3 center;
	Vector3 size;
	XrResult plane = get_plane_boundary(session, p_anchor, shape);
	if (XR_SUCCEEDED(plane)) {
		center = Vector3(floats[SHAPE_CENTER_FLOAT], floats[SHAPE_CENTER_FLOAT + 1], floats[SHAPE_CENTER_FLOAT + 2]);
		size = Vector3(floats[SHAPE_SIZE_FLOAT], floats[SHAPE_SIZE_FLOAT + 1], 0.0);
	} else if (plane == RESULT_NO_COMPONENT && XR_SUCCEEDED(get_box(session, p_anchor, shape))) {
		// Measured (9dd67b0): a box's pose sits on its top face with local +Z pointing down, and its bottom lands on
		// the floor (0.711 - 0.78 = -0.069, the floor's y), so its centre is half the height along +Z; the runtime
		// reports that offset with the opposite sign.
		center = Vector3(floats[SHAPE_CENTER_FLOAT], floats[SHAPE_CENTER_FLOAT + 1], -floats[SHAPE_CENTER_FLOAT + 2]);
		size = Vector3(floats[SHAPE_SIZE_FLOAT], floats[SHAPE_SIZE_FLOAT + 1], floats[SHAPE_SIZE_FLOAT + 2]);
	} else {
		return Dictionary();
	}
	Dictionary piece;
	piece["label"] = (int64_t)(label[0] & 0xFFFFFFFF);
	piece["transform"] = transform.translated_local(center);
	piece["size"] = size;
	return piece;
}

void PicoRoom::_not_found() {
	scanning = false;
	loading = false;
	call_deferred("emit_signal", "room_not_found");
}
