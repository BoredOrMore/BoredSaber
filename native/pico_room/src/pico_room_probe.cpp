#include "pico_room_probe.h"

#include <godot_cpp/classes/open_xrapi_extension.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <vector>

using namespace godot;

Dictionary PicoRoomProbe::_get_requested_extensions() {
	Dictionary requested;
	requested["XR_BD_spatial_sensing"] = (uint64_t)&spatial_sensing;
	requested["XR_BD_spatial_scene"] = (uint64_t)&spatial_scene;
	requested["XR_BD_room_scene"] = (uint64_t)&room_scene;
	requested["XR_BD_semi_auto_room_capture"] = (uint64_t)&semi_auto_room_capture;
	requested["XR_BD_spatial_localization_and_tracking"] = (uint64_t)&spatial_localization_and_tracking;
	requested["XR_BD_spatial_anchor"] = (uint64_t)&spatial_anchor;
	requested["XR_EXT_future"] = (uint64_t)&future;
	requested["XR_BD_async_task"] = (uint64_t)&async_task;
	return requested;
}

void PicoRoomProbe::_on_instance_created(uint64_t p_instance) {
	Ref<OpenXRAPIExtension> api = get_openxr_api();
	if (api.is_null()) {
		UtilityFunctions::push_error("PicoRoom: no OpenXR API");
		return;
	}
	auto enumerate = (PFN_xrEnumerateInstanceExtensionProperties)api->get_instance_proc_addr(
			"xrEnumerateInstanceExtensionProperties");
	if (enumerate == nullptr) {
		UtilityFunctions::push_error("PicoRoom: xrEnumerateInstanceExtensionProperties not found");
		return;
	}
	uint32_t count = 0;
	XrResult result = enumerate(nullptr, 0, &count, nullptr);
	if (XR_FAILED(result)) {
		UtilityFunctions::push_error("PicoRoom: counting extensions failed ", (int64_t)result);
		return;
	}
	std::vector<XrExtensionProperties> extensions(count, { XR_TYPE_EXTENSION_PROPERTIES });
	result = enumerate(nullptr, count, &count, extensions.data());
	if (XR_FAILED(result)) {
		UtilityFunctions::push_error("PicoRoom: listing extensions failed ", (int64_t)result);
		return;
	}
	UtilityFunctions::print("PicoRoom: runtime offers ", (int64_t)count, " extensions");
	for (const XrExtensionProperties &extension : extensions) {
		UtilityFunctions::print("PicoRoom: ext ", String(extension.extensionName), " v", (int64_t)extension.extensionVersion);
	}
	UtilityFunctions::print("PicoRoom: enabled spatial_sensing ", spatial_sensing, " spatial_scene ", spatial_scene,
			" room_scene ", room_scene, " semi_auto_room_capture ", semi_auto_room_capture,
			" spatial_localization_and_tracking ", spatial_localization_and_tracking, " spatial_anchor ", spatial_anchor,
			" future ", future, " async_task ", async_task);
}
