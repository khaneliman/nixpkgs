{
  lib,
  booleanoperations,
  buildPythonPackage,
  cffsubr,
  compreffor,
  defcon,
  fetchFromGitHub,
  fontmath,
  fonttools,
  pytestCheckHook,
  setuptools,
  setuptools-scm,
  skia-pathops,
  syrupy,
  ufolib2,
  uharfbuzz,
}:

buildPythonPackage (finalAttrs: {
  pname = "ufo2ft";
  version = "3.9.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "googlefonts";
    repo = "ufo2ft";
    tag = "v${finalAttrs.version}";
    hash = "sha256-McMhpGIvQHpsOe3jza6E3b72cKiY8gr8W9OY2Mg9JvE=";
  };

  build-system = [
    setuptools
    setuptools-scm
  ];

  dependencies = [
    fontmath
    fonttools
    booleanoperations
    cffsubr
  ]
  ++ fonttools.optional-dependencies.lxml
  ++ fonttools.optional-dependencies.ufo;

  nativeCheckInputs = [
    pytestCheckHook
    syrupy
    ufolib2
    uharfbuzz
    defcon
  ]
  ++ finalAttrs.passthru.optional-dependencies.compreffor
  ++ finalAttrs.passthru.optional-dependencies.pathops;

  disabledTests = [
    # Do not depend on skia.
    "test_removeOverlaps_CFF_pathops"
    "test_removeOverlaps_pathops"
    "test_custom_filters_as_argument"
    "test_custom_filters_as_argument"
    # Some integration tests fail
    "test_compileVariableCFF2"
    "test_compileVariableTTF"
    "test_drop_glyph_names_variable"
    "test_drop_glyph_names_variable"
  ];
  optional-dependencies = {
    compreffor = [ compreffor ];
    cffsubr = [ ];
    pathops = [ skia-pathops ];
  };

  pythonImportsCheck = [ "ufo2ft" ];

  meta = {
    description = "Bridge from UFOs to FontTools objects";
    homepage = "https://github.com/googlefonts/ufo2ft";
    changelog = "https://github.com/googlefonts/ufo2ft/releases/tag/${finalAttrs.src.tag}";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ jopejoe1 ];
  };
})
