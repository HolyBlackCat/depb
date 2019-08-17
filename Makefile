# --- MAKEFILE CONFIGURATION ---

# Disable parallel builds.
.NOTPARALLEL:

# Prevent recursive invocations of Make from using our flags.
# This fixes some really obscure bugs.
override _MAKEFLAGS := $(MAKEFLAGS)
undefine MAKEFLAGS


# --- ALTERNATIVE  MAKEFILE MODES ---

# If this is non-null, this command is executed instead of doing anything else.
# In the command, `__BUILD_DIR__` is replaced with the build directory,
# which is assumed to be the most-nested subdirectory of the current directory.
__MAKE_EXECUTE_COMMAND__ ?=

ifneq ($(strip $(__MAKE_EXECUTE_COMMAND__)),)

# $1 is a directory. If it has a single element, appends that element to the path (recursively).
override most_nested_entry = $(call most_nested_entry_0,$1,$(wildcard $1/*))
override most_nested_entry_0 = $(if $(filter 1,$(words $2)),$(call most_nested_entry,$2),$1)

.PHONY: command
command:
	@$(subst __BUILD_DIR__,$(call most_nested_entry,$(CURDIR)),$(__MAKE_EXECUTE_COMMAND__))

else

# --- DEFAULT TARGET ---

all:


# --- DEFINITIONS ---

# Some constants.
override space := $(strip) $(strip)
override comma := ,
override dollar := $
override define lf :=
$(strip)
$(strip)
endef

# A recursive wildcard function.
# Source: https://stackoverflow.com/a/18258352/2752075
# Recursively searches a directory for all files matching a pattern.
# The first parameter is a directory, the second is a pattern.
# Example usage: SOURCES = $(call rwildcard, src, *.c *.cpp)
# This implementation differs from the original. It was changed to correctly handle directory names without trailing `/`.
override rwildcard=$(foreach d,$(wildcard $1/*),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))


# --- DETECT ENVIRONMENT ---

# Host OS.
ifeq ($(OS),Windows_NT)
HOST_OS ?= windows
else
HOST_OS ?= unix
endif

# Target OS.
TARGET_OS ?= $(HOST_OS)

# Make sure we're not in a Windows shell.
ifeq ($(shell echo "foo"),"foo")
$(error Can't operate in the native Windows shell. Go download MSYS2)
endif

# Shell commands.
# Example usage: $(call rmfile, bin/out.exe)
# - Utilities
override success := true
# - Shell commands
override cd = cd $1
override copy = cp -af $1 $2
override rmfile = rm -f $1
override rmdir = rm -rf $1
override mkdir = mkdir -p $1
override move = mv -f $1 $2
override touch = touch $1
override echo = echo '$(subst ','"'"',$1)'
override echo_lf := echo
override pause := read -s -n 1 -p "Press any key to continue . . ." && echo
# - Functions
override native_path = $1
override dir_target_name = $1
override which = $(shell which $1 2>/dev/null || true)# Sic!


# --- LOGIC AND BUILD TEMPLATES ---

OUTPUT_DIR := output
SOURCE_DIR := archives
TMP_DIR := tmp
LOG_DIR := $(OUTPUT_DIR)/logs

override prefix := $(CURDIR)/$(OUTPUT_DIR)

override PKG_CONFIG_PATH :=
export PKG_CONFIG_PATH
override PKG_CONFIG_LIBDIR := $(prefix)/lib/pkgconfig
export PKG_CONFIG_LIBDIR

CC ?= $(error Variable not specified: `CC`)
export CC
CXX ?= $(error Variable not specified: `CXX`)
export CXX

# The amount of parallel jobs to run.
JOBS := 1
override JOBS := $(strip $(JOBS))

# Whether we should pause after each step to let user examine the logs.
PAUSE := 1
override PAUSE := $(strip $(PAUSE))

ifeq ($(PAUSE),0)
override maybe_pause := $(success)
else ifeq ($(PAUSE),1)
override maybe_pause := $(echo_lf) && $(pause) && $(echo_lf)
else
$(error Expected PAUSE to be one 0 or 1)
endif

override make_version := $(shell $(MAKE) --version)
ifneq ($(findstring mingw,$(make_version)),)
CMAKE_MAKEFILE_FLAVOR := "MinGW Makefiles"
else ifneq ($(findstring msys,$(make_version)),)
CMAKE_MAKEFILE_FLAVOR := "MSYS Makefiles"
else
CMAKE_MAKEFILE_FLAVOR := "Unix Makefiles"
endif

# $1 is the build mode.
# $2 is the log file name.
# $3 is the additional build parameters.
override generic_build = $(call Build_$1,$2,$(call most_nested_entry,$(TMP_DIR)),$3)

# This command should hopefully fix paths in all pkg-config files.
# Better prefix it with `-` in case it can't find the directory.
# Warning! Correctly expanding the dollar symbol is tricky. Make sure it's expanded just enough times.
override fix_pkgconfig_files := find $(OUTPUT_DIR)/lib/pkgconfig -type f -name *.pc -exec sed -e "s|$(prefix)|\$$$${prefix}|g" -e "s|prefix=.*|prefix=$(prefix)|g" -i {} \;

# Each target overrides this with a build command.
override __MAKE_EXECUTE_COMMAND__ :=
export __MAKE_EXECUTE_COMMAND__

# $1 is the pretty library name.
# $2 is the parent target name.
# $3 is the temporary log file name.
# $4 is the final log file name.
# $5 is the archive name.
# $6 is the unpack mode.
# $7 is the build mode.
# $8 is additional build parameters.
override define target_template =
$4: override __MAKE_EXECUTE_COMMAND__ := $(subst __LOG__,>>"$(CURDIR)/$3",$(call Build_$7,$8))
$4: $2
	@$(call echo_lf)
	@$(call echo,--- NOW MAKING: $1)
	@$(call echo_lf)
	@$(call echo,Will write log to `$3`)
	@$(call rmfile,$3)
	@$(call rmdir,./$(TMP_DIR))
	@$(call mkdir,./$(TMP_DIR))
	@$(maybe_pause)
	@$(call echo,Obtaining source... [$6])
	@$(call Unpack_$6,>>"$(CURDIR)/$3","$(SOURCE_DIR)/$5")
	@$(maybe_pause)
	@$(call echo,Building... [$7])
	@$(MAKE) --no-print-directory -C $(TMP_DIR) -f $(CURDIR)/Makefile $(filter --trace,$(_MAKEFLAGS))
	@-$(fix_pkgconfig_files)
	@$(maybe_pause)
	@$(call move,$3,$4)
	@$(call echo,Done. Moved log to `$4`)
endef

# Note the `|`. Without it, targets that inherit from `__prepare` are always rebuilt.
override last_target := | __prepare

# $1 is the pretty library name.
override tmp_lib_log_name = $(LOG_DIR)/_incomplete.$1.log
override final_lib_log_name = $(LOG_DIR)/$1.log

# $1 is the pretty library name (no spaces please).
# $2 is the archive name.
# $3 is the unpack mode.
# $4 is the build mode.
# $5 (opt) is the extra build parameters.
override Library = \
	$(eval $(call target_template,$1,$(last_target),$(call tmp_lib_log_name,$1),$(call final_lib_log_name,$1),$2,$3,$4,$5)) \
	$(eval override last_target := $(call final_lib_log_name,$1))

# Unpack modes:
# $1 is the log file name, written as `>>"/foo/foo.log"`.
# $2 is the archive name.
override Unpack_TarGzArchive = tar -C $(TMP_DIR) -x -f $2 $1
override Unpack_ZipArchive = unzip $2 -d $(TMP_DIR) $1

# You can use this in your build modes to signal that the configuration step is finished.
override configuring_done := $(call echo,Configuration finished$(comma) proceeding.) && $(maybe_pause)

# Build modes:
# $1 is the additional parameters.
# __LOG__ (not a variable) is the log file name, written as `>>"/foo/foo.log"`.
# __BUILD_DIR__ (not a variable) is the build directory.
override Build_Prebuilt = \
	@$(call copy,"__BUILD_DIR__$(if $(strip $1),/$(strip $1))"/*,"$(prefix)") __LOG__
override Build_Custom = \
	$(call cd,"__BUILD_DIR__") && \
	$1
override Build_ConfigureMake = \
	$(call cd,"__BUILD_DIR__") && \
	./configure "--prefix=$(prefix)" $1 __LOG__ && \
	$(configuring_done) && \
	$(MAKE) --no-print-directory -j$(JOBS) __LOG__ && \
	$(MAKE) --no-print-directory install __LOG__
override Build_CMake = $(call cd,"__BUILD_DIR__") && \
	$(call mkdir,build) && \
	$(call cd,build) && \
	cmake -DCMAKE_C_COMPILER=$(CC) -DCMAKE_CXX_COMPILER=$(CXX) -DCMAKE_BUILD_TYPE=Release -G $(CMAKE_MAKEFILE_FLAVOR) .. __LOG__ && \
	$(MAKE) --no-print-directory -j$(JOBS) && \
	$(MAKE) --no-print-directory install __LOG__


# --- LOAD CONFIG ---

MODE :=
override MODE := $(strip $(MODE))

include config.mk

ifneq ($(MODE),)
ifneq ($(words $(MODE)),1)
$(error Invalid `MODE`. Expected one of: $(mode_list))
endif
ifeq ($(filter $(mode_list),$(MODE)),)
$(error Invalid `MODE`. Expected one of: $(mode_list))
endif
endif


# --- TARGETS ---

.PHONY: all
all: $(last_target)
	@$(call echo_lf)
	@$(call echo,--- CLEANING UP)
	@$(call rmdir,./$(TMP_DIR))
	@$(call echo_lf)
	@$(call echo,--- DONE)
	@$(call echo_lf)

.PHONY: clean
clean:
	@$(call rmdir,./$(OUTPUT_DIR))
	@$(call rmdir,./$(TMP_DIR))


.PHONY: here
here:
	@-$(subst $$$$,$,$(fix_pkgconfig_files))

# An internal target.
# Prints various info about the build configuration, and prepares things
.PHONY: __prepare
__prepare:
ifeq ($(MODE),)
	$(error Please specify `MODE`. One of: $(mode_list))
endif
	@$(if $(findstring $(MODE),-),$(error Please specify `MODE`. One of: $(mode_list)))
	@$(if $(findstring $(space),$(CURDIR)),$(info WARNING: Current path contains spaces. This could be problematic.))
	@$(echo_lf)
	@$(call echo,--- STATUS)
	@$(echo_lf)
	@$(call echo,Mode: $(MODE))
	@$(call echo,Target directory: $(prefix))
	@$(call echo,Makefile flavor: $(CMAKE_MAKEFILE_FLAVOR))
	@$(call echo,Parallel jobs: $(JOBS))
	@$(echo_lf)
	@$(call echo,PAUSE = $(PAUSE) ($(if $(findstring 0,$(PAUSE)),will run in non-interactive mode,will pause between actions)))
	@$(echo_lf)
	@$(call echo,MAKE = $(MAKE))
	@$(MAKE) --version
	@$(echo_lf)
	@$(call echo,CC = $(CC))
	@$(CC) --version
	@$(echo_lf)
	@$(call echo,CXX = $(CXX))
	@$(CXX) --version
	@$(maybe_pause)
	@$(call mkdir,./$(LOG_DIR))
	@$(call mkdir,./$(LOG_DIR))

endif
