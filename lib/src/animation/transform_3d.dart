import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

/// 4x4 transformation matrix for 3D transforms.
///
/// Uses column-major order storage (same as Matrix4 from vector_math):
/// ```
/// [m00, m10, m20, m30,  // column 0
///  m01, m11, m21, m31,  // column 1
///  m02, m12, m22, m32,  // column 2
///  m03, m13, m23, m33]  // column 3
/// ```
///
/// Matrix layout:
/// ```
/// | m00 m01 m02 m03 |   | 0  4  8  12 |
/// | m10 m11 m12 m13 | = | 1  5  9  13 |
/// | m20 m21 m22 m32 |   | 2  6  10 14 |
/// | m30 m31 m32 m33 |   | 3  7  11 15 |
/// ```
class Matrix4x4 {
  /// Creates a 4x4 matrix with the given values in column-major order.
  Matrix4x4(this._storage);

  /// Creates an identity 4x4 matrix.
  factory Matrix4x4.identity() {
    return Matrix4x4(Float64List.fromList([
      1, 0, 0, 0, // column 0
      0, 1, 0, 0, // column 1
      0, 0, 1, 0, // column 2
      0, 0, 0, 1, // column 3
    ]));
  }

  /// Creates a translation matrix.
  factory Matrix4x4.translation(double x, double y, double z) {
    return Matrix4x4(Float64List.fromList([
      1, 0, 0, 0, // column 0
      0, 1, 0, 0, // column 1
      0, 0, 1, 0, // column 2
      x, y, z, 1, // column 3
    ]));
  }

  /// Creates a scale matrix.
  factory Matrix4x4.scale(double x, double y, double z) {
    return Matrix4x4(Float64List.fromList([
      x, 0, 0, 0, // column 0
      0, y, 0, 0, // column 1
      0, 0, z, 0, // column 2
      0, 0, 0, 1, // column 3
    ]));
  }

  /// Creates a rotation matrix around the X axis.
  factory Matrix4x4.rotationX(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Matrix4x4(Float64List.fromList([
      1, 0, 0, 0, // column 0
      0, c, s, 0, // column 1
      0, -s, c, 0, // column 2
      0, 0, 0, 1, // column 3
    ]));
  }

  /// Creates a rotation matrix around the Y axis.
  factory Matrix4x4.rotationY(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Matrix4x4(Float64List.fromList([
      c, 0, -s, 0, // column 0
      0, 1, 0, 0, // column 1
      s, 0, c, 0, // column 2
      0, 0, 0, 1, // column 3
    ]));
  }

  /// Creates a rotation matrix around the Z axis (equivalent to 2D rotate).
  factory Matrix4x4.rotationZ(double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return Matrix4x4(Float64List.fromList([
      c, s, 0, 0, // column 0
      -s, c, 0, 0, // column 1
      0, 0, 1, 0, // column 2
      0, 0, 0, 1, // column 3
    ]));
  }

  /// Creates a rotation matrix around an arbitrary axis.
  ///
  /// The axis is specified by (x, y, z) and should be normalized.
  factory Matrix4x4.rotation3d(double x, double y, double z, double radians) {
    // Normalize the axis
    final len = math.sqrt(x * x + y * y + z * z);
    if (len < 1e-10) {
      return Matrix4x4.identity();
    }
    final nx = x / len;
    final ny = y / len;
    final nz = z / len;

    final c = math.cos(radians);
    final s = math.sin(radians);
    final omc = 1 - c; // one minus cosine

    return Matrix4x4(Float64List.fromList([
      nx * nx * omc + c,
      ny * nx * omc + nz * s,
      nz * nx * omc - ny * s,
      0,
      nx * ny * omc - nz * s,
      ny * ny * omc + c,
      nz * ny * omc + nx * s,
      0,
      nx * nz * omc + ny * s,
      ny * nz * omc - nx * s,
      nz * nz * omc + c,
      0,
      0,
      0,
      0,
      1,
    ]));
  }

  /// Creates a perspective projection matrix.
  ///
  /// [distance] is the distance from the viewer to the z=0 plane.
  factory Matrix4x4.perspective(double distance) {
    if (distance <= 0 || !distance.isFinite) {
      return Matrix4x4.identity();
    }
    // CSS perspective:
    // The perspective matrix transforms points as if viewing from z=distance
    // toward z=0. Points with larger z appear smaller.
    // Standard perspective matrix:
    // | 1  0  0  0          |
    // | 0  1  0  0          |
    // | 0  0  1  0          |
    // | 0  0  -1/d  1       |
    return Matrix4x4(Float64List.fromList([
      1, 0, 0, 0, // column 0
      0, 1, 0, 0, // column 1
      0, 0, 1, -1 / distance, // column 2
      0, 0, 0, 1, // column 3
    ]));
  }

  /// Creates a 4x4 matrix from CSS matrix3d() values.
  ///
  /// CSS matrix3d takes 16 values in column-major order:
  /// matrix3d(a1, b1, c1, d1, a2, b2, c2, d2, a3, b3, c3, d3, a4, b4, c4, d4)
  /// where a4=tx, b4=ty, c4=tz are translations.
  factory Matrix4x4.fromMatrix3d(List<double> values) {
    if (values.length < 16) {
      return Matrix4x4.identity();
    }
    // CSS matrix3d is already in column-major order, same as our storage
    return Matrix4x4(Float64List.fromList([
      values[0], values[1], values[2], values[3], // column 0
      values[4], values[5], values[6], values[7], // column 1
      values[8], values[9], values[10], values[11], // column 2
      values[12], values[13], values[14], values[15], // column 3
    ]));
  }

  /// Creates a 4x4 matrix from a 2D CSS matrix() (6 values).
  factory Matrix4x4.from2dMatrix(List<double> values) {
    if (values.length < 6) {
      return Matrix4x4.identity();
    }
    // CSS matrix(a, b, c, d, e, f) maps to:
    // | a  c  0  e |
    // | b  d  0  f |
    // | 0  0  1  0 |
    // | 0  0  0  1 |
    return Matrix4x4(Float64List.fromList([
      values[0], values[1], 0, 0, // column 0
      values[2], values[3], 0, 0, // column 1
      0, 0, 1, 0, // column 2
      values[4], values[5], 0, 1, // column 3
    ]));
  }

  final Float64List _storage;

  /// Returns the matrix storage in column-major order.
  Float64List get storage => _storage;

  /// Gets element at row [r] and column [c].
  double get(int r, int c) => _storage[c * 4 + r];

  /// Sets element at row [r] and column [c].
  void set(int r, int c, double value) {
    _storage[c * 4 + r] = value;
  }

  /// Multiplies this matrix by [other] and returns a new matrix.
  Matrix4x4 operator *(Matrix4x4 other) {
    final result = Float64List(16);
    for (var c = 0; c < 4; c++) {
      for (var r = 0; r < 4; r++) {
        var sum = 0.0;
        for (var k = 0; k < 4; k++) {
          sum += get(r, k) * other.get(k, c);
        }
        result[c * 4 + r] = sum;
      }
    }
    return Matrix4x4(result);
  }

  /// Transforms a 3D point (with w=1) and returns the projected 2D point.
  ///
  /// Applies perspective divide: x' = x/w, y' = y/w
  ui.Offset transform2D(double x, double y, double z) {
    // Transform the point
    final rx = get(0, 0) * x + get(0, 1) * y + get(0, 2) * z + get(0, 3);
    final ry = get(1, 0) * x + get(1, 1) * y + get(1, 2) * z + get(1, 3);
    // final rz = get(2, 0) * x + get(2, 1) * y + get(2, 2) * z + get(2, 3);
    final rw = get(3, 0) * x + get(3, 1) * y + get(3, 2) * z + get(3, 3);

    // Perspective divide
    if (rw.abs() > 1e-10) {
      return ui.Offset(rx / rw, ry / rw);
    }
    return ui.Offset(rx, ry);
  }

  /// Extracts a 2D affine transform by projecting key points.
  ///
  /// Projects the unit square corners to derive the 2D matrix.
  /// Returns the 6 values [a, b, c, d, e, f] for a 2D matrix.
  List<double> extract2DMatrix() {
    // Transform corners of unit square at z=0
    final p00 = transform2D(0, 0, 0);
    final p10 = transform2D(1, 0, 0);
    final p01 = transform2D(0, 1, 0);

    // Derive 2D matrix from transformed points:
    // | a c e |   | 0 |   | p00.x |
    // | b d f | * | 0 | = | p00.y |
    //             | 1 |
    // So e = p00.x, f = p00.y
    //
    // | a c e |   | 1 |   | p10.x |
    // | b d f | * | 0 | = | p10.y |
    //             | 1 |
    // So a + e = p10.x, b + f = p10.y
    // a = p10.x - p00.x, b = p10.y - p00.y
    //
    // | a c e |   | 0 |   | p01.x |
    // | b d f | * | 1 | = | p01.y |
    //             | 1 |
    // So c + e = p01.x, d + f = p01.y
    // c = p01.x - p00.x, d = p01.y - p00.y

    final e = p00.dx;
    final f = p00.dy;
    final a = p10.dx - e;
    final b = p10.dy - f;
    final c = p01.dx - e;
    final d = p01.dy - f;

    return [a, b, c, d, e, f];
  }

  /// Determines if the element is facing away from the viewer.
  ///
  /// Used for backface-visibility. Returns true if the element
  /// should be hidden (facing away).
  bool isBackfacing() {
    // Extract the transformed normal of the z=0 plane
    // The normal is (0, 0, 1) in local space
    // After rotation, we check if it points away (z < 0)

    // Transform the normal vector (direction only, no translation)
    final nz = get(2, 2); // z component of transformed (0,0,1)

    // If the z component of the transformed normal is negative,
    // the surface is facing away
    return nz < 0;
  }

  /// Creates a copy of this matrix.
  Matrix4x4 clone() {
    return Matrix4x4(Float64List.fromList(_storage));
  }

  @override
  String toString() {
    final sb = StringBuffer('Matrix4x4(\n');
    for (var r = 0; r < 4; r++) {
      sb.write('  [');
      for (var c = 0; c < 4; c++) {
        sb.write(get(r, c).toStringAsFixed(4));
        if (c < 3) sb.write(', ');
      }
      sb.write(']\n');
    }
    sb.write(')');
    return sb.toString();
  }
}

/// Represents the 3D transform context for a node.
///
/// Handles perspective, transform-style (flat vs preserve-3d),
/// and backface-visibility.
class Transform3DContext {
  Transform3DContext({
    this.perspective,
    this.perspectiveOriginX = 0.5,
    this.perspectiveOriginY = 0.5,
    this.transformStyle = Transform3DStyle.flat,
    this.backfaceVisibility = BackfaceVisibility.visible,
  });

  /// Perspective distance (from CSS `perspective` property or `perspective()` function).
  final double? perspective;

  /// Perspective origin X as a fraction of width (0.0 to 1.0).
  final double perspectiveOriginX;

  /// Perspective origin Y as a fraction of height (0.0 to 1.0).
  final double perspectiveOriginY;

  /// Whether to preserve 3D space for children or flatten immediately.
  final Transform3DStyle transformStyle;

  /// Whether backfaces should be visible.
  final BackfaceVisibility backfaceVisibility;

  /// Creates a perspective matrix for this context.
  Matrix4x4? createPerspectiveMatrix(double width, double height) {
    if (perspective == null || perspective! <= 0) {
      return null;
    }

    // Translate to perspective origin
    final ox = width * perspectiveOriginX;
    final oy = height * perspectiveOriginY;

    final toOrigin = Matrix4x4.translation(-ox, -oy, 0);
    final perspectiveMatrix = Matrix4x4.perspective(perspective!);
    final fromOrigin = Matrix4x4.translation(ox, oy, 0);

    return fromOrigin * perspectiveMatrix * toOrigin;
  }
}

/// Transform style for 3D transforms.
enum Transform3DStyle {
  /// Each element's 3D transform is flattened to 2D before applying
  /// to children. This is the default.
  flat,

  /// 3D transforms are preserved and accumulated for children.
  /// Children exist in the same 3D space as the parent.
  preserve3d,
}

/// Backface visibility setting.
enum BackfaceVisibility {
  /// The back face is visible (default).
  visible,

  /// The back face is hidden. Elements facing away are not rendered.
  hidden,
}

/// Converts degrees to radians.
double degreesToRadians(double degrees) => degrees * math.pi / 180.0;

/// Converts radians to degrees.
double radiansToDegrees(double radians) => radians * 180.0 / math.pi;
