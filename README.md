# Peridigm Build Pipeline

A complete automated build system for Peridigm peridynamics simulation software and all its dependencies, with all compatibility fixes applied and tested.

## Overview

This pipeline builds the complete software stack required for Peridigm:
- **Parallel HDF5** (1.14.3) with MPI and C++ support
- **NetCDF Stack** (4.9.2) with parallel HDF5 support  
- **Trilinos** (13.4.1) with SEACAS/ExodusII support
- **Peridigm** (latest) with all material models and GCC 13.2.0 compatibility fixes

## Quick Start (Recommended)

```bash
# 1. Set up directories and download all source code
./scripts/setup_directories.sh
./scripts/download_sources.sh

# 2. Start the complete automated build pipeline (~15 hours)
./scripts/master_build.sh

# 3. Monitor progress
squeue -u $USER
watch -n 30 ./scripts/check_build_status.sh

# 4. When complete, set up runtime environment and test
./scripts/setup_environment.sh
./scripts/test_installation.sh
```

That's it! The automated pipeline handles everything including dependencies, compatibility fixes, and error handling.

## What the Build Pipeline Does

### Automated Job Submission with Dependencies
- Submits 4 SLURM jobs in sequence with proper dependencies
- Each job only starts after the previous one completes successfully  
- Handles all library linking and environment setup automatically
- Applies all known compatibility fixes for GCC 13.2.0

### Applied Compatibility Fixes
The pipeline automatically applies these critical fixes:
- **Vector3D.h**: Removes deprecated `std::binary_function` inheritance
- **correspondence.cxx**: Adds missing `#include <mpi.h>`
- **Compiler flags**: Uses `-Wno-deprecated-declarations` to handle remaining warnings
- **Module compatibility**: Uses GCC 11.3.0 for Trilinos, GCC 13.2.0 for others

### Robust Error Handling
- Verifies parallel support at each stage
- Checks for required files before proceeding
- Creates backups before applying patches
- Comprehensive status reporting and logging

## Prerequisites

- **HPC System**: SLURM job scheduler
- **Modules Required**:
  - `compiler/GCC/13.2.0` and `compiler/GCC/11.3.0`  
  - `mpi/OpenMPI/4.1.6-GCC-13.2.0`
  - `devel/CMake/3.27.6-GCCcore-13.2.0`
  - `devel/Boost/1.83.0-GCC-13.2.0`  
  - `numlib/OpenBLAS/0.3.24-GCC-13.2.0`
- **Disk Space**: 5GB minimum, 8GB recommended
- **Network**: Access to download source repositories

## Detailed Build Process

### Stage 1: Environment Setup (~2 minutes)
```bash
./scripts/setup_directories.sh    # Creates directory structure
./scripts/download_sources.sh     # Downloads ~500MB of source code
```

**What this does:**
- Creates `./software/{src,build,install}` and `./output_logs/` directories
- Downloads Trilinos 13.4.1 source (~300MB)
- Clones latest Peridigm from GitHub (~50MB)
- Sets up portable directory structure

### Stage 2: Automated Build Pipeline (~15 hours)
```bash
./scripts/master_build.sh
```

**Job Sequence:**
1. **HDF5 Build** (3 hours) → Job ID returned
   - Builds zlib 1.2.13 dependency
   - Builds HDF5 1.14.3 with `--enable-parallel --enable-cxx`
   - Creates both `h5cc` and `h5pcc` compiler wrappers
   - Verifies parallel support is enabled

2. **NetCDF Stack** (2 hours) → Depends on HDF5
   - Builds NetCDF-C 4.9.2 with `--enable-parallel4`
   - Builds NetCDF-CXX 4.3.1 for C++ support
   - Builds NetCDF-Fortran 4.6.1 for Fortran support
   - Creates environment setup script

3. **Trilinos Build** (8 hours) → Depends on NetCDF  
   - Uses GCC 11.3.0 for compatibility
   - Enables 20+ essential packages including SEACAS
   - Links with parallel NetCDF/HDF5
   - Builds ExodusII for mesh I/O support

4. **Peridigm Build** (2 hours) → Depends on Trilinos
   - Applies Vector3D.h compatibility patches automatically
   - Adds missing MPI includes to correspondence files  
   - Uses GCC 13.2.0 with warning suppression
   - Links with complete Trilinos installation

### Stage 3: Verification and Setup (~1 minute)
```bash
./scripts/test_installation.sh     # Comprehensive testing
source ./scripts/setup_environment.sh  # Runtime environment
```

## Directory Structure (After Build)

```
./
├── software/
│   ├── src/                          # Source code (keep for examples)
│   │   ├── Trilinos-trilinos-release-13-4-1/
│   │   ├── peridigm/                 # Contains example input files
│   │   ├── hdf5-1.14.3/
│   │   └── netcdf-*/
│   ├── build/                        # Temporary build files (can delete)
│   └── install/                      # FINAL INSTALLATIONS
│       ├── bin/                      # h5cc, nc-config, etc.
│       ├── lib/                      # All libraries
│       ├── include/                  # Headers
│       ├── trilinos/                 # Trilinos installation  
│       ├── peridigm/                 # Peridigm installation
│       └── setup_parallel_netcdf_env.sh
├── scripts/                          # Build and utility scripts
├── output_logs/                      # SLURM job logs
├── build_status.txt                  # Job tracking info
└── peridigm_env.sh                  # Quick environment setup
```

## Monitoring and Status

### Check Build Progress
```bash
# Overall status with component verification
./scripts/check_build_status.sh

# Job queue status  
squeue -u $USER

# Detailed job information
scontrol show job <JOB_ID>

# Watch logs in real-time
tail -f ./output_logs/trilinos_parallel_netcdf_<JOB_ID>.out
```

### Status Indicators
- ✅ **Component installed and verified**
- ⚠️ **Component installed but issues detected**  
- ❌ **Component missing or failed**
- 🔧 **Build in progress**

## Using Peridigm

### Set Up Environment
```bash
# Quick setup (recommended)
source ./peridigm_env.sh

# Or manually
source ./scripts/setup_environment.sh

# Or add to ~/.bashrc for permanent access
echo "source $(pwd)/scripts/setup_environment.sh" >> ~/.bashrc
```

### Verify Installation
```bash
# Comprehensive test suite
./scripts/test_installation.sh

# Quick verification
which Peridigm
Peridigm --version 2>/dev/null || echo "Peridigm found (version check may fail)"
```

### Run Examples
```bash
# Find example files
ls ./software/src/peridigm/examples/*.xml

# Single-core run
cd ./software/src/peridigm/examples/
Peridigm <example_file>.xml

# Parallel run
mpirun -np 4 Peridigm <example_file>.xml

# With SLURM
srun -n 4 Peridigm <example_file>.xml
```

## Advanced Usage

### Manual Build (Alternative to Automated Pipeline)
```bash
# Load modules first
module purge
module load compiler/GCC/13.2.0 mpi/OpenMPI/4.1.6-GCC-13.2.0 \
            devel/CMake/3.27.6-GCCcore-13.2.0 devel/Boost/1.83.0-GCC-13.2.0 \
            numlib/OpenBLAS/0.3.24-GCC-13.2.0

# Build in sequence (wait for each to complete)
sbatch ./slurm/build_parallel_hdf5.slurm      # 3 hours
sbatch ./slurm/build_netcdf_stack.slurm       # 2 hours  
sbatch ./slurm/build_trilinos.slurm           # 8 hours
sbatch ./slurm/build_peridigm.slurm           # 2 hours
```

### Clean Up Build Artifacts
```bash
# Remove temporary build files (saves ~3GB)
rm -rf ./software/build/

# Remove source downloads (saves ~500MB, but removes examples)
rm -rf ./software/src/

# Keep only final installation (~1GB)
```

### Cancel Running Jobs
```bash
# Cancel all your jobs
scancel -u $USER

# Cancel specific job
scancel <JOB_ID>

# Check what was cancelled
sacct -u $USER --starttime=today
```

## Troubleshooting

### Build Failures

**Check job logs:**
```bash
# Most recent error logs
find ./output_logs/ -name "*.err" -newermt "1 hour ago" -exec tail -20 {} +

# Specific component logs
tail -50 ./output_logs/trilinos_parallel_netcdf_*.out
```

**Common issues and solutions:**

1. **HDF5 Parallel Support Missing**
   ```bash
   # Check if HDF5 was built correctly
   ./software/install/bin/h5cc -showconfig | grep "Parallel HDF5"
   # Should show "Parallel HDF5: yes"
   ```

2. **NetCDF Configuration Fails**
   ```bash
   # Verify HDF5 is available
   ls -la ./software/install/bin/h5*
   # Should see h5cc or h5pcc
   ```

3. **Trilinos Build Errors**
   ```bash
   # Check if NetCDF has parallel support
   ./software/install/bin/nc-config --has-parallel
   # Should return "yes"
   ```

4. **Peridigm Compilation Warnings**
   - These are expected and handled by the build scripts
   - Vector3D.h warnings are automatically patched
   - MPI includes are automatically added

### Disk Space Issues
```bash
# Check current usage
du -sh ./software/
df -h .

# Clean up safely
rm -rf ./software/build/     # Temporary build files
```

### Module Loading Issues
```bash
# Reset modules
module purge
module avail GCC          # Check available versions
module load compiler/GCC/13.2.0  # Load required version
```

## Performance Notes

- **Total Build Time**: ~15 hours on typical HPC nodes (8 cores, 24GB RAM)
- **Peak Disk Usage**: ~5GB during Trilinos build  
- **Final Installation**: ~1GB
- **Memory Requirements**: 24GB for Trilinos build, 8-16GB for others
- **CPU Utilization**: Builds use all allocated cores (`make -j 8`)

## Version Information

| Component | Version | Key Features |
|-----------|---------|--------------|
| HDF5 | 1.14.3 | Parallel I/O, C++ support |
| NetCDF-C | 4.9.2 | Parallel HDF5 backend |
| NetCDF-CXX | 4.3.1 | C++ interface |
| NetCDF-Fortran | 4.6.1 | Fortran interface |
| Trilinos | 13.4.1 | SEACAS, ExodusII, 20+ packages |
| Peridigm | Latest | All material models, GCC 13.2.0 fixes |

## Validation and Testing

The build system includes comprehensive testing:

- **Library Dependency Verification**: Ensures all libraries link correctly
- **Parallel Support Testing**: Verifies MPI functionality in HDF5/NetCDF
- **Executable Testing**: Confirms Peridigm runs without library errors
- **Example File Access**: Verifies examples are available for testing

Run the full test suite after installation:
```bash
./scripts/test_installation.sh
```

## Support and Updates

**Tested On:**
- Multiple HPC clusters with SLURM
- GCC 11.3.0 - 13.2.0
- OpenMPI 4.1.4 - 4.1.6
- CentOS/RHEL 7-9 based systems

**For Updates:**
- Trilinos: Update version in `build_trilinos.slurm`
- Peridigm: `cd software/src/peridigm && git pull`
- Dependencies: Update URLs in build scripts

**Getting Help:**
1. Run `./scripts/check_build_status.sh` for component status
2. Check log files in `./output_logs/` for specific errors
3. Verify all prerequisite modules are available
4. Ensure sufficient disk space and time limits

This build system has been thoroughly tested and includes all necessary compatibility fixes for modern GCC compilers and HPC environments.
