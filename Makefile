# Creates a dev package containing the Secretive app and CLI
# Usage:
#   make                      - Build unsigned (no keychain/Secure Enclave access)
#   make SIGN=1 TEAM=XXXXXX   - Build with development signing (enables keychain access)
#
# To find your team ID, run:
#   security find-identity -v -p codesigning
# Look for "Apple Development: Your Name (TEAMID)" - the TEAMID is in parentheses at the end

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

# Signing configuration
# SIGN_IDENTITY can be set to a specific identity, otherwise defaults to "Apple Development"
SIGN_IDENTITY ?= Apple Development

ifdef SIGN
    CODE_SIGN_ARGS := CODE_SIGNING_ALLOWED=YES CODE_SIGNING_REQUIRED=YES CODE_SIGN_STYLE=Automatic
    ifdef TEAM
        CODE_SIGN_ARGS += DEVELOPMENT_TEAM=$(TEAM)
    endif
else
    CODE_SIGN_ARGS := CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
endif

.PHONY: all clean

all: $(FINAL_PKG)
	@echo "Built: $(FINAL_PKG)"

# Validate TEAM is set when SIGN is enabled
ifdef SIGN
ifndef TEAM
$(error SIGN=1 requires TEAM=<your-team-id>. Find it with: security find-identity -v -p codesigning)
endif
endif

$(ARCHIVE):
	@mkdir -p $(BUILD_DIR)
	$(XCODEBUILD) -scheme Secretive -configuration Release $(CODE_SIGN_ARGS) -archivePath $(ARCHIVE) archive

$(APP_BUNDLE): $(ARCHIVE)
	@rm -rf $(APP_BUNDLE)
	cp -R $(ARCHIVE)/Products/Applications/Secretive.app $(APP_BUNDLE)

CLI_ENTITLEMENTS_SRC := $(PROJECT_DIR)/Sources/Packages/Sources/SecretiveCLI/SecretiveCLI.entitlements
CLI_ENTITLEMENTS     := $(BUILD_DIR)/SecretiveCLI.entitlements

$(CLI_BIN):
	@mkdir -p $(BUILD_DIR)
	swift build -c release --product SecretiveCLI --package-path $(PROJECT_DIR)/Sources/Packages
	cp $(PROJECT_DIR)/Sources/Packages/.build/release/SecretiveCLI $(CLI_BIN)
ifdef SIGN
	@echo "Signing CLI binary with team $(TEAM)..."
	@sed 's/$$(AppIdentifierPrefix)/$(TEAM)./g' $(CLI_ENTITLEMENTS_SRC) > $(CLI_ENTITLEMENTS)
	codesign --force --sign "$(SIGN_IDENTITY)" --entitlements $(CLI_ENTITLEMENTS) $(CLI_BIN)
endif

$(APP_ROOT): $(APP_BUNDLE)
	@rm -rf $(APP_ROOT)
	@mkdir -p $(APP_ROOT)
	cp -R $(APP_BUNDLE) $(APP_ROOT)/

$(CLI_ROOT): $(CLI_BIN)
	@rm -rf $(CLI_ROOT)
	@mkdir -p $(CLI_ROOT)
	cp $(CLI_BIN) $(CLI_ROOT)/secretive

$(APP_PKG): $(APP_ROOT)
	pkgbuild --root $(APP_ROOT) --install-location /Applications --identifier com.cursorinternal.Secretive.app --version 0.0.0-dev $(APP_PKG)

$(CLI_PKG): $(CLI_ROOT)
	pkgbuild --root $(CLI_ROOT) --install-location /usr/local/bin --identifier com.cursorinternal.Secretive.cli --version 0.0.0-dev $(CLI_PKG)

$(DIST):
	@mkdir -p $(BUILD_DIR)
	@printf '%s\n' \
	'<?xml version="1.0" encoding="utf-8"?>' \
	'<installer-gui-script minSpecVersion="2">' \
	'    <title>Secretive (Dev)</title>' \
	'    <organization>com.cursorinternal</organization>' \
	'    <domains enable_localSystem="true"/>' \
	'    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>' \
	'    <pkg-ref id="com.cursorinternal.Secretive.app"/>' \
	'    <pkg-ref id="com.cursorinternal.Secretive.cli"/>' \
	'    <choices-outline>' \
	'        <line choice="default">' \
	'            <line choice="com.cursorinternal.Secretive.app"/>' \
	'            <line choice="com.cursorinternal.Secretive.cli"/>' \
	'        </line>' \
	'    </choices-outline>' \
	'    <choice id="default"/>' \
	'    <choice id="com.cursorinternal.Secretive.app" visible="false">' \
	'        <pkg-ref id="com.cursorinternal.Secretive.app"/>' \
	'    </choice>' \
	'    <choice id="com.cursorinternal.Secretive.cli" visible="false">' \
	'        <pkg-ref id="com.cursorinternal.Secretive.cli"/>' \
	'    </choice>' \
	'    <pkg-ref id="com.cursorinternal.Secretive.app" version="0.0.0-dev" onConclusion="none">App.pkg</pkg-ref>' \
	'    <pkg-ref id="com.cursorinternal.Secretive.cli" version="0.0.0-dev" onConclusion="none">CLI.pkg</pkg-ref>' \
	'</installer-gui-script>' \
	> $(DIST)

$(FINAL_PKG): $(APP_PKG) $(CLI_PKG) $(DIST)
	productbuild --distribution $(DIST) --package-path $(BUILD_DIR) $(FINAL_PKG)
	@rm -rf $(ARCHIVE) $(APP_BUNDLE) $(APP_ROOT) $(APP_PKG) $(CLI_BIN) $(CLI_ROOT) $(CLI_PKG) $(DIST)

clean:
	rm -rf $(BUILD_DIR)
