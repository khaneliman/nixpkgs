{
  lib,
  stdenv,
  buildDotnetModule,
  fetchFromGitHub,
  dotnetCorePackages,
  mono,
}:

buildDotnetModule rec {
  pname = "artifacts-credprovider";
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "artifacts-credprovider";
    rev = "v${version}";
    hash = "";
  };

  projectFile = "CredentialProvider.Microsoft/CredentialProvider.Microsoft.csproj";

  nugetDeps = ./deps.nix;

  dotnet-sdk = dotnetCorePackages.sdk_6_0;

  dotnet-runtime = dotnetCorePackages.runtime_6_0;

  doCheck = !(stdenv.isDarwin && stdenv.isAarch64); # mono is not available on aarch64-darwin

  nativeCheckInputs = [ mono ];

  testProjectFile = "CredentialProvider.Microsoft.Tests/CredentialProvider.Microsoft.Tests.csproj";

  passthru.updateScript = ./updater.sh;

  meta = {
    description = "Automates the acquisition of credentials needed to restore NuGet packages as part of your .NET development workflow";
    changelog = "https://github.com/microsoft/artifacts-credprovider/releases/tag/v${version}";
    homepage = "https://github.com/microsoft/artifacts-credprovider";
    license = lib.licenses.mit;
    longDescription = "The Azure Artifacts Credential Provider automates the acquisition of credentials needed to restore NuGet packages as part of your .NET development workflow. It integrates with MSBuild, dotnet, and NuGet(.exe) and works on Windows, Mac, and Linux. Any time you want to use packages from an Azure Artifacts feed, the Credential Provider will automatically acquire and securely store a token on behalf of the NuGet client you're using";
    maintainers = with lib.maintainers; [ khaneliman ];
    platforms = lib.platforms.all;
  };
}
