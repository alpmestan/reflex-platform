{ haskellLib
, lib, nixpkgs
, fetchFromGitHub, hackGet
, useFastWeak, useReflexOptimizer, enableTraceReflexEvents
}:

with haskellLib;

self: super:

let
  reflexDom = import (hackGet ../reflex-dom) self nixpkgs;
  jsaddleSrc = hackGet ../jsaddle;
  gargoylePkgs = self.callPackage (hackGet ../gargoyle) self;
  ghcjsDom = import (hackGet ../ghcjs-dom) self;
  addReflexTraceEventsFlag = drv: if enableTraceReflexEvents
    then appendConfigureFlag drv "-fdebug-trace-events"
    else drv;
  addReflexOptimizerFlag = drv: if useReflexOptimizer && (self.ghc.cross or null) == null
    then appendConfigureFlag drv "-fuse-reflex-optimizer"
    else drv;
  addFastWeakFlag = drv: if useFastWeak
    then enableCabalFlag drv "fast-weak"
    else drv;
in
{
  ##
  ## Reflex family
  ##

  reflex = dontCheck (addFastWeakFlag (addReflexTraceEventsFlag (addReflexOptimizerFlag (self.callPackage (hackGet ../reflex) {}))));
  reflex-todomvc = self.callPackage (hackGet ../reflex-todomvc) {};
  reflex-aeson-orphans = self.callCabal2nix "reflex-aeson-orphans" (hackGet ../reflex-aeson-orphans) {};

  # Broken Haddock - Please fix!
  # : error is: haddock: internal error: internal: extractDecl
  # No idea where it hits?
  reflex-dom = dontHaddock (addReflexOptimizerFlag reflexDom.reflex-dom);
  reflex-dom-core = dontHaddock (addReflexOptimizerFlag reflexDom.reflex-dom-core);

  ##
  ## GHCJS and JSaddle
  ##

  jsaddle = self.callCabal2nix "jsaddle" "${jsaddleSrc}/jsaddle" {};
  jsaddle-clib = self.callCabal2nix "jsaddle-clib" "${jsaddleSrc}/jsaddle-clib" {};
  jsaddle-webkit2gtk = self.callCabal2nix "jsaddle-webkit2gtk" "${jsaddleSrc}/jsaddle-webkit2gtk" {};
  jsaddle-webkitgtk = self.callCabal2nix "jsaddle-webkitgtk" "${jsaddleSrc}/jsaddle-webkitgtk" {};
  jsaddle-wkwebview = overrideCabal (self.callCabal2nix "jsaddle-wkwebview" "${jsaddleSrc}/jsaddle-wkwebview" {}) (drv: {
    # HACK(matthewbauer): Can’t figure out why cf-private framework is
    #                     not getting pulled in correctly. Has something
    #                     to with how headers are looked up in xcode.
    preBuild = lib.optionalString (!nixpkgs.stdenv.hostPlatform.useiOSPrebuilt) ''
      mkdir include
      ln -s ${nixpkgs.buildPackages.darwin.cf-private}/Library/Frameworks/CoreFoundation.framework/Headers include/CoreFoundation
      export NIX_CFLAGS_COMPILE="-I$PWD/include $NIX_CFLAGS_COMPILE"
    '';

    libraryFrameworkDepends = (drv.libraryFrameworkDepends or []) ++
      (if nixpkgs.stdenv.hostPlatform.useiOSPrebuilt then [
         "${nixpkgs.buildPackages.darwin.xcode}/Contents/Developer/Platforms/${nixpkgs.stdenv.hostPlatform.xcodePlatform}.platform/Developer/SDKs/${nixpkgs.stdenv.hostPlatform.xcodePlatform}.sdk/System"
       ] else with nixpkgs.buildPackages.darwin; with apple_sdk.frameworks; [
         Cocoa
         WebKit
       ]);
  });

  # another broken test
  # phantomjs has issues with finding the right port
  # jsaddle-warp = dontCheck (addTestToolDepend (self.callCabal2nix "jsaddle-warp" "${jsaddleSrc}/jsaddle-warp" {}));
  jsaddle-warp = dontCheck (self.callCabal2nix "jsaddle-warp" "${jsaddleSrc}/jsaddle-warp" {});

  jsaddle-dom = self.callPackage (hackGet ../jsaddle-dom) {};
  inherit (ghcjsDom) ghcjs-dom-jsffi;

  ##
  ## Gargoyle
  ##

  inherit (gargoylePkgs) gargoyle gargoyle-postgresql;

  ##
  ## Misc other dependencies
  ##

  haskell-gi-overloading = dontHaddock (self.callHackage "haskell-gi-overloading" "0.0" {});

  monoidal-containers = self.callCabal2nix "monoidal-containers" (fetchFromGitHub {
    owner = "obsidiansystems";
    repo = "monoidal-containers";
    rev = "79c25ac6bb469bfa92f8fd226684617b6753e955";
    sha256 = "0j2mwf5zhz7cmn01x9v51w8vpx16hrl9x9rcx8fggf21slva8lf8";
  }) {};
}