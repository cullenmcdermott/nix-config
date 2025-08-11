{ config, lib, dream2nix, ... }: {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python312;  # kagimcp requires Python >=3.12
  };

  name = "kagimcp";
  version = "0.1.3";

  mkDerivation = {
    src = config.paths.package;
  };

  buildPythonPackage = {
    pyproject = true;
    pythonImportsCheck = [
      "kagimcp"
    ];
  };

  paths.lockFile = "./lock.${config.deps.stdenv.system}.json";

  pip = {
    requirementsList = [
      "hatchling"  # build system
      "kagiapi~=0.2.1"
      "mcp[cli]~=1.6.0" 
      "pydantic~=2.10.3"
    ];
    flattenDependencies = true;
  };
}