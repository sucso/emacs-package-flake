{ nixpkgs, flake-utils, fromElisp }:

{
  mkOutputs =
    { name
    , src
    , regexes ? [ "^.*\.el$" "^test$" "^test/.*$" ]
    , version ? null
    , overlays ? []
    , optionalDependencies ? []
    , doErt ? true
    , doCheckdoc ? true
    , doPackageLint ? true
    }:
    let
      file = src + "/${name}.el";
      filteredSrc = nixpkgs.lib.sourceByRegex src regexes;
      sourceFilesGlob = "${filteredSrc}/*.el";

      requiresFor = pkgs:
      let
        inherit (pkgs) lib;
        parse = import ./parse.nix {
          inherit lib;
          fromElisp = import "${fromElisp}/default.nix" { inherit lib pkgs; };
        };
      in
      builtins.filter (n: n != "emacs")
        (parse.parsePackagesFromPackageRequires (builtins.readFile file));

      versionFrom = file:
      let
        matches = builtins.filter (m: m != null)
          (map (l: builtins.match ";;;* *[vV]ersion *: *([^ \t\r]+) *" l)
            (nixpkgs.lib.splitString "\n" (builtins.readFile file)));
      in
      if matches == [ ] then throw "no Version header in ${file}"
      else builtins.head (builtins.head matches);

      resolvedVersion =
        if version != null then version
        else versionFrom file;

      packageOverlay = final: prev: {
        emacsPackagesFor = emacs:
          (prev.emacsPackagesFor emacs).overrideScope (efinal: _eprev: {
            ${name} = mkPackage final efinal;
          });
      };

      overlay = nixpkgs.lib.composeManyExtensions (overlays ++ [ packageOverlay ]);

      mkPackage = pkgs: efinal:
      efinal.melpaBuild {
        pname = name;
        version = resolvedVersion;
        src = filteredSrc;
        packageRequires = map (x: efinal.${x}) (requiresFor pkgs);
        turnCompilationWarningToError = true;
      };

      mkChecks = pkgs: efinal:
      let
        inherit (pkgs) lib;
        requires = requiresFor pkgs;

        emacsWith = efinal: packages:
          efinal.emacsWithPackages (epkgs: map (x: epkgs.${x}) packages);
        emacsWithDeps = emacsWith efinal requires;
        emacsForChecks = emacsWith efinal
          (requires ++ optionalDependencies
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
      lib.optionalAttrs doErt { inherit ert; }
      // lib.optionalAttrs doPackageLint { inherit package-lint; }
      // lib.optionalAttrs doCheckdoc { inherit checkdoc; };
    in
    { overlays.default = overlay; }
    // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; overlays = [ overlay ]; };
      scope = pkgs.emacsPackagesFor pkgs.emacs;
    in
    {
      packages.default = scope.${name};
      checks = mkChecks pkgs scope;
    });
}
