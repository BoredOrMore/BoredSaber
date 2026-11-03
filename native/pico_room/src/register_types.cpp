// Registers PicoRoom with Godot's OpenXR module and as the engine singleton "PicoRoom". It has to be registered at the core level, before
// OpenXR creates its instance, or its extensions are never requested.
#include "pico_room.h"

#include <gdextension_interface.h>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/core/memory.hpp>
#include <godot_cpp/godot.hpp>

using namespace godot;

static PicoRoom *room = nullptr;

/// Creates PicoRoom, hands it to Godot's OpenXR module and lets the game reach it as a singleton.
static void initialize_pico_room(ModuleInitializationLevel p_level) {
	if (p_level != MODULE_INITIALIZATION_LEVEL_CORE) {
		return;
	}
	GDREGISTER_CLASS(PicoRoom);
	room = memnew(PicoRoom);
	room->register_extension_wrapper();
	Engine::get_singleton()->register_singleton("PicoRoom", room);
}

/// Forgets PicoRoom when the library unloads. Godot's OpenXR module owns a registered wrapper and frees it itself
/// (freeing it here too crashed the headless import on exit: "double free or corruption").
static void uninitialize_pico_room(ModuleInitializationLevel p_level) {
	if (p_level == MODULE_INITIALIZATION_LEVEL_CORE) {
		Engine::get_singleton()->unregister_singleton("PicoRoom");
		room = nullptr;
	}
}

extern "C" GDExtensionBool GDE_EXPORT pico_room_library_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
		GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
	GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);
	init_obj.register_initializer(initialize_pico_room);
	init_obj.register_terminator(uninitialize_pico_room);
	init_obj.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_CORE);
	return init_obj.init();
}
