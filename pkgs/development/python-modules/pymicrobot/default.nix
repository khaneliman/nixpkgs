{ lib
, bleak
, bleak-retry-connector
, buildPythonPackage
, fetchPypi
, pythonOlder
, setuptools
}:

buildPythonPackage rec {
  pname = "pymicrobot";
  version = "0.0.15";
  pyproject = true;

  disabled = pythonOlder "3.9";

  src = fetchPypi {
    pname = "PyMicroBot";
    inherit version;
    hash = "sha256-1uJetSJ4P4PcuvzBQBfkQHVIvLU+rdyEZDV2T28GKhg=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  propagatedBuildInputs = [
    bleak
    bleak-retry-connector
  ];

  # Module has no tests
  doCheck = false;

  pythonImportsCheck = [
    "microbot"
  ];

  meta = with lib; {
    description = "Library to communicate with MicroBot";
    homepage = "https://github.com/spycle/pyMicroBot/";
    changelog = "https://github.com/spycle/pyMicroBot/releases/tag/v${version}";
    license = licenses.mit;
    maintainers = with maintainers; [ fab ];
  };
}
