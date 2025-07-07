{
  inputs = {
    nixpkgs.url = "nixpkgs/release-25.05";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils, ... }: let
    inherit (nixpkgs) lib;
  in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs { inherit system; };
      inherit (pkgs) stdenv luajitPackages;
    in {
      packages.kresdLuaModules.acns = luajitPackages.toLuaModule (
        stdenv.mkDerivation {
          pname = "acns-kresd";
          version = "0.0.1";

          src = lib.cleanSource ./src;

          propagatedBuildInputs = with luajitPackages; [
            luasocket
          ];

          dontBuild = true;
          dontConfigure = true;
          installPhase = ''
            runHook preInstall
            mkdir -p $out/share/lua/5.1
            cp -r ./ $out/share/lua/5.1
            runHook postInstall
          '';
        }
      );
    });
}
