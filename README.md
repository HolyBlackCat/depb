## depb

This repository contains scripts for building dependencies for this [simple game engine](https://github.com/HolyBlackCat/imp-re) of mine.

### How to build

**Requirements**:

* **C/C++ compiler** (MSVC is not supported!)
* (on Windows only) **MSYS2 shell** (or equivalent; the default Windows shell is not supported)
* **make**
* **cmake**
* **tar**

**Steps:**

1. Go to [Releases](https://github.com/HolyBlackCat/depb/releases) page and **pick a release**.

2. **Consider using prebuilt libraries** if they are provided for your platform.

   Currently I only ship prebuilt libraries for `mingw-w64-x86_64` (built with MSYS2 Clang).

   If you decided to not use prebuilt libraries, then...

3. **Download** the release.

   You need two things:

   * **Build scripts** — Clone the repository and checkout a specific release, or get 'Source code' archive from the Releases page.

   * **Library sources** — Get `<version>_source-archives.tar.gz` from the Releases page.

   Unpack `<version>_source-archives.tar.gz` into the directory where the `Makefile` is. You should get following directory structure:

   ```
   ├── archives/
   │   └── ...
   ├── config.mk
   └── Makefile
   ```

4. **Build** everything.

   See comments at the beginning of `config.mk` for instructions.

   TL;DR:

   * Windows x64, Clang — `make PAUSE=never CC=clang CXX=clang++ MODE=windows-x86_64 JOBS=4`
   * Linux, Clang 9 —  `make PAUSE=never CC=clang-9 CXX=clang++-9 MODE=linux JOBS=4`
   * . . .

   If everything works out, you'll get a `.tar.gz` archive with the results.
