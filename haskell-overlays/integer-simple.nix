{ haskellLib }:

self: super: {
  blaze-textual = haskellLib.enableCabalFlag super.blaze-textual "integer-simple";
  cryptonite = haskellLib.disableCabalFlag super.cryptonite "integer-gmp";
}
