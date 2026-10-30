{
  description = "A library to facilitate the definition of Nix Flakes for Emacs packages";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    fromElisp = {
      url = "https://github.com/talyz/fromElisp";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, fromElisp }: {
    lib = import ./lib.nix {
      inherit nixpkgs flake-utils fromElisp;
    };
  };
}
