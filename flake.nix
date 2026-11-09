{
  description = "chip8-runtime - emulador CHIP-8 em Zig + raylib";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay = {
      url = "github:mitchellh/zig-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = { self, nixpkgs, flake-utils, zig-overlay }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };

        # Mesma versao do build.zig.zon (.version = "0.16.0")
        zig = zig-overlay.packages.${system}."0.16.0";

        # Libs que o raylib (GLFW/X11 + miniaudio) precisa
        runtimeLibs = with pkgs; [
          libGL
          xorg.libX11
          xorg.libXcursor
          xorg.libXrandr
          xorg.libXinerama
          xorg.libXi
          xorg.libXext
          xorg.libXfixes
          xorg.libXrender
          alsa-lib
          libpulseaudio
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          packages = [ zig pkgs.pkg-config ];
          buildInputs = runtimeLibs;

          # GLFW e miniaudio fazem dlopen() dessas libs em runtime
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath runtimeLibs;

          shellHook = ''
            echo "zig $(zig version) | zig build run / zig build test"
          '';
        };
      });
}
