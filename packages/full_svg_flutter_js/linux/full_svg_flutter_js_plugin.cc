// Minimal GTK Flutter plugin shim — no method-channel handlers needed.
// The Dart side talks to quickjs-ng directly through FFI.
#include "include/full_svg_flutter_js/full_svg_flutter_js_plugin.h"
#include <flutter_linux/flutter_linux.h>

#define FULL_SVG_FLUTTER_JS_PLUGIN(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj), full_svg_flutter_js_plugin_get_type(), FullSvgFlutterJsPlugin))

struct _FullSvgFlutterJsPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(FullSvgFlutterJsPlugin, full_svg_flutter_js_plugin, g_object_get_type())

static void full_svg_flutter_js_plugin_class_init(FullSvgFlutterJsPluginClass* klass) {}
static void full_svg_flutter_js_plugin_init(FullSvgFlutterJsPlugin* self) {}

void full_svg_flutter_js_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  FullSvgFlutterJsPlugin* plugin = FULL_SVG_FLUTTER_JS_PLUGIN(
      g_object_new(full_svg_flutter_js_plugin_get_type(), nullptr));
  g_object_unref(plugin);
}
