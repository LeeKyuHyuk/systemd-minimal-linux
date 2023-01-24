-include config.mk

export PARALLEL_JOBS := 16
export WORKSPACE_DIR := $(shell cd "$(dirname "$0")" && pwd)
export SOURCES_DIR := $(WORKSPACE_DIR)/sources
export SCRIPTS_DIR := $(WORKSPACE_DIR)/scripts
export SUPPORT_DIR := $(WORKSPACE_DIR)/support
export OUTPUT_DIR := $(WORKSPACE_DIR)/out
export BUILD_DIR := $(OUTPUT_DIR)/build
export TOOLS_DIR := $(OUTPUT_DIR)/tools
export ROOTFS_DIR := $(OUTPUT_DIR)/rootfs
export KERNEL_DIR := $(OUTPUT_DIR)/kernel
export IMAGES_DIR := $(OUTPUT_DIR)/image
export SYSROOT_DIR := $(TOOLS_DIR)/$(CONFIG_TARGET)/sysroot
export PATH := "$(TOOLS_DIR)/bin:$(TOOLS_DIR)/sbin:$(TOOLS_DIR)/usr/bin:$(TOOLS_DIR)/usr/sbin:$(PATH)"
export CONFIG_SITE := /dev/null
