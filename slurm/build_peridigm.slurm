#!/bin/bash
#SBATCH --job-name=peridigm_build
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --output=./output_logs/peridigm_build_%j.out
#SBATCH --error=./output_logs/peridigm_build_%j.err

echo "Starting Peridigm build at $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Running on node: $(hostname)"

# Load required modules (same as Trilinos)
echo "Loading modules..."
module load compiler/GCC/13.2.0
module load mpi/OpenMPI/4.1.6-GCC-13.2.0
module load devel/CMake/3.27.6-GCCcore-13.2.0
module load devel/Boost/1.83.0-GCC-13.2.0
module load numlib/OpenBLAS/0.3.24-GCC-13.2.0

# Set environment variables
export CC=mpicc
export CXX=mpicxx
export FC=mpif90
export F77=mpif77

# Set up paths - PORTABLE using SLURM submit directory
BASE_DIR="${SLURM_SUBMIT_DIR}"

# Set up NetCDF environment from existing installation
export NETCDF_ROOT="$BASE_DIR/software/install"
export HDF5_ROOT="$BASE_DIR/software/install"
export PATH="$NETCDF_ROOT/bin:$PATH"
export LD_LIBRARY_PATH="$NETCDF_ROOT/lib:$LD_LIBRARY_PATH"
export CMAKE_PREFIX_PATH="$NETCDF_ROOT:$CMAKE_PREFIX_PATH"

# Print environment for verification
echo "Environment check:"
echo "CC: $CC"
echo "CXX: $CXX"
echo "FC: $FC"
echo "OpenMPI: $EBROOTOPENMPI"
echo "Boost: $EBROOTBOOST"
echo "Trilinos should be at: $BASE_DIR/software/install/trilinos"

# Set paths
TRILINOS_DIR="$BASE_DIR/software/install/trilinos"
PERIDIGM_SRC="$BASE_DIR/software/src/peridigm"
PERIDIGM_BUILD="$PERIDIGM_SRC/build"
PERIDIGM_INSTALL="$BASE_DIR/software/install/peridigm"

# Verify Trilinos installation
if [ ! -d "$TRILINOS_DIR" ]; then
    echo "ERROR: Trilinos installation not found at $TRILINOS_DIR"
    exit 1
fi

if [ ! -f "$TRILINOS_DIR/lib/cmake/Trilinos/TrilinosConfig.cmake" ]; then
    echo "ERROR: Trilinos CMake configuration not found!"
    echo "Looking for: $TRILINOS_DIR/lib/cmake/Trilinos/TrilinosConfig.cmake"
    echo "Contents of $TRILINOS_DIR:"
    ls -la "$TRILINOS_DIR/"
    exit 1
fi

echo "Trilinos found at: $TRILINOS_DIR"

# Navigate to Peridigm source
if [ ! -d "$PERIDIGM_SRC" ]; then
    echo "ERROR: Peridigm source not found at $PERIDIGM_SRC"
    echo "Please clone Peridigm first with:"
    echo "cd $BASE_DIR/software/src && git clone https://github.com/peridigm/peridigm.git"
    exit 1
fi

# Fix all known build issues before building
echo "=== Fixing Known Build Issues ==="

# Fix 1: Vector3D.h deprecation issues
VECTOR3D_FILE="$PERIDIGM_SRC/src/io/utilities/Vector3D.h"
if [ -f "$VECTOR3D_FILE" ]; then
    if grep -q "binary_function" "$VECTOR3D_FILE"; then
        echo "Patching Vector3D.h to remove deprecated binary_function..."
        if [ ! -f "$VECTOR3D_FILE.backup" ]; then
            cp "$VECTOR3D_FILE" "$VECTOR3D_FILE.backup"
            echo "Created backup: $VECTOR3D_FILE.backup"
        fi
        sed -i 's/struct Distance : public binary_function< Vector3D, Vector3D, double >/struct Distance/' "$VECTOR3D_FILE"
        sed -i 's/struct Dot : public binary_function< Vector3D, Vector3D, double>/struct Dot/' "$VECTOR3D_FILE"
        sed -i 's/struct Cross : public binary_function< Vector3D, Vector3D, Vector3D >/struct Cross/' "$VECTOR3D_FILE"
        sed -i 's/struct Minus : public binary_function< Vector3D, Vector3D, Vector3D >/struct Minus/' "$VECTOR3D_FILE"
        sed -i 's/struct Plus : public binary_function< Vector3D, Vector3D, Vector3D >/struct Plus/' "$VECTOR3D_FILE"
        sed -i 's/struct InsideSphere : public binary_function< Vector3D, Vector3D, bool >/struct InsideSphere/' "$VECTOR3D_FILE"
        sed -i 's/struct OutsideSphere : public binary_function< Vector3D, Vector3D, bool >/struct OutsideSphere/' "$VECTOR3D_FILE"
        echo "Vector3D.h patched successfully"
    else
        echo "Vector3D.h already patched"
    fi
fi

# Fix 2: MPI includes in correspondence.cxx
CORRESPONDENCE_FILE="$PERIDIGM_SRC/src/materials/correspondence.cxx"
if [ -f "$CORRESPONDENCE_FILE" ]; then
    if ! grep -q "#include.*mpi\.h" "$CORRESPONDENCE_FILE"; then
        echo "Adding MPI header include to correspondence.cxx..."
        if [ ! -f "$CORRESPONDENCE_FILE.backup" ]; then
            cp "$CORRESPONDENCE_FILE" "$CORRESPONDENCE_FILE.backup"
            echo "Created backup: $CORRESPONDENCE_FILE.backup"
        fi
        sed -i '1i#include <mpi.h>' "$CORRESPONDENCE_FILE"
        echo "Added #include <mpi.h> to correspondence.cxx"
    else
        echo "MPI header already included in correspondence.cxx"
    fi
fi

# Create and navigate to build directory
mkdir -p "$PERIDIGM_BUILD"
cd "$PERIDIGM_BUILD"

echo "Configuring Peridigm..."
echo "Source directory: $PERIDIGM_SRC"
echo "Build directory: $PERIDIGM_BUILD" 
echo "Install directory: $PERIDIGM_INSTALL"

# Clear any previous build
rm -rf CMakeCache.txt CMakeFiles/

# Configure Peridigm with comprehensive flags
cmake \
  -D CMAKE_BUILD_TYPE=Release \
  -D CMAKE_INSTALL_PREFIX="$PERIDIGM_INSTALL" \
  -D CMAKE_C_COMPILER=mpicc \
  -D CMAKE_CXX_COMPILER=mpicxx \
  -D CMAKE_CXX_FLAGS="-O3 -std=c++11 -Wno-deprecated-declarations -Wno-deprecated -Wno-error" \
  -D CMAKE_C_FLAGS="-O3 -Wno-deprecated-declarations -Wno-error" \
  -D Trilinos_DIR="$TRILINOS_DIR/lib/cmake/Trilinos" \
  -D Boost_ROOT="$EBROOTBOOST" \
  -D Boost_INCLUDE_DIRS="$EBROOTBOOST/include" \
  -D Boost_LIBRARY_DIRS="$EBROOTBOOST/lib" \
  -D TPL_ENABLE_Netcdf=ON \
  -D Netcdf_ROOT="$NETCDF_ROOT" \
  -D Netcdf_INCLUDE_DIRS="$NETCDF_ROOT/include" \
  -D Netcdf_LIBRARY_DIRS="$NETCDF_ROOT/lib" \
  -D TPL_ENABLE_HDF5=ON \
  -D HDF5_ROOT="$HDF5_ROOT" \
  "$PERIDIGM_SRC"

# Check if configuration succeeded
CONFIG_STATUS=$?
echo "Configuration exit status: $CONFIG_STATUS"

if [ $CONFIG_STATUS -eq 0 ]; then
    echo "Configuration successful at $(date)"
    echo "Starting build..."
    
    # Build Peridigm with make flags to continue on warnings
    make -j 8 -k VERBOSE=1
    BUILD_STATUS=$?
    echo "Build exit status: $BUILD_STATUS"
    
    if [ $BUILD_STATUS -eq 0 ]; then
        echo "Build successful at $(date)"
        echo "Installing Peridigm..."
        
        # Install Peridigm
        make install
        INSTALL_STATUS=$?
        echo "Install exit status: $INSTALL_STATUS"
        
        if [ $INSTALL_STATUS -eq 0 ]; then
            echo "Installation successful at $(date)"
            echo "Peridigm installed to: $PERIDIGM_INSTALL"
            
            # Verify installation
            echo "Verifying installation:"
            ls -la "$PERIDIGM_INSTALL/"
            
            if [ -f "$PERIDIGM_INSTALL/bin/Peridigm" ]; then
                echo "SUCCESS: Peridigm executable found at $PERIDIGM_INSTALL/bin/Peridigm"
                
                # Test if it runs
                echo "Testing Peridigm executable:"
                "$PERIDIGM_INSTALL/bin/Peridigm" --version 2>/dev/null || echo "Peridigm executable exists but version check failed (this may be normal)"
                
                echo ""
                echo "=== INSTALLATION COMPLETE ==="
                echo "Peridigm is installed at: $PERIDIGM_INSTALL/bin/Peridigm"
                echo "To use Peridigm, add this to your PATH:"
                echo "export PATH=$PERIDIGM_INSTALL/bin:\$PATH"
                echo ""
                
            else
                echo "WARNING: Peridigm executable not found in expected location"
                echo "Contents of install directory:"
                find "$PERIDIGM_INSTALL" -name "*Peridigm*" -o -name "*peridigm*" 2>/dev/null
            fi
            
        else
            echo "ERROR: Installation failed (status: $INSTALL_STATUS)"
            exit 1
        fi
    else
        echo "ERROR: Build failed (status: $BUILD_STATUS)"
        echo "Check the build output above for details"
        exit 1
    fi
else
    echo "ERROR: Configuration failed (status: $CONFIG_STATUS)"
    echo "Check the CMake output above for details"
    exit 1
fi

echo "Job completed at $(date)"
