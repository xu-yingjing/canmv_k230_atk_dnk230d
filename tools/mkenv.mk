export SDK_TOOLCHAIN_DIR?=$(shell echo $$HOME)/.kendryte/k230_toolchains
export SDK_TOOLS_DIR=$(SDK_SRC_ROOT_DIR)/tools

# Default target
.DEFAULT_GOAL := all

# Strip quotes and then whitespaces
qstrip = $(strip $(subst ",,$(1)))

define check_build_dir
$(shell \
  if [ ! -d $(1) ]; then \
    mkdir -p $(1); \
  fi; \
)
endef

define del_mark
$(shell find $(SDK_SRC_ROOT_DIR) -type f -name ".parse_config" | xargs rm -rf {})
$(shell find $(SDK_SRC_ROOT_DIR) -type f -name ".mpp_built" | xargs rm -rf {})
$(shell find $(SDK_SRC_ROOT_DIR) -type f -name ".mpp_samples" | xargs rm -rf {})
endef

# Do not print "Entering directory ...",
# but we want to display it when entering to the output directory
# so that IDEs/editors are able to understand relative filenames.
MAKEFLAGS += --no-print-directory

JOBS := $(shell ps -o args= $(MAKEPPID) | grep -o -E -- '-j[0-9]+' | head -n 1 | cut -c3-)
ifneq ($(JOBS),)
  ifneq ($(JOBS),1)
    $(error not support parallel build now)
  endif
endif

ifeq ($(shell curl --output /dev/null --silent --head --fail https://ai.b-bug.org/k230/ && echo $$?),0)
  NATIVE_BUILD = 1
else
  NATIVE_BUILD = 0
endif

export NATIVE_BUILD

# Check if 'bear' command exists
BEAR_EXISTS := $(shell command -v bear >/dev/null 2>&1 && echo yes || echo no)

PARALLEL ?= $(shell if command -v nproc > /dev/null 2>&1; then nproc; \
            elif [ -f /proc/cpuinfo ]; then grep -c '^processor' /proc/cpuinfo; \
            elif command -v sysctl > /dev/null 2>&1; then sysctl -n hw.ncpu; \
            else echo 1; fi)

export NCPUS?=$(PARALLEL)

CONFIG_SDK_ENABLE_CANMV ?= n

# Variable to hold the extracted part of xxx_defconfig
def_config :=$(filter %_defconfig,$(MAKECMDGOALS))
# Extract the variable part xxx from xxx_defconfig
ifneq ($(def_config),)
  ifeq ($(shell if [ -f $(SDK_SRC_ROOT_DIR)/configs/$(def_config) ]; then echo 1; else echo 0; fi;), 0)
    $(error "Please specify a valid CONFIG")
  endif
  CONFIG_BOARD := $(patsubst %_defconfig,%,$(def_config))
else
  -include $(SDK_SRC_ROOT_DIR)/.config
endif

export CONFIG_SDK_ENABLE_CANMV

ifeq ($(CONFIG_BOARD),)
  $(error "Please run make xxx_defconfig first")
endif

export SDK_DEFCONFIG=$(patsubst %,%_defconfig,$(call qstrip,$(CONFIG_BOARD)))

export SDK_BOARDS_DIR=$(SDK_SRC_ROOT_DIR)/boards
export SDK_BOARD_DIR=$(SDK_BOARDS_DIR)/$(call qstrip,$(CONFIG_BOARD))

export SDK_OPENSBI_SRC_DIR=$(SDK_SRC_ROOT_DIR)/src/opensbi
export SDK_RTSMART_SRC_DIR=$(SDK_SRC_ROOT_DIR)/src/rtsmart
export SDK_UBOOT_SRC_DIR=$(SDK_SRC_ROOT_DIR)/src/uboot
export SDK_CANMV_SRC_DIR=$(SDK_SRC_ROOT_DIR)/src/canmv
export SDK_APPS_SRC_DIR=$(SDK_SRC_ROOT_DIR)/src/applications

export SDK_BUILD_DIR=$(SDK_SRC_ROOT_DIR)/output/$(call qstrip,$(CONFIG_BOARD))

export SDK_OPENSBI_BUILD_DIR=$(SDK_BUILD_DIR)/opensbi
export SDK_RTSMART_BUILD_DIR=$(SDK_BUILD_DIR)/rtsmart
export SDK_UBOOT_BUILD_DIR=$(SDK_BUILD_DIR)/uboot
export SDK_CANMV_BUILD_DIR=$(SDK_BUILD_DIR)/canmv
export SDK_APPS_BUILD_DIR=$(SDK_BUILD_DIR)/applications

export SDK_BUILD_IMAGES_DIR=$(SDK_BUILD_DIR)/images

$(call check_build_dir, $(SDK_BUILD_IMAGES_DIR))

$(call check_build_dir, $(SDK_OPENSBI_BUILD_DIR))
$(call check_build_dir, $(SDK_RTSMART_BUILD_DIR))
$(call check_build_dir, $(SDK_UBOOT_BUILD_DIR))
$(call check_build_dir, $(SDK_CANMV_BUILD_DIR))
$(call check_build_dir, $(SDK_APPS_BUILD_DIR))

$(call check_build_dir, $(SDK_TOOLCHAIN_DIR))

export MKENV_INCLUDED = 1
