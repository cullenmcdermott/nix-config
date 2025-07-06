{
  disko.devices = {
    disk = {
      main = {
        type = "disk";
        device = "/dev/sda";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              size = "512M";
              type = "EF00";
              priority = 1000; # Ensure ESP is created early
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [ "defaults" ];
              };
            };
            swap = {
              size = "34G";
              priority = 2000; # Create swap after ESP
              content = {
                type = "swap";
                resumeDevice = true;
              };
            };
            root = {
              size = "100G";
              priority = 3000; # Root before nix
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
                mountOptions = [ "defaults" "noatime" ];
              };
            };
            nix = {
              size = "100%"; # Takes remaining space
              priority = 4000; # Lowest priority, created last
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/nix";
                mountOptions = [ "defaults" "noatime" ];
              };
            };
          };
        };
      };
    };
  };
  
  # This is crucial - it generates the fileSystems configuration
  # with proper neededForBoot flags
  fileSystems."/nix".neededForBoot = true;
}
