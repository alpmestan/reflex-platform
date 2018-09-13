{ haskellLib }:

self: super: {
  blaze-textual = haskellLib.enableCabalFlag super.blaze-textual "integer-simple";
}
