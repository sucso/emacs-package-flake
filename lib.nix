{ nixpkgs, flake-utils, fromElisp }:

{
  mkOutputs =
    { name
    , src
    , regexes ? [ "^.*\.el$" "^tests?$" "^tests?/.*$" ]
    , version ? null
    , overlays ? []
    , doCheck ? true
    , doErt ? false
    , doCheckdoc ? true
    , doPackageLint ? true
    }:
    let
      packageOverlay = final: prev: {
        emacsPackagesFor = emacs:
        (prev.emacsPackagesFor emacs).overrideScope (efinal: _eprev: {
          ${name} = mkPackage final efinal;
        });
      };
      overlay = nixpkgs.lib.composeManyExtensions (overlays ++ [packageOverlay]);

      mkPackage = pkgs: efinal:
      let
        inherit (pkgs) lib;
        file = src + "/${name}.el";

        parse = import ./parse.nix {
          inherit lib;
          fromElisp = import "${fromElisp}/default.nix" { inherit pkgs lib; };
        };
        requires = builtins.filter (n: n != "emacs")
          (parse.parsePackagesFromPackageRequires
            (builtins.readFile file));
        dependencies = requires
        ++ (lib.optional doErt "ert-runner")
        ++ (lib.optional doPackageLint "package-lint");
        emacsWithDeps = efinal.emacsWithPackages (epkgs:
        map (x: builtins.getAttr x epkgs) dependencies);

        versionFrom = file:
        let
          matches = builtins.filter (m: m != null)
            (map (l: builtins.match ";;;* *[vV]ersion *: *([^ \t\r]+) *" l)
              (lib.splitString "\n" (builtins.readFile file)));
        in
        if matches == [ ] then throw "no Version header in ${file}"
        else builtins.head (builtins.head matches);
        resolvedVersion =
          if version != null then version
          else versionFrom file;
      in
      pkgs.stdenv.mkDerivation {
        pname = name;
        version = resolvedVersion;
        buildInputs = [ emacsWithDeps ];
        propagatedBuildInputs = map (x: efinal.${x}) requires;
        src = lib.sourceByRegex src regexes;

        buildPhase = ''
          set -e
          emacs -L . --batch -f batch-byte-compile *.el 2> stderr.txt
          cat stderr.txt
          ! grep -q ': Warning:' stderr.txt || false
        '';

        installPhase = ''
          set -e
          LISPDIR=$out/share/emacs/site-lisp
          install -d $LISPDIR
          install *.el *.elc $LISPDIR
        '';

        inherit doCheck;
        checkPhase = ''
          set -e

          ${lib.optionalString doErt ''
            emacs -L . --batch \
              --eval "(progn (require 'ert-runner) (ert-run-tests t (lambda (x) nil)))"
          ''}

          ${lib.optionalString doCheckdoc ''
            emacs -L . --batch --eval "
              (progn
                (require 'checkdoc)
                (dolist (x command-line-args-left)
                  (checkdoc-file x)))
            " *.el 2> checkdoc-stderr.txt
            cat checkdoc-stderr.txt
            ! test -s checkdoc-stderr.txt || false
          ''}

          ${lib.optionalString doPackageLint ''
            emacs -L . \
              --batch \
              --eval "
                (progn
                  (require 'package-lint)
                  (defun package-lint--check-packages-installable (valid-deps) nil)
                  (package-lint-batch-and-exit))
              " \
              *.el
          ''}
        '';

        # TODO Attempt to populate the Nix package's meta attribute?

      };
    in
    { overlays.default = overlay; }
    // flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import nixpkgs { inherit system; overlays = [overlay]; };
    in
    {
      packages.default = (pkgs.emacsPackagesFor pkgs.emacs).${name};
    });
}
