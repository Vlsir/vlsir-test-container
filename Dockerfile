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

# Install NgSPICE
RUN apt-get update
RUN apt-get install -y ngspice iverilog curl

#? Install Rust
# RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | bash -s -- -y
# ENV PATH="${PATH}:$HOME/.cargo/env"

# Add Deadsnakes for later Python debugging
RUN apt install -y software-properties-common
RUN add-apt-repository -y ppa:deadsnakes/ppa

# Make user comfortable at home
WORKDIR /home