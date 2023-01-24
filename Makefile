include settings.mk

.PHONY: all toolchain clean

all:
	@make clean toolchain rootfs kernel image

toolchain:
	@$(SCRIPTS_DIR)/toolchain.sh

rootfs:
	@$(SCRIPTS_DIR)/root-file-system.sh

kernel:
	@$(SCRIPTS_DIR)/kernel.sh

image:
	@$(SCRIPTS_DIR)/image.sh

clean:
	@rm -rf out

download:
	@wget -c -i wget-list -P $(SOURCES_DIR)
