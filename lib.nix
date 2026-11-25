{ nixpkgs, flake-utils, fromElisp }:

let
  elispRegexes = [ "^.*\.el$" "^test$" "^test/.*$" ];
in
rec {
  inherit fromElisp;

  packageRequires = file:
  let
    inherit (nixpkgs) lib;
    parse = import ./parse.nix {
      inherit lib;
      fromElisp = import "${fromElisp}/default.nix" { inherit nixpkgs lib; };
    };
  in
  builtins.filter (n: n != "emacs")
    (parse.parsePackagesFromPackageRequires (builtins.readFile file));

  packageVersion = file:
  let
    matches = builtins.filter (m: m != null)
      (map (l: builtins.match ";;;* *[vV]ersion *: *([^ \t\r]+) *" l)
        (nixpkgs.lib.splitString "\n" (builtins.readFile file)));
  in
  if matches == [ ] then throw "no Version header in ${file}"
  else builtins.head (builtins.head matches);

  mkPackage =
    { name
    , src
    , version ? null
    , regexes ? elispRegexes
    , emacsPackages
    , buildArgs ? {}
    }:
    let
      file = src + "/${name}.el";
      filteredSrc = nixpkgs.lib.sourceByRegex src regexes;

      resolvedVersion =
        if version != null then version
        else packageVersion file;
    in
    emacsPackages.melpaBuild ({
      pname = name;
      version = resolvedVersion;
      src = filteredSrc;
      packageRequires = map (x: emacsPackages.${x}) (packageRequires file);
      turnCompilationWarningToError = true;
    } // buildArgs);

  mkPackageOverlay =
    { name
    , src
    , version ? null
    , regexes ? elispRegexes
    , buildArgs ? {}
    , ...
    }:
    (final: prev: {
      emacsPackagesFor = emacs:
      (prev.emacsPackagesFor emacs).overrideScope (efinal: _eprev: {
        ${name} = mkPackage {
          inherit name src version regexes buildArgs;
          emacsPackages = efinal;
        };
      });
    });

  mkFlakeOutputs =
    { name
    , src
    , version ? null
    , regexes ? elispRegexes
    , overlays ? []
    , optionalDependencies ? []
    , doErt ? true
    , doCheckdoc ? true
    , doPackageLint ? true
    , buildArgs ? {}
    }:
    let
      overlay = nixpkgs.lib.composeManyExtensions (overlays ++ [
        (mkPackageOverlay { inherit name src version regexes buildArgs; })
      ]);
    in
    { overlays.default = overlay; }
    // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
      epkgs = pkgs.emacsPackagesFor pkgs.emacs;
      inherit (pkgs) lib;

      emacsWith = epkgs: required:
      epkgs.emacsWithPackages (epkgs: map (x: epkgs.${x}) required);

      file = src + "/${name}.el";
      filteredSrc = lib.sourceByRegex src regexes;
      sourceFilesGlob = "${filteredSrc}/*.el";
      required = packageRequires file;
      emacsWithDeps = emacsWith epkgs required;
      emacsForChecks = emacsWith epkgs
        (required ++ optionalDependencies
        ++ (lib.optional doPackageLint "package-lint"));

      ert = pkgs.runCommand
        "${name}-ert" { nativeBuildInputs = [ emacsForChecks ]; }
        ''
          emacs --batch \
            --directory ${filteredSrc} \
            --directory ${filteredSrc}/test \
            --eval "
              (progn
                (mapc 'load-file (file-expand-wildcards \"${filteredSrc}/test/*.el\"))
                (ert-run-tests-batch-and-exit))
            "
          touch $out
        '';

      package-lint = pkgs.runCommand
        "${name}-package-lint" { nativeBuildInputs = [ emacsForChecks ]; }
        ''
          emacs --batch --eval "
            (progn
              (require 'package-lint)
              (defun package-lint--check-packages-installable (valid-deps) nil)
              (package-lint-batch-and-exit))
            " ${sourceFilesGlob}
          touch $out
        '';

      checkdoc = pkgs.runCommand
        "${name}-checkdoc" { nativeBuildInputs = [ emacsWithDeps ]; }
        ''
          emacs --batch --eval "
            (progn
              (require 'checkdoc)
              (dolist (x (file-expand-wildcards \"${sourceFilesGlob}\"))
                (checkdoc-file x)))
          " 2> checkdoc-stderr.txt
          cat checkdoc-stderr.txt
          ! test -s checkdoc-stderr.txt || false
          touch $out
        '';
    in
    {
      packages.default = epkgs.${name};
      checks =
        lib.optionalAttrs doErt { inherit ert; }
        // lib.optionalAttrs doPackageLint { inherit package-lint; }
        // lib.optionalAttrs doCheckdoc { inherit checkdoc; };
    });

  mkOutputs = mkFlakeOutputs; # Backwards compatibility.
}
