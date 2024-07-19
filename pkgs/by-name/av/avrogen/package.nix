{ lib, buildDotnetGlobalTool }:

buildDotnetGlobalTool rec {
  pname = "avrogen";
  nugetName = "Apache.Avro.Tools";
  version = "1.11.3";
  nugetSha256 = "sha256-nrG5NXCQwN1dOpf+fIXcbTjpYOHiQ++hBryYfpRFThU=";

  meta = {
    description = "Automates the acquisition of credentials needed to restore NuGet packages as part of your .NET development workflow";
    changelog = "https://github.com/microsoft/artifacts-credprovider/releases/tag/v${version}";
    homepage = "https://github.com/microsoft/artifacts-credprovider";
    license = lib.licenses.mit;
    longDescription = "The Azure Artifacts Credential Provider automates the acquisition of credentials needed to restore NuGet packages as part of your .NET development workflow. It integrates with MSBuild, dotnet, and NuGet(.exe) and works on Windows, Mac, and Linux. Any time you want to use packages from an Azure Artifacts feed, the Credential Provider will automatically acquire and securely store a token on behalf of the NuGet client you're using";
    maintainers = with lib.maintainers; [ khaneliman ];
    platforms = lib.platforms.all;
    mainProgram = "avrogen";
  };
}
