{
  description = "Assorted utility functions and derivations for Nix";

  inputs = {
    nixlib.url = "github:nix-community/nixpkgs.lib";
  };

  outputs = { nixlib, ... }:
    let
      inherit (nixlib.lib) concatStringsSep mapAttrsToList makeBinPath;
      setToStringSep = sep: x: fun: concatStringsSep sep (mapAttrsToList fun x);
      substituteInPlace = file: substitutions: ''
        substituteInPlace ${file} \
          ${setToStringSep " "
        substitutions
        (name: value: '' --subst-var-by ${name} "${value}"'')}
      '';

      lib = {
        inherit setToStringSep substituteInPlace;
      };

    in
    {
      inherit lib;

      overlay = final: prev:
        let
          inherit (prev) stdenv shellcheck writeTextFile writeShellScript;

          ## The different helpers below make bash much stricter.
          ## As part of the build step, they also check the scripts using shellcheck
          ## and will refuse to build if shellcheck complains.
          ## See: http://redsymbol.net/articles/unofficial-bash-strict-mode/
          ## and https://www.shellcheck.net/.

          ## A helper for creating shell script derivations from files.
          ## Fail on undefined variables etc. and enforces a shellcheck as part of build.
          ## We skip SC1117 see: https://github.com/koalaman/shellcheck/wiki/SC1117 as
          ## it has been retired (and is kind of annoying).
          mkStrictShellScript =
            { name
            , src
            , substitutions ? { }
            }: stdenv.mkDerivation {
              inherit name;
              buildCommand = ''
                install -v -D -m755 ${src} $out/bin/${name}
                ${lib.substituteInPlace "$out/bin/${name}" substitutions}

                if S=$(grep -E '@[a-zA-Z0-9-]+@' < $out/bin/${name}); then
                  WHAT=$(echo "$S" | sed 's|.*\(@.*@\).*|\1|g')
                  cat<<ERR

                  ${name}:
                     '$WHAT'
                       ^ this doesn't look right, forgotten substitution?

                ERR
                  exit 1
                fi

                ## check the syntax
                ${stdenv.shell} -n $out/bin/${name}

                ## shellcheck
                ${shellcheck}/bin/shellcheck -x -e SC1117 -s bash -f tty $out/bin/${name}
              '';
            };

          ## Fail on undefined variables etc. and enforces a shellcheck as part of build.
          ## We skip SC1117 see: https://github.com/koalaman/shellcheck/wiki/SC1117 as
          ## it has been retired (and is kind of annoying).
          writeStrictShellScriptBin = name: text:
            writeTextFile {
              inherit name;
              executable = true;
              destination = "/bin/${name}";
              text = ''
                #!${stdenv.shell}
                set -euo pipefail
                ${text}
              '';
              checkPhase = ''
                ## check the syntax
                ${stdenv.shell} -n $out/bin/${name}
                ## shellcheck
                ${shellcheck}/bin/shellcheck -e SC1117 -s bash -f tty $out/bin/${name}
              '';
            };

          ## Stores it directly at $out in nix store (eg. no containing /bin dir).
          ## Fail on undefined variables etc. and enforces a shellcheck as part of build.
          ## We skip SC1117 see: https://github.com/koalaman/shellcheck/wiki/SC1117 as
          ## it has been retired (and is kind of annoying).
          writeStrictShellScript = name: text:
            writeTextFile {
              inherit name;
              executable = true;
              text = ''
                #!${stdenv.shell}
                set -euo pipefail
                ${text}
              '';
              checkPhase = ''
                ${stdenv.shell} -n $out
                ${shellcheck}/bin/shellcheck -e SC1117 -s bash -f tty $out
              '';
            };

          ## Takes shell code on stdin, runs shellcheck on it and automatically adds
          ## the unofficial strict-mode - eg. "set -euo pipefail". Useful in CI for example,
          ## where you can wrap your scripts in something like:
          ## strict-bash <<'SH'
          ## echo starting
          ## mycommand > out.txt
          ## SH
          strict-bash = writeStrictShellScriptBin "strict-bash" ''
            ## first define a random script name and make it executable
            script="$(mktemp /tmp/script.XXXXXX.sh)"
            chmod +x "$script"

            ## then add a prelude (eg. shebang + "strict mode")
            cat<<EOF>"$script"
            #!${stdenv.shell}
            set -euo pipefail

            EOF

            ## now send stdin to the above file - which
            ## follows the defined prelude
            cat>>"$script"

            ## do a syntax check
            #!${stdenv.shell} -n "$script"

            ## check the script for common errors
            ${shellcheck}/bin/shellcheck -e SC1117 -s bash -f tty "$script"

            ## if all of the above went well - execute the script
            "$script"
          '';

        in
        {
          inherit mkStrictShellScript writeStrictShellScript
            writeStrictShellScriptBin strict-bash;
        };
    };
}
