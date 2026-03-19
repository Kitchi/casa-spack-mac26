##
# CASA6 Modular Makefile
# The intention of this file is to serve as a quick way to put together
# the different pieces of the modular build system to have a full build
# up to casashell with a single "make" command. The target users is
# developers with an understanding of the CASA build procedure.
#
# While the Makefile should work out of the box it is meant to be
# customized fo the individual developer needs. For instance, it
# will checkout the code from git, which might not be neccesary
# for some developers.
#
# To customize for a given branch build, please change the
# CASA_BRANCH variable below to the branch of interest.
# All the steps, from checking out the code to the build directories
# uses directories under ROOT, which by default points to the current
# working directory. This can be changed modriyfying the ROOT variable
# below.
#
# To get a full build from scratch, type "make firstcasa" in a
# directory which contains only this Makefile. Afterwards, the individual
# targets can be used to run different steps. Note that this Makefile
# to perform incremental builds of casacpp one would type
# "make casacpp-build" after the first "make firstcasa"
#
# This Makefile does not run any test.

# Path to spack_env/patches directory — must be set by user
PATCHDIR    ?=
ifneq ($(PATCHDIR),)
PATCHDIR    := $(realpath $(PATCHDIR))
endif

CASA_BRANCH         = master
CASA_REPO           = https://open-bitbucket.nrao.edu:/scm/casa/casa6.git
CASACORE_DATA_REPO  = ftp://ftp.astron.nl/outgoing/Measures/WSRT_Measures.ztar

CASA_BUILD_TYPE     = RelWithDebInfo
CASACORE_BUILD_TYPE = RelWithDebInfo

LIBSAKURA_VERSION   = 5.2.1
CASASHELL_BRANCH    = master

# Number of cores used for compilation (default: all available in the machine)
NCORES              = $(shell getconf _NPROCESSORS_ONLN)

# Fortran compiler (auto-detect gfortran or versioned variants)
FC ?= $(shell which gfortran 2>/dev/null || which gfortran-15 2>/dev/null || which gfortran-14 2>/dev/null || which gfortran-13 2>/dev/null)

# System prefix and pkg-config path (auto-detect Homebrew or MacPorts)
BREW_PREFIX := $(shell brew --prefix 2>/dev/null)
PORT_PREFIX := $(shell port -q version >/dev/null 2>&1 && echo /opt/local)
SYSTEM_PREFIX := $(if $(BREW_PREFIX),$(BREW_PREFIX),$(if $(PORT_PREFIX),$(PORT_PREFIX),))
SYSTEM_PKG_CONFIG_PATH := $(if $(SYSTEM_PREFIX),$(SYSTEM_PREFIX)/lib/pkgconfig,)

# GCC runtime library directory (for rpath to libgfortran etc.)
GCC_LIB_DIR := $(shell $(FC) -print-file-name=libgfortran.dylib 2>/dev/null | xargs dirname 2>/dev/null | xargs realpath 2>/dev/null)

# Spack view prefix (for libomp, etc.)
SPACK_VIEW := $(shell echo $$SPACK_ENV/.spack-env/view 2>/dev/null)

#oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo
#--------------------------------------------------------------------------------------------------------
#
# Package-level dir structure
ROOT        = $(shell pwd)

SRCDIR      = $(ROOT)/src
CASASRC     = $(SRCDIR)/casa6
CASAINSTALL = $(ROOT)/install
CASATESTDIR = $(ROOT)/test
CASAVENVDIR = $(ROOT)/venv
CASABUILD   = $(ROOT)/build
#INSTALLPREFIX  = $(CASAINSTALL)
#
# Common options to install artifacts of all packages in a single location
#
#INSTALLOPTS = -DCMAKE_INSTALL_PREFIX=$(INSTALLPREFIX) \
#		  -DCMAKE_INSTALL_BINDIR=sbin \
#		  -DCMAKE_INSTALL_LIBDIR=lib


#--------------------------------------------------------------------------------------------------------
#--------------------------------------------------------------------------------------------------------

check-patchdir:
	@if [ -z "$(PATCHDIR)" ]; then \
		echo "ERROR: PATCHDIR is not set. Set it to the spack_env/patches directory, e.g.:"; \
		echo "  make PATCHDIR=/path/to/spack_env/patches ..."; \
		exit 1; \
	fi
	@if [ ! -d "$(PATCHDIR)" ]; then \
		echo "ERROR: PATCHDIR=$(PATCHDIR) does not exist."; \
		exit 1; \
	fi

check-fc:
	@if [ -z "$(FC)" ]; then \
		echo ""; \
		echo "ERROR: No Fortran compiler found."; \
		echo ""; \
		echo "  gfortran is required but was not found in PATH."; \
		echo "  This can happen if 'spack env deactivate' stripped /opt/homebrew/bin"; \
		echo "  (or /opt/local/bin) from your PATH — a known Spack bug (spack#48391)."; \
		echo ""; \
		echo "  Fix: activate from a fresh shell rather than deactivate/re-activate:"; \
		echo ""; \
		echo "    # Open a new terminal, then:"; \
		echo "    source ~/src/spack/share/spack/setup-env.sh"; \
		echo "    spack env activate casa-dev"; \
		echo ""; \
		echo "  Or install gfortran if missing:"; \
		echo "    brew install gcc@15    # Homebrew"; \
		echo "    sudo port install gcc15  # MacPorts"; \
		echo ""; \
		exit 1; \
	fi

firstcasa: check-patchdir check-fc init casa-clone libsakura casacore casacpp venv-build casatools casatasks casashell
	@echo  ========================================
	@echo  CASA has been built successfully.
	@echo You can run it with:
	@echo $$ . $(CASAVENVDIR)/bin/activate
	@echo $$ python
	@echo \>\>\> import casatasks

casa: check-patchdir check-fc libsakura casacore casacpp venv-build casatools casatasks casashell

clean:
	rm -rf $(SRCDIR) $(CASASRC) $(CASABUILD) $(CASAINSTALL) $(CASATESTDIR) $(CASAVENVDIR)

init:
	mkdir -p $(SRCDIR) $(CASASRC) $(CASABUILD) $(CASAINSTALL) $(CASATESTDIR) $(CASAVENVDIR)

casa-clone: init
	git -C $(SRCDIR) clone -b $(CASA_BRANCH) --recursive $(CASA_REPO)

libsakura:
	curl -L https://github.com/tnakazato/sakura/archive/refs/tags/libsakura-$(LIBSAKURA_VERSION).tar.gz | gunzip | tar -xvf - -C $(SRCDIR)

	mkdir -p $(CASABUILD)/libsakura
	cmake  \
		-DCMAKE_C_COMPILER=cc \
		-DCMAKE_CXX_COMPILER=c++ \
		-DCMAKE_INSTALL_PREFIX=$(CASAINSTALL) \
		-DCMAKE_BUILD_TYPE=$(CASA_BUILD_TYPE) \
		-DBUILD_DOC:BOOL=OFF \
		-DPYTHON_BINDING:BOOL=OFF \
		-DSIMD_ARCH=GENERIC \
		-DENABLE_TEST:BOOL=OFF \
		-DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
		-DCMAKE_C_COMPILER_LAUNCHER=ccache \
		-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
		$(SRCDIR)/sakura-libsakura-$(LIBSAKURA_VERSION)/libsakura/ \
		-B $(CASABUILD)/libsakura

	$(MAKE) -C $(CASABUILD)/libsakura  install -j $(NCORES)


casacore: casacore-build casacore-configure

casacore-configure:
	if [ ! -d $(CASAINSTALL)/data ]; then \
		mkdir -p $(CASAINSTALL)/data ; \
		curl -L $(CASACORE_DATA_REPO) | gunzip | tar -xvf - -C $(CASAINSTALL)/data ; \
	fi

	mkdir -p $(CASABUILD)/casacore
	cd $(CASABUILD)/casacore
	cmake \
		-DCMAKE_C_COMPILER=cc \
		-DCMAKE_CXX_COMPILER=c++ \
		-DCMAKE_Fortran_COMPILER=$(FC) \
		-DCMAKE_CXX_FLAGS="-Qunused-arguments -flat_namespace" \
		-DCMAKE_INSTALL_PREFIX=$(CASAINSTALL) \
		-DDATA_DIR=$(CASAINSTALL)/data \
		-DCMAKE_BUILD_TYPE=$(CASACORE_BUILD_TYPE) \
		-DUSE_OPENMP=ON \
		-DOpenMP_ROOT=$(SPACK_VIEW) \
		-DUSE_THREADS=ON \
		-DBUILD_FFTPACK_DEPRECATED=ON \
		-DBUILD_TESTING=OFF \
		-DBUILD_PYTHON3=OFF \
		-DBUILD_DYSCO=ON \
		-DPORTABLE=ON \
		-DUSE_PCH=OFF \
		-DCMAKE_C_COMPILER_LAUNCHER=ccache \
		-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
		-DPRIVATE_LIBS="-framework Accelerate -lm -ldl -Wl,-rpath,$(GCC_LIB_DIR)" \
		$(CASASRC)/casatools/casacore \
		-B $(CASABUILD)/casacore

casacore-build : casacore-configure
	$(MAKE) -C $(CASABUILD)/casacore install -j $(NCORES)


casacpp: libsakura casacore casacpp-build

casacpp-needs-configure: $(CASABUILD)/casacpp/Makefile

casacpp-configure: clean_casacpp_build $(CASABUILD)/casacpp/Makefile

clean-casacpp-build:
	rm -rf $(CASABUILD)/casacpp

$(CASABUILD)/casacpp/Makefile: check-fc
	if [ -d $(CASABUILD)/casacpp ]; then rm -rf $(CASABUILD)/casacpp; fi
	mkdir -p $(CASABUILD)/casacpp
	PKG_CONFIG_PATH=$(CASAINSTALL)/lib/pkgconfig:$(SYSTEM_PKG_CONFIG_PATH) \
		cmake \
		-DCMAKE_C_COMPILER=cc \
		-DCMAKE_CXX_COMPILER=c++ \
		-DCMAKE_Fortran_COMPILER=$(FC) \
		-DCMAKE_CXX_FLAGS="-ffp-contract=off -isystem $(SYSTEM_PREFIX)/include" \
		-DCMAKE_INSTALL_PREFIX=$(CASAINSTALL) \
		-DCMAKE_PREFIX_PATH=$(CASAINSTALL) \
		-DCMAKE_SHARED_LINKER_FLAGS="-L$(CASAINSTALL)/lib" \
		-DCMAKE_EXE_LINKER_FLAGS="-L$(CASAINSTALL)/lib" \
		-DPKG_CONFIG_USE_CMAKE_PREFIX_PATH=$(CASAINSTALL) \
		-DCMAKE_DISABLE_FIND_PACKAGE_gRPC=ON \
		-DCMAKE_C_COMPILER_LAUNCHER=ccache \
		-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
		$(CASASRC)/casatools/src/code \
		-B $(CASABUILD)/casacpp


casacpp-build : casacpp-needs-configure
	$(MAKE) -C $(CASABUILD)/casacpp  install -j $(NCORES)

venv-build: $(CASAVENVDIR)/bin/activate

$(CASAVENVDIR)/bin/activate:
	-deactivate # Disable any running virtual environments
	python3 -m venv $(CASAVENVDIR)
	. $(CASAVENVDIR)/bin/activate

casatools-patch:
	@cd $(CASASRC) && \
		if grep -q 'lib/gcc/current' casatools/setup.py 2>/dev/null; then \
			echo "casatools patch already applied"; \
		else \
			echo "Applying casatools-setup-gcc-libdir.patch"; \
			patch -p1 --batch --ignore-whitespace < $(PATCHDIR)/casatools-setup-gcc-libdir.patch; \
		fi

casatools: casacpp casatools-patch casatools-wheel

casatools-wheel: venv-build
	if [ -d $(CASABUILD)/casatools ]; then rm -rf $(CASABUILD)/casatools; fi
	mkdir -p $(CASABUILD)/casatools
	if [ -d $(CASAINSTALL)/dist ]; then rm -rf $(CASAINSTALL)/dist; fi
	mkdir -p $(CASAINSTALL)/dist

	# Run the build in a venv
	# Disable any potentially running virtual environments beforehand
	-deactivate ; \
		. $(CASAVENVDIR)/bin/activate ; \
		pip install build ; \
		export CMAKE_BUILD_PARALLEL_LEVEL=$(NCORES) ; \
		cd $(CASABUILD)/casatools; CC=cc CXX=c++ FC=$(FC) PKG_CONFIG_PATH=$(CASAINSTALL)/lib/pkgconfig:$(SYSTEM_PKG_CONFIG_PATH) CMAKE_PREFIX_PATH=$(CASAINSTALL):$(SYSTEM_PREFIX) CXXFLAGS="-isystem $(SYSTEM_PREFIX)/include" LDFLAGS="-L$(CASAINSTALL)/lib -L$(SYSTEM_PREFIX)/lib -Wl,-rpath,$(CASAINSTALL)/lib" python3 -m build -o $(CASAINSTALL)/dist $(CASASRC)/casatools ; \
		pip uninstall -y casatools ; \
		pip install $(CASAINSTALL)/dist/casatools*whl ; \
		pip install casadata ; \
		deactivate

casatasks: casatools casatasks-wheel

casatasks-wheel: venv-build
	if [ -d $(CASABUILD)/casatasks ]; then rm -rf $(CASABUILD)/casatasks; fi
	mkdir -p $(CASABUILD)/casatasks

	# Run the build in a venv
	# Disable any potentially running virtual environments beforehand
	-deactivate ; \
		. $(CASAVENVDIR)/bin/activate ; \
		pip install --upgrade setuptools ; \
		pip install --upgrade wheel ; \
		mkdir -p $(HOME)/.casa/data ; \
		cd $(CASASRC)/casatasks ; \
		./setup.py bdist_wheel ; \
		pip uninstall -y casatasks ; \
		pip install $(CASASRC)/casatasks/dist/casatasks*.whl

casashell: casatasks casashell-wheel

casashell-wheel: venv-build
	if [ -d $(SRCDIR)/casashell ]; then rm -rf $(SRCDIR)/casashell; fi
	git -C $(SRCDIR) clone -b $(CASASHELL_BRANCH) --recursive https://open-bitbucket.nrao.edu/scm/casa/casashell.git

	# Run the build in a venv
	# Disable any potentially running virtual environments beforehand
	-deactivate ; \
		. $(CASAVENVDIR)/bin/activate ; \
		cd $(SRCDIR)/casashell ; \
		./setup.py bdist_wheel ; \
		pip uninstall -y casashell ; \
		pip install $(SRCDIR)/casashell/dist/casashell*whl ; \
		\cp -f $(SRCDIR)/casashell/dist/casashell*whl $(CASAINSTALL)/dist

# end
