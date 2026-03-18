# CASA Spack Build Environment

Spack environment for CASA6 build dependencies on macOS (ARM64).

> **Note:** This build recipe was developed with LLM assistance (Claude) but has
> been debugged and verified to produce a working build through every stage of the
> CASA6 build pipeline (libsakura, casacore, casacpp, casatools, casatasks,
> casashell).

## Prerequisites

- **Xcode** (with command line tools)
- **Spack** (https://spack.io)
- **GCC 15** (provides gfortran)
- **grpc** and **protobuf** (via Homebrew or MacPorts)

Install via Homebrew or MacPorts:

```bash
# Homebrew
brew install gcc@15 grpc protobuf

# MacPorts
sudo port install gcc15 grpc protobuf3-cpp
```

## Setup

Register the custom package repo (one-time):

```bash
spack repo add /path/to/spack_env/repo
```

Create and install the environment:

```bash
spack env create casa-dev /path/to/spack_env/spack.yaml
spack env activate casa-dev
spack concretize
spack install
```

## Usage

Activate the environment before building CASA:

```bash
source ~/src/spack/share/spack/setup-env.sh
spack env activate casa-dev
```

Python packages (numpy, pip, build) are not managed by Spack.
Install them in a venv after activation:

If you are using the CASA Makefile, the venv created within there contains all
the Python dependencies. The venv Python binary is located in
/path/to/CASA/venv/bin/python

```bash
python -m venv .venv
source .venv/bin/activate
pip install numpy build
```

## Makefile

The included `Makefile` is a modified version of the upstream CASA6 Makefile with
the following changes for Spack/ARM64 compatibility:

- **Compiler selection**: Forces `cc`/`c++` (Apple Clang) instead of letting cmake
  pick up GCC from the Spack view
- **grpc cmake bypass**: Disables `find_package(gRPC)` to avoid cmake config
  conflicts between Spack-managed and system protobuf/abseil; falls back to pkgconfig
- **Library search paths**: Adds `-L$(CASAINSTALL)/lib` to linker flags so
  casacore's pkgconfig `-l` flags resolve correctly
- **System pkgconfig**: Auto-detects Homebrew or MacPorts prefix and appends it to
  `PKG_CONFIG_PATH` so grpc/protobuf `.pc` files are found

## Patches

The `patches/` directory contains patches to CASA source that are needed for
Homebrew/MacPorts compatibility:

- **casatools-setup-gcc-libdir.patch**: Fixes `casatools/setup.py` to find GCC
  runtime libs on both MacPorts (`lib/libgcc`) and Homebrew (`lib/gcc/current`).

Apply before building:

```bash
cd /path/to/casa6
git apply /path/to/spack_env/patches/casatools-setup-gcc-libdir.patch
```

## Custom Packages

The `repo/` directory contains patched Spack package recipes:

- **wcslib**: Adds `-headerpad_max_install_names` on macOS to fix `install_name_tool` failures during Spack relocation.

## External Dependencies

grpc and protobuf are managed externally (Homebrew/MacPorts) rather than built by
Spack. Spack-built abseil-cpp generates `.pc` files with CMake `SHELL:` generator
expression syntax that breaks pkgconfig on ARM64, causing bare x86 flags (`-maes`,
`-msse4.1`) to leak through without their `-Xarch_x86_64` guards. Using system
packages avoids this entirely.

## Known Issues

### `gfortran` not found after `spack env deactivate` / re-activate

`spack env deactivate` may strip `/opt/homebrew/bin` (or `/opt/local/bin`) from
your PATH and not restore it on subsequent `spack env activate`. This is a known
Spack bug ([spack#48391](https://github.com/spack/spack/issues/48391)).

**Workaround:** Always activate from a fresh shell rather than deactivating and
re-activating:

```bash
# Open a new terminal, then:
source ~/src/spack/share/spack/setup-env.sh
spack env activate casa-dev
```
