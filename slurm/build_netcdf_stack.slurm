#!/bin/bash
#SBATCH --job-name=build_netcdf_parallel
#SBATCH --partition=shared
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=16G
#SBATCH --time=02:00:00
#SBATCH --output=./output_logs/build_netcdf_parallel_%j.out
#SBATCH --error=./output_logs/build_netcdf_parallel_%j.err

echo "Building NetCDF with parallel HDF5 support at $(date)"
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

# Set compiler variables for MPI
export CC=mpicc
export CXX=mpicxx
export FC=mpif90
export F77=mpif90

# Set common configure flags
export CFLAGS="-O3 -fPIC"
export CXXFLAGS="-O3 -fPIC"
export FCFLAGS="-O3 -fPIC"
export CPPFLAGS="-I$INSTALL_PREFIX/include"
export LDFLAGS="-L$INSTALL_PREFIX/lib"
export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"

echo "Environment setup:"
echo "CC: $CC"
echo "CXX: $CXX" 
echo "FC: $FC"
echo "Install prefix: $INSTALL_PREFIX"

# Verify HDF5 is available and has parallel support
echo "=== Verifying HDF5 Installation ==="

# Check for both h5cc and h5pcc
HDF5_COMPILER=""
if [ -f "$INSTALL_PREFIX/bin/h5cc" ]; then
    HDF5_COMPILER="h5cc"
elif [ -f "$INSTALL_PREFIX/bin/h5pcc" ]; then
    HDF5_COMPILER="h5pcc"
else
    echo "ERROR: Neither h5cc nor h5pcc found at $INSTALL_PREFIX"
    echo "Please run build_parallel_hdf5.slurm first"
    echo "Available files in $INSTALL_PREFIX/bin:"
    ls -la "$INSTALL_PREFIX/bin/" 2>/dev/null || echo "Directory does not exist"
    exit 1
fi

PARALLEL_CHECK=$($INSTALL_PREFIX/bin/$HDF5_COMPILER -showconfig | grep -i "Parallel HDF5:" | grep "yes")
if [ -z "$PARALLEL_CHECK" ]; then
    echo "ERROR: HDF5 does not have parallel support!"
    echo "HDF5 configuration:"
    $INSTALL_PREFIX/bin/$HDF5_COMPILER -showconfig | grep -i parallel
    exit 1
fi

echo "✅ HDF5 with parallel support found ($HDF5_COMPILER)"

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

# Build NetCDF-C with PARALLEL support
echo "=== Building NetCDF-C (parallel) ==="
download_extract "https://downloads.unidata.ucar.edu/netcdf-c/4.9.2/netcdf-c-4.9.2.tar.gz" "netcdf-c-4.9.2"
cd $SRC_DIR/netcdf-c-4.9.2

# Clean any previous build
make distclean 2>/dev/null || true

echo "Configuring NetCDF-C with parallel support..."
./configure \
    --prefix=$INSTALL_PREFIX \
    --enable-shared \
    --enable-static \
    --enable-netcdf-4 \
    --enable-hdf5 \
    --enable-parallel4 \
    --disable-dap \
    CPPFLAGS="-I$INSTALL_PREFIX/include" \
    LDFLAGS="-L$INSTALL_PREFIX/lib" \
    CC=mpicc

echo "Building NetCDF-C..."
make -j 8

echo "Installing NetCDF-C..."
make install

# Build NetCDF-CXX
echo "=== Building NetCDF-CXX ==="
download_extract "https://downloads.unidata.ucar.edu/netcdf-cxx/4.3.1/netcdf-cxx4-4.3.1.tar.gz" "netcdf-cxx4-4.3.1"
cd $SRC_DIR/netcdf-cxx4-4.3.1

# Clean any previous build
make distclean 2>/dev/null || true

./configure \
    --prefix=$INSTALL_PREFIX \
    --enable-shared \
    --enable-static \
    CPPFLAGS="-I$INSTALL_PREFIX/include" \
    LDFLAGS="-L$INSTALL_PREFIX/lib" \
    CXX=mpicxx
make -j 8
make install

# Build NetCDF-Fortran
echo "=== Building NetCDF-Fortran ==="
download_extract "https://downloads.unidata.ucar.edu/netcdf-fortran/4.6.1/netcdf-fortran-4.6.1.tar.gz" "netcdf-fortran-4.6.1"
cd $SRC_DIR/netcdf-fortran-4.6.1

# Clean any previous build
make distclean 2>/dev/null || true

./configure \
    --prefix=$INSTALL_PREFIX \
    --enable-shared \
    --enable-static \
    CPPFLAGS="-I$INSTALL_PREFIX/include" \
    LDFLAGS="-L$INSTALL_PREFIX/lib" \
    FC=mpif90
make -j 8
make install

# Verify NetCDF installation
echo "=== Verifying NetCDF Installation ==="
if [ ! -f "$INSTALL_PREFIX/bin/nc-config" ]; then
    echo "ERROR: NetCDF installation failed - nc-config not found"
    exit 1
fi

echo "NetCDF configuration:"
$INSTALL_PREFIX/bin/nc-config --all

echo "Checking parallel support:"
NETCDF_PARALLEL=$($INSTALL_PREFIX/bin/nc-config --has-parallel)
echo "NetCDF parallel support: $NETCDF_PARALLEL"

if [ "$NETCDF_PARALLEL" != "yes" ]; then
    echo "ERROR: NetCDF parallel support not enabled!"
    exit 1
fi

echo "✅ NetCDF with parallel support installed successfully"

# Create environment setup script
echo "=== Creating NetCDF environment setup script ==="
cat > $INSTALL_PREFIX/setup_parallel_netcdf_env.sh << EOF
#!/bin/bash
# Source this script to set up the parallel NetCDF environment

export NETCDF_ROOT="$INSTALL_PREFIX"
export HDF5_ROOT="$INSTALL_PREFIX"
export ZLIB_ROOT="$INSTALL_PREFIX"

export PATH="$INSTALL_PREFIX/bin:\$PATH"
export LD_LIBRARY_PATH="$INSTALL_PREFIX/lib:\$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$INSTALL_PREFIX/lib/pkgconfig:\$PKG_CONFIG_PATH"
export CMAKE_PREFIX_PATH="$INSTALL_PREFIX:\$CMAKE_PREFIX_PATH"

echo "Parallel NetCDF environment loaded:"
echo "NetCDF: \$NETCDF_ROOT"
echo "HDF5: \$HDF5_ROOT"
echo "nc-config: \$(which nc-config)"
echo "Parallel support: \$(nc-config --has-parallel)"
EOF

chmod +x $INSTALL_PREFIX/setup_parallel_netcdf_env.sh

echo ""
echo "=== SUCCESS: Parallel NetCDF stack built ==="
echo ""
echo "Summary:"
echo "- NetCDF-C with parallel HDF5 support"
echo "- NetCDF-CXX and NetCDF-Fortran"
echo "- Parallel support: ENABLED"
echo "- Installed to: $INSTALL_PREFIX"
echo ""
echo "Next step:"
echo "sbatch ./slurm/build_trilinos_with_parallel_netcdf.slurm"
echo ""
echo "To use this NetCDF:"
echo "source $INSTALL_PREFIX/setup_parallel_netcdf_env.sh"
echo ""

echo "Build completed at $(date)"
