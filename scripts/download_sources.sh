#!/bin/bash
# download_sources.sh - Download all required source code (PORTABLE VERSION)

echo "=== Downloading Source Packages ==="

# Use current directory structure instead of hardcoded home path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$BASE_DIR/software/src"

echo "Script directory: $SCRIPT_DIR"
echo "Base directory: $BASE_DIR" 
echo "Source directory: $SRC_DIR"

# Create source directory if it doesn't exist
mkdir -p "$SRC_DIR"
cd "$SRC_DIR"

# Function to download and verify
download_file() {
    local url=$1
    local filename=$(basename $url)
    
    if [ -f "$filename" ]; then
        echo "✅ $filename already downloaded"
        return 0
    fi
    
    echo "📥 Downloading $filename..."
    if command -v wget &> /dev/null; then
        wget "$url"
    elif command -v curl &> /dev/null; then
        curl -O "$url"
    else
        echo "❌ Neither wget nor curl found!"
        return 1
    fi
    
    if [ -f "$filename" ]; then
        echo "✅ Downloaded $filename"
        return 0
    else
        echo "❌ Failed to download $filename"
        return 1
    fi
}

# Download Trilinos
echo ""
echo "=== Downloading Trilinos ==="
if [ ! -d "Trilinos-trilinos-release-13-4-1" ]; then
    download_file "https://github.com/trilinos/Trilinos/archive/trilinos-release-13-4-1.tar.gz"
    if [ $? -eq 0 ]; then
        echo "📦 Extracting Trilinos..."
        tar -xzf trilinos-release-13-4-1.tar.gz
        mkdir -p Trilinos-trilinos-release-13-4-1/build
        echo "✅ Trilinos extracted and build directory created"
    fi
else
    echo "✅ Trilinos already extracted"
fi

# Download/Clone Peridigm
echo ""
echo "=== Downloading Peridigm ==="
if [ ! -d "peridigm" ] || [ ! -f "peridigm/CMakeLists.txt" ]; then
    if [ -d "peridigm" ]; then
        echo "⚠️  Peridigm directory exists but appears incomplete, removing..."
        rm -rf peridigm
    fi
    
    if command -v git &> /dev/null; then
        echo "📥 Cloning Peridigm from GitHub..."
        git clone https://github.com/peridigm/peridigm.git
        if [ $? -eq 0 ] && [ -f "peridigm/CMakeLists.txt" ]; then
            echo "✅ Peridigm cloned successfully"
        else
            echo "❌ Failed to clone Peridigm or clone is incomplete"
            echo "   Please check your internet connection and try again"
            exit 1
        fi
    else
        echo "❌ Git not found! Please install git or download Peridigm manually"
        exit 1
    fi
else
    echo "✅ Peridigm already cloned"
fi

# Download HDF5 (for reference, will be downloaded by build scripts)
echo ""
echo "=== Source Dependencies ==="
echo "The following will be downloaded by build scripts:"
echo "  - zlib-1.2.13.tar.gz"
echo "  - hdf5-1.14.3.tar.gz"  
echo "  - netcdf-c-4.9.2.tar.gz"
echo "  - netcdf-cxx4-4.3.1.tar.gz"
echo "  - netcdf-fortran-4.6.1.tar.gz"

# Verify downloads
echo ""
echo "=== Download Summary ==="
if [ -d "Trilinos-trilinos-release-13-4-1" ] && [ -f "Trilinos-trilinos-release-13-4-1/CMakeLists.txt" ]; then
    TRILINOS_SIZE=$(du -sh Trilinos-trilinos-release-13-4-1 | cut -f1)
    echo "✅ Trilinos: $TRILINOS_SIZE"
else
    echo "❌ Trilinos: Missing or incomplete"
fi

if [ -d "peridigm" ] && [ -f "peridigm/CMakeLists.txt" ]; then
    PERIDIGM_SIZE=$(du -sh peridigm | cut -f1)
    echo "✅ Peridigm: $PERIDIGM_SIZE"
else
    echo "❌ Peridigm: Missing or incomplete"
    echo "   Try running this script again or manually clone:"
    echo "   git clone https://github.com/peridigm/peridigm.git"
fi

echo ""
echo "📊 Total space used:"
du -sh . | cut -f1

echo ""
echo "✅ Source download complete!"
echo ""
echo "Next step: Run ./scripts/master_build.sh to start the build pipeline"
