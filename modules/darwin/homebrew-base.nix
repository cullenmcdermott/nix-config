{ ... }:
{
  homebrew = {
    enable = true;
    global.brewfile = true;
    taps = [ "manaflow-ai/cmux" ];
    masApps = {};
    casks = [ ];
  };
}
