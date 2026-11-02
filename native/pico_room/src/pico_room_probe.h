// Test probe for the room-aware Mixed Reality plan (not for merging): logs which of PICO's room functions the runtime
// has, then reads the room the player scanned in PICO's own room setup through PICO's private anchor entity API
// (XR_BD_anchor_entity) and logs every anchor it finds, raw. Tag "PicoRoom:" in logcat.
#pragma once

#include <openxr/openxr.h>

#include <godot_cpp/classes/open_xr_extension_wrapper_extension.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/string.hpp>

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

class PicoRoomProbe : public godot::OpenXRExtensionWrapperExtension {
	GDCLASS(PicoRoomProbe, godot::OpenXRExtensionWrapperExtension);

public:
	/// Returns PICO's room and anchor extensions, each with the flag Godot sets when the runtime has it.
	godot::Dictionary _get_requested_extensions() override;
	/// Logs which room extensions got enabled and resolves PICO's room functions.
	void _on_instance_created(uint64_t p_instance) override;
	/// Keeps the session handle for the room calls.
	void _on_session_created(uint64_t p_session) override;
	/// Asks the runtime for the saved room the first time the app gets focus.
	void _on_state_focused() override;
	/// Logs every runtime event raw; reads the load results when the event carrying the load's task id arrives.
	bool _on_event_polled(const void *p_event) override;

protected:
	/// No script-facing methods yet.
	static void _bind_methods() {}

private:
	/// Returns true when this stage crashed the game last launch (its marker is still there); else writes the marker.
	bool _enter_stage(const char *p_stage);
	/// Removes the stage's marker: the stage returned.
	void _leave_stage(const char *p_stage);
	/// Calls xrLoadAnchorEntityBD with the session and no filter.
	void _start_load();
	/// Reads the load results and logs every anchor.
	void _read_results();
	/// Logs one anchor's label, component flags, plane, box and pose.
	void _log_anchor(uint64_t p_anchor);

	typedef XrResult(XRAPI_PTR *LoadAnchorEntity)(XrSession, const PicoAnchorEntityLoadInfo *, uint64_t *);
	typedef XrResult(XRAPI_PTR *GetAnchorEntityLoadResults)(XrSession, uint64_t, void *);
	typedef XrResult(XRAPI_PTR *GetAnchorValue)(XrSession, uint64_t, void *);

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
	bool results_read = false;

	LoadAnchorEntity load_anchor_entity = nullptr;
	GetAnchorEntityLoadResults get_load_results = nullptr;
	GetAnchorValue get_scene_label = nullptr;
	GetAnchorValue get_component_flags = nullptr;
	GetAnchorValue get_plane_boundary = nullptr;
	GetAnchorValue get_box = nullptr;
	PFN_xrLocateSpace locate_space = nullptr;
};
