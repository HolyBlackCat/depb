# --- HOW TO USE ---
#
# See `Makefile` for detailed instructions.
# Example usage:
# (Windows x32, Clang) ->  make PAUSE=never CC=clang CXX=clang++ MODE=windows-i686 JOBS=4
# (Windows x64, Clang) ->  make PAUSE=never CC=clang CXX=clang++ MODE=windows-x86_64 JOBS=4
# (Linux, Clang 8)     ->  make PAUSE=never CC=clang-8 CXX=clang++-8 MODE=linux JOBS=4

# --- DEPENDENCIES ---
#
# -- Required --
# On Windows, OpenAL needs `dsound.h`.
#   If you're using MSYS2, get it by installing `mingw-w64-x86_64-wined3d` package.
#   If you downloaded MinGW-w64 separately, you should already have it.
#
# -- Optional --
# You probably want Doxygen for generating documentation.
#   On MSYS2 it comes in `mingw-w64-x86_64-doxygen` package.

# --- ADVICE ---
#
# When adding a library, check if it has any significant optional dependencies.
#   You might want to explicitly enable of disable all of them, to make library builds more reproducible.
#   E.g. if a library uses autotools, use `./configure --help` to figure out what optional dependencies it has.
#   Then use `--with-*` or `--without-*` to enable or disable each one.


# --- CONFIGURATION ---

# Required variables
override name := imp-re_deps_v1.0
override mode_list := windows-i686 windows-x86_64 linux

# Misc
override is_windows := $(findstring windows,$(MODE))

ifeq ($(MODE),linux)
override LDFLAGS := -Wl,-rpath=.
endif


# -- Utility libraries --

# - Zlib
ifneq ($(is_windows),)
$(call Library,zlib,zlib-1.2.11.tar.gz,TarArchive,Custom,\
	make -f win32/Makefile.gcc --no-print-directory "CC=$(CC)" "CXX=$(CXX)" "CFLAGS=$(CFLAGS)" "CXXFLAGS=$(CXXFLAGS)" "LDFLAGS=$(LDFLAGS)" -j$(JOBS) __LOG__ && \
	make -f win32/Makefile.gcc --no-print-directory install "INCLUDE_PATH=$(prefix)/include" "LIBRARY_PATH=$(prefix)/lib" "BINARY_PATH=$(prefix)/bin" __LOG__)
else ifeq ($(MODE),linux)
$(call Library,zlib,zlib-1.2.11.tar.gz,TarArchive,Custom,\
	prefix="$(prefix)" ./configure __LOG__ && \
	$(configuring_done) && \
	make -j$(JOBS) __LOG__ && \
	make install __LOG__)
else ifneq ($(MODE),)
$(error Not sure how to build sdl2 for this mode. Please fix `config.mk`.)
endif

# - Freetype
$(call Library,freetype,freetype-2.10.1.tar.gz,TarArchive,ConfigureMake,\
	--with-zlib --without-bzip2 --without-png --without-harfbuzz)

# - Ogg
$(call Library,ogg,libogg-1.3.3.tar.gz,TarArchive,ConfigureMake)

# - Vorbis
$(call Library,vorbis,libvorbis-1.3.6.tar.gz,TarArchive,ConfigureMake)

# - Fmt
$(call Library,fmt,fmt_master-2aae6b1-aug-13-2019.tar.gz,TarArchive,CMake)


# -- Media frameworks --

# - SDL2
ifeq ($(MODE),windows-i686)
$(call Library,sdl2,SDL2-devel-2.0.10-mingw.tar.gz,TarArchive,Prebuilt,i686-w64-mingw32)
else ifeq ($(MODE),windows-x86_64)
$(call Library,sdl2,SDL2-devel-2.0.10-mingw.tar.gz,TarArchive,Prebuilt,x86_64-w64-mingw32)
else ifeq ($(MODE),linux)
$(call Library,sdl2,SDL2-2.0.10.tar.gz,TarArchive,CMake)
else ifneq ($(MODE),)
$(error Not sure how to build sdl2 for this mode. Please fix `config.mk`.)
endif

# - OpenAL
override openal_flags :=
ifeq ($(MODE),windows-x86_64)
# We're on Windows. Make sure we're building with DirectSound backend.
override openal_dsound_header := /mingw64/x86_64-w64-mingw32/include/dsound.h
$(if $(wildcard $(openal_dsound_header)),,\
	$(error `$(notdir $(openal_dsound_header))` not found in `$(dir $(openal_dsound_header))`.\
	$(lf) If you're using MSYS2, go install `mingw-w64-x86_64-wined3d` package))
override openal_flags += -DALSOFT_REQUIRE_DSOUND=TRUE -DDSOUND_INCLUDE_DIR=$(dir $(openal_dsound_header))
else ifeq ($(MODE),linux)
# We're not on Windows, no extra flags needed.
else ifneq ($(MODE),)
$(error Not sure how to build openal for this mode. Please fix `config.mk`.)
endif
$(call Library,openal,openal-soft-1.19.1.tar.bz2,TarArchive,CMake,$(openal_flags))
