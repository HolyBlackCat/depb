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

override mode_list := windows-x86_64 generic


# -- Utility libraries --

# - Zlib
ifeq ($(MODE),windows-x86_64)
$(call Library,zlib,zlib-1.2.11.tar.gz,TarGzArchive,Custom,\
	make -f win32/Makefile.gcc --no-print-directory "CC=$(CC)" "CXX=$(CXX)" __LOG__ && \
	make -f win32/Makefile.gcc --no-print-directory install "INCLUDE_PATH=$(prefix)/include" "LIBRARY_PATH=$(prefix)/lib" "BINARY_PATH=$(prefix)/bin" __LOG__)
else ifneq ($(MODE),)
$(error Not sure how to build zlib for this mode. Please fix `config.mk`.)
endif

# - Freetype
$(call Library,freetype,freetype-2.10.1.tar.gz,TarGzArchive,ConfigureMake,\
	--with-zlib --without-bzip2 --without-png --without-harfbuzz)

# - Ogg
$(call Library,ogg,libogg-1.3.3.tar.gz,TarGzArchive,ConfigureMake)

# - Vorbis
$(call Library,vorbis,libvorbis-1.3.6.tar.gz,TarGzArchive,ConfigureMake)

# - Fmt
$(call Library,fmt,fmt_master-2aae6b1-aug-13-2019.tar.gz,TarGzArchive,CMake)


# -- Media frameworks --

# - SDL2
ifeq ($(MODE),windows-x86_64)
$(call Library,sdl2,SDL2-devel-2.0.10-mingw.tar.gz,TarGzArchive,Prebuilt,x86_64-w64-mingw32)
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
else ifeq ($(MODE),generic)
# We're not on Windows, no extra flags needed.
else ifneq ($(MODE),)
$(error Not sure how to build openal for this mode. Please fix `config.mk`.)
endif
$(call Library,openal,openal-soft-1.19.1.tar.bz2,TarGzArchive,CMake,$(openal_flags))
