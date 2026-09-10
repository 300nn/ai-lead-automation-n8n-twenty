param(
  [string]$N8nContainer = "lead-automatisation",
  [int]$TwentyPort = 3000,
  [int]$MailpitPort = 8025
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:Results = New-Object System.Collections.ArrayList
$script:Context = @{}
$script:BaseUrl = $null
$script:RunId = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds().ToString()
$script:ReportDir = Join-Path $PSScriptRoot "reports"
New-Item -ItemType Directory -Force -Path $script:ReportDir | Out-Null

function Step([string]$Text) {
  Write-Host "`n==> $Text" -ForegroundColor Cyan
}
function Info([string]$Text) {
  Write-Host "    $Text"
}
function Pass([string]$Text) {
  Write-Host "    PASS  $Text" -ForegroundColor Green
}
function Fail([string]$Text) {
  Write-Host "    FAIL  $Text" -ForegroundColor Red
}
function Skip([string]$Text) {
  Write-Host "    SKIP  $Text" -ForegroundColor Yellow
}

function Add-Result {
  param(
    [string]$Name,
    [string]$Status,
    [string]$Detail,
    [double]$DurationMs = 0
  )
  [void]$script:Results.Add([pscustomobject]@{
    name = $Name
    status = $Status
    detail = $Detail
    duration_ms = [math]::Round($DurationMs, 1)
  })
}

function Assert-True([bool]$Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}
function Assert-Equal($Actual, $Expected, [string]$Message) {
  if ([string]$Actual -ne [string]$Expected) {
    throw "$Message Expected='$Expected' Actual='$Actual'"
  }
}
function Assert-NotBlank($Value, [string]$Message) {
  if ([string]::IsNullOrWhiteSpace([string]$Value)) { throw $Message }
}

function Get-N8nHostPort {
  $lines = @(& docker port $N8nContainer 5678/tcp 2>$null)
  if ($LASTEXITCODE -ne 0 -or $lines.Count -eq 0) {
    throw "Could not resolve host port for $N8nContainer:5678"
  }
  foreach ($line in $lines) {
    $m = [regex]::Match([string]$line, ':(\d+)$')
    if ($m.Success) { return [int]$m.Groups[1].Value }
  }
  throw "Docker returned an unexpected port mapping: $($lines -join ', ')"
}

function Invoke-HttpJson {
  param(
    [ValidateSet('GET','POST','PATCH','DELETE')][string]$Method,
    [string]$Uri,
    $Body = $null,
    [int]$TimeoutSec = 90
  )
  $params = @{
    Method = $Method
    Uri = $Uri
    UseBasicParsing = $true
    TimeoutSec = $TimeoutSec
  }
  if ($null -ne $Body) {
    $params['ContentType'] = 'application/json'
    if ($Body -is [string]) { $params['Body'] = $Body }
    else { $params['Body'] = ($Body | ConvertTo-Json -Depth 12 -Compress) }
  }
  try {
    $r = Invoke-WebRequest @params
    $json = $null
    if (-not [string]::IsNullOrWhiteSpace([string]$r.Content)) {
      try { $json = $r.Content | ConvertFrom-Json } catch {}
    }
    return [pscustomobject]@{ StatusCode=[int]$r.StatusCode; Content=[string]$r.Content; Json=$json }
  }
  catch {
    $status = 0
    $content = ''
    try { $status = [int]$_.Exception.Response.StatusCode } catch {}

    # Windows PowerShell 5.1 often puts the HTTP error body in
    # ErrorDetails.Message and leaves GetResponseStream() empty/consumed.
    try {
      if ($null -ne $_.ErrorDetails -and -not [string]::IsNullOrWhiteSpace([string]$_.ErrorDetails.Message)) {
        $content = [string]$_.ErrorDetails.Message
      }
    } catch {}

    if ([string]::IsNullOrWhiteSpace($content)) {
      try {
        $stream = $_.Exception.Response.GetResponseStream()
        if ($null -ne $stream) {
          $reader = New-Object System.IO.StreamReader($stream)
          $content = $reader.ReadToEnd()
          $reader.Dispose()
        }
      } catch {}
    }

    $json = $null
    if (-not [string]::IsNullOrWhiteSpace($content)) {
      try { $json = $content | ConvertFrom-Json } catch {}
    }
    return [pscustomobject]@{ StatusCode=$status; Content=$content; Json=$json }
  }
}

function Invoke-Test {
  param(
    [string]$Name,
    [scriptblock]$Body,
    [scriptblock]$SkipWhen = $null,
    [string]$SkipReason = ''
  )
  if ($null -ne $SkipWhen -and (& $SkipWhen)) {
    Skip $Name
    Add-Result -Name $Name -Status 'SKIP' -Detail $SkipReason
    return
  }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  try {
    $detail = & $Body
    $sw.Stop()
    if ($detail -is [System.Array]) { $detail = ($detail -join '; ') }
    if ([string]::IsNullOrWhiteSpace([string]$detail)) { $detail = 'ok' }
    Pass "$Name - $detail"
    Add-Result -Name $Name -Status 'PASS' -Detail ([string]$detail) -DurationMs $sw.Elapsed.TotalMilliseconds
  }
  catch {
    $sw.Stop()
    $msg = $_.Exception.Message
    Fail "$Name - $msg"
    Add-Result -Name $Name -Status 'FAIL' -Detail $msg -DurationMs $sw.Elapsed.TotalMilliseconds
  }
}

function New-LeadPayload {
  param(
    [string]$Kind,
    [string]$RequestId,
    [string]$Email
  )
  switch ($Kind) {
    'HOT' {
      return [ordered]@{
        request_id=$RequestId; name='Regression Hot Lead'; email=$Email; phone='+15550102031';
        company='Regression Hot Co'; company_size=75; website='https://example.com'; budget=12000;
        service='CRM Automation'; message='We need lead routing workflow integration and sales automation.'; source='Regression Test'
      }
    }
    'WARM' {
      return [ordered]@{
        request_id=$RequestId; name='Regression Warm Lead'; email=$Email; phone='+15550102032';
        company='Regression Warm Co'; company_size=12; website='https://example.com'; budget=2500;
        service='Data cleanup'; message='Need help with internal operations.'; source='Regression Test'
      }
    }
    'COLD' {
      return [ordered]@{
        request_id=$RequestId; name='Regression Cold Lead'; email=$Email; phone='+15550102033';
        company=''; company_size=2; website=''; budget=500;
        service='Reporting'; message='Need a simple monthly report.'; source='Regression Test'
      }
    }
    default { throw "Unknown lead kind: $Kind" }
  }
}

function Assert-ProcessedLead {
  param(
    $Response,
    [string]$Category,
    [int]$Score,
    [bool]$ExpectOpportunity,
    [string]$ExpectedNotification
  )
  Assert-Equal $Response.StatusCode 200 'Lead HTTP status mismatch.'
  Assert-True ($null -ne $Response.Json) 'Lead response was not JSON.'
  Assert-Equal $Response.Json.status 'processed' 'Lead status mismatch.'
  Assert-Equal $Response.Json.category $Category 'Lead category mismatch.'
  Assert-Equal $Response.Json.score $Score 'Lead score mismatch.'
  Assert-NotBlank $Response.Json.contact_id 'Twenty Person ID is missing.'
  if ($ExpectOpportunity) { Assert-NotBlank $Response.Json.deal_id 'Twenty Opportunity ID is missing.' }
  else { Assert-True ([string]::IsNullOrWhiteSpace([string]$Response.Json.deal_id)) 'Non-HOT lead unexpectedly has an Opportunity ID.' }
  Assert-Equal $Response.Json.email_status 'sent' 'Client email was not sent through Mailpit.'
  Assert-Equal $Response.Json.notification_status $ExpectedNotification 'Sales notification status mismatch.'
  Assert-Equal $Response.Json.ai_provider 'mock' 'OpenAI must remain mocked during regression tests.'
  Assert-Equal $Response.Json.ai_fallback 'False' 'AI fallback unexpectedly ran.'
}

function Get-MailpitSnapshot {
  $r = Invoke-HttpJson -Method GET -Uri "http://localhost:$MailpitPort/api/v1/messages" -TimeoutSec 10
  if ($r.StatusCode -ne 200) { throw "Mailpit messages API returned HTTP $($r.StatusCode)." }
  $count = 0
  if ($null -ne $r.Json) {
    $names = @($r.Json.PSObject.Properties.Name)
    if ($names -contains 'total') { $count = [int]$r.Json.total }
    elseif ($names -contains 'messages') { $count = @($r.Json.messages).Count }
  }
  return [pscustomobject]@{ Count=$count; Raw=$r.Content }
}

Step 'Preflight'
try {
  & docker inspect $N8nContainer *> $null
  if ($LASTEXITCODE -ne 0) { throw "n8n container '$N8nContainer' was not found." }
  $running = (& docker inspect -f '{{.State.Running}}' $N8nContainer 2>$null | Select-Object -First 1)
  if ([string]$running -ne 'true') { throw "n8n container '$N8nContainer' is not running." }

  $port = Get-N8nHostPort
  $script:BaseUrl = "http://localhost:$port"
  $health = Invoke-HttpJson -Method GET -Uri "$script:BaseUrl/healthz" -TimeoutSec 10
  Assert-Equal $health.StatusCode 200 'n8n health check failed.'
  $twenty = Invoke-HttpJson -Method GET -Uri "http://localhost:$TwentyPort/healthz" -TimeoutSec 10
  Assert-Equal $twenty.StatusCode 200 'Twenty health check failed.'
  $mailpit = Invoke-HttpJson -Method GET -Uri "http://localhost:$MailpitPort/" -TimeoutSec 10
  Assert-Equal $mailpit.StatusCode 200 'Mailpit health check failed.'
  Info "n8n:    $script:BaseUrl"
  Info "Twenty: http://localhost:$TwentyPort"
  Info "Mailpit:http://localhost:$MailpitPort"
  Info "Run ID: $script:RunId"
}
catch {
  Write-Host "`nPRECHECK FAILED: $($_.Exception.Message)" -ForegroundColor Red
  exit 2
}

$script:Context['mailBefore'] = $null
try { $script:Context['mailBefore'] = Get-MailpitSnapshot } catch { Info "Mailpit count baseline unavailable: $($_.Exception.Message)" }

Step 'Regression tests'

Invoke-Test 'WEBHOOK REGISTRATION' {
  $leadProbe = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/lead" -Body @{} -TimeoutSec 20
  Assert-Equal $leadProbe.StatusCode 400 'Lead webhook should exist and reject empty payload with 400.'
  Assert-True ($null -ne $leadProbe.Json) "Lead webhook returned HTTP 400 but its JSON body could not be parsed. Raw='$($leadProbe.Content)'"
  Assert-Equal $leadProbe.Json.status 'invalid' 'Lead webhook probe returned an unexpected body.'
  $calProbe = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/calendly" -Body @{} -TimeoutSec 20
  Assert-Equal $calProbe.StatusCode 200 'Calendly webhook should exist and ignore empty event with 200.'
  Assert-Equal $calProbe.Json.status 'ignored' 'Calendly webhook probe returned an unexpected body.'
  '02 and 03 production webhooks are registered'
}

Invoke-Test 'INVALID PAYLOAD' {
  $r = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/lead" -Body @{ request_id="reg-invalid-$script:RunId"; email='not-an-email' } -TimeoutSec 30
  Assert-Equal $r.StatusCode 400 'Invalid lead should return HTTP 400.'
  Assert-True ($null -ne $r.Json) "Invalid lead returned HTTP 400 but its JSON body could not be parsed. Raw='$($r.Content)'"
  Assert-Equal $r.Json.status 'invalid' 'Invalid lead status mismatch.'
  Assert-True (@($r.Json.errors).Count -ge 3) 'Expected multiple validation errors.'
  'validation rejects malformed lead without external integrations'
}

Invoke-Test 'HOT LEAD' {
  $requestId = "reg-hot-$script:RunId"
  $email = "regression.hot.$script:RunId@example.com"
  $payload = New-LeadPayload -Kind HOT -RequestId $requestId -Email $email
  $r = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/lead" -Body $payload -TimeoutSec 90
  Assert-ProcessedLead -Response $r -Category HOT -Score 100 -ExpectOpportunity $true -ExpectedNotification 'sent'
  $script:Context['hotRequestId']=$requestId
  $script:Context['hotEmail']=$email
  $script:Context['hotResponse']=$r.Json
  "Person=$($r.Json.contact_id); Opportunity=$($r.Json.deal_id); score=100"
}

Invoke-Test 'WARM LEAD' {
  $requestId = "reg-warm-$script:RunId"
  $email = "regression.warm.$script:RunId@example.com"
  $payload = New-LeadPayload -Kind WARM -RequestId $requestId -Email $email
  $r = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/lead" -Body $payload -TimeoutSec 90
  Assert-ProcessedLead -Response $r -Category WARM -Score 58 -ExpectOpportunity $false -ExpectedNotification 'not_required'
  $script:Context['warmRequestId']=$requestId
  $script:Context['warmEmail']=$email
  $script:Context['warmResponse']=$r.Json
  "Person=$($r.Json.contact_id); no Opportunity; score=58"
}

Invoke-Test 'COLD LEAD' {
  $requestId = "reg-cold-$script:RunId"
  $email = "regression.cold.$script:RunId@gmail.com"
  $payload = New-LeadPayload -Kind COLD -RequestId $requestId -Email $email
  $r = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/lead" -Body $payload -TimeoutSec 90
  Assert-ProcessedLead -Response $r -Category COLD -Score 25 -ExpectOpportunity $false -ExpectedNotification 'not_required'
  $script:Context['coldRequestId']=$requestId
  $script:Context['coldEmail']=$email
  $script:Context['coldResponse']=$r.Json
  "Person=$($r.Json.contact_id); no Opportunity; score=25"
}

Invoke-Test 'IDEMPOTENCY' -SkipWhen { -not $script:Context.ContainsKey('hotRequestId') } -SkipReason 'HOT lead did not complete, so there is no completed request to replay.' -Body {
  $payload = New-LeadPayload -Kind HOT -RequestId $script:Context['hotRequestId'] -Email $script:Context['hotEmail']
  $r = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/lead" -Body $payload -TimeoutSec 30
  Assert-Equal $r.StatusCode 200 'Duplicate request HTTP status mismatch.'
  Assert-Equal $r.Json.status 'already_completed' 'Duplicate request was not rejected as already_completed.'
  'same request_id is not processed twice'
}

Invoke-Test 'TWENTY PERSON UPSERT' -SkipWhen { -not $script:Context.ContainsKey('warmResponse') } -SkipReason 'WARM lead did not complete, so existing-person update cannot be verified.' -Body {
  $requestId = "reg-warm-update-$script:RunId"
  $payload = New-LeadPayload -Kind WARM -RequestId $requestId -Email $script:Context['warmEmail']
  $payload.name = 'Regression Warm Lead Updated'
  $payload.phone = '+15550102999'
  $r = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/lead" -Body $payload -TimeoutSec 90
  Assert-ProcessedLead -Response $r -Category WARM -Score 58 -ExpectOpportunity $false -ExpectedNotification 'not_required'
  Assert-Equal $r.Json.contact_id $script:Context['warmResponse'].contact_id 'Same email should update/reuse the existing Twenty Person.'
  $script:Context['warmUpdateResponse']=$r.Json
  "same Person ID reused: $($r.Json.contact_id)"
}

Invoke-Test 'CALENDLY HOT -> TWENTY STAGE' -SkipWhen { -not $script:Context.ContainsKey('hotResponse') } -SkipReason 'HOT lead did not complete, so there is no Opportunity to update.' -Body {
  $cal = [ordered]@{
    event='invitee.created'
    payload=[ordered]@{
      email=$script:Context['hotEmail']
      name='Regression Hot Lead'
      scheduled_event=[ordered]@{ start_time=(Get-Date).ToUniversalTime().AddDays(1).ToString('o') }
    }
  }
  $r = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/calendly" -Body $cal -TimeoutSec 90
  Assert-Equal $r.StatusCode 200 'Calendly booking HTTP status mismatch.'
  Assert-Equal $r.Json.status 'meeting_scheduled' 'Calendly booking status mismatch.'
  Assert-Equal $r.Json.deal_id $script:Context['hotResponse'].deal_id 'Calendly updated a different Opportunity.'
  Assert-Equal $r.Json.mode 'updated' 'Twenty Opportunity stage was not updated.'
  "Opportunity=$($r.Json.deal_id) stage updated"
}

Invoke-Test 'CALENDLY WARM -> NO DEAL' -SkipWhen { -not $script:Context.ContainsKey('warmResponse') } -SkipReason 'WARM lead did not complete.' -Body {
  $cal = [ordered]@{
    event='invitee.created'
    payload=[ordered]@{
      email=$script:Context['warmEmail']
      name='Regression Warm Lead'
      scheduled_event=[ordered]@{ start_time=(Get-Date).ToUniversalTime().AddDays(2).ToString('o') }
    }
  }
  $r = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/calendly" -Body $cal -TimeoutSec 40
  Assert-Equal $r.StatusCode 202 'Booking without Opportunity should return HTTP 202.'
  Assert-Equal $r.Json.status 'accepted_no_deal' 'Booking without Opportunity status mismatch.'
  'booking accepted safely when lead has no HOT Opportunity'
}

Invoke-Test 'CALENDLY IGNORED EVENT' {
  $cal = [ordered]@{ event='invitee.canceled'; payload=[ordered]@{ email="ignored.$script:RunId@example.com"; name='Ignored Event' } }
  $r = Invoke-HttpJson -Method POST -Uri "$script:BaseUrl/webhook/portfolio/calendly" -Body $cal -TimeoutSec 30
  Assert-Equal $r.StatusCode 200 'Non-booking Calendly event should return HTTP 200.'
  Assert-Equal $r.Json.status 'ignored' 'Non-booking Calendly event should be ignored.'
  'non invitee.created event is ignored'
}

Invoke-Test 'MAILPIT DELIVERY' -SkipWhen { -not ($script:Context.ContainsKey('hotEmail') -and $script:Context.ContainsKey('warmEmail') -and $script:Context.ContainsKey('coldEmail')) } -SkipReason 'Lead tests did not all complete, so message-recipient assertions would be incomplete.' -Body {
  Start-Sleep -Milliseconds 500
  $after = Get-MailpitSnapshot
  $raw = [string]$after.Raw
  foreach ($address in @($script:Context['hotEmail'],$script:Context['warmEmail'],$script:Context['coldEmail'])) {
    Assert-True ($raw.IndexOf([string]$address, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) "Mailpit list does not contain recipient $address."
  }
  Assert-True ($raw.IndexOf('sales@example.com', [System.StringComparison]::OrdinalIgnoreCase) -ge 0) 'Mailpit list does not contain the HOT sales notification recipient.'
  if ($null -ne $script:Context['mailBefore']) {
    $delta = [int]$after.Count - [int]$script:Context['mailBefore'].Count
    Assert-True ($delta -ge 5) "Expected at least 5 new messages (HOT x2, WARM, COLD, WARM update); observed delta=$delta."
    return "captured >=5 new local emails; delta=$delta"
  }
  'expected recipients found in Mailpit'
}

Step 'Summary'
$passCount = @($script:Results | Where-Object { $_.status -eq 'PASS' }).Count
$failCount = @($script:Results | Where-Object { $_.status -eq 'FAIL' }).Count
$skipCount = @($script:Results | Where-Object { $_.status -eq 'SKIP' }).Count
$total = $script:Results.Count

foreach ($r in $script:Results) {
  $dots = '.' * [math]::Max(2, 34 - $r.name.Length)
  $color = if ($r.status -eq 'PASS') {'Green'} elseif ($r.status -eq 'FAIL') {'Red'} else {'Yellow'}
  Write-Host ("{0} {1} {2}" -f $r.name,$dots,$r.status) -ForegroundColor $color
}
Write-Host ""
Write-Host "$passCount PASS / $failCount FAIL / $skipCount SKIP / $total TOTAL" -ForegroundColor $(if($failCount -eq 0){'Green'}else{'Red'})

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$jsonPath = Join-Path $script:ReportDir "regression-$stamp.json"
$mdPath = Join-Path $script:ReportDir "regression-$stamp.md"

$report = [ordered]@{
  generated_at = (Get-Date).ToUniversalTime().ToString('o')
  run_id = $script:RunId
  n8n_url = $script:BaseUrl
  twenty_url = "http://localhost:$TwentyPort"
  mailpit_url = "http://localhost:$MailpitPort"
  mode = [ordered]@{ ai='mock'; crm='real Twenty'; email='real Mailpit'; notification='real Mailpit' }
  summary = [ordered]@{ pass=$passCount; fail=$failCount; skip=$skipCount; total=$total }
  results = @($script:Results)
  test_records = [ordered]@{
    hot_email = $script:Context['hotEmail']
    warm_email = $script:Context['warmEmail']
    cold_email = $script:Context['coldEmail']
    hot_person_id = if($script:Context.ContainsKey('hotResponse')){$script:Context['hotResponse'].contact_id}else{$null}
    hot_opportunity_id = if($script:Context.ContainsKey('hotResponse')){$script:Context['hotResponse'].deal_id}else{$null}
  }
}
$report | ConvertTo-Json -Depth 8 | Set-Content -Encoding UTF8 $jsonPath

$md = New-Object System.Collections.Generic.List[string]
$md.Add('# n8n + Twenty regression report')
$md.Add('')
$md.Add("- Generated: $($report.generated_at)")
$md.Add("- n8n: $($report.n8n_url)")
$md.Add("- Twenty: $($report.twenty_url)")
$md.Add("- Mailpit: $($report.mailpit_url)")
$md.Add('- Mode: mock AI, real Twenty CRM, real Mailpit email/notification')
$md.Add('')
$md.Add("**Result: $passCount PASS / $failCount FAIL / $skipCount SKIP**")
$md.Add('')
$md.Add('| Test | Status | Detail |')
$md.Add('|---|---|---|')
foreach($r in $script:Results){
  $safe = ([string]$r.detail).Replace('|','\|').Replace("`r",' ').Replace("`n",' ')
  $md.Add("| $($r.name) | $($r.status) | $safe |")
}
$md.Add('')
$md.Add('## Notes')
$md.Add('- Tests intentionally create/update local Twenty records and capture emails in local Mailpit.')
$md.Add('- OpenAI is not called; every successful lead must report `ai_provider=mock` and `ai_fallback=false`.')
$md.Add('- The script does not restart, republish, import, delete, or modify workflow definitions.')
$md | Set-Content -Encoding UTF8 $mdPath

Info "JSON report: $jsonPath"
Info "Markdown report: $mdPath"
Info 'The tests do not modify workflow definitions or restart any containers.'
Info 'Regression leads remain as local test data in Twenty/Mailpit.'

if ($failCount -gt 0) { exit 1 }
exit 0
