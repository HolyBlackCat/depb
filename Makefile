# --- HOW TO USE ---
#
# -- Build all libraries and archive the result --
# `make MODE=...`
# For the list of allowed modes, see `config.mk` or simply run `make` without extra flags.
# Also you should add `JOBS=4` to the flags. (Replace 4 with the number of threads.
#   The convetional `-j4` isn't going to work here.)
# To get a fully non-interactive build, add `PAUSE=never`.
# Also you might want to set `CC` and `CXX` to override the environment defaults.
# If you interrupt the build, you can safely resume it later. But any library that wasn't
#   built completely will be discarded and rebuilt.
#
# -- Clean the repo --
# `make clean`
# This cleans everything except for the source archives (in `./archives`)
#   and the archived results (`./*.zip`).
#
# -- Archive the sources --
# `make archive_sources`
# This creates an archive with all library sources.
#
#
# There is nothing more to see in this file.
# Go check `config.mk`.


# --- GLOBAL CONFIGURATION ---

# Disable parallel builds.
.NOTPARALLEL:

# Prevent recursive invocations of Make from using our flags.
# This fixes some really obscure bugs.
override _MAKEFLAGS := $(MAKEFLAGS)
undefine MAKEFLAGS

# Disable localized messages
override LANG :=
export LANG


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


# --- DEFINITIONS ---

# Some constants.
override space := $(strip) $(strip)
override comma := ,
override dollar := $
override define lf :=
$(strip)
$(strip)
endef


# --- CHECK ENVIRONMENT ---

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
override pause := bash -c 'read -s -n 1 -p "Press any key to continue . . ." && echo'
# - Functions
override native_path = $1
override dir_target_name = $1
override which = $(shell which $1 2>/dev/null || true)# Sic!


# --- LOGIC AND BUILD TEMPLATES ---

OUTPUT_DIR := output
SOURCE_DIR := archives
TMP_DIR := tmp
LOG_DIR := $(OUTPUT_DIR)/logs

ifeq ($(wildcard ./$(SOURCE_DIR)/*),)
$(error Library sources not found in `./$(SOURCE_DIR)`. Go download them from 'Releases' page on Github)
endif

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
PAUSE := sometimes
override PAUSE := $(strip $(PAUSE))

ifeq ($(PAUSE),never)
override maybe_pause := $(success)
override maybe_pause_hard := $(maybe_pause)
else ifeq ($(PAUSE),sometimes)
override maybe_pause := $(success)
override maybe_pause_hard := $(echo_lf) && $(pause) && $(echo_lf)
else ifeq ($(PAUSE),always)
override maybe_pause := $(echo_lf) && $(pause) && $(echo_lf)
override maybe_pause_hard := $(maybe_pause)
else
$(error Expected PAUSE to be one of: never, sometimes, always)
endif

override make_version := $(shell $(MAKE) --version)
ifneq ($(findstring mingw,$(make_version)),)
CMAKE_MAKEFILE_FLAVOR := "MinGW Makefiles"
else ifneq ($(findstring msys,$(make_version)),)
CMAKE_MAKEFILE_FLAVOR := "MSYS Makefiles"
else
CMAKE_MAKEFILE_FLAVOR := "Unix Makefiles"
endif

# Library pack name. Config file must override this.
override name = $(error Config file doesn't specify package name)

# Prints a short info about the build environment.
# You can redirect the output as usual.
# `grep -v InstalledDir` strips the installation directory from Clang output.
override echo_build_info = (echo 'name = $(name)' && echo 'MODE = $(MODE)' && echo && \
	((echo 'CC:' && $(CC) --version && echo && echo 'CXX:' && $(CXX) --version) | grep -v InstalledDir) && echo && \
	echo 'CFLAGS = $(CFLAGS)' && echo 'CXXFLAGS = $(CXXFLAGS)' && echo 'LDFLAGS = $(LDFLAGS)')

# $1 is the build mode.
# $2 is the log file name.
# $3 is the additional build parameters.
override generic_build = $(call Build_$1,$2,$(call most_nested_entry,$(TMP_DIR)),$3)

# A crude function to convert a path to the Windows style.
# `/c/foo/bar` -> `c:\foo\bar`
override to_windows_path = $(subst <, ,$(subst $(space),\,$(join $(subst /, ,$(subst $(space),<,$1)),:)))

# This command should hopefully fix paths in all pkg-config files.
# Better prefix it with `-` in case it can't find the directory.
# Warning! Correctly expanding the dollar symbol is tricky. Make sure it's expanded just enough times.
# Note that we use a separate regular expression to replace Windows paths (this was observed to be necessary for some libraries even under MSYS2, e.g. for libfmt).
# We could make sure it's used only on Windows, but eh.
override fix_pkgconfig_files := \
	find $(OUTPUT_DIR)/lib/pkgconfig -type f -name *.pc -exec sed \
	-e "s|$(prefix)|\$$$${prefix}|g" \
	-e "s|$(subst \,[\/],$(call to_windows_path,$(prefix)))|\$$$${prefix}|ig" \
	-e "s|^prefix=.*|prefix=$(prefix)|g" -i {} \;

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
.PRECIOUS: $4# Prevents deletion of the log on failure.
$4: override __MAKE_EXECUTE_COMMAND__ := $(subst __LOG__,>>"$(CURDIR)/$3" 2>&1,$(call Build_$7,$8))
$4: $2
	@$(call echo_lf)
	@$(call echo,--- NOW MAKING: $1)
	@$(call echo_lf)
	@$(call echo,Will write log to `$3`)
	@$(call rmfile,$3)
	@$(call rmdir,./$(TMP_DIR))
	@$(call mkdir,./$(TMP_DIR))
	@$(maybe_pause_hard)
	@$(call echo,Obtaining source... [$6])
	@$(call Unpack_$6,"$(SOURCE_DIR)/$5",>>"$(CURDIR)/$3" 2>&1)
	@$(maybe_pause)
	@$(call echo,Building... [$7])
	@$(MAKE) --no-print-directory -C $(TMP_DIR) -f $(CURDIR)/Makefile $(filter --trace,$(_MAKEFLAGS))
	@$(if $(wildcard $(SOURCE_DIR)/$1.pc),mkdir -p '$(prefix)/lib/pkgconfig' && cp -f '$(SOURCE_DIR)/$1.pc' '$(prefix)/lib/pkgconfig/')
	@-$(fix_pkgconfig_files)
	@$(maybe_pause)
	@$(call move,$3,$4)
	@$(call echo,Done. Moved log to `$4`)
endef

# Note the `|`. Without it, derived targets are always rebuilt.
override last_target := | __check_env

# $1 is the pretty library name.
override tmp_lib_log_name = $(LOG_DIR)/_incomplete.$1.log
override final_lib_log_name = $(LOG_DIR)/$1.log

# $1 is the pretty library name (no spaces please).
# $2 is the archive name.
# $3 is the unpack mode.
# $4 is the build mode.
# $5 (opt) is the extra build parameters.
# If the archive directory contains a `$1.pc` file, it will be used as a pkg-config file for this library.
override Library = \
	$(eval $(subst <dollar>,\$$$$$$$$,$(call target_template,$1,$(last_target),$(call tmp_lib_log_name,$1),$(call final_lib_log_name,$1),$2,$3,$4,$5))) \
	$(eval override last_target := $(call final_lib_log_name,$1))

# Unpack modes:
# $1 is the archive name.
# $2 is the log file name, written as `>>"/foo/foo.log" 2>&1`.
override Unpack_TarArchive = tar -C $(TMP_DIR) -x -f $1 $2
override Unpack_ZipArchive = unzip $1 -d $(TMP_DIR) $2

# You can use this in your build modes to signal that the configuration step is finished.
override configuring_done := $(call echo,Configuration finished$(comma) proceeding.) && $(maybe_pause)

# Replaces `$` with `<dollar>`.
# Each time you use `(C|CXX|LD)FLAGS` in a build command, it should be wrapped in `$(call escape,...)`.
override escape = $(subst $$,<dollar>,$1)

# Build modes:
# $1 is the additional parameters.
# __LOG__ (not a variable) is the log file name, written as `>>"/foo/foo.log"`.
# We can't put __LOG__ into a parameter, because then user wouldn't be able to use it in $1.
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
	$(call mkdir,_build) && \
	$(call cd,_build) && \
	cmake -Wno-dev $(call escape,-DCMAKE_C_COMPILER="$(CC)" -DCMAKE_CXX_COMPILER="$(CXX)" -DCMAKE_C_FLAGS="$(CFLAGS)" -DCMAKE_CXX_FLAGS="$(CXXFLAGS)" \
		-DCMAKE_EXE_LINKER_FLAGS="$(LDFLAGS)" -DCMAKE_MODULE_LINKER_FLAGS="$(LDFLAGS)" -DCMAKE_SHARED_LINKER_FLAGS="$(LDFLAGS)") \
		-DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$(prefix)" -DCMAKE_SYSTEM_PREFIX_PATH=$(prefix) $1 -G $(CMAKE_MAKEFILE_FLAVOR) .. __LOG__ && \
	$(configuring_done) && \
	$(MAKE) --no-print-directory -j$(JOBS) __LOG__ && \
	$(MAKE) --no-print-directory install __LOG__


# --- LOAD CONFIG ---

MODE :=
override MODE := $(strip $(MODE))

override CFLAGS :=
override CXXFLAGS :=
override LDFLAGS :=
export CFLAGS
export CXXFLAGS
export LDFLAGS

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

override build_info_file := $(LOG_DIR)/_buildinfo.txt

override final_archive_dir := $(name)
override final_archive := $(final_archive_dir)_$(MODE).tar.gz

override sources_archive_dir := $(name)_source-archives
override sources_archive := $(sources_archive_dir).tar.gz

.DEFAULT_GOAL := $(final_archive)

# Build all libraries.
$(final_archive): $(last_target)
	@$(call echo_lf)
	@$(call echo,--- PACKAGING)
	@$(maybe_pause_hard)
	@$(call echo_lf)
	@$(call rmfile,./$(final_archive))
	@tar -cz --exclude=.git --transform="s|$(OUTPUT_DIR)/\(.*\)|$(final_archive_dir)/\1|" -f $(final_archive) $(OUTPUT_DIR)/*
	@$(call echo,--- CLEANING UP)
	@$(call rmdir,./$(TMP_DIR))
	@$(call echo_lf)

# Clean everything, except archived source libraries and archived output.
.PHONY: clean
clean:
	@$(call rmdir,./$(OUTPUT_DIR))
	@$(call rmdir,./$(TMP_DIR))
	@$(call rmdir,./$(final_archive_dir))

# Add library sources and the rest of the current directory to an archive.
# This only works after `make clean`.
.PHONY: archive_sources
archive_sources:
	@$(call rmfile,./$(sources_archive))
	@tar -czf $(sources_archive) $(SOURCE_DIR)

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
	@$(call echo,PAUSE = $(PAUSE) (use `PAUSE=` to get a list of allowed values))
	@$(echo_lf)
	@$(call echo,MAKE = $(MAKE))
	@$(MAKE) --version
	@$(echo_lf)
	@$(call echo,CC = $(CC))
	@$(CC) --version
	@$(echo_lf)
	@$(call echo,CXX = $(CXX))
	@$(CXX) --version

# An internal target.
# Creates a log directory.
# Then, if it's a clean build, saves some information about the build environment.
# Otherwise makes sure that the environment didn't change too much since the first build.
# Then, in any case, pauses.
.PHONY: __check_env
__check_env: __prepare
ifeq ($(wildcard $(build_info_file)),)
	@$(call mkdir,./$(LOG_DIR))
	@$(echo_build_info) >>"$(build_info_file)"
else
	$(if $(strip $(shell $(echo_build_info) | cmp -s $(build_info_file) || echo foo)),$(info $(strip))$(error THE BUILD ENVIRONMENT HAS CHANGED. A CLEAN BUILD IS NECESSARY))
endif
	@$(maybe_pause_hard)


endif
