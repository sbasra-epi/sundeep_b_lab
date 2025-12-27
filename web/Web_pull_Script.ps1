
# -------------------------------
# 1) Load API credentials from your XML
# -------------------------------
$creds     = Import-CliXml -Path "path to credential.xml"
$WebCred = $creds.WebCred; if (-not $WebCred) { $WebCred = $creds }
$userName  = $WebCred.UserName
$password  = $WebCred.GetNetworkCredential().Password  # use literal chars

New-PSDrive -Name "Z" -PSProvider FileSystem -Root "\\NetworkShare" -Credential $creds.CompanyActiveDirectory



# -------------------------------
# 2) Endpoints
# -------------------------------
$apiHost    = "https://website"
$signInUrl  = "$apiHost/api/auth/signIn"
$exportUrl  = "$apiHost/api/Data"
# Optional refresh endpoint (only if you decide to use it later)
$refreshUrl = "$apiHost/api/auth/refreshToken"

# -------------------------------
# 3) Browser-like headers/session (match your Edge capture)
# -------------------------------
$origin    = "https://website"
$referer   = "https://website/"
$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) PowerShell"
$session   = New-Object Microsoft.PowerShell.Commands.WebRequestSession

$baseHeaders = @{
  "Origin"             = $origin
  "Referer"            = $referer
  "User-Agent"         = $userAgent
  "Accept-Language"    = "en-US,en;q=0.9"
  "Sec-Fetch-Mode"     = "cors"
  "Sec-Fetch-Site"     = "same-site"
  "Sec-Fetch-Dest"     = "empty"
  'sec-ch-ua'          = '"Microsoft Edge";v="143", "Chromium";v="143", "Not A(Brand";v="24"'
  'sec-ch-ua-platform' = '"Windows"'
  'sec-ch-ua-mobile'   = '?0'
}

# -------------------------------
# 4) Sign-in → token.accessToken
# -------------------------------
$signinHeaders = $baseHeaders.Clone()
$signinHeaders["Accept"]       = "*/*"
$signinHeaders["Content-Type"] = "application/json"

$signinBody = @{ userName = $userName; password = $password } | ConvertTo-Json -Depth 3 -Compress

$signInRaw  = Invoke-WebRequest -Uri $signInUrl -Method POST -Headers $signinHeaders -Body $signinBody -WebSession $session -UseBasicParsing
$signInJson = $null
try { $signInJson = $signInRaw.Content | ConvertFrom-Json } catch {
  throw "Sign-in did not return JSON. Raw content: $($signInRaw.Content)"
}

$bearerToken  = $signInJson.token.accessToken
$refreshToken = $signInJson.token.refreshToken   # optional if you later implement refresh
if (-not $bearerToken) { throw "Sign-in JSON missing token.accessToken." }

# -------------------------------
# 5) Export headers & body (your exact payload)
# -------------------------------
$exportHeaders = $baseHeaders.Clone()
$exportHeaders["Content-Type"]  = "application/json"
$exportHeaders["Accept"]        = "*/*"
$exportHeaders["Authorization"] = "Bearer $bearerToken"

$exportBody = @{
  filter = @{
    SS            = @("Value")
    SSFilterType  = "Value"
    riskCatFilterType    = "Value"     # keep exact spelling
  }
  search         = ""
  sortBy         = "Value"
  sortDescending = $false
} | ConvertTo-Json -Depth 6 -Compress

# -------------------------------
# 6) Save to Downloads
# -------------------------------
$outDir  = "\\NetworkShare\folder"
if (-not (Test-Path $outDir)) { New-Item -Path $outDir -ItemType Directory | Out-Null }
$outFile = Join-Path $outDir ("Data_{0:yyyyMMdd_HHmmss}.csv" -f (Get-Date))

# -------------------------------
# 7) Export (POST) → write file
# -------------------------------
try {
  Invoke-WebRequest -Uri $exportUrl -Method POST -Headers $exportHeaders -Body $exportBody -WebSession $session -OutFile $outFile -UseBasicParsing
  Write-Host "Saved CSV to: $outFile"
  
}
catch {
  $resp   = $_.Exception.Response
  $status = if ($resp) { $resp.StatusCode.value__ } else { -1 }
  Write-Warning "Export failed (HTTP $status): $($_.Exception.Message)"
  if ($resp) {
    $raw = New-Object IO.StreamReader($resp.GetResponseStream()).ReadToEnd()
    $debugFile = Join-Path $outDir ("debug_export_response_{0:yyyyMMdd_HHmmss}.txt" -f (Get-Date))
    $raw | Set-Content $debugFile
    Write-Warning "Server response saved to: $debugFile"
  }
  throw
}

# -------------------------------
# 8) (Optional) refresh logic if you ever need it
# -------------------------------
<# 
# If the above fails with 401 due to token expiry and your API supports refresh:
if ($refreshToken) {
  $refreshHeaders = $baseHeaders.Clone()
  $refreshHeaders["Content-Type"] = "application/json"
  $refreshHeaders["Accept"]       = "*/*"
  $refreshBody = @{ refreshToken = $refreshToken } | ConvertTo-Json -Compress

  $refreshResp = Invoke-WebRequest -Uri $refreshUrl -Method POST -Headers $refreshHeaders -Body $refreshBody -WebSession $session
  $refreshJson = $refreshResp.Content | ConvertFrom-Json

  $newToken = $refreshJson?.token?.accessToken
  if ($newToken) {
    $exportHeaders["Authorization"] = "Bearer $newToken"
    Invoke-WebRequest -Uri $exportUrl -Method POST -Headers $exportHeaders -Body $exportBody -WebSession $session -OutFile $outFile
    Write-Host "Saved CSV to: $outFile"
  }
}
#>
