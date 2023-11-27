$username = "Bombarding"
$repo = "SomethingNeedDoing"

function GetAssetByType($assets, $type) {
  foreach ($asset in $assets) {
    if ($type -eq $asset.content_type) {
      $asset
    }
  }
}

function ExitWithCode($code) {
  $host.SetShouldExit($code)
  exit $code
}

function PreviousVersionDownloadCount($username, $repo) {
  $data = Invoke-WebRequest -Uri "https://api.github.com/repos/$($username)/$($repo)/releases?per_page=100"
  $json = ConvertFrom-Json $data.content
  $downloadCount = 0
  foreach ($release in $json) {
    $downloadAsset = GetAssetByType $release.assets "application/zip"
    $downloadCount += $downloadAsset.download_count
  }
  $downloadCount
}

$pluginsOut = @()

# Fetch the release data from the Github API
$data = Invoke-WebRequest -Uri "https://api.github.com/repos/$($username)/$($repo)/releases/latest"
$json = ConvertFrom-Json $data.content

# Get data from the api request.
$downloadAsset = GetAssetByType $json.assets "application/zip"
$configAsset = GetAssetByType $json.assets "application/json"

if ($null -eq $downloadAsset) {
  Write-Error "Download asset for plugin $($plugin) is null!"
  ExitWithCode 1
}

if ($null -eq $configAsset) {
  Write-Error "Config asset for plugin $($plugin) is null!"
  ExitWithCode 1
}

$latestDownloadCount = $downloadAsset.download_count
$downloadCount = PreviousVersionDownloadCount $username $repo
$downloadCount = $latestDownloadCount += $downloadCount
$downloadUrl = $downloadAsset.browser_download_url

# Get timestamp for the release.
$releaseTimestamp = [Int](New-TimeSpan -Start (Get-Date "01/01/1970") -End ([DateTime]$json.published_at)).TotalSeconds

# Get the config data from the release data.
$configData = Invoke-WebRequest -Uri $configAsset.browser_download_url
$config = ConvertFrom-Json ([System.Text.Encoding]::UTF8.GetString($configData.content))

# Ensure that config is converted properly.
if ($null -eq $config) {
  Write-Error "Config for plugin $($plugin) is null!"
  ExitWithCode 1
}

# Add additional properties to the config.
$config | Add-Member -Name "IsHide" -MemberType NoteProperty -Value @false
$config | Add-Member -Name "IsTestingExclusive" -MemberType NoteProperty -Value @false
$config | Add-Member -Name "LastUpdate" -MemberType NoteProperty -Value $releaseTimestamp
$config | Add-Member -Name "DownloadCount" -MemberType NoteProperty -Value $downloadCount
$config | Add-Member -Name "Changelog" -MemberType NoteProperty -Value $json.body
$config | Add-Member -Name "DownloadLinkInstall" -MemberType NoteProperty -Value $downloadUrl
$config | Add-Member -Name "DownloadLinkUpdate" -MemberType NoteProperty -Value $downloadUrl
$config | Add-Member -Name "DownloadLinkTesting" -MemberType NoteProperty -Value $downloadUrl

# Add to the plugin array.
$pluginsOut += $config

# Convert plugins to JSON
$pluginJson = ConvertTo-Json $pluginsOut

# Save repo to file
Set-Content -Path "plugin.json" -Value $pluginJson
