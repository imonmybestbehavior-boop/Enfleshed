<#
Uploads Enfleshed's melee animation clips (tools/animations/clips/*.rbxmx) to Roblox with
the Open Cloud Assets API and records the new animation ids in animation_ids.json.

You run this yourself; the key is read from your environment and never printed or saved.
  1. create.roblox.com > Open Cloud > API Keys: new key with "Assets" read + write,
     for your own user account (allow your IP or 0.0.0.0/0).
  2. setx ROBLOX_API_KEY "<your key>"
     setx ROBLOX_CREATOR "user:<your user id>"
     Close and reopen PowerShell so the variables load.
  3. powershell -ExecutionPolicy Bypass -File tools\animations\upload_animations.ps1 -Test
     (uploads one clip; if it succeeds, run again without -Test for the rest)
Clips already in animation_ids.json are skipped, so re-running only retries failures.
#>
param([switch]$Test, [string]$Only = "")

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Net.Http
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$clipDir = Join-Path $root "clips"
$idsPath = Join-Path $root "animation_ids.json"
$api = "https://apis.roblox.com/assets/v1"

# Falls back to the values saved with setx, so a PowerShell window opened earlier still works.
$key = $env:ROBLOX_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("ROBLOX_API_KEY", "User") }
$creator = $env:ROBLOX_CREATOR
if (-not ($creator -match '^(user|group):\d+$')) { $creator = [Environment]::GetEnvironmentVariable("ROBLOX_CREATOR", "User") }
if (-not $key -or -not ($creator -match '^(user|group):\d+$')) {
    Write-Output "Set ROBLOX_API_KEY and ROBLOX_CREATOR=user:<id> first (see the top of this script), then reopen PowerShell."
    exit 1
}
$kind, $ident = $creator.Split(":")

$ids = @{}
if (Test-Path $idsPath) {
    (Get-Content $idsPath -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $ids[$_.Name] = $_.Value }
}

$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(120)
$client.DefaultRequestHeaders.Add("x-api-key", $key)

function Send-Clip([System.IO.FileInfo]$file) {
    $name = $file.BaseName
    $creatorField = if ($kind -eq "user") { "userId" } else { "groupId" }
    $meta = @{
        assetType = "Animation"
        displayName = "Enfleshed $name"
        description = "Enfleshed melee animation ($name)."
        creationContext = @{ creator = @{ $creatorField = $ident } }
    } | ConvertTo-Json -Depth 5 -Compress
    $form = New-Object System.Net.Http.MultipartFormDataContent
    $metaPart = New-Object System.Net.Http.StringContent($meta, [System.Text.Encoding]::UTF8, "application/json")
    $form.Add($metaPart, "request")
    $filePart = New-Object System.Net.Http.ByteArrayContent(,[System.IO.File]::ReadAllBytes($file.FullName))
    $filePart.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("model/x-rbxm")
    $form.Add($filePart, "fileContent", $file.Name)
    $response = $client.PostAsync("$api/assets", $form).Result
    $body = $response.Content.ReadAsStringAsync().Result
    if (-not $response.IsSuccessStatusCode) { throw "HTTP $([int]$response.StatusCode): $body" }
    $op = $body | ConvertFrom-Json
    $opId = if ($op.operationId) { $op.operationId } else { ($op.path -split "/")[-1] }
    for ($i = 0; $i -lt 40; $i++) {
        if ($op.done) {
            if ($op.error) { throw "Upload failed: $($op.error | ConvertTo-Json -Compress)" }
            return [int64]$op.response.assetId
        }
        Start-Sleep -Seconds 2
        $poll = $client.GetAsync("$api/operations/$opId").Result
        $op = $poll.Content.ReadAsStringAsync().Result | ConvertFrom-Json
    }
    throw "Upload did not finish in time (operation $opId)"
}

$files = Get-ChildItem $clipDir -Filter *.rbxmx | Sort-Object Name
if ($Only) { $wanted = $Only.Split(","); $files = $files | Where-Object { $wanted -contains $_.BaseName } }
if ($Test) { $files = @($files | Where-Object { $_.BaseName -eq "Sword_L1" }) }

$done = 0; $failed = 0
foreach ($file in $files) {
    if ($ids.ContainsKey($file.BaseName) -and -not $Only) { continue }
    try {
        $id = Send-Clip $file
        $ids[$file.BaseName] = $id
        Write-Output ("[anim] {0} -> {1}" -f $file.BaseName, $id)
        $done++
    } catch {
        Write-Output ("[anim] {0} FAILED: {1}" -f $file.BaseName, $_.Exception.Message)
        $failed++
    }
    ($ids | ConvertTo-Json) | Set-Content -Path $idsPath -Encoding UTF8  # Save progress after every clip.
}
Write-Output ("Uploaded {0}, failed {1}. Ids are in tools\animations\animation_ids.json - tell Claude when it's done." -f $done, $failed)
