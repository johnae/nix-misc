# nix-misc

Nix utility functions and derivations.

## Usage

This is intended to be used as a Nix flake input. Eg. (contrived example):

```nix
{
  description = "Flake using Nix-misc";

  inputs.nix-misc.url = "github:johnae/nix-misc";
  outputs = { self, nixpkgs, nix-misc }:
    let
      pkgs = import inputs.nixpkgs {
        localSystem = { system = "x86_64-linux"; };
        overlays = [
          inputs.nix-misc.overlay
        ];
        config = {
          allowUnfree = true;
        };
      };
    in
      {
          packages = pkgs;
      };

  # see default.nix within this repo for the available
  # derivations and functions
}
```

As noted above, what's available can be seen in [default.nix](default.nix).

For actual real-world usage, see:

https://github.com/johnae/world/blob/b425d56ed234189b84cf014704c791a3519c2f7c/flake.nix#L19

https://github.com/johnae/world/blob/b425d56ed234189b84cf014704c791a3519c2f7c/flake.nix#L150

https://github.com/johnae/world/blob/b425d56ed234189b84cf014704c791a3519c2f7c/shell.nix#L12

and

https://github.com/johnae/world/blob/b425d56ed234189b84cf014704c791a3519c2f7c/.buildkite/util/default.nix#L9