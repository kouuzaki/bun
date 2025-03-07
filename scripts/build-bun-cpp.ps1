$ErrorActionPreference = 'Stop'  # Setting strict mode, similar to 'set -euo pipefail' in bash

.\scripts\env.ps1
.\scripts\update-submodules.ps1
.\scripts\build-libuv.ps1 -CloneOnly $True

# libdeflate.h is needed otherwise the build fails
git submodule update --init --recursive --progress --depth=1 --checkout src/deps/libdeflate

cd build
cmake .. @CMAKE_FLAGS `
  -G Ninja `
  -DCMAKE_BUILD_TYPE=Release `
  -DNO_CODEGEN=0 `
  -DNO_CONFIGURE_DEPENDS=1 `
  -DBUN_CPP_ONLY=1
if ($LASTEXITCODE -ne 0) { throw "CMake configuration failed" }

.\compile-cpp-only.ps1 -v -j $env:CPUS
if ($LASTEXITCODE -ne 0) { throw "C++ compilation failed" }

# HACK: For some reason, the buildkite agent is hanging when uploading bun-cpp-objects.a
# Best guess is that there is an issue when uploading files larger than 500 MB
#
# For now, use FileSplitter to split the file into smaller chunks:
# https://www.powershellgallery.com/packages/FileSplitter/1.3
if ($env:BUILDKITE) {
  Split-File -Path (Resolve-Path "bun-cpp-objects.a") -PartSizeBytes "50MB" -Verbose
}
