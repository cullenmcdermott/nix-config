{ pkgs, lib, ... }:

pkgs.python3Packages.buildPythonApplication rec {
  pname = "claude-monitor";
  version = "1.0.18";
  pyproject = true;

  src = pkgs.fetchFromGitHub {
    owner = "Maciek-roboblog";
    repo = "Claude-Code-Usage-Monitor";
    rev = "v${version}";
    sha256 = "sha256-mnS0n7PYNAJpXCeFA9UzayYbpmcE445xPH6giU2ueig=";
  };

  build-system = with pkgs.python3Packages; [
    hatchling
  ];

  propagatedBuildInputs = with pkgs.python3Packages; [
    requests
    click
    rich
    anthropic
    pytz
    # Add other dependencies as needed
  ];

  # Skip tests since this is a simple CLI tool
  doCheck = false;

  meta = with lib; {
    description = "Monitor Claude API usage";
    homepage = "https://github.com/Maciek-roboblog/Claude-Code-Usage-Monitor";
    license = licenses.mit;
    maintainers = [ ];
  };
}
