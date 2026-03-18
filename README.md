# CASA Spack Build Environment

Spack environment for CASA6 build dependencies on macOS (ARM64).

## Prerequisites

- **Xcode** (with command line tools)
- **Spack** (https://spack.io)
- **GCC 15** (provides gfortran)

Install GCC via Homebrew or MacPorts:

```bash
# Homebrew
brew install gcc@15

# MacPorts
sudo port install gcc15
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

## Custom Packages

The `repo/` directory contains patched Spack package recipes:

- **wcslib**: Adds `-headerpad_max_install_names` on macOS to fix `install_name_tool` failures during Spack relocation.
