// Test probe for the room-aware Mixed Reality plan (not for merging): logs the OpenXR extensions the headset's runtime
// offers, then tries to read the room the player scanned in PICO's own room setup through PICO's private anchor entity
// API (XR_BD_anchor_entity) and logs every wall, floor and ceiling it finds. Tag "PicoRoom:" in logcat.
#pragma once

#include <openxr/openxr.h>

#include <godot_cpp/classes/open_xr_extension_wrapper_extension.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <cstdint>

// PICO's private room types. PICO publishes no C header for them: the layouts follow the C# declarations in PICO's
// Unity SDK (Runtime/Scripts/PXR_Plugin.cs) and the names follow the function list in the runtime's library.
struct PxrUuid {
	uint64_t value0;
	uint64_t value1;
};

struct PxrAnchorEntityLoadInfo {
	uint32_t max_result;
	uint64_t timeout;
	int32_t location; // 1 = saved on the headset.
	const void *include; // Optional filter, nullptr loads everything.
	const void *exclude;
};

// Filter by scene label (PxrAnchorEntityLoadSpatialSceneFilter). The runtime reads the include filter without a null
// check (build cbe237d crashed at address 0x4 with include = nullptr), so one is always passed.
struct PxrAnchorEntityLoadSpatialSceneFilter {
	int32_t type; // PXR_TYPE_ANCHOR_ENTITY_LOAD_SPATIAL_SCENE_FILTER.
	uint64_t type_flags; // PxrSpatialSceneDataTypeFlags: floor, ceiling, wall, door, window, opening, object.
};

struct PxrAnchorEntityLoadResult {
	uint64_t anchor; // The runtime destroys it with xrDestroySpace, so it is an XrSpace.
	PxrUuid uuid;
};

struct PxrAnchorEntityLoadResults {
	uint32_t input_count;
	uint32_t output_count;
	PxrAnchorEntityLoadResult *results;
};

struct PxrAnchorPlaneBoundaryInfo {
	float center[3];
	float width;
	float height;
};

struct PxrAnchorVolumeInfo {
	float center[3];
	float extent[3];
};

class PicoRoomProbe : public godot::OpenXRExtensionWrapperExtension {
	GDCLASS(PicoRoomProbe, godot::OpenXRExtensionWrapperExtension);

public:
	/// Returns PICO's room and anchor extensions, each with the flag Godot sets when the runtime has it.
	godot::Dictionary _get_requested_extensions() override;
	/// Logs the runtime's extension list, which room extensions got enabled and which room functions resolve.
	void _on_instance_created(uint64_t p_instance) override;
	/// Keeps the session handle for the room calls.
	void _on_session_created(uint64_t p_session) override;
	/// Asks the runtime for the saved room the first time the app gets focus.
	void _on_state_focused() override;
	/// Checks for the room load result a few times a second until it arrives or the wait runs out.
	void _on_process() override;
	/// Logs every event the runtime sends, raw, so PICO's room events show up even though their layout isn't public.
	bool _on_event_polled(const void *p_event) override;

protected:
	/// No script-facing methods yet.
	static void _bind_methods() {}

private:
	/// Calls xrLoadAnchorEntityBD with the session and a filter that keeps every kind of room surface.
	void _start_load();
	/// Asks for the load results; logs every anchor once they are in. Returns true when the probe is done.
	bool _read_results();
	/// Marks the probe finished and removes the crash marker.
	void _finish();
	/// Logs one anchor's label, components, plane, box and pose.
	void _log_anchor(uint64_t p_anchor);

	typedef XrResult(XRAPI_PTR *LoadAnchorEntity)(uint64_t, const PxrAnchorEntityLoadInfo *, uint64_t *);
	typedef XrResult(XRAPI_PTR *GetAnchorEntityLoadResults)(uint64_t, uint64_t, PxrAnchorEntityLoadResults *);
	typedef XrResult(XRAPI_PTR *GetAnchorSceneLabel)(uint64_t, uint64_t, int32_t *);
	typedef XrResult(XRAPI_PTR *GetAnchorComponentFlags)(uint64_t, uint64_t, uint64_t *);
	typedef XrResult(XRAPI_PTR *GetAnchorPlaneBoundaryInfo)(uint64_t, uint64_t, PxrAnchorPlaneBoundaryInfo *);
	typedef XrResult(XRAPI_PTR *GetAnchorBoxInfo)(uint64_t, uint64_t, PxrAnchorVolumeInfo *);

	// Godot writes true into these when the runtime offers the extension (names as the runtime lists them).
	bool spatial_scene = false;
	bool room_scene = false;
	bool semi_auto_room_capture = false;
	bool spatial_anchor = false;
	bool anchor_entity = false;
	bool anchor_entity_persistence = false;
	bool mr_management = false;
	bool async_task = false;

	uint64_t instance = 0;
	uint64_t session = 0;
	uint64_t handle = 0; // The session: the runtime rejects the instance (-12, "session ==" check in its log).
	uint64_t task_id = 0;
	bool load_started = false;
	bool done = false;
	int frames_waited = 0;
	XrResult last_result = XR_SUCCESS;

	LoadAnchorEntity load_anchor_entity = nullptr;
	GetAnchorEntityLoadResults get_load_results = nullptr;
	GetAnchorSceneLabel get_scene_label = nullptr;
	GetAnchorComponentFlags get_component_flags = nullptr;
	GetAnchorPlaneBoundaryInfo get_plane_boundary = nullptr;
	GetAnchorBoxInfo get_box = nullptr;
	PFN_xrLocateSpace locate_space = nullptr;
};
