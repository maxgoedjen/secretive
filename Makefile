# Creates a dev package containing the Secretive app and CLI
# Usage: make

PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
BUILD_DIR   := $(PROJECT_DIR)/build

ARCHIVE      := $(BUILD_DIR)/Archive.xcarchive
APP_BUNDLE   := $(BUILD_DIR)/Secretive.app
APP_ROOT     := $(BUILD_DIR)/AppPayload
APP_PKG      := $(BUILD_DIR)/App.pkg
CLI_BIN      := $(BUILD_DIR)/SecretiveCLI
CLI_ROOT     := $(BUILD_DIR)/CLIPayload
CLI_PKG      := $(BUILD_DIR)/CLI.pkg
DIST         := $(BUILD_DIR)/distribution.xml
FINAL_PKG    := $(BUILD_DIR)/Secretive-dev-unsigned.pkg

XCODEBUILD   := xcodebuild -project $(PROJECT_DIR)/Sources/Secretive.xcodeproj

.PHONY: all clean

all: $(FINAL_PKG)
	@echo "Built: $(FINAL_PKG)"

$(ARCHIVE):
	@mkdir -p $(BUILD_DIR)
	$(XCODEBUILD) -scheme Secretive -configuration Release CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" -archivePath $(ARCHIVE) archive

$(APP_BUNDLE): $(ARCHIVE)
	@rm -rf $(APP_BUNDLE)
	cp -R $(ARCHIVE)/Products/Applications/Secretive.app $(APP_BUNDLE)

$(CLI_BIN):
	@mkdir -p $(BUILD_DIR)
	cd $(PROJECT_DIR)/Sources/Packages && xcodebuild -scheme SecretiveCLI -configuration Release \
		-destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
		SYMROOT=$(BUILD_DIR)/xcode-cli build
	cp $(BUILD_DIR)/xcode-cli/Release/SecretiveCLI $(CLI_BIN)
	cp -R $(BUILD_DIR)/xcode-cli/Release/*.bundle $(BUILD_DIR)/ 2>/dev/null || true

$(APP_ROOT): $(APP_BUNDLE)
	@rm -rf $(APP_ROOT)
	@mkdir -p $(APP_ROOT)
	cp -R $(APP_BUNDLE) $(APP_ROOT)/

$(CLI_ROOT): $(CLI_BIN)
	@rm -rf $(CLI_ROOT)
	@mkdir -p $(CLI_ROOT)
	cp $(CLI_BIN) $(CLI_ROOT)/secretive

$(APP_PKG): $(APP_ROOT)
	pkgbuild --root $(APP_ROOT) --install-location /Applications --identifier com.maxgoedjen.Secretive.app --version 0.0.0-dev $(APP_PKG)

$(CLI_PKG): $(CLI_ROOT)
	pkgbuild --root $(CLI_ROOT) --install-location /usr/local/bin --identifier com.maxgoedjen.Secretive.cli --version 0.0.0-dev $(CLI_PKG)

$(DIST):
	@mkdir -p $(BUILD_DIR)
	@printf '%s\n' \
	'<?xml version="1.0" encoding="utf-8"?>' \
	'<installer-gui-script minSpecVersion="2">' \
	'    <title>Secretive (Dev)</title>' \
	'    <organization>com.maxgoedjen</organization>' \
	'    <domains enable_localSystem="true"/>' \
	'    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>' \
	'    <pkg-ref id="com.maxgoedjen.Secretive.app"/>' \
	'    <pkg-ref id="com.maxgoedjen.Secretive.cli"/>' \
	'    <choices-outline>' \
	'        <line choice="default">' \
	'            <line choice="com.maxgoedjen.Secretive.app"/>' \
	'            <line choice="com.maxgoedjen.Secretive.cli"/>' \
	'        </line>' \
	'    </choices-outline>' \
	'    <choice id="default"/>' \
	'    <choice id="com.maxgoedjen.Secretive.app" visible="false">' \
	'        <pkg-ref id="com.maxgoedjen.Secretive.app"/>' \
	'    </choice>' \
	'    <choice id="com.maxgoedjen.Secretive.cli" visible="false">' \
	'        <pkg-ref id="com.maxgoedjen.Secretive.cli"/>' \
	'    </choice>' \
	'    <pkg-ref id="com.maxgoedjen.Secretive.app" version="0.0.0-dev" onConclusion="none">App.pkg</pkg-ref>' \
	'    <pkg-ref id="com.maxgoedjen.Secretive.cli" version="0.0.0-dev" onConclusion="none">CLI.pkg</pkg-ref>' \
	'</installer-gui-script>' \
	> $(DIST)

$(FINAL_PKG): $(APP_PKG) $(CLI_PKG) $(DIST)
	productbuild --distribution $(DIST) --package-path $(BUILD_DIR) $(FINAL_PKG)

clean:
	rm -rf $(BUILD_DIR)
