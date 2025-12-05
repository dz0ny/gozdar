# Gozdar Makefile
# Version format: YYYY.MMDD.N+build (Flutter-compatible semver with date)
# Example: 2025.1205.1+1

# Configuration
APP_NAME := gozdar
PUBSPEC := pubspec.yaml
BUILD_DIR := build/app/outputs/flutter-apk

# Get current date parts
YEAR := $(shell date +%Y)
MMDD := $(shell date +%m%d)

# Get current version info from pubspec.yaml
CURRENT_VERSION := $(shell grep '^version:' $(PUBSPEC) | sed 's/version: //')
CURRENT_BUILD_NUMBER := $(shell echo $(CURRENT_VERSION) | cut -d'+' -f2)

# Extract current MMDD from version (middle part)
CURRENT_MMDD := $(shell echo $(CURRENT_VERSION) | cut -d'.' -f2)

# Calculate new build number
# If MMDD matches today, increment; otherwise start at 1
NEW_BUILD_NUMBER := $(shell \
	if [ "$(CURRENT_MMDD)" = "$(MMDD)" ]; then \
		echo $$(($(CURRENT_BUILD_NUMBER) + 1)); \
	else \
		echo 1; \
	fi)
NEW_VERSION := $(YEAR).$(MMDD).$(NEW_BUILD_NUMBER)+$(NEW_BUILD_NUMBER)

.PHONY: help version bump build release clean deps analyze test

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

version: ## Show current and next version
	@echo "Current version: $(CURRENT_VERSION)"
	@echo "Current name:    $(CURRENT_VERSION_NAME)"
	@echo "Current build:   $(CURRENT_BUILD_NUMBER)"
	@echo "---"
	@echo "Next version:    $(NEW_VERSION)"

bump: ## Bump version in pubspec.yaml
	@echo "Bumping version to $(NEW_VERSION)..."
	@sed -i '' 's/^version: .*/version: $(NEW_VERSION)/' $(PUBSPEC)
	@echo "Version bumped to $(NEW_VERSION)"

deps: ## Install dependencies
	flutter pub get

analyze: ## Run Flutter analyze
	flutter analyze

test: ## Run tests
	flutter test

build: bump ## Build release APK (auto-bumps version)
	@echo "Building release APK..."
	flutter build apk --release
	@echo "APK built: $(BUILD_DIR)/app-release.apk"
	@ls -lh $(BUILD_DIR)/app-release.apk

build-no-bump: ## Build release APK without bumping version
	flutter build apk --release
	@ls -lh $(BUILD_DIR)/app-release.apk

release: build ## Create GitHub release with APK
	@echo "Creating GitHub release v$(NEW_VERSION)..."
	@if ! command -v gh &> /dev/null; then \
		echo "Error: GitHub CLI (gh) not installed. Install with: brew install gh"; \
		exit 1; \
	fi
	gh release create "v$(shell grep '^version:' $(PUBSPEC) | sed 's/version: //' | cut -d'+' -f1)" \
		$(BUILD_DIR)/app-release.apk \
		--title "Gozdar v$(shell grep '^version:' $(PUBSPEC) | sed 's/version: //' | cut -d'+' -f1)" \
		--notes "Release $(shell grep '^version:' $(PUBSPEC) | sed 's/version: //' | cut -d'+' -f1)"
	@echo "Release created!"

clean: ## Clean build artifacts
	flutter clean
	rm -rf $(BUILD_DIR)

# Run the app in development
run: ## Run app in development mode
	flutter run

# Build for all platforms
build-all: bump ## Build for Android and iOS
	flutter build apk --release
	flutter build ios --release --no-codesign
