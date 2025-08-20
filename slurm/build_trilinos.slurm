#!/bin/bash
#SBATCH --job-name=trilinos_parallel_netcdf
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=24G
#SBATCH --time=08:00:00
#SBATCH --output=./output_logs/trilinos_parallel_netcdf_%j.out
#SBATCH --error=./output_logs/trilinos_parallel_netcdf_%j.err

echo "=== Building Trilinos with Parallel NetCDF ==="
echo "Started at $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Running on node: $(hostname)"
echo "Current directory: $(pwd)"

# Set up paths - PORTABLE using SLURM submit directory
BASE_DIR="${SLURM_SUBMIT_DIR}"

# Load only the basic compiler toolchain
echo "Loading base modules..."
module purge
module load compiler/GCC/13.2.0
module load mpi/OpenMPI/4.1.6-GCC-13.2.0
module load devel/CMake/3.27.6-GCCcore-13.2.0
module load devel/Boost/1.83.0-GCC-13.2.0
module load numlib/OpenBLAS/0.3.24-GCC-13.2.0

# Set compiler variables
export CC=mpicc
export CXX=mpicxx
export FC=mpif90
export F77=mpif90

# IMPORTANT: Source the parallel NetCDF environment
echo "=== Sourcing Parallel NetCDF Environment ==="
source "$BASE_DIR/software/install/setup_parallel_netcdf_env.sh"

# Explicitly set NetCDF environment (should be set by sourcing, but making sure)
export NETCDF_ROOT="$BASE_DIR/software/install"
export HDF5_ROOT="$BASE_DIR/software/install"
export PATH="$NETCDF_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$NETCDF_ROOT/lib:$LD_LIBRARY_PATH"
export CMAKE_PREFIX_PATH="$NETCDF_ROOT:$CMAKE_PREFIX_PATH"

echo "=== Environment Check ==="
echo "CC: $CC"
echo "CXX: $CXX"
echo "FC: $FC"
echo "OpenMPI: $EBROOTOPENMPI"
echo "Boost: $EBROOTBOOST"
echo "OpenBLAS: $EBROOTOPENBLAS"
echo "NetCDF: $NETCDF_ROOT"

# Verify NetCDF installation and parallel support
echo "=== Verifying NetCDF Installation ==="
echo "nc-config location: $(which nc-config)"
if [ -f "$NETCDF_ROOT/bin/nc-config" ]; then
    echo "NetCDF version:"
    $NETCDF_ROOT/bin/nc-config --version
    echo "HDF5 support:"
    $NETCDF_ROOT/bin/nc-config --has-hdf5
    echo "Parallel support:"
    $NETCDF_ROOT/bin/nc-config --has-parallel
    echo "NetCDF configuration:"
    $NETCDF_ROOT/bin/nc-config --all
else
    echo "ERROR: NetCDF not found at $NETCDF_ROOT"
    exit 1
fi

# Check if parallel support is enabled
PARALLEL_SUPPORT=$($NETCDF_ROOT/bin/nc-config --has-parallel)
echo "NetCDF parallel support result: '$PARALLEL_SUPPORT'"
if [ "$PARALLEL_SUPPORT" != "yes" ]; then
    echo "ERROR: NetCDF does not have parallel support enabled!"
    echo "Expected 'yes', got '$PARALLEL_SUPPORT'"
    echo "You may need to rebuild NetCDF with --enable-parallel-tests"
    exit 1
fi

# Set up Trilinos paths
TRILINOS_SOURCE_DIR="$BASE_DIR/software/src/Trilinos-trilinos-release-13-4-1"
TRILINOS_BUILD_DIR="$BASE_DIR/software/build/trilinos"
TRILINOS_INSTALL_DIR="$BASE_DIR/software/install/trilinos"

echo "=== Trilinos Directory Setup ==="
echo "Source: $TRILINOS_SOURCE_DIR"
echo "Build: $TRILINOS_BUILD_DIR"
echo "Install: $TRILINOS_INSTALL_DIR"

if [ ! -d "$TRILINOS_SOURCE_DIR" ]; then
    echo "ERROR: Trilinos source not found!"
    echo "Expected: $TRILINOS_SOURCE_DIR"
    ls -la "$BASE_DIR/software/src/"
    exit 1
fi

# Create and navigate to build directory
mkdir -p "$TRILINOS_BUILD_DIR"
cd "$TRILINOS_BUILD_DIR"

# Clean previous build safely
echo "Cleaning previous build..."
echo "Current directory: $(pwd)"
echo "Expected directory: $TRILINOS_BUILD_DIR"
if [ "$(pwd)" = "$TRILINOS_BUILD_DIR" ] && [[ "$(pwd)" == *"/software/build/trilinos" ]]; then
    echo "Safe to clean - removing CMake files and build artifacts"
    rm -rf CMakeCache.txt CMakeFiles/ Makefile *.cmake install_manifest.txt
else
    echo "ERROR: Directory mismatch. Not cleaning to prevent data loss."
    echo "Current: $(pwd)"
    echo "Expected: $TRILINOS_BUILD_DIR"
    exit 1
fi

# Configure Trilinos with parallel NetCDF
echo "--- Configuring Trilinos with SEACAS/ExodusII support (PARALLEL NetCDF) ---"
cmake \
  -D CMAKE_INSTALL_PREFIX=$TRILINOS_INSTALL_DIR \
  -D CMAKE_BUILD_TYPE=RELEASE \
  -D CMAKE_CXX_FLAGS="-O3 -std=c++14" \
  -D CMAKE_C_FLAGS="-O3" \
  -D CMAKE_Fortran_FLAGS="-O3" \
  -D TPL_ENABLE_MPI=ON \
  -D MPI_BASE_DIR=$EBROOTOPENMPI \
  -D CMAKE_CXX_COMPILER=mpicxx \
  -D CMAKE_C_COMPILER=mpicc \
  -D CMAKE_Fortran_COMPILER=mpif90 \
  -D TPL_BLAS_LIBRARIES="$EBROOTOPENBLAS/lib/libopenblas.so" \
  -D TPL_LAPACK_LIBRARIES="$EBROOTOPENBLAS/lib/libopenblas.so" \
  -D TPL_ENABLE_Boost=ON \
  -D Boost_INCLUDE_DIRS=$EBROOTBOOST/include \
  -D Boost_LIBRARY_DIRS=$EBROOTBOOST/lib \
  -D TPL_ENABLE_Netcdf=ON \
  -D Netcdf_ROOT="$NETCDF_ROOT" \
  -D Netcdf_INCLUDE_DIRS="$NETCDF_ROOT/include" \
  -D Netcdf_LIBRARY_DIRS="$NETCDF_ROOT/lib" \
  -D TPL_ENABLE_HDF5=ON \
  -D HDF5_ROOT="$HDF5_ROOT" \
  -D HDF5_INCLUDE_DIRS="$HDF5_ROOT/include" \
  -D HDF5_LIBRARY_DIRS="$HDF5_ROOT/lib" \
  -D Trilinos_ENABLE_ALL_PACKAGES=OFF \
  -D Trilinos_ENABLE_Teuchos=ON \
  -D Trilinos_ENABLE_Shards=ON \
  -D Trilinos_ENABLE_Sacado=ON \
  -D Trilinos_ENABLE_Epetra=ON \
  -D Trilinos_ENABLE_EpetraExt=ON \
  -D Trilinos_ENABLE_Ifpack=ON \
  -D Trilinos_ENABLE_AztecOO=ON \
  -D Trilinos_ENABLE_Amesos=ON \
  -D Trilinos_ENABLE_Anasazi=ON \
  -D Trilinos_ENABLE_Belos=ON \
  -D Trilinos_ENABLE_ML=ON \
  -D Trilinos_ENABLE_Intrepid=ON \
  -D Trilinos_ENABLE_NOX=ON \
  -D Trilinos_ENABLE_Stratimikos=ON \
  -D Trilinos_ENABLE_Thyra=ON \
  -D Trilinos_ENABLE_Rythmos=ON \
  -D Trilinos_ENABLE_Zoltan=ON \
  -D Trilinos_ENABLE_SEACAS=ON \
  -D Trilinos_ENABLE_SEACASExodus=ON \
  -D Trilinos_ENABLE_SEACASIoss=ON \
  -D Trilinos_ENABLE_SEACASExo2mat=OFF \
  -D Trilinos_ENABLE_Pamgen=ON \
  -D Trilinos_ENABLE_Kokkos=OFF \
  -D Trilinos_ENABLE_STK=OFF \
  -D Trilinos_ENABLE_Phalanx=OFF \
  -D Trilinos_ENABLE_TriKota=OFF \
  -D Trilinos_ENABLE_FEI=OFF \
  -D TPL_ENABLE_X11=OFF \
  -D TPL_ENABLE_Matio=OFF \
  -D Trilinos_ENABLE_TESTS=OFF \
  -D Trilinos_ENABLE_EXAMPLES=OFF \
  $TRILINOS_SOURCE_DIR

# Check if configuration succeeded
CONFIG_STATUS=$?
echo "Configuration exit status: $CONFIG_STATUS"

if [ $CONFIG_STATUS -eq 0 ]; then
    echo "--- Trilinos configuration successful at $(date) ---"
    echo "--- Starting Trilinos build ---"
    
    # Build Trilinos
    make -j${SLURM_CPUS_PER_TASK}
    BUILD_STATUS=$?
    echo "Build exit status: $BUILD_STATUS"
    
    if [ $BUILD_STATUS -eq 0 ]; then
        echo "--- Trilinos build successful at $(date) ---"
        echo "--- Installing Trilinos ---"
        
        # Create install directory
        mkdir -p "$TRILINOS_INSTALL_DIR"
        
        # Install Trilinos
        make install
        INSTALL_STATUS=$?
        echo "Install exit status: $INSTALL_STATUS"
        
        if [ $INSTALL_STATUS -eq 0 ]; then
            echo "=== INSTALLATION SUCCESSFUL ==="
            echo "Trilinos with SEACAS (parallel NetCDF) installed to: $TRILINOS_INSTALL_DIR"
            
            # Verify installation
            echo "=== Verifying Installation ==="
            ls -la "$TRILINOS_INSTALL_DIR/"
            
            if [ -f "$TRILINOS_INSTALL_DIR/lib/cmake/Trilinos/TrilinosConfig.cmake" ]; then
                echo "SUCCESS: Trilinos CMake configuration found!"
                
                # Check for ExodusII
                echo "Checking for ExodusII support:"
                find "$TRILINOS_INSTALL_DIR" -name "*exodus*" | head -3
                
                echo ""
                echo "TRILINOS BUILD COMPLETE!"
                echo "Ready for Peridigm build!"
                
            else
                echo "WARNING: CMake configuration not found"
            fi
            
        else
            echo "ERROR: Trilinos installation failed (status: $INSTALL_STATUS)"
            exit 1
        fi
    else
        echo "ERROR: Trilinos build failed (status: $BUILD_STATUS)"
        exit 1
    fi
else
    echo "ERROR: Trilinos configuration failed (status: $CONFIG_STATUS)"
    echo "Check the cmake output above for details"
    exit 1
fi

echo "=== Job completed at $(date) ==="
