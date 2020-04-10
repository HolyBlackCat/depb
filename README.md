## depb

This repository contains scripts for building dependencies for this [simple game engine](https://github.com/HolyBlackCat/imp-re) of mine.

### How to build

**Requirements**:

* **C/C++ compiler** (MSVC is not supported!)
* (on Windows only) **MSYS2 shell** (or equivalent; the default Windows shell is not supported)
* **make**
* **cmake**
* **tar**
* **unzip**

**Steps:**

1. Go to [Releases](https://github.com/HolyBlackCat/depb/releases) page and **pick a release**.

2. **Consider using prebuilt libraries** if they are provided for your platform.

   Currently I only ship prebuilt libraries for `mingw-w64-x86_64` (built with Clang, using libstdc++ provided by MSYS2).

   If you decide to not use prebuilt libraries, then...

3. **Download** the release.

   Go to the 'Releases' page and download `<version>_sources.tag.gz`.

4. **Build** everything.

   See comments at the beginning of `config.mk` for instructions.

   If everything works out, you'll get a `.tar.gz` archive with the results.
