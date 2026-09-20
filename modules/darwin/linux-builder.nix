# Linux remote builder VM. With this enabled, `nix build --system aarch64-linux`
# transparently routes to a NixOS VM running on this Mac. Added for the
# nix-image-builder/mkosi work, which needs a real Linux kernel and user
# namespaces to build OS images.
#
# The VM is also sshable for impure work the nix sandbox forbids:
#   sudo ssh builder@linux-builder
#
# TWO-STAGE BOOTSTRAP -- see `tuned` below. Upstream nixpkgs is explicit about
# this: "Initially you should not change the remote builder configuration else
# you will not be able to use the binary cache."
{ config, lib, ... }:
let
  cfg = config.cullen.linuxBuilder;
in
{
  options.cullen.linuxBuilder = {
    enable = lib.mkEnableOption "Linux remote builder VM (nix.linux-builder)";

    tuned = lib.mkEnableOption ''
      resized + x86_64-emulating builder VM.

      Leave this OFF for the first switch. Any change to the VM's NixOS config
      makes it a cache miss, and building it then requires the very
      aarch64-linux builder it is supposed to provide -- a deadlock that
      surfaces as "platform mismatch" errors on darwin-rebuild.

      Once the stock builder is running, flip this on and rebuild: the builder
      builds its own replacement
    '';
  };

  config = lib.mkIf cfg.enable {
    nix.linux-builder = {
      enable = true;
      # Host-side only (feeds the `builders =` line), so it never invalidates
      # the cached VM and is safe during bootstrap.
      maxJobs = 4;
      systems = [ "aarch64-linux" ] ++ lib.optional cfg.tuned "x86_64-linux";
    }
    // lib.optionalAttrs cfg.tuned {
      config = {
        # qemu-user-static will not link at current nixpkgs: gnutls drags in
        # nettle, whose --enable-fat dispatch table overflows the GOT under
        # -static-pie (R_AARCH64_LD64_GOTPAGE_LO15 truncated). gnutls is there
        # only for luks in qemu-img, which user-mode builds do not ship -- so
        # drop it. Scoped to pkgsStatic to keep the VM's ordinary closure
        # cache-hot. Not a version regression: qemu 10.2.4 from nixos-26.05
        # fails identically. Drop once nettle/binutils fix the relocation.
        nixpkgs.overlays = [
          (_final: prev: {
            qemu-user =
              if prev.stdenv.hostPlatform.isStatic then
                prev.qemu-user.overrideAttrs (o: {
                  configureFlags = map (f: if f == "--enable-gnutls" then "--disable-gnutls" else f) o.configureFlags;
                })
              else
                prev.qemu-user;
          })
        ];

        # x86_64 on aarch64 silicon means every dpkg maintainer script runs
        # under qemu-user: correct, but slow, and a nondeterminism source of
        # its own. Fine for development -- x86 release builds should eventually
        # move to a real x86 builder rather than emulation.
        boot.binfmt = {
          emulatedSystems = [ "x86_64-linux" ];
          # Static emulators get binfmt's F (fix-binary) flag, which pins the
          # interpreter at registration time instead of resolving it per-exec.
          # Without it the interpreter path (/run/binfmt/...) is invisible
          # inside mkosi's mount namespace and every foreign-arch maintainer
          # script dies with ENOENT.
          preferStaticEmulators = true;
        };

        virtualisation = {
          cores = 6;
          darwin-builder = {
            # OS image builds are disk-hungry: rootfs, package cache, and two
            # full copies for reproducibility diffing. The default is 20G. Kept well
            # under the host's free space -- qcow2 is sparse, but a runaway build
            # should not be able to fill the Mac.
            diskSize = 100 * 1024; # MiB
            memorySize = 8 * 1024; # MiB
          };
        };
      };
    };
  };
}
