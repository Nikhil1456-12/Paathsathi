# tool/export_graph.ps1
#
# One-time (offline-dev-machine) OSM road/pedestrian graph exporter for
# PathSaathi's offline RoutingService. Queries the Overpass API for walkable
# highways within a bbox, reduces the raw OSM ways+nodes into a COMPACT routing
# graph, and writes it as assets/maps/graph_<region>.json.
#
# Output schema (kept tiny so pure-Dart A* can hold it in memory):
#   {
#     "region": "prayagraj",
#     "bbox": [south, west, north, east],
#     "nodes": [ [id, lat, lng], ... ],           # id is a compact 0..N index
#     "edges": [ [fromIdx, toIdx, distanceMeters, wayType], ... ]  # undirected
#   }
#
# Usage:
#   pwsh tool/export_graph.ps1 -Region prayagraj -South 25.42 -West 81.855 -North 25.465 -East 81.900
#
# Requires: curl.exe (bundled with Windows 10+), internet access.

param(
  [Parameter(Mandatory = $true)][string]$Region,
  [Parameter(Mandatory = $true)][double]$South,
  [Parameter(Mandatory = $true)][double]$West,
  [Parameter(Mandatory = $true)][double]$North,
  [Parameter(Mandatory = $true)][double]$East
)

$ErrorActionPreference = 'Stop'

# Walkable/road highway types worth routing on (excludes motorways where a
# pilgrim wouldn't walk, but keeps footways, paths, residential, etc.).
$hwFilter = 'footway|path|pedestrian|steps|living_street|residential|service|unclassified|tertiary|secondary|primary|track|road'

$dollar = [char]36
$bbox = "$South,$West,$North,$East"
$query = '[out:json][timeout:120];(way["highway"~"^(' + $hwFilter + ')' + $dollar + '"](' + $bbox + '););(._;>;);out body;'

# Write the query to a file and pass it via `data@file` so no shell quoting
# mangles the regex anchors (^ / $) — passing inline breaks on Windows.
$qFile = "query_$Region.overpassql"
Set-Content -Path $qFile -Value $query -Encoding ASCII -NoNewline

$raw = "raw_$Region.json"
# Try multiple Overpass mirrors with retries — the main instance often returns
# 504/429 under load, but the same query succeeds on retry / another mirror.
$mirrors = @(
  'https://overpass-api.de/api/interpreter',
  'https://overpass.kumi.systems/api/interpreter',
  'https://maps.mail.ru/osm/tools/overpass/api/interpreter'
)
$ok = $false
foreach ($m in $mirrors) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    Write-Host "[export_graph] Querying '$Region' via $m (attempt $attempt)..."
    $code = curl.exe -s -o $raw -w "%{http_code}" --data-urlencode "data@$qFile" $m
    if ($code -eq '200' -and (Get-Item $raw).Length -gt 1000) { $ok = $true; break }
    Write-Host "[export_graph]   HTTP=$code — retrying in 5s..."
    Start-Sleep -Seconds 5
  }
  if ($ok) { break }
}
Remove-Item $qFile -ErrorAction SilentlyContinue
if (-not $ok) { throw "Overpass export failed for '$Region' after all mirrors/retries." }

$osm = Get-Content $raw -Raw | ConvertFrom-Json

# ── Build node lookup (only nodes actually used by kept ways) ────────────────
$rawNodes = @{}
foreach ($el in $osm.elements) {
  if ($el.type -eq 'node') { $rawNodes[[string]$el.id] = @($el.lat, $el.lon) }
}

$ways = $osm.elements | Where-Object { $_.type -eq 'way' -and $_.nodes.Count -ge 2 }

# Compact remapping: OSM node id -> 0..N index, only for nodes on kept ways.
$idxOf = @{}
$nodes = New-Object System.Collections.ArrayList
function Get-Idx([string]$osmId) {
  if ($idxOf.ContainsKey($osmId)) { return $idxOf[$osmId] }
  $ll = $rawNodes[$osmId]
  if ($null -eq $ll) { return -1 }
  $i = $nodes.Count
  [void]$nodes.Add(@([double]$ll[0], [double]$ll[1]))
  $idxOf[$osmId] = $i
  return $i
}

# Haversine in metres.
function HaversineM([double]$lat1, [double]$lon1, [double]$lat2, [double]$lon2) {
  $R = 6371000.0
  $p = [Math]::PI / 180.0
  $a = 0.5 - [Math]::Cos(($lat2 - $lat1) * $p) / 2 +
       [Math]::Cos($lat1 * $p) * [Math]::Cos($lat2 * $p) *
       (1 - [Math]::Cos(($lon2 - $lon1) * $p)) / 2
  return 2 * $R * [Math]::Asin([Math]::Sqrt($a))
}

$edges = New-Object System.Collections.ArrayList
foreach ($w in $ways) {
  $wayType = if ($w.tags -and $w.tags.highway) { [string]$w.tags.highway } else { 'road' }
  $seq = @($w.nodes)
  for ($k = 0; $k -lt $seq.Count - 1; $k++) {
    $aId = Get-Idx([string]$seq[$k])
    $bId = Get-Idx([string]$seq[$k + 1])
    if ($aId -lt 0 -or $bId -lt 0 -or $aId -eq $bId) { continue }
    $an = $nodes[$aId]; $bn = $nodes[$bId]
    $d = [Math]::Round((HaversineM $an[0] $an[1] $bn[0] $bn[1]), 1)
    [void]$edges.Add(@($aId, $bId, $d, $wayType))
  }
}

# Emit compact nodes [idx,lat,lng] (idx is implicit = array position, but we
# include it for clarity/robustness).
$outNodes = New-Object System.Collections.ArrayList
for ($i = 0; $i -lt $nodes.Count; $i++) {
  [void]$outNodes.Add(@($i, $nodes[$i][0], $nodes[$i][1]))
}

$graph = [ordered]@{
  region = $Region
  bbox   = @($South, $West, $North, $East)
  nodes  = $outNodes
  edges  = $edges
}

$outDir = Join-Path $PSScriptRoot '..\assets\maps'
$outPath = Join-Path $outDir "graph_$Region.json"
$graph | ConvertTo-Json -Depth 6 -Compress | Set-Content -Path $outPath -Encoding UTF8

Remove-Item $raw -ErrorAction SilentlyContinue
$sizeKB = [Math]::Round((Get-Item $outPath).Length / 1KB, 1)
Write-Host "[export_graph] Wrote $outPath — nodes=$($outNodes.Count) edges=$($edges.Count) size=${sizeKB}KB"
