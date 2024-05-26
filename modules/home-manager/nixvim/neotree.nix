{
  plugins.neo-tree = {
    enable = true;
    filesystem = {
      bindToCwd = false;
      followCurrentFile = { enabled = true; };
    };
  };
}
