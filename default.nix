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

  ## A helper for creating shell script derivations from files
  ## see above - enables one to get syntax highlighting while
  ## developing.
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

  ## Fail on undefined variables etc. and enforce shellcheck on all scripts.
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


  ## Takes shell code on stdin, runs shellcheck on it and automatically adds
  ## the inofficial strict-mode - eg. "set -euo pipefail"
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
  inherit changeFirst capitalize uncapitalize toCamelCase
    toMixedCase toSnakeCase isUpper isLower substituteInPlace
    isCamelCase isMixedCase isSnakeCase setToStringSep
    mkStrictShellScript writeStrictShellScriptBin strict-bash;

}
