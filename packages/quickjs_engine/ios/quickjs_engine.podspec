#
# iOS counterpart of the macOS podspec — builds the same bridge + quickjs-ng
# source tree against the iOS Flutter framework.
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

  s.source_files = [
    'Classes/**/*.{swift,h,m}',
    '../native/cxx/libfastdev_quickjs_runtime.cpp',
    '../native/cxx/quickjs/quickjs.c',
    '../native/cxx/quickjs/libregexp.c',
    '../native/cxx/quickjs/libunicode.c',
    '../native/cxx/quickjs/dtoa.c',
    '../native/cxx/quickjs/*.h',
  ]
  s.public_header_files = []

  s.dependency 'Flutter'
  s.platform = :ios, '11.0'
  s.swift_version = '5.0'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'GCC_C_LANGUAGE_STANDARD' => 'c11',
    'CLANG_ENABLE_MODULES' => 'YES',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/../native/cxx" "$(PODS_TARGET_SRCROOT)/../native/cxx/quickjs"',
    'GCC_PREPROCESSOR_DEFINITIONS' => 'CONFIG_VERSION=\"ng-0.14.0\" $(inherited)',
    'WARNING_CFLAGS' => '-Wno-unused-function -Wno-unused-variable -Wno-unused-parameter -Wno-unused-but-set-variable',
  }
end
