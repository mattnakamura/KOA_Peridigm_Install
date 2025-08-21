#!/bin/bash
#SBATCH --job-name=build_parallel_hdf5
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=03:00:00
#SBATCH --output=./output_logs/build_parallel_hdf5_%j.out
#SBATCH --error=./output_logs/build_parallel_hdf5_%j.err

echo "Building parallel HDF5 from source at $(date)"
echo "Job ID: $SLURM_JOB_ID"
echo "Running on node: $(hostname)"

# Load required modules
echo "Loading modules..."
module purge
module load compiler/GCC/13.2.0
module load mpi/OpenMPI/4.1.6-GCC-13.2.0
module load devel/CMake/3.27.6-GCCcore-13.2.0

# Set up paths - PORTABLE using SLURM submit directory
BASE_DIR="${SLURM_SUBMIT_DIR}"

export INSTALL_PREFIX="$BASE_DIR/software/install"
export SRC_DIR="$BASE_DIR/software/src"
export BUILD_DIR="$BASE_DIR/software/build"

# Create directories
mkdir -p $INSTALL_PREFIX $SRC_DIR $BUILD_DIR

# Set compiler variables for MPI
export CC=mpicc
export CXX=mpicxx

# Set common configure flags
export CFLAGS="-O3 -fPIC"
export CXXFLAGS="-O3 -fPIC"
export CPPFLAGS="-I$INSTALL_PREFIX/include"
export LDFLAGS="-L$INSTALL_PREFIX/lib"
export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

echo "Environment setup:"
echo "CC: $CC"
echo "CXX: $CXX" 
echo "Install prefix: $INSTALL_PREFIX"

# Function to download and extract
download_extract() {
    local url=$1
    local filename=$(basename $url)
    local dirname=$2
    
    echo "Downloading $filename..."
    cd $SRC_DIR
    if [ ! -f "$filename" ]; then
        wget $url || curl -O $url
    fi
    
    if [ ! -d "$dirname" ]; then
        if [[ $filename == *.tar.gz ]]; then
            tar -xzf $filename
        elif [[ $filename == *.tar.bz2 ]]; then
            tar -xjf $filename
        elif [[ $filename == *.zip ]]; then
            unzip $filename
        fi
    fi
}

# 1. Build zlib (dependency for HDF5)
echo "=== Building zlib ==="
download_extract "https://zlib.net/fossils/zlib-1.2.13.tar.gz" "zlib-1.2.13"
cd $SRC_DIR/zlib-1.2.13

# Clean any previous build
make distclean 2>/dev/null || true

./configure --prefix=$INSTALL_PREFIX
make -j 8
make install

# Verify zlib installation
if [ ! -f "$INSTALL_PREFIX/lib/libz.so" ]; then
    echo "ERROR: zlib installation failed"
    exit 1
fi
echo "✅ zlib installed successfully"

# 2. Build HDF5 with PARALLEL support
echo "=== Building HDF5 (parallel with C++ support) ==="
download_extract "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.14/hdf5-1.14.3/src/hdf5-1.14.3.tar.gz" "hdf5-1.14.3"
cd $SRC_DIR/hdf5-1.14.3

# Clean any previous build
make distclean 2>/dev/null || true

echo "Configuring HDF5 with parallel support..."
./configure \
    --prefix=$INSTALL_PREFIX \
    --enable-shared \
    --enable-static \
    --enable-parallel \
    --enable-cxx \
    --enable-unsupported \
    --disable-fortran \
    --with-zlib=$INSTALL_PREFIX \
    CC=mpicc CXX=mpicxx

echo "Building HDF5..."
make -j 8 2>&1 | tee hdf5_build.log

echo "Installing HDF5..."
make install 2>&1 | tee hdf5_install.log

# Verify HDF5 installation - CHECK FOR BOTH h5cc AND h5pcc
echo "=== Verifying HDF5 Installation ==="

# For parallel HDF5, we might get h5pcc instead of h5cc
HDF5_COMPILER=""
if [ -f "$INSTALL_PREFIX/bin/h5cc" ]; then
    HDF5_COMPILER="h5cc"
    echo "Found h5cc compiler wrapper"
elif [ -f "$INSTALL_PREFIX/bin/h5pcc" ]; then
    HDF5_COMPILER="h5pcc"
    echo "Found h5pcc parallel compiler wrapper"
else
    echo "ERROR: Neither h5cc nor h5pcc found!"
    echo "Checking what was installed:"
    ls -la "$INSTALL_PREFIX/bin/h5*" 2>/dev/null || echo "No h5* files found"
    echo "Build log tail:"
    tail -50 hdf5_build.log
    echo "Install log tail:"
    tail -50 hdf5_install.log
    exit 1
fi

echo "HDF5 configuration using $HDF5_COMPILER:"
$INSTALL_PREFIX/bin/$HDF5_COMPILER -showconfig

echo "Checking parallel support:"
PARALLEL_CHECK=$($INSTALL_PREFIX/bin/$HDF5_COMPILER -showconfig | grep -i "Parallel HDF5:" | grep "yes")
if [ -z "$PARALLEL_CHECK" ]; then
    echo "ERROR: HDF5 parallel support not enabled!"
    echo "Full configuration:"
    $INSTALL_PREFIX/bin/$HDF5_COMPILER -showconfig | grep -i parallel
    exit 1
fi

echo "✅ HDF5 with parallel support installed successfully"

# Create environment setup script that works with both h5cc and h5pcc
echo "=== Creating HDF5 environment setup script ==="
cat > $INSTALL_PREFIX/setup_hdf5_env.sh << EOF
#!/bin/bash
# Source this script to set up the HDF5 environment

export HDF5_ROOT="$INSTALL_PREFIX"
export ZLIB_ROOT="$INSTALL_PREFIX"

export PATH="$HDF5_ROOT/bin:\$PATH"
export LD_LIBRARY_PATH="$HDF5_ROOT/lib:\$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$HDF5_ROOT/lib/pkgconfig:\$PKG_CONFIG_PATH"
export CMAKE_PREFIX_PATH="$HDF5_ROOT:\$CMAKE_PREFIX_PATH"

echo "HDF5 environment loaded:"
echo "HDF5: \$HDF5_ROOT"

# Check which compiler wrapper exists
if [ -f "\$HDF5_ROOT/bin/h5cc" ]; then
    echo "h5cc: \$(which h5cc)"
    echo "Parallel support: \$(h5cc -showconfig | grep 'Parallel HDF5:' | cut -d: -f2 | xargs)"
elif [ -f "\$HDF5_ROOT/bin/h5pcc" ]; then
    echo "h5pcc: \$(which h5pcc)"  
    echo "Parallel support: \$(h5pcc -showconfig | grep 'Parallel HDF5:' | cut -d: -f2 | xargs)"
else
    echo "Warning: No HDF5 compiler wrapper found"
fi
EOF

chmod +x $INSTALL_PREFIX/setup_hdf5_env.sh

# Create a symlink from h5pcc to h5cc if needed (for compatibility with other scripts)
if [ -f "$INSTALL_PREFIX/bin/h5pcc" ] && [ ! -f "$INSTALL_PREFIX/bin/h5cc" ]; then
    echo "Creating h5cc symlink to h5pcc for compatibility..."
    cd $INSTALL_PREFIX/bin
    ln -sf h5pcc h5cc
    echo "✅ Created h5cc -> h5pcc symlink"
fi

echo ""
echo "=== SUCCESS: Parallel HDF5 built ==="
echo ""
echo "Summary:"
echo "- HDF5 with parallel and C++ support"
echo "- Installed to: $INSTALL_PREFIX"
echo "- Parallel support: ENABLED"
echo "- Compiler wrapper: $HDF5_COMPILER"
if [ -f "$INSTALL_PREFIX/bin/h5cc" ]; then
    echo "- h5cc available: YES"
fi
if [ -f "$INSTALL_PREFIX/bin/h5pcc" ]; then
    echo "- h5pcc available: YES"
fi
echo ""
echo "Next steps:"
echo "1. Build NetCDF with: sbatch ./slurm/build_netcdf_with_parallel_hdf5.slurm"
echo "2. Then build Trilinos"
echo ""
echo "To use this HDF5:"
echo "source $INSTALL_PREFIX/setup_hdf5_env.sh"
echo ""

echo "Build completed at $(date)"
