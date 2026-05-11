#
# Ships a prebuilt quickjs-ng bridge dylib so the plugin links against a
# known-good binary. The dylib is rebuilt by `tools/build_native.sh` from the
# vendored sources under ../native/. CocoaPods' source_files cannot reach
# outside the pod directory reliably, so we go through vendored_libraries.
#
Pod::Spec.new do |s|
  s.name             = 'quickjs_engine'
  s.version          = '0.1.0'
  s.summary          = 'quickjs-ng bridge for full_svg_flutter.'
  s.description      = <<-DESC
Forked from flutter_js. Bundles quickjs-ng 0.14.0 directly so the JS engine
that runs SVGator/SMIL/animation scripts is the same modern QuickJS on every
platform — no JavaScriptCore fallback.
                       DESC
  s.homepage         = 'https://github.com/denisnadey/flutter_full_svg_support'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Denis Nadey' => 'denis.nadey@gmail.com' }
  s.source           = { :path => '.' }

  s.source_files = 'Classes/**/*.{swift,h,m}'

  # The bridge dylib (built once via tools/build_native.sh from ../native/).
  s.vendored_libraries = 'Frameworks/libquickjs_c_bridge_plugin.dylib'

  # Make sure the dylib lands in the app's Frameworks dir.
  s.preserve_paths = 'Frameworks/libquickjs_c_bridge_plugin.dylib'

  s.dependency 'FlutterMacOS'
  s.platform = :osx, '10.13'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'LD_RUNPATH_SEARCH_PATHS' => '$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks',
  }
end
