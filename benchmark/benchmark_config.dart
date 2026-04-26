// Copyright 2024 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Configuration constants for benchmarks.
class BenchmarkConfig {
  BenchmarkConfig._();

  /// Number of warmup iterations before measurement.
  static const int warmupIterations = 5;

  /// Number of measured iterations.
  static const int iterations = 50;

  /// Timeout for any single benchmark in milliseconds.
  static const int timeoutMs = 30000;
}
