{ lib
, buildPythonPackage
, pythonRelaxDepsHook
, fetchPypi
, grpcio
, protobuf
}:

buildPythonPackage rec {
  pname = "grpcio-channelz";
  version = "1.60.1";
  format = "setuptools";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-eAYWHTlyThrJ9vTumXPDeEcyk5OC8tfI12K073heF6A=";
  };

  nativeBuildInputs = [
    pythonRelaxDepsHook
  ];
  pythonRelaxDeps = [
    "grpcio"
  ];

  propagatedBuildInputs = [
    grpcio
    protobuf
  ];

  pythonImportsCheck = [ "grpc_channelz" ];

  # no tests
  doCheck = false;

  meta = with lib; {
    description = "Channel Level Live Debug Information Service for gRPC";
    homepage = "https://pypi.org/project/grpcio-channelz";
    license = with licenses; [ asl20 ];
    maintainers = with maintainers; [ happysalada ];
  };
}
