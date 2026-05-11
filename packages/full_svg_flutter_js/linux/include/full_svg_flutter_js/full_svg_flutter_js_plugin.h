#ifndef FLUTTER_PLUGIN_FULL_SVG_FLUTTER_JS_PLUGIN_H_
#define FLUTTER_PLUGIN_FULL_SVG_FLUTTER_JS_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

typedef struct _FullSvgFlutterJsPlugin FullSvgFlutterJsPlugin;
typedef struct {
  GObjectClass parent_class;
} FullSvgFlutterJsPluginClass;

FLUTTER_PLUGIN_EXPORT GType full_svg_flutter_js_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void full_svg_flutter_js_plugin_register_with_registrar(
    FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // FLUTTER_PLUGIN_FULL_SVG_FLUTTER_JS_PLUGIN_H_
