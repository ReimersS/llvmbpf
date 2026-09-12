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

        nativeBuildInputs = [ pkgs.cmake ];
        buildInputs = [
          llvmPkgs.llvm
          pkgs.spdlog
          pkgs.libbpf
          pkgs.elfutils
          pkgs.zlib
        ];

        cmakeFlags = [
          "-DENABLE_LLVM_SHARED=OFF"
          "-DBUILD_LLVM_AOT_CLI=OFF"
          "-DSPDLOG_INCLUDE=${pkgs.spdlog}/include"
        ];

        installPhase = ''
          mkdir -p $out/lib $out/include $out/bin
          cp $src/libllvmbpf_vm.a $out/lib/ 2>/dev/null || \
            find /build -name 'libllvmbpf_vm.a' -exec cp {} $out/lib/ \;
          cp -r $src/include/* $out/include/
          for f in vm-llvm-example maps-example array-map-inline-bench; do
            [ -f "$f" ] && cp "$f" $out/bin/
          done
        '';
      };

      devShells.default = pkgs.mkShell {
        inputsFrom = [ self.packages.${system}.default ];
        packages = [ pkgs.clang-tools ];
      };
    }
  );
}
