{
  description = "DaVinci Resolve Studio with FFmpeg encoder plugin";

  # pin davinci-resolve to 21.1.1
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/bb9df0af54703bcf6566ee48df34bca033672849";

  outputs =
    { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      resolve = pkgs.callPackage ./package.nix { };
    in
    {
      packages.${system} = {
        default = resolve;
        davinci-resolve-studio = resolve;
      };
      overlays.default = _: _: { davinci-resolve-studio = resolve; };
    };
}
