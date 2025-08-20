#!/bin/bash
# master_build.sh - Execute the complete Peridigm build pipeline

echo "=== Peridigm Complete Build Pipeline ==="
echo ""
echo "This will build the complete software stack:"
echo "  1. 🔧 Parallel HDF5 (3 hours)"
echo "  2. 🌐 NetCDF with parallel support (2 hours)" 
echo "  3. 🔺 Trilinos with SEACAS (8 hours)"
echo "  4. 🎯 Peridigm (2 hours)"
echo ""
echo "Total estimated time: ~15 hours"
echo "Jobs will run sequentially with dependencies"
echo ""

# Check prerequisites
echo "=== Prerequisites Check ==="

# Check if source code is downloaded
if [ ! -d "./software/src/Trilinos-trilinos-release-13-4-1" ]; then
    echo "❌ Trilinos source not found"
    echo "   Run: ./download_sources.sh"
    exit 1
fi

if [ ! -d "./software/src/peridigm" ]; then
    echo "❌ Peridigm source not found"
    echo "   Run: ./download_sources.sh"
    exit 1
fi

# Check if SLURM scripts exist
REQUIRED_SCRIPTS=(
    "./slurm/build_parallel_hdf5.slurm"
    "./slurm/build_netcdf_stack.slurm"
    "./slurm/build_trilinos.slurm"
    "./slurm/build_peridigm.slurm"
)

for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [ ! -f "$script" ]; then
        echo "❌ Missing SLURM script: $script"
        exit 1
    fi
done

echo "✅ All prerequisites satisfied"
echo ""

# Show current queue
echo "=== Current Job Queue ==="
squeue -u $USER 2>/dev/null || echo "No jobs currently running"
echo ""

# Confirm build
read -p "🚀 Start the complete build pipeline? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Build cancelled"
    exit 0
fi

echo ""
echo "🚀 Submitting build jobs with dependencies..."
echo ""

# Submit jobs in sequence with dependencies

# Step 1: Build parallel HDF5
echo "📋 Submitting HDF5 build..."
JOB1=$(sbatch --parsable slurm/build_parallel_hdf5.slurm)
if [ $? -eq 0 ]; then
    echo "✅ HDF5 build queued: Job ID $JOB1"
else
    echo "❌ Failed to submit HDF5 build"
    exit 1
fi

# Step 2: Build NetCDF (depends on HDF5)
echo "📋 Submitting NetCDF build (depends on HDF5)..."
JOB2=$(sbatch --parsable --dependency=afterok:$JOB1 slurm/build_netcdf_stack.slurm)
if [ $? -eq 0 ]; then
    echo "✅ NetCDF build queued: Job ID $JOB2"
else
    echo "❌ Failed to submit NetCDF build"
    exit 1
fi

# Step 3: Build Trilinos (depends on NetCDF)
echo "📋 Submitting Trilinos build (depends on NetCDF)..."
JOB3=$(sbatch --parsable --dependency=afterok:$JOB2 slurm/build_trilinos.slurm)
if [ $? -eq 0 ]; then
    echo "✅ Trilinos build queued: Job ID $JOB3"
else
    echo "❌ Failed to submit Trilinos build"
    exit 1
fi

# Step 4: Build Peridigm (depends on Trilinos)
echo "📋 Submitting Peridigm build (depends on Trilinos)..."
JOB4=$(sbatch --parsable --dependency=afterok:$JOB3 slurm/build_peridigm.slurm)
if [ $? -eq 0 ]; then
    echo "✅ Peridigm build queued: Job ID $JOB4"
else
    echo "❌ Failed to submit Peridigm build"
    exit 1
fi

echo ""
echo "🎉 Build pipeline submitted successfully!"
echo ""
echo "Job Dependencies:"
echo "  $JOB1 (HDF5) → $JOB2 (NetCDF) → $JOB3 (Trilinos) → $JOB4 (Peridigm)"
echo ""
echo "📊 Monitor progress:"
echo "  Queue status:    squeue -u $USER"
echo "  Job details:     scontrol show job <JOB_ID>"
echo "  Cancel all:      scancel -u $USER"
echo ""
echo "📁 Check logs in:  ./output_logs/"
echo "📊 Check status:   ./scripts/check_build_status.sh"
echo ""
echo "⏱️  Estimated completion: $(date -d '+15 hours' '+%Y-%m-%d %H:%M')"

# Create a status file
cat > ./build_status.txt << EOF
Peridigm Build Pipeline Started: $(date)

Job IDs:
  HDF5:     $JOB1
  NetCDF:   $JOB2  
  Trilinos: $JOB3
  Peridigm: $JOB4

Monitor with:
  squeue -u $USER
  ./scripts/check_build_status.sh

Logs in: ./output_logs/
EOF

echo "📝 Build info saved to: ./build_status.txt"
