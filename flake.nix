{
  description = "Assorted utility functions and derivations for Nix";

  outputs = { self }:
    {
      overlay = final: prev: prev.callPackage ./. { };
    };
}
