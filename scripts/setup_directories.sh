#!/bin/bash
# setup_directories.sh - Create the complete directory structure for Peridigm build

echo "=== Setting up Peridigm Build Environment ==="

# Create main directory structure
echo "Creating directory structure..."
mkdir -p ./software/{src,build,install}
mkdir -p ./output_logs

# Create Trilinos build directory
mkdir -p ./software/src/build_temp

echo "✅ Directory structure created:"
echo "  ./software/src/         - Source code downloads"
echo "  ./software/build/       - Temporary build artifacts"
echo "  ./software/install/     - Final installed software"
echo "  ./output_logs/          - SLURM job output logs"
echo ""

# Check available space
echo "=== Disk Space Check ==="
echo "Available space in home directory:"
df -h ~ | tail -1

echo ""
echo "Estimated space requirements:"
echo "  - Source downloads: ~500MB"
echo "  - Build artifacts: ~2-3GB (temporary)"
echo "  - Final installation: ~1GB"
echo "  - Total peak usage: ~4-5GB"
echo ""

# Set up basic environment
echo "=== Creating basic environment setup ==="
cat > ./load_modules.sh << 'EOF'
#!/bin/bash
# Basic module loading for Peridigm builds

module purge
module load compiler/GCC/13.2.0
module load mpi/OpenMPI/4.1.6-GCC-13.2.0
module load devel/CMake/3.27.6-GCCcore-13.2.0
module load devel/Boost/1.83.0-GCC-13.2.0
module load numlib/OpenBLAS/0.3.24-GCC-13.2.0

echo "Modules loaded for Peridigm build"
EOF

chmod +x ./load_modules.sh

echo "✅ Environment setup complete!"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/download_sources.sh"
echo "  2. Then: ./scripts/master_build.sh"

