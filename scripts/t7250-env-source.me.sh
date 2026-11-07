# Intel Core 2 Duo T7250 (Merom) Compiler Flags & Kernel Build Environment
# Architecture: x86_64, Instruction sets: MMX, SSE, SSE2, SSE3, SSSE3, EM64T

export ARCH=x86_64
export LOCALVERSION="-d630-core2"

export CFLAGS="-march=core2 -mtune=core2 -O2 -pipe"
export CXXFLAGS="-march=core2 -mtune=core2 -O2 -pipe"
export CPPFLAGS="-march=core2 -mtune=core2 -O2 -pipe"
export FFLAGS="-march=core2 -mtune=core2 -O2 -pipe"
export FCFLAGS="-march=core2 -mtune=core2 -O2 -pipe"
export KCFLAGS="-march=core2 -mtune=core2 -O2 -pipe"
export LDFLAGS="-Wl,-O1 -Wl,--as-needed"

# Rust flags for Core 2 Duo T7250
export RUSTFLAGS="-C target-cpu=core2 -C opt-level=2"

echo "T7250 environment & compiler flags (including KCFLAGS, ARCH, LOCALVERSION) exported successfully."
