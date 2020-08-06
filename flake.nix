{
  description = "Assorted utility functions and derivations for Nix";

  outputs = { self }:
    {
      overlay = final: prev:
        {
          inherit (prev.callPackage ./. { }) strict-bash;
        };
    };
}
