{lib}: {
  scanPaths = path:
    builtins.map (f: path + "/${f}") (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          name: type:
            (type == "directory")
            || ((name != "default.nix") && (lib.strings.hasSuffix ".nix" name))
        ) (builtins.readDir path)
      )
    );
}
