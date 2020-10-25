# --- HOW TO USE ---
#
# See `Makefile` for detailed instructions.
# Example usage:
#   (Windows x64, Vanilla Clang) ->  make PAUSE=never CC=clang CXX=clang++ CPP=cpp FORCED_FLAGS="-femulated-tls --target=x86_64-w64-windows-gnu" LDFLAGS=-pthread MODE=windows-x86_64 JOBS=4
#   (Windows x32, Vanilla Clang) ->  make PAUSE=never CC=clang CXX=clang++ CPP=cpp FORCED_FLAGS="-femulated-tls --target=i686-w64-windows-gnu" LDFLAGS=-pthread  MODE=windows-i686 JOBS=4
#   (Windows x64, MSYS2 Clang)   ->  make PAUSE=never CC=clang CXX=clang++ FORCED_FLAGS=-femulated-tls MODE=windows-x86_64 JOBS=4
#   (Windows x32, MSYS2 Clang)   ->  make PAUSE=never CC=clang CXX=clang++ FORCED_FLAGS=-femulated-tls MODE=windows-i686 JOBS=4
#   (Linux, Clang 11)            ->  make PAUSE=never CC=clang-11 CXX=clang++-11 MODE=linux JOBS=4
#
#   (Linux -> Windows x64, Clang, msys2_pacmake) ->  make PAUSE=never CC=win-clang CXX=win-clang++ CMAKE=win-cmake MODE=windows-x86_64 JOBS=4
#   (See https://github.com/HolyBlackCat/msys2-pacmake for details.)
# `-femulated-tls` is needed when using Clang with libstdc++, if atomics are used.

# --- DEPENDENCIES ---
#
# About SDL2:
#   On Windows, we rely on a prebuild SDL2.
#   On Linux we build it ourselves. According to `docs/README-linux.md`, you need following dependencies to have all the features:
#       sudo apt install build-essential mercurial make cmake autoconf automake libtool libasound2-dev libpulse-dev libaudio-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxi-dev libxinerama-dev libxxf86vm-dev libxss-dev libgl1-mesa-dev libdbus-1-dev libudev-dev libgles2-mesa-dev libegl1-mesa-dev libibus-1.0-dev fcitx-libs-dev libsamplerate0-dev libsndio-dev libwayland-dev libxkbcommon-dev wayland-protocols
#   The list in this comment was last updated at SDL 2.0.12.
#   Following changes were made compared to the list in the readme:
#       * Wayland libs (mentioned in the readme after the primary ones) were appended to the list.
#       * `libesd0-dev` and `libgles1-mesa-dev` were removed from the list, as they're not in Ubuntu 20.04 packages.
#       * `` was added to the list, otherwise I was getting error "error: unknown type name 'SDL_DBusContext'".
#
# About OpenAL:
#   On Windows we rely on the SDL2 backend. If any other backends happen to be detected, good.
#   On Linux we also use SDL2, but we explicitly disable everything else, to get rid of the dependencies.
#
# --- ADVICE ---
#
# When adding a library, check if it has any significant optional dependencies.
#   You might want to explicitly enable of disable all of them, to make library builds more reproducible.
#   E.g. if a library uses autotools, use `./configure --help` to figure out what optional dependencies it has.
#   Then use `--with-*` or `--without-*` to enable or disable each one.


# --- CONFIGURATION ---

# Required variables
override name := imp-re_deps_2020-10-25
override mode_list := windows-i686 windows-x86_64 linux

# Misc
override is_windows := $(findstring windows,$(MODE))


# -- Utility libraries --

# - Zlib
ifneq ($(is_windows),)
$(call Library,zlib,zlib-1.2.11.tar.gz,TarArchive,Custom,\
	make -f win32/Makefile.gcc --no-print-directory $(call escape,"CC=$(CC)" "CXX=$(CXX)" "CPP=$(CPP)" "CFLAGS=$(CFLAGS)" "CXXFLAGS=$(CXXFLAGS)" "LDFLAGS=$(LDFLAGS)") -j$(JOBS) __LOG__ && \
	make -f win32/Makefile.gcc --no-print-directory install "INCLUDE_PATH=$(prefix)/include" "LIBRARY_PATH=$(prefix)/lib" "BINARY_PATH=$(prefix)/bin" __LOG__)
else ifeq ($(MODE),linux)
$(call Library,zlib,zlib-1.2.11.tar.gz,TarArchive,Custom,\
	prefix="$(prefix)" ./configure __LOG__ && \
	$(configuring_done) && \
	make -j$(JOBS) __LOG__ && \
	make install __LOG__)
else ifneq ($(MODE),)
$(error Not sure how to build zlib for this mode. Please fix `config.mk`.)
endif

# - Freetype
$(call Library,freetype,freetype-2.10.2.tar.gz,TarArchive,ConfigureMake,\
	--with-zlib --without-bzip2 --without-png --without-harfbuzz)

# - Ogg
$(call Library,ogg,libogg-1.3.4.tar.gz,TarArchive,ConfigureMake)

# - Vorbis
$(call Library,vorbis,libvorbis-1.3.7.tar.gz,TarArchive,ConfigureMake)

# - Fmt
# Tests seem to be compiled but not run by default. Even compiling them takes a lot of time, so we disable them.
$(call Library,fmt,fmt-7.0.2.zip,ZipArchive,CMake,-DFMT_TEST=OFF)

# - Double-conversion
$(call Library,double-conversion,double-conversion-3.1.5+git-trunk-a54561b.tar.gz,TarArchive,CMake)


# -- Media frameworks --

# - SDL2
ifeq ($(MODE),windows-i686)
$(call Library,sdl2,SDL2-devel-2.0.12-mingw.tar.gz,TarArchive,Prebuilt,i686-w64-mingw32)
else ifeq ($(MODE),windows-x86_64)
$(call Library,sdl2,SDL2-devel-2.0.12-mingw.tar.gz,TarArchive,Prebuilt,x86_64-w64-mingw32)
else ifeq ($(MODE),linux)
# Note that we unset pkg-config variables, because they'd otherwise point to our target directory, and SDL relies on a lot of external dependencies.
$(call Library,sdl2,SDL2-2.0.12.tar.gz,TarArchive,ConfigureMake,`env;-uPKG_CONFIG_PATH;-uPKG_CONFIG_LIBDIR)
else ifneq ($(MODE),)
$(error Not sure how to build SDL2 for this mode. Please fix `config.mk`.)
endif

# - OpenAL
override openal_flags := -DALSOFT_EXAMPLES=FALSE
# Enable SDL2 backend.
override openal_flags += -DALSOFT_REQUIRE_SDL2=TRUE -DSDL2_LIBRARY=$(prefix)/lib/libSDL2.dll.a -DSDL2_INCLUDE_DIR=$(prefix)/include -DALSOFT_BACKEND_SDL2=TRUE
ifeq ($(is_windows),)
# On Linux, disable all the extra backends to make sure we only depend on SDL2.
# The list of backends was obtained by stopping the build after configuration, and looking at the CMake variables.
# We don't disable `ALSOFT_BACKEND_SDL2`, and also `ALSOFT_BACKEND_SDL2` (which is a backend that writes to a file, so it's harmless).
# The list of backends was last updated at OpenAL-soft 1.20.1.
override openal_flags += -DALSOFT_BACKEND_ALSA=FALSE -DALSOFT_BACKEND_OSS=FALSE -DALSOFT_BACKEND_PULSEAUDIO=FALSE -DALSOFT_BACKEND_SNDIO=FALSE
endif
$(call Library,openal,openal-soft-1.20.1.tar.bz2,TarArchive,CMake,$(openal_flags))

# - Bullet physics
# Disable unnecessary stuff.
# Note that cmake logs say that "BUILD_CLSOCKET BUILD_CPU_DEMOS BUILD_ENET" variables we set aren't "used".
# But even if we don't set them, they still appear in the cmake cache, so we set them just to be sure.
override bullet_flags := -DBUILD_BULLET2_DEMOS:BOOL=OFF -DBUILD_EXTRAS:BOOL=OFF -DBUILD_OPENGL3_DEMOS:BOOL=OFF \
	-DBUILD_UNIT_TESTS:BOOL=OFF -DBUILD_CLSOCKET:BOOL=OFF -DBUILD_CPU_DEMOS:BOOL=OFF -DBUILD_ENET:BOOL=OFF
# Use doubles instead of floats.
override bullet_flags += -DUSE_DOUBLE_PRECISION:BOOL=ON
# Disable shared libraries. This should be the default behavior (with the flags above), but we also set it for a good measure.
override bullet_flags += -DBUILD_SHARED_LIBS:BOOL=OFF
# This defaults to off if the makefile flavor is not exactly "Unix Makefiles", which is silly.
# That used to cause 'make install' to not install anything useful.
override bullet_flags += -DINSTALL_LIBS:BOOL=ON
# The `_no-examples` suffix on the archive indicates that `./examples` and `./data` directories were stripped from it.
# This decreases the archive size from 170+ mb to 10+ mb.
$(call Library,bullet-physics,bullet3-2.89_no-examples.tar.gz,TarArchive,CMake,$(bullet_flags))
