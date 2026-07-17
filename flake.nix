{
  description = "Alternate client for Discord with Vencord built-in";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  inputs.flake-parts.url = "github:hercules-ci/flake-parts";

  outputs = inputs@{ self, flake-parts, nixpkgs }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
      ];

      perSystem = { lib, pkgs, system, ... }: {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            nodejs
            pnpm_11
          ];
        };
        packages.default = pkgs.callPackage ./vesktop.nix {
          version =
            let v = builtins.getEnv "VESKTOP_VERSION";
            in if v != "" then v else (self.dirtyShortRev or self.shortRev or "unknown");
          electron = pkgs.electron_41;
          pnpm = pkgs.pnpm_10;
        };
      };
    };
}
