# full_svg_flutter benchmarks · Makefile
#
# All targets resolve paths relative to the *repo root*, but Make is invoked
# from the benchmarks/ directory (or with `make -C benchmarks <target>`).
#
# Build configuration is locked to the project's FVM-pinned Flutter SDK so
# CI and local runs use the exact same toolchain.

SHELL := /bin/bash
REPO_ROOT := $(realpath $(dir $(lastword $(MAKEFILE_LIST)))..)
FLUTTER := $(REPO_ROOT)/.fvm/flutter_sdk/bin/flutter
DART    := $(REPO_ROOT)/.fvm/flutter_sdk/bin/dart

BENCHMARK_APP := $(REPO_ROOT)/benchmarks/benchmark_app
BENCHMARK_RUN := $(REPO_ROOT)/benchmarks/benchmark_runner
COMPARISON    := $(REPO_ROOT)/benchmarks/comparison
TOOL          := $(REPO_ROOT)/benchmarks/tool

# Default target — show help.
.DEFAULT_GOAL := help

.PHONY: help
help:
	@echo ""
	@echo "  full_svg_flutter benchmarks"
	@echo "  ──────────────────────────────────────────────────────────────"
	@echo "  Side-by-side comparison (macOS):"
	@echo "    make compare                    Build + launch Flutter & Chrome"
	@echo "    make compare-build              Build Flutter macOS release only"
	@echo "    make compare-rebuild            Force rebuild then launch"
	@echo "    make compare-run                Launch (assumes already built)"
	@echo "    make compare-flutter-only       Launch only the Flutter side"
	@echo "    make compare-chrome-only        Launch only the Chrome side"
	@echo ""
	@echo "  Asset generation:"
	@echo "    make storm-regen                Regenerate galactic_storm.svg"
	@echo ""
	@echo "  Bench tooling:"
	@echo "    make analyze                    flutter analyze on benchmark_app"
	@echo "    make parser-bench               Run pure Dart parser microbenchmarks"
	@echo "    make integration-macos          Run integration tests on macOS"
	@echo ""
	@echo "  Cleanup:"
	@echo "    make clean                      flutter clean both projects"
	@echo "    make distclean                  clean + remove macos/ platform dir"
	@echo ""
	@echo "  Resolved paths:"
	@echo "    REPO_ROOT     = $(REPO_ROOT)"
	@echo "    FLUTTER       = $(FLUTTER)"
	@echo "    BENCHMARK_APP = $(BENCHMARK_APP)"
	@echo ""

# ---------------------------------------------------------------------------
# Side-by-side comparison
# ---------------------------------------------------------------------------

.PHONY: compare-platform-init
compare-platform-init:
	@if [ ! -d "$(BENCHMARK_APP)/macos" ]; then \
		echo "==> Adding macOS platform support (one-time)..."; \
		cd "$(BENCHMARK_APP)" && "$(FLUTTER)" create --platforms=macos . ; \
	else \
		echo "==> macOS platform already present."; \
	fi

.PHONY: compare-build
compare-build: compare-platform-init
	@echo "==> flutter pub get"
	@cd "$(BENCHMARK_APP)" && "$(FLUTTER)" pub get
	@echo "==> flutter build macos --release"
	@cd "$(BENCHMARK_APP)" && "$(FLUTTER)" build macos --release
	@echo ""
	@echo "    Built: $(BENCHMARK_APP)/build/macos/Build/Products/Release/*.app"

.PHONY: compare-run
compare-run:
	@python3 "$(COMPARISON)/launcher.py" --no-build

.PHONY: compare
compare:
	@python3 "$(COMPARISON)/launcher.py"

.PHONY: compare-rebuild
compare-rebuild:
	@python3 "$(COMPARISON)/launcher.py" --rebuild

.PHONY: compare-flutter-only
compare-flutter-only:
	@python3 "$(COMPARISON)/launcher.py" --flutter-only

.PHONY: compare-chrome-only
compare-chrome-only:
	@python3 "$(COMPARISON)/launcher.py" --chrome-only --no-build

# ---------------------------------------------------------------------------
# Assets
# ---------------------------------------------------------------------------

.PHONY: storm-regen
storm-regen:
	@"$(DART)" run "$(TOOL)/generate_galactic_storm.dart"

# ---------------------------------------------------------------------------
# Quality / smoke
# ---------------------------------------------------------------------------

.PHONY: analyze
analyze:
	@cd "$(BENCHMARK_APP)" && "$(FLUTTER)" pub get >/dev/null
	@cd "$(BENCHMARK_APP)" && "$(FLUTTER)" analyze lib/ integration_test/

.PHONY: parser-bench
parser-bench:
	@bash "$(REPO_ROOT)/benchmarks/scripts/run_parser_benchmarks.sh"

.PHONY: integration-macos
integration-macos: compare-platform-init
	@cd "$(BENCHMARK_APP)" && "$(FLUTTER)" pub get
	@cd "$(BENCHMARK_APP)" && "$(FLUTTER)" test integration_test/benchmark_test.dart -d macos

# ---------------------------------------------------------------------------
# Cleanup
# ---------------------------------------------------------------------------

.PHONY: clean
clean:
	@cd "$(BENCHMARK_APP)" && "$(FLUTTER)" clean
	@cd "$(BENCHMARK_RUN)" && "$(FLUTTER)" clean

.PHONY: distclean
distclean: clean
	@rm -rf "$(BENCHMARK_APP)/macos"
	@rm -rf /tmp/full-svg-flutter-comparison-profile
