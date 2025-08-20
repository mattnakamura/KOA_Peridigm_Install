#!/bin/bash
# check_build_status.sh - Check the status of all build components (PORTABLE VERSION)

echo "=== Peridigm Build Status Check ==="
echo "$(date)"
echo ""

# Use current directory as base instead of hardcoded path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$BASE_DIR/software/install"

echo "Base directory: $BASE_DIR"
echo "Install directory: $INSTALL_DIR"
echo ""

# Function to check file size
get_size() {
    if [ -f "$1" ]; then
        ls -lh "$1" | awk '{print $5}'
    else
        echo "N/A"
    fi
}

# Check SLURM job status
echo "=== Active Jobs ==="
JOBS=$(squeue -u $USER --format="%.10i %.15j %.8T %.10M %.6D %.20R" --noheader 2>/dev/null)
if [ -n "$JOBS" ]; then
    echo "ID         NAME            STATE    TIME   NODES REASON"
    echo "$JOBS"
else
    echo "No active jobs"
fi
echo ""

# Check recent job history
echo "=== Recent Completed Jobs ==="
sacct -u $USER --starttime=today --format=JobID,JobName,State,ExitCode,Elapsed --noheader 2>/dev/null | tail -10 || echo "Job history not available"
echo ""

# Check build components
echo "=== Build Components Status ==="

# 1. Check HDF5
echo "🔧 HDF5:"
if [ -f "$INSTALL_DIR/bin/h5cc" ]; then
    PARALLEL_HDF5=$($INSTALL_DIR/bin/h5cc -showconfig 2>/dev/null | grep -i "Parallel HDF5:" | grep "yes")
    SIZE=$(get_size "$INSTALL_DIR/lib/libhdf5.so")
    if [ -n "$PARALLEL_HDF5" ]; then
        echo "   ✅ Installed with parallel support ($SIZE)"
    else
        echo "   ⚠️  Installed but no parallel support ($SIZE)"
    fi
elif [ -f "$INSTALL_DIR/bin/h5pcc" ]; then
    PARALLEL_HDF5=$($INSTALL_DIR/bin/h5pcc -showconfig 2>/dev/null | grep -i "Parallel HDF5:" | grep "yes")
    SIZE=$(get_size "$INSTALL_DIR/lib/libhdf5.so")
    if [ -n "$PARALLEL_HDF5" ]; then
        echo "   ✅ Installed with parallel support (h5pcc) ($SIZE)"
    else
        echo "   ⚠️  Installed but no parallel support (h5pcc) ($SIZE)"
    fi
else
    echo "   ❌ Not installed"
fi

# 2. Check NetCDF
echo "🌐 NetCDF:"
if [ -f "$INSTALL_DIR/bin/nc-config" ]; then
    PARALLEL_NETCDF=$($INSTALL_DIR/bin/nc-config --has-parallel 2>/dev/null)
    VERSION=$($INSTALL_DIR/bin/nc-config --version 2>/dev/null)
    SIZE=$(get_size "$INSTALL_DIR/lib/libnetcdf.so")
    if [ "$PARALLEL_NETCDF" = "yes" ]; then
        echo "   ✅ $VERSION with parallel support ($SIZE)"
    else
        echo "   ⚠️  $VERSION but no parallel support ($SIZE)"
    fi
else
    echo "   ❌ Not installed"
fi

# 3. Check Trilinos
echo "🔺 Trilinos:"
if [ -f "$INSTALL_DIR/trilinos/lib/cmake/Trilinos/TrilinosConfig.cmake" ]; then
    SIZE=$(du -sh "$INSTALL_DIR/trilinos" 2>/dev/null | cut -f1)
    EXODUS_LIB=$(find "$INSTALL_DIR/trilinos" -name "*exodus*" | head -1)
    if [ -n "$EXODUS_LIB" ]; then
        echo "   ✅ Installed with SEACAS/ExodusII ($SIZE)"
    else
        echo "   ⚠️  Installed but no ExodusII found ($SIZE)"
    fi
else
    echo "   ❌ Not installed"
fi

# 4. Check Peridigm
echo "🎯 Peridigm:"
if [ -f "$INSTALL_DIR/peridigm/bin/Peridigm" ]; then
    SIZE=$(get_size "$INSTALL_DIR/peridigm/bin/Peridigm")
    echo "   ✅ Installed ($SIZE)"
    
    # Test if it runs
    if "$INSTALL_DIR/peridigm/bin/Peridigm" --version &>/dev/null; then
        echo "   ✅ Executable runs successfully"
    else
        echo "   ⚠️  Executable exists but may have issues"
    fi
else
    echo "   ❌ Not installed"
fi

echo ""

# Check disk space usage
echo "=== Disk Space Usage ==="
echo "Software installation: $(du -sh $INSTALL_DIR 2>/dev/null | cut -f1)"
echo "Source code: $(du -sh $BASE_DIR/software/src 2>/dev/null | cut -f1)"
echo "Build artifacts: $(du -sh $BASE_DIR/software/build 2>/dev/null | cut -f1)"
echo "Total directory: $(du -sh $BASE_DIR 2>/dev/null | cut -f1)"
echo ""

# Check logs for errors
echo "=== Recent Log Summary ==="
LOG_DIR="$BASE_DIR/output_logs"
if [ -d "$LOG_DIR" ]; then
    echo "Latest log files:"
    ls -lt "$LOG_DIR"/*.out 2>/dev/null | head -3 | while read line; do
        file=$(echo $line | awk '{print $9}')
        echo "  $(basename $file): $(tail -1 $file 2>/dev/null | cut -c1-60)..."
    done
    
    echo ""
    echo "Recent errors:"
    find "$LOG_DIR" -name "*.err" -newermt "1 day ago" -exec grep -l "ERROR\|FAIL\|Error\|Failed" {} \; 2>/dev/null | head -3 | while read file; do
        echo "  $(basename $file): $(grep -i "error\|fail" $file | tail -1 | cut -c1-60)..."
    done
else
    echo "No log directory found"
fi

echo ""

# Overall status
echo "=== Overall Status ==="
HDF5_OK=false
NETCDF_OK=false
TRILINOS_OK=false
PERIDIGM_OK=false

[ -f "$INSTALL_DIR/bin/h5cc" ] || [ -f "$INSTALL_DIR/bin/h5pcc" ] && HDF5_OK=true
[ -f "$INSTALL_DIR/bin/nc-config" ] && NETCDF_OK=true
[ -f "$INSTALL_DIR/trilinos/lib/cmake/Trilinos/TrilinosConfig.cmake" ] && TRILINOS_OK=true
[ -f "$INSTALL_DIR/peridigm/bin/Peridigm" ] && PERIDIGM_OK=true

if $PERIDIGM_OK; then
    echo "🎉 BUILD COMPLETE! Peridigm is ready to use."
    echo ""
    echo "To use Peridigm:"
    echo "  export PATH=$INSTALL_DIR/peridigm/bin:\$PATH"
    echo "  module load compiler/GCC/13.2.0 mpi/OpenMPI/4.1.6-GCC-13.2.0"
elif $TRILINOS_OK; then
    echo "🔄 Trilinos complete, Peridigm building or queued"
elif $NETCDF_OK; then
    echo "🔄 NetCDF complete, Trilinos building or queued"
elif $HDF5_OK; then
    echo "🔄 HDF5 complete, NetCDF building or queued"
else
    echo "🔄 Build in progress or not started"
fi

# Show next steps
if ! $PERIDIGM_OK; then
    echo ""
    echo "Monitor progress:"
    echo "  squeue -u $USER"
    echo "  watch -n 30 ./scripts/check_build_status.sh"
fi
