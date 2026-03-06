PLUGIN_NAME  := claude-code
PLUGIN_VER   := 2025.03.06
ARCH         := x86_64

PLUGIN_PKG   := $(PLUGIN_NAME)-$(PLUGIN_VER)-$(ARCH)-1.txz

BUILD_DIR    := build
PLUGIN_STAGE := $(BUILD_DIR)/plugin-staging
PACKAGES_DIR := packages


.PHONY: all clean package-plugin checksums deploy

all: package-plugin checksums

package-plugin:
	@echo "Packaging plugin..."
	mkdir -p $(PLUGIN_STAGE) $(PACKAGES_DIR)
	cp -a source/* $(PLUGIN_STAGE)/
	chown root:root $(PLUGIN_STAGE)
	chmod 755 $(PLUGIN_STAGE)
	cd $(PLUGIN_STAGE) && makepkg -l y -c n ../$(PLUGIN_PKG)
	mv $(BUILD_DIR)/$(PLUGIN_PKG) $(PACKAGES_DIR)/

checksums: $(PACKAGES_DIR)/$(PLUGIN_PKG)
	@echo "Generating checksums..."
	@echo "Plugin:  $$(md5sum $(PACKAGES_DIR)/$(PLUGIN_PKG) | cut -d' ' -f1)"
	@echo ""
	@echo "Update claude-code.plg with this MD5 value."

clean:
	rm -rf $(BUILD_DIR)
	rm -rf $(PACKAGES_DIR)
