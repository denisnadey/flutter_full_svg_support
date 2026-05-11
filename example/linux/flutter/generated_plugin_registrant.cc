//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <quickjs_engine/quickjs_engine_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) quickjs_engine_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "QuickjsEnginePlugin");
  quickjs_engine_plugin_register_with_registrar(quickjs_engine_registrar);
}
