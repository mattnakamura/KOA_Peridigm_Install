#!/bin/bash
# test_installation.sh - Test the complete Peridigm installation

echo "=== Testing Peridigm Installation ==="
echo "$(date)"
echo ""

# Set up environment
source ./scripts/setup_environment.sh 2>/dev/null || {
    echo "❌ Could not load environment"
    echo "   Run: source setup_environment.sh"
    exit 1
}

INSTALL_DIR="$HOME/fracture/software/install"
PASSED=0
TOTAL=0

# Function to run test
run_test() {
    local test_name="$1"
    local test_command="$2"
    local expected_result="$3"
    
    ((TOTAL++))
    echo -n "🧪 Testing $test_name... "
    
    if eval "$test_command" > /dev/null 2>&1; then
        if [ -n "$expected_result" ]; then
            result=$(eval "$test_command" 2>/dev/null)
            if echo "$result" | grep -q "$expected_result"; then
                echo "✅ PASS"
                ((PASSED++))
            else
                echo "❌ FAIL (unexpected result: $result)"
            fi
        else
            echo "✅ PASS"
            ((PASSED++))
        fi
    else
        echo "❌ FAIL"
    fi
}

# Test 1: HDF5 installation
run_test "HDF5 parallel support" "h5cc -showconfig | grep 'Parallel HDF5:'" "yes"

# Test 2: NetCDF installation
run_test "NetCDF parallel support" "nc-config --has-parallel" "yes"

# Test 3: NetCDF version
run_test "NetCDF version" "nc-config --version" "4.9.2"

# Test 4: Trilinos installation
run_test "Trilinos CMake config" "test -f $INSTALL_DIR/trilinos/lib/cmake/Trilinos/TrilinosConfig.cmake"

# Test 5: Trilinos ExodusII support
run_test "Trilinos ExodusII library" "find $INSTALL_DIR/trilinos -name '*exodus*' | head -1"

# Test 6: Peridigm executable
run_test "Peridigm executable exists" "test -f $INSTALL_DIR/peridigm/bin/Peridigm"

# Test 7: Peridigm in PATH
run_test "Peridigm in PATH" "which Peridigm"

# Test 8: All required libraries present
echo ""
echo "📚 Library Dependencies Check:"

REQUIRED_LIBS=(
    "libhdf5.so"
    "libnetcdf.so" 
    "libz.so"
)

for lib in "${REQUIRED_LIBS[@]}"; do
    if find "$INSTALL_DIR/lib" -name "$lib" &>/dev/null; then
        echo "   ✅ $lib found"
        ((PASSED++))
    else
        echo "   ❌ $lib missing"
    fi
    ((TOTAL++))
done

# Test 9: Create a simple test input file and try to run Peridigm
echo ""
echo "🚀 Testing Peridigm Execution:"

TEST_DIR="/tmp/peridigm_test_$$"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Create a minimal test input file
cat > minimal_test.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<ParameterList>
  <Parameter name="Verbose" type="bool" value="false"/>
  <ParameterList name="Discretization">
    <Parameter name="Type" type="string" value="Exodus"/>
    <Parameter name="Input Mesh File" type="string" value="nonexistent.g"/>
  </ParameterList>
</ParameterList>
EOF

echo "   Creating minimal test input... ✅"

# Try to run Peridigm (expect it to fail gracefully due to missing mesh file)
echo -n "   Testing Peridigm execution... "
if timeout 10s Peridigm minimal_test.xml &>/dev/null; then
    echo "❓ Unexpected success (no mesh file provided)"
elif $? -eq 124; then
    echo "⏱️  Timeout (Peridigm running but hanging)"
else
    # Check if it failed for the right reason (missing file vs. other errors)
    ERROR_OUTPUT=$(timeout 5s Peridigm minimal_test.xml 2>&1 || true)
    if echo "$ERROR_OUTPUT" | grep -qi "mesh\|file\|input"; then
        echo "✅ PASS (failed as expected - missing mesh file)"
        ((PASSED++))
    elif echo "$ERROR_OUTPUT" | grep -qi "library\|symbol\|undefined"; then
        echo "❌ FAIL (library linking issues)"
    else
        echo "⚠️  Unknown error pattern"
    fi
fi
((TOTAL++))

# Cleanup
cd - &>/dev/null
rm -rf "$TEST_DIR"

echo ""
echo "=== Test Results ==="
echo "Tests passed: $PASSED/$TOTAL"

if [ $PASSED -eq $TOTAL ]; then
    echo "🎉 ALL TESTS PASSED!"
    echo ""
    echo "✅ Peridigm installation is working correctly"
    echo ""
    echo "Next steps:"
    echo "  1. Find example input files in: $(pwd)/software/src/peridigm/examples/"
    echo "  2. Run with: mpirun -np 1 Peridigm <input_file>.xml"
    echo "  3. For parallel runs: mpirun -np 4 Peridigm <input_file>.xml"
    
elif [ $PASSED -gt $((TOTAL * 3 / 4)) ]; then
    echo "⚠️  Most tests passed, minor issues detected"
    echo "   Installation should work for basic usage"
    
elif [ $PASSED -gt $((TOTAL / 2)) ]; then
    echo "❌ Some tests failed, installation may have issues"
    echo "   Check build logs and dependencies"
    
else
    echo "❌ Many tests failed, installation likely broken"
    echo "   Consider rebuilding from scratch"
fi

echo ""
echo "📊 Component Status Summary:"
echo "   HDF5:     $([ -f "$INSTALL_DIR/bin/h5cc" ] && echo "✅ OK" || echo "❌ Missing")"
echo "   NetCDF:   $([ -f "$INSTALL_DIR/bin/nc-config" ] && echo "✅ OK" || echo "❌ Missing")"
echo "   Trilinos: $([ -f "$INSTALL_DIR/trilinos/lib/cmake/Trilinos/TrilinosConfig.cmake" ] && echo "✅ OK" || echo "❌ Missing")"
echo "   Peridigm: $([ -f "$INSTALL_DIR/peridigm/bin/Peridigm" ] && echo "✅ OK" || echo "❌ Missing")"

echo ""
echo "For detailed status: ./scripts/check_build_status.sh"
