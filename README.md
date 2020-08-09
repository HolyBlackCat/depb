## depb

This repository contains scripts for building dependencies for this [simple game engine](https://github.com/HolyBlackCat/imp-re) of mine.

### How to build

**Requirements**:

* **C/C++ compiler** (MSVC is not supported!)
* (on Windows only) **MSYS2 shell** (or equivalent; the default Windows shell is not supported)
* **`make`**, **`cmake`**, **`tar`**, **`unzip`**
* **Dependencies** listed in the comments at the beginning of `config.mk`.

**Steps:**

1. Go to [Releases](https://github.com/HolyBlackCat/depb/releases) page and **pick a release**.

2. **Download** it: `<version>_sources.tag.gz`.

4. **Build** everything by running `make`.

   See comments at the beginning of `config.mk` for the exact flags you need to pass to `make`.

   If everything works out, you'll get a `<version>_prebuilt_<target>.tar.gz` archive with the results.
