// Reads the player's real room through PICO's private anchor entity API (XR_BD_anchor_entity, OS 5.12): opens PICO's
// scene capture so the headset recognises the room, then loads its walls, floor, ceiling and furniture with their
// poses in the play space. The game reaches it as the engine singleton "PicoRoom". Logs tagged "PicoRoom:".
#pragma once

#include <openxr/openxr.h>

#include <godot_cpp/classes/open_xr_extension_wrapper_extension.hpp>
#include <godot_cpp/variant/array.hpp>
#include <godot_cpp/variant/dictionary.hpp>

#include <cstddef>
#include <cstdint>

// xrLoadAnchorEntityBD's info, as the runtime reads it (libpxrruntime.so, OS 5.12): an OpenXR-style header, then
// maxResult, timeout and location, then the include filter. The runtime doesn't check the type field.
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

class PicoRoom : public godot::OpenXRExtensionWrapperExtension {
	GDCLASS(PicoRoom, godot::OpenXRExtensionWrapperExtension);

public:
	/// Returns PICO's room and anchor extensions, each with the flag Godot sets when the runtime has it.
	godot::Dictionary _get_requested_extensions() override;
	/// Resolves PICO's room functions once the runtime enabled its extensions.
	void _on_instance_created(uint64_t p_instance) override;
	/// Keeps the session handle for the room calls.
	void _on_session_created(uint64_t p_session) override;
	/// Notes focus; loads the room when focus comes back from PICO's scene capture.
	void _on_state_focused() override;
	/// Notes that focus left the app, which means PICO's scene capture opened if one was asked for.
	void _on_state_visible() override;
	/// Asks for the scene capture until it opens, and retries a load that found nothing.
	void _on_process() override;
	/// Reads the room once PICO says its load finished.
	bool _on_event_polled(const void *p_event) override;

	/// Returns whether this headset's runtime has every function a room scan needs.
	bool is_supported() const;
	/// Opens PICO's scene capture, then loads the room when the player comes back; ends in room_loaded or
	/// room_not_found.
	void scan_room();

protected:
	/// Binds the methods and signals the game uses.
	static void _bind_methods();

private:
	typedef XrResult(XRAPI_PTR *LoadAnchorEntity)(XrSession, const PicoAnchorEntityLoadInfo *, uint64_t *);
	// The results struct is filled at +0x10 (capacity), +0x14 (count) and +0x18 (entries); see the .cpp.
	typedef XrResult(XRAPI_PTR *GetAnchorEntityLoadResults)(XrSession, uint64_t, void *);
	// Every per-anchor getter takes the session, the anchor id and a struct to fill.
	typedef XrResult(XRAPI_PTR *GetAnchorValue)(XrSession, uint64_t, void *);
	// Session, an info with the anchor id at +0x10, then the XrSpace out (9dd67b0).
	typedef XrResult(XRAPI_PTR *CreateAnchorSpace)(XrSession, void *, XrSpace *);
	// Session, an info (zeroed works), then a task id out.
	typedef XrResult(XRAPI_PTR *StartSpatialSceneCapture)(XrSession, void *, uint64_t *);

	/// Asks PICO to open its scene capture.
	void _start_capture();
	/// Starts loading the room's anchors.
	void _start_load();
	/// Reads every loaded anchor and sends room_loaded.
	void _read_results(uint64_t p_task);
	/// Returns one anchor as a piece of the room (label, centre transform, size), or an empty Dictionary.
	godot::Dictionary _read_piece(uint64_t p_anchor);
	/// Ends a scan that found no room.
	void _not_found();

	XrSession session = XR_NULL_HANDLE;
	uint64_t task_id = 0;
	bool scanning = false;
	bool capture_asked = false;
	// Focus left the app after the capture was asked for, so PICO's capture screen took it.
	bool capture_opened = false;
	bool focused = false;
	bool loading = false;
	int capture_frames = 0;
	int capture_tries = 0;
	int load_frames = 0;
	int load_tries = 0;

	uint64_t spatial_scene = 0;
	uint64_t room_scene = 0;
	uint64_t semi_auto_room_capture = 0;
	uint64_t spatial_anchor = 0;
	uint64_t anchor_entity = 0;
	uint64_t anchor_entity_persistence = 0;
	uint64_t mr_management = 0;
	uint64_t async_task = 0;

	LoadAnchorEntity load_anchor_entity = nullptr;
	GetAnchorEntityLoadResults get_load_results = nullptr;
	GetAnchorValue get_scene_label = nullptr;
	GetAnchorValue get_plane_boundary = nullptr;
	GetAnchorValue get_box = nullptr;
	CreateAnchorSpace create_anchor_space = nullptr;
	PFN_xrLocateSpace locate_space = nullptr;
	PFN_xrDestroySpace destroy_space = nullptr;
	StartSpatialSceneCapture start_scene_capture = nullptr;
};
