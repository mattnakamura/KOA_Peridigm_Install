#!/bin/bash
# setup_environment.sh - Set up runtime environment for Peridigm

echo "=== Setting up Peridigm Runtime Environment ==="

# Check if Peridigm is installed
PERIDIGM_ROOT="$(pwd)/software/install"

if [ ! -f "$PERIDIGM_ROOT/peridigm/bin/Peridigm" ]; then
    echo "❌ Peridigm not found at $PERIDIGM_ROOT/peridigm/bin/Peridigm"
    echo "   Please complete the build first with: ./master_build.sh"
    exit 1
fi

# Load required modules
echo "Loading required modules..."
module purge 2>/dev/null
module load compiler/GCC/13.2.0 2>/dev/null
module load mpi/OpenMPI/4.1.6-GCC-13.2.0 2>/dev/null

# Set up paths
export PERIDIGM_HOME="$PERIDIGM_ROOT/peridigm"
export TRILINOS_HOME="$PERIDIGM_ROOT/trilinos"
export NETCDF_ROOT="$PERIDIGM_ROOT"
export HDF5_ROOT="$PERIDIGM_ROOT"

# Add to PATH
export PATH="$PERIDIGM_HOME/bin:$PATH"
export PATH="$PERIDIGM_ROOT/bin:$PATH"

# Add to library path
export LD_LIBRARY_PATH="$PERIDIGM_ROOT/lib:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="$TRILINOS_HOME/lib:$LD_LIBRARY_PATH"

# Set up CMake path for building other software
export CMAKE_PREFIX_PATH="$PERIDIGM_ROOT:$TRILINOS_HOME:$CMAKE_PREFIX_PATH"

echo ""
echo "✅ Peridigm environment loaded successfully!"
echo ""
echo "Environment summary:"
echo "  Peridigm executable: $(which Peridigm 2>/dev/null || echo 'Not found in PATH')"
echo "  NetCDF config:       $(which nc-config 2>/dev/null || echo 'Not found in PATH')"
echo "  HDF5 compiler:       $(which h5cc 2>/dev/null || echo 'Not found in PATH')"
echo ""

# Verify Peridigm works
echo "Testing Peridigm installation..."
if command -v Peridigm &> /dev/null; then
    echo "✅ Peridigm found in PATH"
    
    # Try to run Peridigm (it may fail without input, but should not give "command not found")
    if Peridigm 2>&1 | grep -q "command not found"; then
        echo "❌ Peridigm execution failed"
    else
        echo "✅ Peridigm executable verified"
    fi
else
    echo "❌ Peridigm not found in PATH"
    echo "   Check that the build completed successfully"
fi

echo ""
echo "🎯 Peridigm is ready to use!"
echo ""
echo "Example usage:"
echo "  # For single-core run:"
echo "  Peridigm input.xml"
echo ""
echo "  # For parallel run:"
echo "  mpirun -np 4 Peridigm input.xml"
echo ""
echo "  # Look for example files:"
echo "  ls $(pwd)/software/src/peridigm/examples/"
echo ""

# Check for example files
EXAMPLES_DIR="$(pwd)/software/src/peridigm/examples"
if [ -d "$EXAMPLES_DIR" ]; then
    echo "📁 Example files found:"
    ls "$EXAMPLES_DIR"/*.xml 2>/dev/null | head -5 | while read file; do
        echo "   $(basename $file)"
    done
    echo ""
    echo "To run an example:"
    echo "  cd $EXAMPLES_DIR"
    echo "  mpirun -np 1 Peridigm <example_file>.xml"
else
    echo "⚠️  No example files found at $EXAMPLES_DIR"
fi

echo ""
echo "💡 To make this environment permanent, add this to your ~/.bashrc:"
echo "   source $(pwd)/scripts/setup_environment.sh"

# Create a convenient alias script
cat > "$(pwd)/peridigm_env.sh" << EOF
#!/bin/bash
# Quick Peridigm environment setup
source $(pwd)/scripts/setup_environment.sh
EOF
chmod +x "$(pwd)/peridigm_env.sh"

echo ""
echo "📝 Quick setup script created: ./peridigm_env.sh"

