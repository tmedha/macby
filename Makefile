.PHONY: generate build release clean

VERSION := $(shell grep 'MARKETING_VERSION' project.yml | head -1 | sed -E 's/.*"([^"]+)".*/\1/')
BUILD_DIR := build
APP := $(BUILD_DIR)/Release/Macby.app
DMG := $(BUILD_DIR)/Macby-$(VERSION).dmg

generate:
	xcodegen generate

build: generate
	xcodebuild -project Macby.xcodeproj -scheme Macby -configuration Release \
		CONFIGURATION_BUILD_DIR="$(CURDIR)/$(BUILD_DIR)/Release" build

# Requires create-dmg: brew install create-dmg
release: build
	rm -rf "$(BUILD_DIR)/dmg" "$(DMG)"
	mkdir -p "$(BUILD_DIR)/dmg"
	cp -R "$(APP)" "$(BUILD_DIR)/dmg/"
	create-dmg \
		--volname "Macby" \
		--window-size 540 380 \
		--icon-size 128 \
		--icon "Macby.app" 140 170 \
		--app-drop-link 400 170 \
		--hide-extension "Macby.app" \
		"$(DMG)" \
		"$(BUILD_DIR)/dmg" || true
	@test -f "$(DMG)" && echo "Built $(DMG)" || (echo "error: DMG was not created" && exit 1)

clean:
	rm -rf "$(BUILD_DIR)" Macby.xcodeproj
