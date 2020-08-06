# nix-misc

Nix utility functions and derivations.

## Usage

This is intended to be used as a Nix flake input. Eg.

```nix
{
  description = "Flake using Nix-misc";

  inputs.nix-misc.url = "github:johnae/nix-misc";

  ... see default.nix within this repo for the available
      derivations and functions
}
```