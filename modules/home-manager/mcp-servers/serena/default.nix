{ config, lib, dream2nix, ... }: {
  imports = [
    dream2nix.modules.dream2nix.pip
  ];

  deps = {nixpkgs, ...}: {
    python = nixpkgs.python311;  # serena requires Python >=3.11, <3.12
  };

  name = "serena-agent";
  version = "0.1.3";

  mkDerivation = {
    src = config.paths.package;
  };

  buildPythonPackage = {
    pyproject = true;
    pythonImportsCheck = [
      "serena"
    ];
  };

  paths.lockFile = "./lock.${config.deps.stdenv.system}.json";

  pip = {
    requirementsList = [
      "hatchling"  # build system
      "requests>=2.32.3"
      "pyright>=1.1.396"
      "python-dotenv>=1.0.0"
      "flask>=3.0.0"
      "pydantic>=2.10.6"
      "anthropic>=0.54.0"
      # Add more dependencies as needed from pyproject.toml
    ];
    flattenDependencies = true;
  };
}