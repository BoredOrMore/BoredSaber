// Test probe for the room-aware Mixed Reality plan (not for merging): logs every OpenXR extension the headset's
// runtime offers, with its version, and which of PICO's room and anchor extensions Godot could enable. Tag
// "PicoRoom:" in logcat.
#pragma once

#include <openxr/openxr.h>

#include <godot_cpp/classes/open_xr_extension_wrapper_extension.hpp>
#include <godot_cpp/variant/dictionary.hpp>

class PicoRoomProbe : public godot::OpenXRExtensionWrapperExtension {
	GDCLASS(PicoRoomProbe, godot::OpenXRExtensionWrapperExtension);

public:
	/// Returns PICO's room and anchor extensions, each with the flag Godot sets when the runtime has it.
	godot::Dictionary _get_requested_extensions() override;
	/// Logs the runtime's whole extension list and which room extensions got enabled.
	void _on_instance_created(uint64_t p_instance) override;

protected:
	/// No script-facing methods yet.
	static void _bind_methods() {}

private:
	// Godot writes true into these when the runtime offers the extension (names as found in the runtime's library).
	bool spatial_sensing = false;
	bool spatial_scene = false;
	bool room_scene = false;
	bool semi_auto_room_capture = false;
	bool spatial_localization_and_tracking = false;
	bool spatial_anchor = false;
	bool future = false;
	bool async_task = false;
};
