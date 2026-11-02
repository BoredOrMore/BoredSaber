// Test probe for the room-aware Mixed Reality plan (not for merging): logs which of PICO's room functions the runtime
// has, then reads the room the player scanned in PICO's own room setup through PICO's private anchor entity API
// (XR_BD_anchor_entity) and logs every anchor it finds, raw. Tag "PicoRoom:" in logcat.
#pragma once

#include <openxr/openxr.h>

#include <godot_cpp/classes/open_xr_extension_wrapper_extension.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

#include <cstddef>
#include <cstdint>

// xrLoadAnchorEntityBD's info, as the runtime reads it (libpxrruntime.so, OS 5.12): an OpenXR-style header, then
// maxResult, timeout and location, then the include filter (nullptr loads everything). The runtime doesn't check the
// type field.
struct PicoAnchorEntityLoadInfo {
	uint32_t type;
	const void *next;
	uint32_t max_result; // +0x10
	uint64_t timeout; // +0x18
	uint32_t location; // +0x20, 1 = saved on the headset.
	const void *include; // +0x28
};
static_assert(sizeof(PicoAnchorEntityLoadInfo) == 0x30, "layout must match the runtime");

// An include filter as the runtime reads it: OpenXR-style header, then a 64-bit value at +0x10 (flags).
struct PicoAnchorEntityLoadFilter {
	uint32_t type;
	const void *next;
	uint64_t flags; // +0x10
};

// The loaded event (type 1200006350) as logged on the headset: header, then task id, result, total and location.
struct PicoEventAnchorEntityLoaded {
	uint32_t type;
	const void *next;
	uint64_t task_id; // +0x10
	int32_t result; // +0x18
	uint32_t total; // +0x1C (matches the runtime's own on_anchor_load_completed log)
	uint32_t location; // +0x20
};
static_assert(offsetof(PicoEventAnchorEntityLoaded, total) == 0x1C, "layout must match the runtime");

class PicoRoomProbe : public godot::OpenXRExtensionWrapperExtension {
	GDCLASS(PicoRoomProbe, godot::OpenXRExtensionWrapperExtension);

public:
	/// Returns PICO's room and anchor extensions, each with the flag Godot sets when the runtime has it.
	godot::Dictionary _get_requested_extensions() override;
	/// Logs which room extensions got enabled and resolves PICO's room functions.
	void _on_instance_created(uint64_t p_instance) override;
	/// Keeps the session handle for the room calls.
	void _on_session_created(uint64_t p_session) override;
	/// Opens PICO's scene capture the first time the app gets focus.
	void _on_state_focused() override;
	/// Notes that the app lost focus (for example to PICO's scene capture), which pauses the retries.
	void _on_state_visible() override;
	/// Retries the load every few seconds until anchors are found.
	void _on_process() override;
	/// Logs PICO's events raw; loads again when the room localization state changes; reads results when a load
	/// finds anchors.
	bool _on_event_polled(const void *p_event) override;

protected:
	/// No script-facing methods yet.
	static void _bind_methods() {}

private:
	/// Returns true when this stage crashed the game last launch (its marker is still there); else writes the marker.
	bool _enter_stage(const char *p_stage);
	/// Removes the stage's marker: the stage returned.
	void _leave_stage(const char *p_stage);
	/// Calls xrLoadAnchorEntityBD with the session and the spatial scene filter (every surface kind).
	void _start_load();
	/// Opens PICO's scene capture from inside the game (xrStartSpatialSceneCaptureBD).
	void _start_capture();
	/// Reads the load results and logs every anchor.
	void _read_results();
	/// Logs one anchor's label, component flags, plane, box and pose, raw.
	void _log_anchor(uint64_t p_anchor);

	typedef XrResult(XRAPI_PTR *LoadAnchorEntity)(XrSession, const PicoAnchorEntityLoadInfo *, uint64_t *);
	typedef XrResult(XRAPI_PTR *GetAnchorEntityLoadResults)(XrSession, uint64_t, void *);
	typedef XrResult(XRAPI_PTR *GetAnchorValue)(XrSession, uint64_t, void *);
	// Guessed: session, info, XrSpace out.
	typedef XrResult(XRAPI_PTR *CreateAnchorSpace)(XrSession, void *, void *);
	// Guessed: session, info, task id out (two arguments crashed).
	typedef XrResult(XRAPI_PTR *StartSpatialSceneCapture)(XrSession, void *, uint64_t *);

	// Godot writes true into these when the runtime offers the extension (names as the runtime lists them).
	bool spatial_scene = false;
	bool room_scene = false;
	bool semi_auto_room_capture = false;
	bool spatial_anchor = false;
	bool anchor_entity = false;
	bool anchor_entity_persistence = false;
	bool mr_management = false;
	bool async_task = false;

	XrSession session = XR_NULL_HANDLE;
	uint64_t task_id = 0;
	bool load_started = false;
	bool capture_started = false;
	bool focused = false;
	bool found = false;
	int frames_since_load = 0;
	int retries = 0;

	LoadAnchorEntity load_anchor_entity = nullptr;
	GetAnchorEntityLoadResults get_load_results = nullptr;
	GetAnchorValue get_scene_label = nullptr;
	GetAnchorValue get_component_flags = nullptr;
	GetAnchorValue get_plane_boundary = nullptr;
	GetAnchorValue get_box = nullptr;
	StartSpatialSceneCapture start_scene_capture = nullptr;
	CreateAnchorSpace create_anchor_space = nullptr;
	PFN_xrLocateSpace locate_space = nullptr;
};
