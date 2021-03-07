{ stdenv, lib, shellcheck, coreutils, writeTextFile, ... }:
let
  inherit (lib) stringToCharacters concatStringsSep
    toUpper toLower splitString mapAttrsToList
    stringAsChars makeSearchPath;
  inherit (builtins) head tail concatMap;
  changeFirst = s: fn:
    let
      c = stringToCharacters s;
    in
    concatStringsSep "" ([ (fn (head c)) ] ++ (tail c));
  capitalize = s: changeFirst s toUpper;
  uncapitalize = s: changeFirst s toLower;
  toCamelCase = s: concatStringsSep "" (map (capitalize) (splitString "_" s));
  isCamelCase = s: s == (toCamelCase s);
  toMixedCase = s: uncapitalize (toCamelCase s);
  isMixedCase = s: s == (toMixedCase s);
  isAlpha = c: (toUpper c) != (toLower c);
  isUpper = c: (isAlpha c) && c == (toUpper c);
  isLower = c: !(isUpper c);
  toSnakeCase = s: concatStringsSep "" (concatMap
    (x:
      if isUpper x then [ "_" (toLower x) ] else [ x ]
    )
    (stringToCharacters s)
  );
  isSnakeCase = s: s == (toSnakeCase s);

  setToStringSep = sep: x: fun: concatStringsSep sep (mapAttrsToList fun x);

  substituteInPlace = file: substitutions: ''
    substituteInPlace ${file} \
      ${setToStringSep " "
    substitutions
    (name: value: '' --subst-var-by ${name} "${value}"'')}
  '';


  ## The different helpers below enable the "unofficial bash strict mode" and
  ## also checks the scripts using shellcheck and will refuse to build if shellcheck
  ## complains. See: http://redsymbol.net/articles/unofficial-bash-strict-mode/
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
        ${substituteInPlace "$out/bin/${name}" substitutions}

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

  ## Just store it directly in nix store without containing /bin dir.
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

  mkSimpleShell =
    { bashInteractive
    , coreutils
    , system
    , writeTextFile
    , writeShellScript
    , lib
    }:
    let
      bashPath = "${bashInteractive}/bin/bash";
      _system = system;

      stdenv = writeTextFile {
        name = "basic-stdenv";
        destination = "/setup";
        text = ''
          : ''${outputs:=out}
          runHook() {
            eval "$shellHook"
            unset runHook
          }
        '';
      };
    in
    { name
    , intro ? ""
    , packages ? [ ]
    , meta ? { }
    , passthru ? { }
    }:
    let
      script = writeShellScript "${name}-hook" ''
        export PATH=${lib.makeBinPath packages}/bin:''${PATH:+:''${PATH}}
        __shell-intro() {
          cat<<INTRO
        ${intro}
        INTRO
        }
        if [[ ''${DIRENV_IN_ENVRC:-} = 1 ]]; then
          __shell-intro
        else
          __shell-prompt() {
            __shell-intro
            __shell-prompt() { :; }
          }
          PROMPT_COMMAND=__shell-prompt''${PROMPT_COMMAND+;$PROMPT_COMMAND}
        fi
      '';
    in
    (derivation {
      inherit name system;
      builder = bashPath;
      args = [ "-ec" "${coreutils}/bin/ln -s ${script} $out; exit 0" ];
      stdenv = stdenv;
      shellHook = ''
        unset NIX_BUILD_TOP NIX_BUILD_CORES NIX_BUILD_TOP NIX_STORE
        unset TEMP TEMPDIR TMP TMPDIR
        unset builder name out shellHook stdenv system
        unset dontAddDisableDepTrack outputs
        export SHELL=${bashPath}
        source "${script}"
      '';
    }) // { inherit meta passthru; } // passthru;
in
{
  inherit changeFirst capitalize uncapitalize toCamelCase
    toMixedCase toSnakeCase isUpper isLower substituteInPlace
    isCamelCase isMixedCase isSnakeCase setToStringSep
    mkStrictShellScript writeStrictShellScript
    writeStrictShellScriptBin strict-bash mkSimpleShell;

}
