# Procedure for adding/updating autotools (configure && make) packages:
#   Run `./configure --help` and figure out all optional dependencies.
#   Specify `--with-*` or `--without-*` for each dependency.
#   That prevents automatic dependency detection, which makes library builds more reproducible.


override mode_list := windows-x86_64 generic

# Begin library list
ifeq ($(MODE),windows-x86_64)
$(call Library,zlib,zlib-1.2.11.tar.gz,TarGzArchive,Custom,\
	make -f win32/Makefile.gcc --no-print-directory "CC=$(CC)" "CXX=$(CXX)" __LOG__ && \
	make -f win32/Makefile.gcc --no-print-directory install "INCLUDE_PATH=$(prefix)/include" "LIBRARY_PATH=$(prefix)/lib" "BINARY_PATH=$(prefix)/bin" __LOG__)
else ifneq ($(MODE),)
$(error Not sure how to build zlib for this mode. Please fix `config.mk`.)
endif

$(call Library,freetype,freetype-2.10.1.tar.gz,TarGzArchive,ConfigureMake,\
	--with-zlib --without-bzip2 --without-png --without-harfbuzz)
