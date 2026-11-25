# Emacs Package Flake

This is a library that can be used to define Nix flakes for Emacs packages. It comes with a number of useful checks:
* bytecode compilation;
* [Emacs Lisp Regression Testing (ERT)][ert];
* [`checkdoc`][checkdoc];
* [`package-lint`][package-lint].

One use case is to have a continuous-integration (CI) setup for Emacs Lisp packages.

[ert]: https://www.gnu.org/software/emacs/manual/html_mono/ert.html
[checkdoc]: https://github.com/emacs-mirror/emacs/blob/master/lisp/emacs-lisp/checkdoc.el
[package-lint]: https://github.com/purcell/package-lint

## Usage

The main interface provided by `emacs-package-flake` is `mkFlakeOutputs`. Here's a minimal example that makes use of it to populate the outputs of a flake, specifically its `check`, `package`, and `overlay` fields.

```nix
# flake.nix
{
  inputs = {
    emacs-package-flake.url = "github:sucso/emacs-package-flake";
  };
  outputs = { self, emacs-package-flake }:
    emacs-package-flake.lib.mkFlakeOutputs {
      name = "my-package";
      src = ./.;
    };
}
```

The `mkFlakeOutputs` function accepts the following arguments.
* `name` (required): the name of the Emacs package.
* `src` (required): the directory where the Emacs package is located.
* `version` (optional): a string indicating the version of the Emacs package. Defaults to the value of the Emacs package's version header.
* `regexes` (optional): a list of regular expressions that match the Emacs package's source files. Defaults to `[ "^.*\.el$" "^test/.*$" ]`. (By default, the Emacs packages are assumed to be located at the top level of the `src` directory, while the ERT tests are assumed to be located under `src`'s `test` subdirectory.)
* `optionalDependencies` (optional): a list of Emacs features, as strings. Defaults to `[]`. If any optional dependencies are declared, they will be provided to the ERT environment.
* `overlays` (optional): a list of overlays for the Emacs package's own dependencies, typically the `overlays.default` output of each dependency's flake. They are composed with the package's overlay. Defaults to `[]`.
* `doErt` (optional): whether to run ERT tests. Defaults to `true`.
* `doCheckdoc` (optional): whether to run `checkdoc`. Defaults to `true`.
* `doPackageLint` (optional): whether to run `package-lint`. Defaults to `true`.

The flake also provides the following functions.
* `packageRequires`. A function that takes a path to an Elisp file and returns the packages it requires (as in MELPA's `;; PackageRequires`) as a list of strings.
* `packageVersion`. A function that takes a path to an Elisp file and returns its `;; PackageVersion`.
* `mkPackage`. A function that wraps nixpkgs's `melpaBuild` to create an Emacs package. It takes the following arguments: `name`, `src`, `version`, `regexes`, `emacsPackages`, `buildArgs`; all are as in `mkFlakeOutputs`.
* `mkPackageOverlay`. A function that returns an overlay to add the output of a `mkPackage` call to the output of `emacsPackagesFor`. (The overall effect is to add the same Emacs package to an instance of nixpkgs.) It takes the following arguments (all are passed to `mkPackage`): `name`, `src`, `version`, `regexes`, `buildArgs`.
* `fromElisp`. A function that takes an Emacs Lisp snippet and turns it into a Nix representation. See [talyz/fromElisp](https://github.com/talyz/fromElisp) for more information.

## Use with GitHub actions

```yaml
# .github/workflows/ci.yaml
name: "Emacs Package Flake"
on:
  push:
    branches:
      - master
  pull_request:
    types:
      - opened
      - synchronize
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v32
      - run: nix flake check
      - run: nix build
```

## License

Copyright © 2023–2026    Mark Karpov   (MIT license)  
Copyright © 2026–present Luca Prandini (GNU GPLv3 license)

Distributed under the GNU GPLv3 license.
