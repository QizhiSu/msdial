# How to contribute to MS-DIAL / MS-FINDER

I'm really glad you're reading this, because we need volunteer developers to help this project come to fruition.

## Building the latest MS-DIAL

Use the current GitHub Actions workflows as the source of truth for reproducible build and test commands:

- [PR build and tests](.github/workflows/dotnet_pr.yml)
- [Master build and publish workflows](.github/workflows/dotnet_master.yml)

Both currently use the .NET 8 SDK; the PR workflow restores, builds, and tests the `Debug vendor unsupported` configuration on Windows. The repository uses the `Assemblies` directory as an additional NuGet source. For Visual Studio setup and GUI development, see the [MS-DIAL development video](https://www.youtube.com/watch?app=desktop&v=5eDAsISjj2I).

And it's important to note that our build artifacts come in two types: those that use the follwoing SDK from the MS vendors and those that do not.

- AB Sciex WiffReader and Data API Libraries
- Agilent MHDAC and MIDAC Libraries
- Bruker CXT, Baf2Sql, and TDF Development Kit Libraries
- Shimadzu DataReader and IoModule Libraries
- Thermo Scientific RawFileReader Library
- Waters MassLynxRaw Library

Vendor-SDK-backed builds require proprietary vendor libraries and are not available in the public source build. The public `vendor unsupported` configuration does not include those SDKs. Supported input formats depend on the active reader implementation and build; check the [README](README.md) and current source/configuration rather than assuming a vendor format is readable from its extension alone. Do not commit vendor SDKs, license files, or private raw data.

Also, MS-DIAL primarily comes in two versions: version 4 series and version 5 series.
However, only the version 5 series of MS-DIAL has reproducible builds that can be guaranteed openly.

## Testing

The current PR workflow is the canonical repository-wide build and test recipe: [`.github/workflows/dotnet_pr.yml`](.github/workflows/dotnet_pr.yml). It runs on Windows. For faster iteration, run the relevant test project (and, where useful, a focused test filter) rather than rebuilding the entire solution after every edit. Check each project's target framework before choosing a command; some test projects target .NET 8, while GUI projects target .NET Framework and require Windows.

## Did you find a bug?

Feel free to create a GitHub issue on https://github.com/systemsomicslab/MsdialWorkbench/issues .

## Do you have questions about MS-DIAL / MS-FINDER ?

Feel free to create a GitHub discussion on https://github.com/systemsomicslab/MsdialWorkbench/discussions .

## Technical Topics
- This repository contains projects targeting multiple frameworks. The current CI uses the .NET 8 SDK; the MS-DIAL 5 GUI project targets .NET Framework 4.7.2, 4.8, and 4.8.1, and its WPF interface is Windows-only. Check the specific project file and CI workflow before selecting a target framework or build command.
- This project can be coded in Visual Studio Code (VSCode), but the GUI part may have limitations in terms of preview functionality within VSCode. If you intend to contribute to the GUI part of the code and would like to have access to a preview, we recommend using Visual Studio.
- In this project, we are using the WPF (Windows Presentation Foundation) UI framework for GUI implementation. The GUI is designed for Windows exclusivity due to inherent limitations in WPF.
- This project primarily adopts the MVVM pattern, utilizing packages such as ReactiveExtensions and ReactiveProperty. However, MVVM frameworks like Prism or Livet are not used in this project. If you are interested in learning more about MVVM, please refer to Microsoft's official documentation at https://learn.microsoft.com/en-us/dotnet/architecture/maui/mvvm.
