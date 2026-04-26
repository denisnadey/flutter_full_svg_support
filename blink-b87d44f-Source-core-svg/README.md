# Blink SVG Core Module

## Project Description

This is the **SVG (Scalable Vector Graphics)** module from the **Blink** rendering engine — the open-source browser engine used in Google Chrome, Chromium, Opera, and other Chromium-based browsers.

This directory contains the core source code for processing and rendering SVG content in a web browser. The code is part of the WebKit/Blink project and is written in C++.

## What Is Blink?

**Blink** is a fork of the WebKit browser engine developed by Google. It is responsible for:
- Parsing HTML/SVG/XML
- Applying CSS styles
- Rendering web pages
- Executing JavaScript via V8

## Project Structure

### Main Components

#### 1. **SVG Elements** (~165 .cpp files)
Implementation of all SVG elements according to the W3C specification:

**Basic Shapes:**
- `SVGCircleElement` - circles
- `SVGRectElement` - rectangles
- `SVGEllipseElement` - ellipses
- `SVGLineElement` - lines
- `SVGPolygonElement`, `SVGPolylineElement` - polygons
- `SVGPathElement` - paths (the most complex element)

**Containers and Grouping:**
- `SVGSVGElement` - root element of an SVG document
- `SVGGElement` - element groups
- `SVGDefsElement` - definitions for reuse
- `SVGSymbolElement` - symbols
- `SVGUseElement` - use of defined elements

**Text Elements:**
- `SVGTextElement` - text
- `SVGTSpanElement` - text spans
- `SVGTextPathElement` - text along a path

**Gradients and Patterns:**
- `SVGLinearGradientElement` - linear gradients
- `SVGRadialGradientElement` - radial gradients
- `SVGPatternElement` - fill patterns

**Filters (SVGFExxxElement):**
Over 20 filter elements for graphical effects:
- `SVGFEGaussianBlurElement` - blur
- `SVGFEBlendElement` - blending
- `SVGFEColorMatrixElement` - color transformations
- `SVGFEDropShadowElement` - drop shadows
- And many other effects

**SVG Fonts:**
- `SVGFontElement`, `SVGGlyphElement` - SVG font support
- `SVGFontFaceElement` - font metadata

#### 2. **Animation**
Directory `animation/`:
- `SVGSMILElement` - base class for SMIL animations
- `SMILTimeContainer` - timeline container
- `SVGAnimateElement` - attribute animation
- `SVGAnimateTransformElement` - transform animation
- `SVGAnimateMotionElement` - motion along a path
- `SVGAnimateColorElement` - color animation

#### 3. **Animated Properties**
Directory `properties/`:
- System for working with animatable SVG attributes
- `SVGAnimatedProperty` - base class
- Various property types: Length, Number, String, Transform, Path, etc.

#### 4. **Graphics**
Directory `graphics/`:
- `SVGImageChromeClient` - integration of SVG images with the browser

#### 5. **Data Types**
SVG data types:
- `SVGLength` - lengths (px, em, %, etc.)
- `SVGAngle` - angles
- `SVGNumber` - numbers
- `SVGTransform` - transforms
- `SVGColor`, `SVGPaint` - colors and fills
- `SVGPreserveAspectRatio` - aspect ratio preservation

#### 6. **Path Processing**
A powerful system for working with SVG paths:
- `SVGPathParser` - parsing path commands
- `SVGPathBuilder` - building paths
- `SVGPathBlender` - blending paths (for animation)
- `SVGPathByteStream` - optimized representation
- `SVGPathUtilities` - path utility functions

#### 7. **Attribute Processing**
- `svgtags.in` - definitions of all SVG tags (99+ elements)
- `svgattrs.in` - definitions of all SVG attributes (252+ attributes)
- `xlinkattrs.in` - XLink attributes

## Technical Details

### Programming Languages
- **C++** - primary implementation language
- **IDL (Web IDL)** - JavaScript API descriptions for SVG elements
- **Build Scripts** - configuration files (.in)

### Code Statistics
- **~165** implementation files (.cpp)
- **~376** header and IDL files (.h, .idl)
- Thousands of lines of code

### Namespace
All code resides in the `WebCore` namespace.

### Licenses
The project contains code under two licenses:
1. **BSD License** (3-clause) - code from Apple, Google
2. **GNU LGPL v2+** - code from KDE contributors (Nikolas Zimmermann, Rob Buis)

### Main copyright holders:
- Apple Inc.
- Google Inc.
- Nikolas Zimmermann (KDE)
- Rob Buis (KDE)
- And other contributors

## Architectural Notes

### 1. Integration with the Browser Engine
- Uses the DOM (Document Object Model) system
- CSS integration for styling
- JavaScript support via V8 bindings
- Rendering via the RenderObject system

### 2. Animated Properties System
An advanced system for animating any SVG attributes:
```cpp
DEFINE_ANIMATED_LENGTH(SVGSVGElement, SVGNames::widthAttr, Width, width)
```

### 3. Performance Optimizations
- Byte stream for paths (compact representation)
- Lazy evaluation
- Transform caching

## Usage

This code is used in:
- **Google Chrome** / Chromium
- **Opera** (Chromium-based versions)
- **Microsoft Edge** (new Chromium-based versions)
- **Brave Browser**
- And other Blink-based browsers

## SVG Capabilities

The module supports the full SVG 1.1 specification and partially SVG 2.0:
- ✅ Basic shapes and paths
- ✅ Text and fonts
- ✅ Gradients and patterns
- ✅ Filters and effects
- ✅ Clipping and masking
- ✅ SMIL animations
- ✅ Transforms
- ✅ Interactivity (events)

## Development

### Build Requirements
Compiling this module requires a full Chromium/Blink build environment:
- C++ compiler (Clang preferred)
- Python (for build scripts)
- Google's depot_tools
- All Chromium dependencies

### Key Files
- `SVGElement.cpp/h` - base class for all SVG elements
- `SVGSVGElement.cpp/h` - root `<svg>` element
- `SVGDocument.cpp/h` - SVG document
- `SVGDocumentExtensions.cpp/h` - extensions for SVG support

## Historical Note

The code was originally part of WebKit (the Safari engine), then forked by Google in 2013 to create Blink. Traces of history are visible in the copyright notices — code from Apple, KDE (KHTML), and later changes from Google.

## Related Technologies

- **WebKit** - the original project
- **V8** - JavaScript engine
- **Skia** - 2D graphics library for rendering
- **CSS** - SVG element styling

## Note

This is not a standalone project — it is part of the enormous Chromium codebase and cannot be compiled separately without the corresponding build infrastructure.

---

**Version:** Snapshot from Blink source (build b87d44f)  
**Date:** 2026  
**License:** BSD & LGPL (see file headers)
