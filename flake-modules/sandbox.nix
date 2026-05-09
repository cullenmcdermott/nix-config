# Flake module exposing the `sandbox` Go binary and its test check.
{ lib, ... }:
{
  perSystem = { pkgs, ... }: {
    packages.sandbox = pkgs.callPackage ../pkgs/sandbox { };

    checks.sandbox-go-test = pkgs.runCommand "sandbox-go-test" {
      buildInputs = [ pkgs.go ];
      preferLocalBuild = true;
    } ''
      export HOME=$TMPDIR
      export GOCACHE=$TMPDIR/go-cache
      export GOMODCACHE=$TMPDIR/go-mod
      cd ${lib.cleanSource ../pkgs/sandbox}
      go test ./...
      mkdir -p $out
      echo ok > $out/result
    '';
  };
}