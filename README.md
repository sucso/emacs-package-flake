# Emacs Package Flake

This is a library that can be used to define Nix flakes for Emacs packages. It comes with a number of useful checks:

* bytecode compilation;
* the [Emacs Lisp Regression Testing (ERT)][ert] tool;
* `checkdoc` for all `*.el` files;
* [`package-lint`][package-lint] for all `*.el` files.

The main use case is to have an easy and reliable continuous-integration (CI) setup for Emacs Lisp packages.

[ert]: https://www.gnu.org/software/emacs/manual/html_mono/ert.html
[package-lint]: https://github.com/purcell/package-lint

## Usage

```nix
# flake.nix
{
  inputs = {
    emacs-package-flake.url = "github:luca-pr/emacs-package-flake";
  };
  outputs = { self, emacs-package-flake }:
    emacs-package-flake.lib.mkOutputs {
      name = "my-package";
      src = ./.;
    };
}
```

The `mkOutputs` function accepts the following arguments.
* `name` (required): the name of the Emacs package.
* `src` (required): the directory where the Emacs package is located.
* `regexes` (optional): a list of regular expressions that match the Emacs package's source files. The default value is `[ "^.*\.el$" "^test/.*$" ]`. (By default, the Emacs packages are assumed to be located at the top level of the `src` directory, while the ERT tests are assumed to be located under `src`'s `test` subdirectory.)
* `version` (optional): a string indicating the version of the Emacs package. Defaults to the value of the Emacs package's version header.
* `overlays` (optional): a list of overlays for the Emacs package's own dependencies, typically the `overlays.default` output of each dependency's flake. They are composed with the package's overlay. Defaults to `[]`.
* `doCheck` (optional): passed to the Nix derivation for the Emacs package. Defaults to `true`. Setting `doCheck` to `false` disables all checks.
* `doErt` (optional): whether to run ERT tests. Defaults to `false`.
* `doCheckdoc` (optional): whether to run `checkdoc`. Defaults to `true`.
* `doPackageLint` (optional): whether to run `package-lint`. Defaults to `true`.

## Use with GitHub actions

```yaml
# .github/workflows/ci.yaml
name: CI
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
      - uses: actions/checkout@v3
      - uses: cachix/install-nix-action@v21
      - run: nix build
```

## License

Copyright © 2023–2026    Mark Karpov   (MIT license)  
Copyright © 2026–present Luca Prandini (GNU GPLv3 license)

Distributed under the GNU GPLv3 license.
