// Minimal Windows Flutter plugin shim — no method-channel handlers.
// The Dart side talks to quickjs-ng directly through FFI.
#include "include/full_svg_flutter_js/full_svg_flutter_js_plugin.h"
#include <flutter/plugin_registrar_windows.h>

namespace full_svg_flutter_js {
class FullSvgFlutterJsPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar) {
    auto plugin = std::make_unique<FullSvgFlutterJsPlugin>();
    registrar->AddPlugin(std::move(plugin));
  }
  FullSvgFlutterJsPlugin() {}
  virtual ~FullSvgFlutterJsPlugin() {}
};
}  // namespace full_svg_flutter_js

void FullSvgFlutterJsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  full_svg_flutter_js::FullSvgFlutterJsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
