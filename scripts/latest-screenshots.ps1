# Downloads the screenshots (and videos of failed tests) from the latest finished CI run
# into the "latest-screenshots" folder of this repo, with readable file names, then opens it.
# Usage: double-click "Get latest screenshots.bat" (or: powershell -File scripts\latest-screenshots.ps1 [-NoOpen])
param([switch]$NoOpen)
$ErrorActionPreference = 'Stop'

$repo = 'abouhasna/Masebha-ios'
$gh = (Get-Command gh -ErrorAction SilentlyContinue).Source
if (-not $gh) { $gh = 'C:\Program Files\GitHub CLI\gh.exe' }
$root = Split-Path -Parent $PSScriptRoot
$dest = Join-Path $root 'latest-screenshots'

# The newest finished run that produced test results (a run that failed to build has none).
# (GitHub's server-side "completed" filter lags behind, so filter here.)
$runs = & $gh run list -R $repo --branch main --limit 10 --json databaseId,status,conclusion,displayTitle,createdAt | ConvertFrom-Json
$downloaded = $null
foreach ($run in $runs | Where-Object { $_.status -eq 'completed' -and $_.conclusion -in 'success', 'failure' }) {
    $tmp = Join-Path $env:TEMP "masebha-results-$($run.databaseId)"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
    $ErrorActionPreference = 'Continue'   # gh writes "no artifacts" to stderr; just try the next run
    & $gh run download $run.databaseId -R $repo -n test-results -D $tmp 2>$null
    $ErrorActionPreference = 'Stop'
    if ($LASTEXITCODE -eq 0 -and (Test-Path (Join-Path $tmp 'screenshots'))) { $downloaded = $run; break }
}
if (-not $downloaded) { Write-Host 'No finished run with screenshots was found.'; exit 1 }

if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
New-Item -ItemType Directory $dest | Out-Null
Get-ChildItem (Join-Path $tmp 'screenshots') -File |
    Where-Object { $_.Extension -in '.png', '.jpg', '.jpeg', '.mp4', '.mov' } |
    ForEach-Object {
        # "10-counter-english_0_5D2C...F1.png" -> "10-counter-english.png"
        $name = $_.Name -replace '_\d+_[0-9A-Fa-f-]{36}(\.\w+)$', '$1'
        Copy-Item $_.FullName (Join-Path $dest $name) -Force
    }

$summary = Get-Content (Join-Path $tmp 'summary.json') -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
$info = @(
    "Run:        $($downloaded.displayTitle)"
    "Date:       $($downloaded.createdAt)"
    "Result:     $($downloaded.conclusion)"
    "Tests:      $($summary.passedTests) passed, $($summary.failedTests) failed (of $($summary.totalTestCount))"
    "Link:       https://github.com/$repo/actions/runs/$($downloaded.databaseId)"
    ""
    "Videos (.mp4) are recorded automatically only for tests that failed."
)
$info | Out-File -Encoding utf8 (Join-Path $dest '_about this run.txt')
Remove-Item -Recurse -Force $tmp

Write-Host "Saved to $dest"
$info | ForEach-Object { Write-Host $_ }
if (-not $NoOpen) { Invoke-Item $dest }
