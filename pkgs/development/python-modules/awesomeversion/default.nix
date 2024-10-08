{ lib
, buildPythonPackage
, fetchFromGitHub
, pythonOlder

# build-system
, poetry-core

# tests
, pytest-snapshot
, pytestCheckHook
}:

buildPythonPackage rec {
  pname = "awesomeversion";
  version = "24.2.0";
  format = "pyproject";

  disabled = pythonOlder "3.8";

  src = fetchFromGitHub {
    owner = "ludeeus";
    repo = pname;
    rev = "refs/tags/${version}";
    hash = "sha256-bpLtHhpWc1VweVl5G8mM473Js3bXT11N3Zc0jiVqq5c=";
  };

  postPatch = ''
    # Upstream doesn't set a version
    substituteInPlace pyproject.toml \
      --replace 'version = "0"' 'version = "${version}"'
  '';

  nativeBuildInputs = [
    poetry-core
  ];

  pythonImportsCheck = [
    "awesomeversion"
  ];

  nativeCheckInputs = [
    pytest-snapshot
    pytestCheckHook
  ];

  meta = with lib; {
    description = "Python module to deal with versions";
    homepage = "https://github.com/ludeeus/awesomeversion";
    changelog = "https://github.com/ludeeus/awesomeversion/releases/tag/${version}";
    license = with licenses; [ mit ];
    maintainers = with maintainers; [ fab ];
  };
}
