{
  config,
  lib,
  ...
}:
{
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 14d";
  };
  launchd.daemons.nix-gc.serviceConfig.StartCalendarInterval = [
    { Weekday = 6; Hour = 10; Minute = 0; }
    { Weekday = 0; Hour = 10; Minute = 0; }
    { Weekday = 1; Hour = 20; Minute = 0; }
    { Weekday = 1; Hour = 21; Minute = 0; }
    { Weekday = 2; Hour = 20; Minute = 0; }
    { Weekday = 2; Hour = 21; Minute = 0; }
    { Weekday = 3; Hour = 20; Minute = 0; }
    { Weekday = 3; Hour = 21; Minute = 0; }
    { Weekday = 4; Hour = 20; Minute = 0; }
    { Weekday = 4; Hour = 21; Minute = 0; }
    { Weekday = 5; Hour = 20; Minute = 0; }
    { Weekday = 5; Hour = 21; Minute = 0; }
  ];
}
