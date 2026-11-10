{
  description = "DaVinci Resolve Studio with FFmpeg encoder plugin";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/e4ec59bc1152b09a4843702e4a49381194f065a2";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      packages.${system} = {
        default = pkgs.callPackage ./package.nix { };
        davinci-resolve-studio = self.packages.${system}.default;
      };

      overlays.default = _: _: {
        davinci-resolve-studio = self.packages.${system}.default;
      };
    };
}
