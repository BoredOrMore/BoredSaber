// Registers the PICO room probe with Godot's OpenXR module. It has to be registered at the core level, before
// OpenXR creates its instance, or its extensions are never requested.
#include "pico_room_probe.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static PicoRoomProbe *probe = nullptr;

/// Creates the probe and hands it to Godot's OpenXR module.
static void initialize_pico_room(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_CORE) {
		return;
	}
	GDREGISTER_CLASS(PicoRoomProbe);
	probe = memnew(PicoRoomProbe);
	probe->register_extension_wrapper();
}

/// Frees the probe when the library unloads.
static void uninitialize_pico_room(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_CORE || probe == nullptr) {
		return;
	}
	memdelete(probe);
	probe = nullptr;
}

extern "C" GDExtensionBool GDE_EXPORT pico_room_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_pico_room);
	init_obj.register_terminator(uninitialize_pico_room);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_CORE);
	return init_obj.init();
}
