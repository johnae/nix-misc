{
  description = "Assorted utility functions and derivations for Nix";

  outputs = { self, nixpkgs }:
    {
      overlay = final: prev: import ./. {
        inherit (prev)
          stdenv lib shellcheck coreutils writeTextFile;
      };
    };
}
