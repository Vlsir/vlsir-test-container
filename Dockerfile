# Start with black Ubuntu template
FROM ubuntu:latest
ARG XYCE_VERSION
ARG TRILINOS_VERSION

ENV TZ=America/Los_Angeles DEBIAN_FRONTEND=noninteractive PATH="${PATH}"

# The "folly" component currently fails if "fmt" is not explicitly installed first.
RUN apt-get update && apt-get install -y cmake build-essential m4 python-dev-is-python3 \
  git gfortran bison flex libfl-dev libfftw3-dev libsuitesparse-dev libopenblas-dev \
  liblapack-dev automake autoconf libtool python3-numpy python3-scipy

RUN git clone --branch $TRILINOS_VERSION --depth 1 https://github.com/trilinos/Trilinos/ /Trilinos
RUN git clone --branch $XYCE_VERSION --depth 1 https://github.com/Xyce/Xyce /Xyce

WORKDIR /Trilinos-build
RUN SRCDIR=/Trilinos; \
  ARCHDIR=/XyceLibs/Serial; \
  FLAGS="-O3 -fPIC"; \
  cmake \
  -G "Unix Makefiles" \
  -DCMAKE_C_COMPILER=gcc \
  -DCMAKE_CXX_COMPILER=g++ \
  -DCMAKE_Fortran_COMPILER=gfortran \
  -DCMAKE_CXX_FLAGS="$FLAGS" \
  -DCMAKE_C_FLAGS="$FLAGS" \
  -DCMAKE_Fortran_FLAGS="$FLAGS" \
  -DCMAKE_INSTALL_PREFIX=$ARCHDIR \
  -DCMAKE_MAKE_PROGRAM="make" \
  -DTrilinos_ENABLE_NOX=ON \
  -DNOX_ENABLE_LOCA=ON \
  -DTrilinos_ENABLE_EpetraExt=ON \
  -DEpetraExt_BUILD_BTF=ON \
  -DEpetraExt_BUILD_EXPERIMENTAL=ON \
  -DEpetraExt_BUILD_GRAPH_REORDERINGS=ON \
  -DTrilinos_ENABLE_TrilinosCouplings=ON \
  -DTrilinos_ENABLE_Ifpack=ON \
  -DTrilinos_ENABLE_Isorropia=ON \
  -DTrilinos_ENABLE_AztecOO=ON \
  -DTrilinos_ENABLE_Belos=ON \
  -DTrilinos_ENABLE_Teuchos=ON \
  -DTeuchos_ENABLE_COMPLEX=ON \
  -DTrilinos_ENABLE_Amesos=ON \
  -DAmesos_ENABLE_KLU=ON \
  -DTrilinos_ENABLE_Sacado=ON \
  -DTrilinos_ENABLE_Kokkos=OFF \
  -DTrilinos_ENABLE_ALL_OPTIONAL_PACKAGES=OFF \
  -DTrilinos_ENABLE_CXX11=ON \
  -DTPL_ENABLE_AMD=ON \
  -DAMD_LIBRARY_DIRS="/usr/lib" \
  -DTPL_AMD_INCLUDE_DIRS="/usr/include/suitesparse" \
  -DTPL_ENABLE_BLAS=ON \
  -DTPL_ENABLE_LAPACK=ON \
  $SRCDIR
RUN make -j$(nproc) && make install

WORKDIR /Xyce
RUN ./bootstrap

WORKDIR /Xyce-serial-build
RUN ../Xyce/configure ARCHDIR=/XyceLibs/Serial \
  CXXFLAGS="-O3 -std=c++11" \
  CPPFLAGS="-I/usr/include/suitesparse" \
  --prefix=/XyceInstall/Serial
RUN make -j$(nproc) && make install

#? Regression Testing for the thorough builder
# RUN /Xyce_Regression/TestScripts/run_xyce_regression \
#   --timelimit=60 \
#   --output=`pwd`/Xyce_Test \
#   --xyce_test="/Xyce_Regression" \
#   --resultfile=`pwd`/serial_results \
#   --taglist="+serial+nightly?noverbose-verbose?klu?fft" \
#   `pwd`/src/Xyce

# Add Xyce to PATH and clean installation
ENV PATH="/XyceInstall/Serial/bin:$PATH"
RUN rm -rf /Xyce
RUN rm -rf /Trilinos
RUN rm -rf /Xyce-serial-build
RUN rm -rf /Trilinos-build

# Install iVerilog
RUN apt-get update
RUN apt-get install -y iverilog

# Install ngspice 40
RUN apt-get install -y wget libreadline6-dev
WORKDIR /
RUN wget "https://sourceforge.net/projects/ngspice/files/ng-spice-rework/40/ngspice-40.tar.gz"
RUN tar -xzvf ngspice-40.tar.gz
RUN ls -a
WORKDIR /ngspice-40
RUN mkdir release
WORKDIR /ngspice-40/release
RUN ../configure --with-x --with-readline=yes --disable-debug
RUN make
RUN make install
RUN rm -rf /ngspice-40
WORKDIR /

# Magic
RUN git clone https://github.com/RTimothyEdwards/magic.git
RUN apt-get install -y tcsh csh m4 libx11-dev tcl-dev tk-dev \
  libcairo2-dev mesa-common-dev libncurses-dev libglu1-mesa-dev
WORKDIR /magic
RUN chmod +x ./configure
RUN ./configure
RUN make database/database.h
RUN make -j"$(nproc)"
RUN make install
WORKDIR /

# # Miniconda
# RUN apt-get update && apt-get install -y curl wget bzip2
# RUN curl -LO https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
# RUN bash Miniconda3-latest-Linux-x86_64.sh -b -p /opt/miniconda
# RUN rm Miniconda3-latest-Linux-x86_64.sh
# ENV PATH="/opt/miniconda/bin:${PATH}"
# RUN conda update -y conda

# Yosys
RUN apt-get install -y yosys

#######################################################################
# Compile iic-osic
#######################################################################
ARG IIC_OSIC_REPO_URL="https://github.com/iic-jku/iic-osic.git"
ARG IIC_OSIC_REPO_COMMIT="3fa99fb2e830226ec5763a11ec963fbecc653ec3"
ARG IIC_OSIC_NAME="iic-osic"
ADD scripts/install_iic_osic.sh install_iic_osic.sh
RUN bash install_iic_osic.sh

#######################################################################
# Create open_pdks (part of OpenLane)
#######################################################################
ARG OPEN_PDKS_REPO_URL="https://github.com/RTimothyEdwards/open_pdks"
ARG OPEN_PDKS_REPO_COMMIT="0c37b7c76527929abfbdbd214df4bffcd260bf50"
ARG OPEN_PDKS_NAME="open_pdks"
ENV PDK_ROOT=/foss/pdks
ADD scripts/install_volare.sh install_volare.sh
RUN bash install_volare.sh

#? Install Rust
# RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
# ENV PATH="${PATH}:$HOME/.cargo/env"

# Add Deadsnakes for later Python debugging
RUN apt install -y software-properties-common
RUN add-apt-repository -y ppa:deadsnakes/ppa

# Make user comfortable at home
WORKDIR /home