{
  description = "peer-observer-docker";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.devshell.flakeModule
      ];
      systems = [ "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {

        devshells.default = {
          devshell.name = "peer-observer-docker";

          packages = [
            pkgs.colima
            pkgs.docker
          ];

          commands = [
            {
              name = "vm-start";
              help = "Start the colima virtual machine";
              command = "colima start -c 6 -m 6 -t vz peer-observer";
              category = "commands";
            }
            {
              name = "vm-stop";
              help = "Stop the colima virtual machine";
              command = "colima stop peer-observer";
              category = "commands";
            }
          ];
        };

      };
    };
}
