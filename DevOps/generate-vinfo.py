import requests
import json

def get_releases(repo_owner, repo_name):
    url = f"https://api.github.com/repos/{repo_owner}/{repo_name}/releases"
    response = requests.get(url)
    releases = response.json()
    return releases

def get_asset_by_name(release, asset_name):
    for asset in release["assets"]:
        if asset["name"] == asset_name:
            return asset
    return None

def get_download_url(release, asset_name):
    asset = get_asset_by_name(release, asset_name)
    if asset is not None:
        return asset["browser_download_url"]
    return None

def get_buildinfo(release):
    url = get_download_url(release, "buildinfo.json")
    if url is None:
        return None
    response = requests.get(url)
    buildinfo = response.json()
    return buildinfo

def get_latest_development_release(releases):
    for release in releases:
        buildinfo = get_buildinfo(release)
        if buildinfo is None:
            continue
        if get_buildinfo(release)["workflow"] == "development":
            return release
    return None

def get_latest_production_release(releases):
    for release in releases:
        version_info = get_buildinfo(release)
        if version_info["workflow"] == "production":
            return release
    return None

def main():
    repo_owner = "Moonshine-IDE"
    repo_name = "Super.Human.Installer"

    releases = get_releases(repo_owner, repo_name)
    development = get_latest_development_release(releases)
    production = get_latest_production_release(releases)    

    production_versioninfo = None
    if production is not None:
        production_buildinfo = get_buildinfo(production)
        production_versioninfo = {
            "version": production_buildinfo["version"],
            "commit_sha": production_buildinfo["commit_sha"],
            "build_date": production_buildinfo["build_date"],
            "linux_url": get_download_url(production, "SuperHumanInstaller-Setup.AppImage"),
            "windows_url": get_download_url(production, "SuperHumanInstaller-Setup.exe"),
            "choco_url": get_download_url(production, "SuperHumanInstaller-Choco.nupkg"),
            "macos_url": get_download_url(production, "SuperHumanInstaller-Setup.pkg")
        }

    development_versioninfo = None
    if development is not None:
        development_buildinfo = get_buildinfo(development)
        development_versioninfo = {
            "version": development_buildinfo["version"],
            "commit_sha": development_buildinfo["commit_sha"],
            "build_date": development_buildinfo["build_date"],
            "linux_url": get_download_url(development, "SuperHumanInstallerDev-Setup.AppImage"),
            "windows_url": get_download_url(development, "SuperHumanInstallerDev-Setup.exe"),
            "choco_url": get_download_url(development, "SuperHumanInstallerDev-Choco.nupkg"),
            "macos_url": get_download_url(development, "SuperHumanInstallerDev-Setup.pkg")
        }

    versioninfo = {
        "production": production_versioninfo,
        "development": development_versioninfo
    }

    with open("versioninfo.json", "w") as f:
        json.dump(versioninfo, f, indent=4)

if __name__ == "__main__":
    main()
