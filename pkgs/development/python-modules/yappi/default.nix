{ lib
, buildPythonPackage
, fetchFromGitHub
, gevent
, python
, pythonOlder
}:

buildPythonPackage rec {
  pname = "yappi";
  version = "1.6.0";
  format = "setuptools";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "sumerc";
    repo = pname;
    rev = "refs/tags/${version}";
    hash = "sha256-zA4apOGyrbjBOxUKBARiKmmM9rSVFVGWsDpOaItOoLU=";
  };

  patches = [
    ./tests.patch
  ];

  nativeCheckInputs = [
    gevent
  ];

  checkPhase = ''
    ${python.interpreter} run_tests.py
  '';

  pythonImportsCheck = [
    "yappi"
  ];

  meta = with lib; {
    description = "Python profiler that supports multithreading and measuring CPU time";
    homepage = "https://github.com/sumerc/yappi";
    license = licenses.mit;
    maintainers = with maintainers; [ orivej ];
  };
}
