{
  description = "llvmbpf — BPF bytecode to LLVM IR lifter and JIT";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
  flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; };
      llvmPkgs = pkgs.llvmPackages_19;
    in
    {
      packages.default = pkgs.stdenv.mkDerivation {
        pname = "llvmbpf";
        version = "0.1.0";
        src = self;

        nativeBuildInputs = [ pkgs.cmake pkgs.pkg-config ];
        buildInputs = [
          llvmPkgs.llvm
          pkgs.spdlog
          pkgs.libbpf
          pkgs.elfutils
          pkgs.zlib
          pkgs.nlohmann_json
        ];

        cmakeFlags = [
          "-DENABLE_LLVM_SHARED=OFF"
          "-DBUILD_LLVM_AOT_CLI=ON"
          "-DSPDLOG_INCLUDE=${pkgs.spdlog}/include"
        ];

        # Patch CLI CMakeLists to use system libbpf instead of git clone
        postPatch = ''
          cat > cli/CMakeLists.txt << 'EOF'
          find_package(PkgConfig REQUIRED)
          pkg_check_modules(LIBBPF REQUIRED libbpf)

          add_executable(bpftime-vm-cli main.cpp)
          set_target_properties(bpftime-vm-cli PROPERTIES OUTPUT_NAME "bpftime-vm")
          set_property(TARGET bpftime-vm-cli PROPERTY CXX_STANDARD 20)
          target_include_directories(bpftime-vm-cli PRIVATE
            ''${SPDLOG_INCLUDE} ''${CMAKE_CURRENT_SOURCE_DIR}/../include ''${LIBBPF_INCLUDE_DIRS})
          target_link_directories(bpftime-vm-cli PRIVATE ''${LIBBPF_LIBRARY_DIRS})
          find_package(nlohmann_json REQUIRED)
          add_dependencies(bpftime-vm-cli spdlog::spdlog llvmbpf_vm)
          target_link_libraries(bpftime-vm-cli PRIVATE spdlog::spdlog llvmbpf_vm nlohmann_json::nlohmann_json ''${LIBBPF_LIBRARIES} elf z)
          target_compile_definitions(bpftime-vm-cli PRIVATE _GNU_SOURCE)
          EOF
        '';

        installPhase = ''
          mkdir -p $out/lib $out/include $out/bin
          cp $src/libllvmbpf_vm.a $out/lib/ 2>/dev/null || \
            find /build -name 'libllvmbpf_vm.a' -exec cp {} $out/lib/ \;
          cp -r $src/include/* $out/include/
          find . -maxdepth 3 -type f -executable \( -name bpftime-vm -o -name vm-llvm-example -o -name maps-example -o -name array-map-inline-bench \) -exec cp {} $out/bin/ \;
        '';
      };

      devShells.default = pkgs.mkShell {
        inputsFrom = [ self.packages.${system}.default ];
        packages = [ pkgs.clang-tools ];
      };
    }
  );
}
