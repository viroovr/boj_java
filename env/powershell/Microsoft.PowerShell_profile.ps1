# ==============================
# Algo Workspace PowerShell Profile
# ==============================

# UTF-8 고정
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---- Workspace Root ----
$ALGO_ROOT = "$env:ALGO_HOME\boj_java"
$BOJ_DIR   = Join-Path $ALGO_ROOT "boj"
$LOG_DIR   = Join-Path $ALGO_ROOT "logs"
$LOG_FILE  = Join-Path $LOG_DIR  "exec_log.csv"
$GLOBAL:CURRENT_PHASE = "baseline"

Add-Type -Path "$ALGO_ROOT/tools/anglesharp/AngleSharp.dll"

# ---- Ensure dirs ----
if (!(Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR | Out-Null
}

if (!(Test-Path $LOG_FILE)) {
    "timestamp,problem,tc,exec_ms,status,phase,tag" | Set-Content -Encoding UTF8 $LOG_FILE
}

# ---- 이동 ----
function algo {
    Set-Location $ALGO_ROOT
}

function Get-BojLimits {
    param([Parameter(Mandatory)][string]$ProblemId)

    $url = "https://www.acmicpc.net/problem/$ProblemId"

    $html = Invoke-WebRequest `
        -Uri $url `
        -Headers @{
            "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36"
            "Accept" = "text/html"
            "Accept-Language" = "ko-KR,ko;q=0.9"
            "Referer" = "https://www.acmicpc.net/"
        } `
        -TimeoutSec 10 `
        -UseBasicParsing |
        Select-Object -ExpandProperty Content

    if (-not $html) {
        throw "HTML fetch failed"
    }

    $parser = [AngleSharp.Html.Parser.HtmlParser]::new()
    $doc = $parser.ParseDocument([string]$html)

    $table = $doc.QuerySelector("#problem-info")
    if (-not $table) {
        throw "problem-info table not found"
    }

    $headers = $table.QuerySelectorAll("thead th")
    $values  = $table.QuerySelectorAll("tbody td")

    $timeMs = 2000
    $memMb  = 512

    for ($i = 0; $i -lt $headers.Length; $i++) {
        $h = $headers[$i].TextContent.Trim()
        $v = $values[$i].TextContent.Trim()

        switch ($h) {
            "시간 제한" {
                $timeMs = [int](([double]($v -replace '[^0-9.]','')) * 1000)
            }
            "메모리 제한" {
                $memMb = [int]($v -replace '[^0-9]','')
            }
        }
    }

    return @{
        time_limit_ms   = $timeMs
        memory_limit_mb = $memMb
        source          = "boj"
        fetched_at      = (Get-Date).ToString("o")
    }
}

function Update-BojReadmeMeta {
    param([string]$problem)

    $problemDir = Join-Path $BOJ_DIR $problem
    $readmePath = Join-Path $problemDir "README.md"
    $limitPath  = Join-Path $problemDir "limits.json"

    if (!(Test-Path $readmePath) -or !(Test-Path $limitPath)) {
        return
    }

    $limits = Get-Content $limitPath | ConvertFrom-Json

    $meta = @"
## 🧾 문제 정보

- 🔗 문제 링크: https://www.acmicpc.net/problem/$problem
- ⏱ 시간 제한: $($limits.time_limit_ms) ms
- 💾 메모리 제한: $($limits.memory_limit_mb) MB

---
"@

    $content = Get-Content $readmePath -Raw
    $content = $content -replace "(?s)## 🧾 문제 정보.*?---\s*", ""
    $content = $content -replace "(?s)^# BOJ.*?\n", "`$0`n$meta`n"

    Set-Content -Encoding UTF8 $readmePath $content
}


function boj {
    param(
        [Parameter(Mandatory)]
        [string]$number
    )

    $problemDir = Join-Path $BOJ_DIR $number
    $filePath  = Join-Path $problemDir "Main.java"
    $readmePath = Join-Path $problemDir "README.md"
    $limitPath = Join-Path $problemDir "limits.json"

    if (!(Test-Path $problemDir)) {
        New-Item -ItemType Directory -Path $problemDir | Out-Null
    }

    if (!(Test-Path $filePath)) {
@"
import java.io.*;
import java.util.*;

public class Main {
    public static void main(String[] args) throws Exception {
        BufferedReader br = new BufferedReader(new InputStreamReader(System.in));
        StringBuilder sb = new StringBuilder();

        // TODO: 구현

        System.out.print(sb.toString());
    }
}
"@ | Set-Content -Encoding UTF8 $filePath
    }

    # README.md 생성 (이미 있으면 유지)
    if (!(Test-Path $readmePath)) {
@"
# BOJ $number

## 1. 문제 개요

- 문제 요약 작성

## 2. 초기 접근 방식

- 최초 풀이 아이디어

## 3. 문제점

- 복잡도, 설계 한계

## 4. 개선된 접근

- 핵심 아이디어 정리

## 5. 개선 효과

- 시간/공간 복잡도 비교

## 6. 회고

- 배운 점
"@ | Set-Content -Encoding UTF8 $readmePath
    }

    # ✅ limits.json은 없을 때만 생성
    if (!(Test-Path $limitPath)) {
        Write-Host "▶ Fetching BOJ limits for problem $number..." -ForegroundColor Yellow
        $limits = Get-BojLimits $number
        $limits | ConvertTo-Json | Set-Content -Encoding UTF8 $limitPath
    }

    Set-Location $problemDir
    code $filePath

    Set-Variable -Name CURRENT_PROBLEM -Value $number -Scope Global
    Update-BojReadmeMeta $number
}

function Get-JavaMemoryArgs {
    param($limit)

    $heapMb = [Math]::Max(128, [int]($limit.memory_limit_mb * 0.75))

    return @(
        "-Xms$heapMb" + "m"
        "-Xmx$heapMb" + "m"
        "-XX:MaxMetaspaceSize=128m"
    )
}

# ---- Java runner (정확한 측정용) ----
function Invoke-Java {
    param(
        [Parameter(Mandatory)][string[]]$InputLines,
        [Parameter(Mandatory)]$Limit,
        [string[]]$JavaArgs = @(),
        [switch]$NoOutput
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "java"

    $psi.ArgumentList.Clear()
    foreach ($a in $JavaArgs) { $psi.ArgumentList.Add($a) }
    $psi.ArgumentList.Add("-cp")
    $psi.ArgumentList.Add(".")
    $psi.ArgumentList.Add("Main")

    $psi.WorkingDirectory = (Get-Location).Path   # ⭐ 핵심
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput  = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError  = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi

    $null = $p.Start()

    # stdin 주입 (임시파일/파이프 제거)
    foreach ($l in $InputLines) { $p.StandardInput.WriteLine($l) }
    $p.StandardInput.Close()

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $timeoutMs = $Limit.time_limit_ms + 500

    if (-not $p.WaitForExit($timeoutMs)) {
        $p.Kill()
        return [pscustomobject]@{
            ExitCode = -1
            Ms = $timeoutMs
            Stdout = ""
            Stderr = "TIMEOUT"
        }
    }
    $sw.Stop()

    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()

    if (-not $NoOutput) {
        if ($out) { [Console]::Out.Write($out) }
        if ($err) { [Console]::Error.Write($err) }
    }

    return [pscustomobject]@{
        ExitCode = $p.ExitCode
        Ms       = $sw.ElapsedMilliseconds
        Stdout   = $out
        Stderr   = $err
    }
}

function phase {
    param([Parameter(Mandatory)][string]$name)
    $GLOBAL:CURRENT_PHASE = $name
    Write-Host "▶ CURRENT_PHASE = $name" -ForegroundColor Cyan
}

# ---- input.txt parser cache ----
$GLOBAL:__TC_CACHE = $null

function Get-TcBlocks {
    param([string]$Path = "input.txt")

    if (!(Test-Path $Path)) { return @() }

    $fi = Get-Item $Path
    $stamp = $fi.LastWriteTimeUtc.Ticks

    if ($GLOBAL:__TC_CACHE -and $GLOBAL:__TC_CACHE.Stamp -eq $stamp) {
        return $GLOBAL:__TC_CACHE.Blocks
    }

    $content = Get-Content -LiteralPath $Path -Encoding UTF8

    $blocks = @()
    $current = New-Object System.Collections.Generic.List[string]
    $currentTc = $null

    foreach ($line in $content) {
        if ($line -match '^\s*#\s*tc\s*=\s*(\d+)\s*$') {
            if ($currentTc -ne $null) {
                $blocks += [pscustomobject]@{ tc = [int]$currentTc; lines = $current.ToArray() }
            }
            $currentTc = $matches[1].Trim()
            $current = New-Object System.Collections.Generic.List[string]
            continue
        }
        $current.Add($line)
    }

    if ($currentTc -ne $null) {
        $blocks += [pscustomobject]@{ 
            tc = [int]$currentTc; 
            lines = $current.ToArray() 
        }
    }

    $GLOBAL:__TC_CACHE = [pscustomobject]@{ Stamp = $stamp; Blocks = $blocks }
    return $blocks
}

function Get-RunStatus {
    param($res, $limit)

    if ($res.Stderr -eq "TIMEOUT") { return "TLE" }

    if ($res.ExitCode -ne 0) {
        if ($res.Stderr -match "OutOfMemoryError|Java heap space|GC overhead") {
            return "MLE"
        }
        return "RUNTIME_ERROR"
    }

    if ($res.Ms -gt $limit.time_limit_ms) {
        return "TLE"
    }

    return "OK"
}

# ---- 실행 ----
function jrun {
    javac Main.java
    if ($LASTEXITCODE -ne 0) { return }

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    java Main
    $sw.Stop()

    Write-Host "`n[EXEC TIME] $($sw.ElapsedMilliseconds) ms" -ForegroundColor Cyan
}

function jrunin {
    param(
        [string]$problem = $CURRENT_PROBLEM,
        [string]$tc
    )

    $limit = Get-Content "limits.json" | ConvertFrom-Json
    $memArgs = Get-JavaMemoryArgs $limit

    if (!(Test-Path "input.txt")) {
        Write-Host "❌ input.txt 없음" -ForegroundColor Red
        return
    }

    javac Main.java
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ 컴파일 실패" -ForegroundColor Red
        return
    }

    if (!(Test-Path "Main.class")) {
        Write-Host "❌ Main.class 생성 안됨" -ForegroundColor Red
        Get-ChildItem -Recurse -Filter "*.class"
        return
    }

    $blocks = Get-TcBlocks "input.txt"
    if ($blocks.Count -eq 0) {
        Write-Host "❌ tc 블록을 찾지 못함" -ForegroundColor Red
        return
    }

    if ($tc) {
        $blocks = $blocks | Where-Object { $_.tc -eq $tc }
        if ($blocks.Count -eq 0) {
            Write-Host "❌ tc=$tc 없음" -ForegroundColor Red
            return
        }
    }

    if (-not $GLOBAL:CURRENT_PHASE) {
        Write-Host "❌ CURRENT_PHASE 미설정" -ForegroundColor Red
        return
    }

    foreach ($b in $blocks) {
        
        $res = Invoke-Java `
            -InputLines $b.lines `
            -JavaArgs $memArgs
            -Limit $limit

        [Console]::Out.WriteLine()

        if ($res.ExitCode -ne 0) {
            Write-Host "❌ TC $($b.tc) 실행 실패 (exit=$($res.ExitCode))" -ForegroundColor Red
            continue
        }

        $ms   = $res.Ms
        $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $phase = $GLOBAL:CURRENT_PHASE
        
        $status = Get-RunStatus $res $limit

        switch ($status) {
            "OK" {
                Write-Host "TC $($b.tc) => $ms ms" -ForegroundColor Cyan
            }
            "TLE" {
                Write-Host "TC $($b.tc) => $ms ms (TLE: $($limit.time_limit_ms))" -ForegroundColor Red
            }
            "MLE" {
                Write-Host "TC $($b.tc) => MLE" -ForegroundColor Magenta
            }
            "RUNTIME_ERROR" {
                Write-Host "TC $($b.tc) => RUNTIME ERROR" -ForegroundColor DarkRed
            }
            default {
                Write-Host "TC $($b.tc) => UNKNOWN ($status)" -ForegroundColor Yellow
            }
        }

        # ✅ CSV 컬럼 7개 고정 (tag 비어도 넣어야 Import-Csv가 안 흔들림)
        "$time,$problem,$($b.tc),$ms,$status,$phase," | Add-Content -Encoding UTF8 $LOG_FILE
    }
}


function jstress {
    param(
        [int]$runs = 100,
        [int]$warmup = 10,
        [string]$problem = $CURRENT_PROBLEM,
        [string[]]$JavaArgs = @()   # 필요하면 "-Xms256m","-Xmx256m","-XX:+UseSerialGC" 등
    )

    $limit = Get-Content "limits.json" | ConvertFrom-Json
    $memArgs = Get-JavaMemoryArgs $limit

    if (-not $problem) {
        Write-Host "❌ problem 번호 없음" -ForegroundColor Red
        return
    }

    if (!(Test-Path "input.txt")) {
        Write-Host "❌ input.txt 없음" -ForegroundColor Red
        return
    }

    javac Main.java
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ 컴파일 실패" -ForegroundColor Red
        return
    }

    if (-not $GLOBAL:CURRENT_PHASE) {
        Write-Host "❌ CURRENT_PHASE 미설정" -ForegroundColor Red
        return
    }

    $blocks = Get-TcBlocks "input.txt"
    $failCount = 0
    Write-Host "▶ Stress Test (runs=$runs, warmup=$warmup, phase=$GLOBAL:CURRENT_PHASE)" -ForegroundColor Yellow

    foreach ($b in $blocks) {
        Write-Host "`n[TC $($b.tc)]" -ForegroundColor Cyan

        $records = New-Object System.Collections.Generic.List[object]

        # warmup 시작 전
        [System.GC]::Collect()
        [System.GC]::WaitForPendingFinalizers()

        for ($i = 1; $i -le ($runs + $warmup); $i++) {

            $res = Invoke-Java `
                -InputLines $b.lines `
                -JavaArgs $memArgs `
                -Limit $limit `
                -NoOutput

            if ($res.ExitCode -ne 0) { 
                $status = Get-RunStatus $res $limit

                $records.Add([pscustomobject]@{
                    ms = $res.Ms
                    idx = $i
                    status = $status
                })
                continue 
            }

            $records.Add([pscustomobject]@{ 
                ms = $res.Ms
                idx = $i
                status = Get-RunStatus $res $limit
            })
        }

        if ($records.Count -lt ($warmup + 10)) {
            Write-Host "❌ 실행 샘플이 너무 적음 (records=$($records.Count))" -ForegroundColor Red
            continue
        }

        # ---- 트림 기준은 'sample 구간'에 대해서만 적용하는 게 맞음 ----
        $onlySample = $records | Where-Object { $_.idx -gt $warmup } | Sort-Object ms
        $n = $onlySample.Count

        $sampleIdxOrder = $onlySample | ForEach-Object { $_.idx }
        $lowCut  = [int]([Math]::Floor($n * 0.05))
        $highCut = $n - $lowCut
        
        if ($n -lt 20) {
            $lowCut = 0
            $highCut = $n
        }

        $posMap = @{}
        for ($i = 0; $i -lt $sampleIdxOrder.Count; $i++) {
            $posMap[$sampleIdxOrder[$i]] = $i
        }

        foreach ($r in $records) {
            $tag = if ($r.idx -le $warmup) { "warmup" } else { "sample" }

            # sample만 trim 태그 부여
            if ($tag -eq "sample") {
                
                $pos = $posMap[$r.idx]
                if ($pos -ge 0 -and $pos -lt $lowCut) { $tag = "trim_low" }
                elseif ($pos -ge $highCut)            { $tag = "trim_high" }
            }

            $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            "$time,$problem,$($b.tc),$($r.ms),$($r.status),$GLOBAL:CURRENT_PHASE,$tag" |
                Add-Content -Encoding UTF8 $LOG_FILE
        }

        Write-Host "TC=$($b.tc) | samples=$runs | trim=5% | heap=$($memArgs -join ' ')" -ForegroundColor DarkGray

    }
    Write-Host "`n✔ Stress Test Complete" -ForegroundColor Green
}


function prompt {
    "PS $pwd> "
}

$GLOBAL:__LOG_CACHE = $null
$GLOBAL:__LOG_CACHE_STAMP = $null

function Get-Logs {
    $stamp = (Get-Item $LOG_FILE).LastWriteTimeUtc.Ticks
    if (-not $GLOBAL:__LOG_CACHE -or $GLOBAL:__LOG_CACHE_STAMP -ne $stamp) {
        $GLOBAL:__LOG_CACHE = Import-Csv $LOG_FILE
        $GLOBAL:__LOG_CACHE_STAMP = $stamp
    }
    return $GLOBAL:__LOG_CACHE
}

# ---------- 통계 유틸 ----------
function Mean($arr) {
    ($arr | Measure-Object -Average).Average
}

function Variance($arr, $mean) {
    ($arr | ForEach-Object { ($_ - $mean) * ($_ - $mean) } |
        Measure-Object -Sum).Sum / ($arr.Count - 1)
}

function analyze {
    param(
        [string]$problem = $CURRENT_PROBLEM
    )

    if (-not $problem) {
        Write-Host "❌ problem 번호 없음" -ForegroundColor Red
        return
    }

    $problemDir = Join-Path $BOJ_DIR $problem
    $readmePath = Join-Path $problemDir "README.md"

    if (!(Test-Path $readmePath)) {
        Write-Host "❌ README.md 없음" -ForegroundColor Red
        return
    }

    $allLogs = Get-Logs | Where-Object {
        $_.problem -eq $problem -and $_.status -eq "OK"
    }

    $logs = Get-Logs | Where-Object {
        $_.problem -eq $problem `
        -and $_.status -eq "OK" `
        -and $_.phase `
        -and $_.tc `
        -and $_.tag -eq "sample"
    }

    if ($logs.Count -eq 0) {
        Write-Host "❌ 분석할 로그 없음" -ForegroundColor Red
        return
    }

    # 제외 로그 수 계산

    $excluded = $allLogs.Count - $logs.Count
    if ($excluded -gt 0) {
        Write-Host "⚠ sample 외 로그 $excluded 건 분석 제외" -ForegroundColor DarkYellow
    }

    # ---------- 통계 ----------
    function Calc-Stats($rows) {
        $times = $rows.exec_ms | ForEach-Object { [int]$_ } | Sort-Object
        $n = $times.Count
        if ($n -eq 0) { return $null }

        $avg = Mean $times
        $std = [math]::Sqrt((Variance $times $avg))

        return @{
            Count  = $n
            Avg    = [math]::Round($avg, 2)
            Min    = $times[0]
            Max    = $times[-1]
            StdDev = [math]::Round($std, 2)
            CV     = [math]::Round(($std / $avg) * 100, 2)
        }
    }

    # ---------- phase × tc ----------
    $rows = @()
    foreach ($g in ($logs | Group-Object phase, tc)) {
        $phase, $tc = $g.Name -split ",\s*"
        $stat = Calc-Stats $g.Group
        if ($stat) {
            $rows += [pscustomobject]@{
                Phase  = $phase
                TC     = $tc
                Avg    = $stat.Avg
                Min    = $stat.Min
                Max    = $stat.Max
                StdDev = $stat.StdDev
                CV     = $stat.CV
                Count  = $stat.Count
            }
        }
    }

    # ---------- phase 순서 정렬 ----------
    $phaseOrder = $logs |
        Group-Object phase |
        ForEach-Object {
            $minTs = ($_.Group | ForEach-Object { [datetime]$_.timestamp } |
                    Measure-Object -Minimum).Minimum
            [pscustomobject]@{ Phase=$_.Name; FirstTs=$minTs }
        } |
        Sort-Object FirstTs |
        Select-Object -ExpandProperty Phase
    $ordered = @()

    foreach ($tc in ($rows.TC | Select-Object -Unique)) {
        $prevAvg = $null

        foreach ($phase in $phaseOrder) {
            $r = $rows | Where-Object { $_.TC -eq $tc -and $_.Phase -eq $phase }
            if ($r) {
                $delta = if ($prevAvg) {
                    [math]::Round((($prevAvg - $r.Avg) / $prevAvg) * 100, 2)
                } else {
                    "-"
                }

                $ordered += [pscustomobject]@{
                    Phase  = $phase
                    TC     = $tc
                    Avg    = $r.Avg
                    Min    = $r.Min
                    Max    = $r.Max
                    StdDev = $r.StdDev
                    CV     = $r.CV
                    Delta  = $delta
                    Count  = $r.Count
                }

                $prevAvg = $r.Avg
            }
        }
    }

    # ---------- 콘솔 출력 ----------
    Write-Host "`n==== Performance Analysis (Problem $problem) ====" -ForegroundColor Yellow
    $ordered | Format-Table Phase, TC, Avg, Delta, StdDev, CV, Count -AutoSize

    # ---------- README Markdown (라인 깨짐 방지) ----------
    $md = @"
## ⏱ 실행 시간 성능 분석 (자동 생성)

> phase × 테스트케이스(tc) 기준 자동 분석  
> Δ%는 평균 실행 시간(Avg)을 기준으로 계산됨

| Phase | TC | Avg(ms) | Δ% | StdDev | CV(%) | N |
|:----:|:--:|-------:|---:|-------:|------:|--:|
"@

    foreach ($r in $ordered) {
        $md += "`n| $($r.Phase) | $($r.TC) | $($r.Avg) | $($r.Delta) | $($r.StdDev) | $($r.CV) | $($r.Count) |"
    }
    $md += "`n"
    
    # 기존 분석 섹션 제거 후 재작성
    $content = Get-Content $readmePath -Raw

    # 해당 섹션만 정확히 제거
    $content = $content -replace "(?s)## ⏱ 실행 시간 성능 분석.*?(?=\n## |\z)", ""

    # 파일 끝에 정확히 한 번만 삽입
    $content = $content.TrimEnd() + "`n`n" + $md

    Set-Content -Encoding UTF8 $readmePath $content

    Write-Host "`n✔ phase 간 개선율 분석 완료 및 README 업데이트" -ForegroundColor Green
}

function Measure-TDist-CDF {
    param(
        [double]$t,
        [double]$df
    )

    # df가 충분히 크면 정규 근사
    if ($df -gt 100) {
        return Measure-Normal-CDF $t
    }

    # Cornish–Fisher 보정
    $g1 = ($t * $t * $t + $t) / (4 * $df)
    $g2 = (5 * $t * $t * $t * $t * $t + 16 * $t * $t * $t + 3 * $t) / (96 * $df * $df)

    $z = $t + $g1 + $g2
    return Measure-Normal-CDF $z
}

# ---- Normal CDF (Abramowitz–Stegun approximation) ----
function Measure-Normal-CDF($z) {
    $z = [double]$z
    $t = 1.0 / (1.0 + 0.2316419 * [Math]::Abs($z))
    $d = 0.3989423 * [Math]::Exp(-$z * $z / 2.0)

    $prob = $d * $t * (
        0.3193815 +
        $t * (
            -0.3565638 +
            $t * (
                1.781478 +
                $t * (
                    -1.821256 +
                    $t * 1.330274
                )
            )
        )
    )

    if ($z -gt 0) {
        return 1.0 - $prob
    } else {
        return $prob
    }
}

# ---- Effect Size (Cohen's d, Welch) ----
function Measure-Cohen-D($x1, $x2) {
    $n1 = $x1.Count
    $n2 = $x2.Count

    if ($n1 -lt 2 -or $n2 -lt 2) { return $null }

    $m1 = ($x1 | Measure-Object -Average).Average
    $m2 = ($x2 | Measure-Object -Average).Average

    $v1 = ($x1 | ForEach-Object { ($_ - $m1) * ($_ - $m1) } |
           Measure-Object -Sum).Sum / ($n1 - 1)

    $v2 = ($x2 | ForEach-Object { ($_ - $m2) * ($_ - $m2) } |
           Measure-Object -Sum).Sum / ($n2 - 1)

    # Welch pooled SD
    $sp = [Math]::Sqrt((($v1 + $v2) / 2))

    if ($sp -eq 0) { return 0 }

    return [Math]::Round((($m1 - $m2) / $sp), 3)
}

function Effect-Label($d) {
    if ($d -ge 0.8) { "LARGE" }
    elseif ($d -ge 0.5) { "MEDIUM" }
    elseif ($d -ge 0.2) { "SMALL" }
    else { "NEGLIGIBLE" }
}

# ---- Effect summary sentence ----
function Effect-Summary($delta, $d, $effect) {
    if ($delta -lt 0) {
        switch ($effect) {
            "LARGE"  { return "의미 있는 성능 저하가 발생했습니다." }
            "MEDIUM" { return "체감 가능한 성능 저하가 확인되었습니다." }
            "SMALL"  { return "미세한 성능 저하가 관측되었습니다." }
            default  { return "성능 변화는 측정 노이즈 수준입니다." }
        }
    } elseif ($delta -gt 0) {
        switch ($effect) {
            "LARGE"  { return "의미 있는 성능 개선이 확인되었습니다." }
            "MEDIUM" { return "체감 가능한 성능 개선이 확인되었습니다." }
            "SMALL"  { return "소폭의 성능 개선이 관측되었습니다." }
            default  { return "성능 변화는 측정 노이즈 수준입니다." }
        }
    } else {
        return "성능 변화가 관측되지 않았습니다."
    }
}

function ttest {
    param(
        [string]$problem = $CURRENT_PROBLEM,
        [double]$alpha = 0.05
    )

    if (-not $problem) {
        Write-Host "❌ problem 번호 없음" -ForegroundColor Red
        return
    }

    $problemDir = Join-Path $BOJ_DIR $problem
    $readmePath = Join-Path $problemDir "README.md"

    if (!(Test-Path $readmePath)) {
        Write-Host "❌ README.md 없음" -ForegroundColor Red
        return
    }

    $logs = Get-Logs | Where-Object {
        $_.problem -eq $problem -and
        $_.status -eq "OK" -and
        $_.tag -eq "sample"
    }

    if ($logs.Count -eq 0) {
        Write-Host "❌ sample 로그 없음" -ForegroundColor Red
        return
    }

    Write-Host "`n==== Welch t-test (Problem $problem) ====" -ForegroundColor Yellow

    $results = @()

    foreach ($tc in ($logs.tc | Select-Object -Unique)) {
        $tcRows = $logs | Where-Object { $_.tc -eq $tc }
        $phases = $tcRows |
            Group-Object phase |
            ForEach-Object {
                $firstTs = ($_.Group.timestamp | ForEach-Object { [datetime]$_ } |
                            Measure-Object -Minimum).Minimum
                [pscustomobject]@{ Phase = $_.Name; Ts = $firstTs }
            } |
            Sort-Object Ts |
            Select-Object -ExpandProperty Phase

        for ($i = 0; $i -lt $phases.Count - 1; $i++) {
            $p1 = $phases[$i]
            $p2 = $phases[$i + 1]

            $x1 = $tcRows | Where-Object { $_.phase -eq $p1 } |
                  ForEach-Object { [double]$_.exec_ms }

            $x2 = $tcRows | Where-Object { $_.phase -eq $p2 } |
                  ForEach-Object { [double]$_.exec_ms }

            if ($x1.Count -lt 2 -or $x2.Count -lt 2) { continue }

            $m1 = Mean $x1
            $m2 = Mean $x2
            $v1 = Variance $x1 $m1
            $v2 = Variance $x2 $m2

            $t = ($m1 - $m2) / [Math]::Sqrt(($v1 / $x1.Count) + ($v2 / $x2.Count))
            # Welch–Satterthwaite df
            $df = (
                [Math]::Pow(($v1 / $x1.Count + $v2 / $x2.Count), 2)
            ) / (
                [Math]::Pow(($v1 / $x1.Count), 2) / ($x1.Count - 1) +
                [Math]::Pow(($v2 / $x2.Count), 2) / ($x2.Count - 1)
            )

            $pval = 2 * (1 - (Measure-TDist-CDF ([Math]::Abs($t)) $df))
            $pval = [Math]::Round($pval, 5)
            $sig = if ($pval -lt $alpha) { "YES" } else { "NO" }
            
            $d = Measure-Cohen-D $x1 $x2
            $effect = Effect-Label $d

            Write-Host "TC $tc : $p1 → $p2 | t=$([Math]::Round($t,3)) p=$([Math]::Round($pval,5)) d=$d ($effect) Significant=$sig"

            $results += [pscustomobject]@{
                TC = $tc
                Phase = "$p1 → $p2"
                T = [Math]::Round($t, 3)
                P = [Math]::Round($pval, 5)
                D = $d
                N1 = $x1.Count
                N2 = $x2.Count
                Effect = $effect
                Sig = $sig
            }
        }
    }

    # ---------- README 반영 ----------
    $md = @"

## 📊 통계적 유의성 검증 (Welch t-test)

- 유의수준 α = $alpha
- 대상 데이터: tag=sample (warmup / trim 제외)
- 검정 방식: 독립 2표본 Welch t-test
- p-value 계산:
  - df > 100 : 정규분포 근사
  - df ≤ 100 : Cornish–Fisher 보정된 t-분포 근사
- Cohen’s d 기준
  - |d| < 0.2 : NEGLIGIBLE
  - 0.2–0.5   : SMALL
  - 0.5–0.8   : MEDIUM
  - ≥ 0.8     : LARGE

| TC | Phase 비교 | n1 | n2 | t-value | p-value | Cohen’s d | Effect | Significant |
|:--:|:-----------|------:|------:|--------:|--------:|----------:|:------:|:-----------:|

"@

    foreach ($r in $results) {
        $md += "| $($r.TC) | $($r.Phase) | $($r.N1) | $($r.N2) |$($r.T) | $($r.P) | $($r.D) | $($r.Effect) | $($r.Sig) |`n"
    }

    # 기존 섹션 제거 후 재작성
    $content = Get-Content $readmePath -Raw
    $content = $content -replace "(?s)## 📊 통계적 유의성 검증.*?(?=\n## |\z)", ""
    Set-Content -Encoding UTF8 $readmePath $content
    Add-Content -Encoding UTF8 $readmePath $md

    Write-Host "`n✔ t-test 결과 README 반영 완료" -ForegroundColor Green
}

function regress {
    param(
        [string]$problem = $CURRENT_PROBLEM,
        [double]$alpha = 0.05
    )

    if (-not $problem) {
        Write-Host "❌ problem 번호 없음" -ForegroundColor Red
        return
    }

    $problemDir = Join-Path $BOJ_DIR $problem
    $readmePath = Join-Path $problemDir "README.md"
    $summaries = @()
    $EFFECT_THRESHOLD = 0.3  # SMALL 이상

    if (!(Test-Path $readmePath)) {
        Write-Host "❌ README.md 없음" -ForegroundColor Red
        return
    }

    $logs = Get-Logs | Where-Object {
        $_.problem -eq $problem -and
        $_.status -eq "OK" -and
        $_.tag -eq "sample"
    }

    if ($logs.Count -eq 0) {
        Write-Host "❌ sample 로그 없음" -ForegroundColor Red
        return
    }

    Write-Host "`n==== Regression Check (Problem $problem) ====" -ForegroundColor Yellow
    Write-Host "(Welch t-test with df-adjusted p-value)" -ForegroundColor DarkGray
    Write-Host "Rule: Δ% < 0 AND p < $alpha (Welch t-test, two-tailed)" -ForegroundColor DarkGray

    $regressions = @()

    foreach ($tc in ($logs.tc | Select-Object -Unique)) {
        $tcRows = $logs | Where-Object { $_.tc -eq $tc }

        # ✅ phase를 "처음 등장한 시간"으로 정렬 (로그 섞임 방지)
        $phaseOrder = $tcRows |
            Group-Object phase |
            ForEach-Object {
                $minTs = ($_.Group | ForEach-Object { [datetime]$_.timestamp } | Measure-Object -Minimum).Minimum
                [pscustomobject]@{ Phase=$_.Name; FirstTs=$minTs }
            } |
            Sort-Object FirstTs |
            Select-Object -ExpandProperty Phase

        for ($i = 0; $i -lt $phaseOrder.Count - 1; $i++) {
            $p1 = $phaseOrder[$i]
            $p2 = $phaseOrder[$i + 1]

            $x1 = $tcRows | Where-Object { $_.phase -eq $p1 } | ForEach-Object { [double]$_.exec_ms }
            $x2 = $tcRows | Where-Object { $_.phase -eq $p2 } | ForEach-Object { [double]$_.exec_ms }

            if ($x1.Count -lt 2 -or $x2.Count -lt 2) { continue }

            $m1 = Mean $x1
            $m2 = Mean $x2
            $v1 = Variance $x1 $m1
            $v2 = Variance $x2 $m2

            # Δ%는 기존 정의 그대로: (이전 - 현재)/이전 * 100
            $delta = [math]::Round((($m1 - $m2) / $m1) * 100, 2)

            # Welch t-stat (df는 회귀 판정에 필수는 아니니 생략 가능, p는 정규근사)
            $t = ($m1 - $m2) / [Math]::Sqrt(($v1 / $x1.Count) + ($v2 / $x2.Count))

            $df = (
                [Math]::Pow(($v1 / $x1.Count + $v2 / $x2.Count), 2)
            ) / (
                [Math]::Pow(($v1 / $x1.Count), 2) / ($x1.Count - 1) +
                [Math]::Pow(($v2 / $x2.Count), 2) / ($x2.Count - 1)
            )

            $pval = 2 * (1 - (Measure-TDist-CDF ([Math]::Abs($t)) $df))
            $pval = [Math]::Round($pval, 5)
            $tR = [math]::Round($t, 3)

            $d = Measure-Cohen-D $x1 $x2
            $isRegression = (
                $delta -lt 0 -and
                $pval -lt $alpha -and
                [Math]::Abs($d) -ge $EFFECT_THRESHOLD
            )

            $effect = Effect-Label $d
            $summaryText = Effect-Summary $delta $d $effect

            $summaries += [pscustomobject]@{
                TC = $tc
                Delta = $delta
                D = $d
                Effect = $effect
                Summary = $summaryText
            }
            if ($isRegression) {
                Write-Host "🚨 REGRESSION: TC $tc | $p1 → $p2 | Δ=$delta% t=$tR p=$pval d=$d ($effect)" -ForegroundColor Red
                $regressions += [pscustomobject]@{ 
                    TC=$tc; 
                    Phase="$p1 → $p2"; 
                    Delta=$delta; 
                    T=$tR; 
                    P=$pval; 
                    D=$d; 
                    Effect=$effect
                    N1 = $x1.Count
                    N2 = $x2.Count
                }
            } else {
                Write-Host "OK : TC $tc | $p1 → $p2 | Δ=$delta% t=$tR p=$pval d=$d ($effect)" -ForegroundColor DarkGray
            }
        }
    }

    if ($regressions.Count -eq 0) {
        Write-Host "`n✔ No regression detected" -ForegroundColor Green
        return
    }

    function Pick-OverallSummary($summaries) {
        if ($summaries.Count -eq 0) {
            return "성능 변화는 통계적·실질적으로 유의하지 않습니다."
        }

        $priority = @{ "LARGE"=4; "MEDIUM"=3; "SMALL"=2; "NEGLIGIBLE"=1 }

        $worst = $summaries |
            Where-Object { $_.Delta -lt 0 } |
            Sort-Object { $priority[$_.Effect] } -Descending |
            Select-Object -First 1

        if ($worst) {
            return "일부 테스트에서 $($worst.Effect.ToLower()) 수준의 성능 저하가 확인되었습니다."
        }

        return "성능 회귀는 감지되지 않았습니다."
    }

    $overallSummary = Pick-OverallSummary $summaries
    # ---------- README 반영 ----------
    $md = @"

## 🚨 성능 Regression 감지 (자동 생성)

- 기준: **Δ% < 0 AND p < $alpha**
- 해석: 평균 실행 시간이 증가했고(Δ% 음수), 그 악화가 통계적으로 유의미함
- p-value는 Welch t-test 기준으로 계산되며,
  df ≤ 100 구간에서는 Cornish–Fisher 보정된 t-분포 근사를 사용함
- p-value는 “우연이 아닐 가능성”
- Cohen’s d는 “개선 규모”
- **p < 0.05 && d ≥ 0.3 → 실질적 영향 가능성**
- **p < 0.05 && d < 0.2 → 통계적이지만 의미 없음**
- 회귀 판정 기준:
  - 평균 실행 시간 증가 (Δ% < 0)
  - 통계적 유의성 (p < α)
  - 효과 크기: |d| ≥ 0.3 (SMALL 이상)

| TC | Phase | n1 | n2 | Δ% | t-value | p-value | Cohen’s d | Effect |
|:--:|:------|---:|---:|---:|--------:|--------:|----------:|:------:|

"@

    foreach ($r in $regressions) {
        $md += "| $($r.TC) | $($r.Phase) | $($r.N1) |$($r.N2) |$($r.Delta) | $($r.T) | $($r.P) | $($r.D) | $($r.Effect) |`n"
    }

    $content = Get-Content $readmePath -Raw
    $content = $content -replace "(?s)## 🚨 성능 Regression 감지.*?(?=\n## |\z)", ""
    Set-Content -Encoding UTF8 $readmePath $content
    Add-Content -Encoding UTF8 $readmePath $md

    Write-Host "`n✔ Regression 결과 README 반영 완료" -ForegroundColor Green

    # ---------- README 상단 요약 반영 ----------
    $content = Get-Content $readmePath -Raw

    # 기존 요약 제거
    $content = $content -replace "(?s)> 🔍 이번 변경의 성능 요약:.*?\n", ""

    # 제목 바로 아래에 삽입
    $headerMatch = [regex]::Match($content, "^# BOJ.*\n", "Multiline")

    if ($headerMatch.Success) {
        $insert = $headerMatch.Value + "`n> 🔍 이번 변경의 성능 요약: **$overallSummary**`n"
        $content = $insert + $content.Substring($headerMatch.Length)
    }

    Set-Content -Encoding UTF8 $readmePath $content
}


function logclean {
    param(
        [int]$days = 7,
        [int]$keepPerProblem = 500
    )

    if (!(Test-Path $LOG_FILE)) {
        Write-Host "❌ exec_log.csv 없음" -ForegroundColor Red
        return
    }

    if ($keepPerProblem -le 0) {
        Write-Host "❌ keepPerProblem은 1 이상이어야 합니다." -ForegroundColor Red
        return
    }


    $now = Get-Date
    $cutoff = $now.AddDays(-$days)

    # timestamp 파싱 가능한 로그만
    $logs = Get-Logs | Where-Object { $_.timestamp -as [datetime] }

    # 1️⃣ 문제별 최신 K개 유지
    $latestPerProblem = @()
    foreach ($problem in ($logs.problem | Select-Object -Unique)) {
        $subset = $logs |
            Where-Object { $_.problem -eq $problem } |
            Sort-Object { [datetime]$_.timestamp } -Descending |
            Select-Object -First $keepPerProblem

        $latestPerProblem += $subset
    }

    # 2️⃣ 기간 기준 필터
    $finalLogs = $latestPerProblem | Where-Object {
        [datetime]$_.timestamp -ge $cutoff
    }


    # 3️⃣ timestamp 기준 재정렬
    $finalLogs = $finalLogs | Sort-Object { [datetime]$_.timestamp }

    $backup = "$LOG_FILE.bak_$(Get-Date -Format yyyyMMddHHmmss)"
    Copy-Item $LOG_FILE $backup

    # 4️⃣ 덮어쓰기
    "timestamp,problem,tc,exec_ms,status,phase,tag" |
        Set-Content -Encoding UTF8 $LOG_FILE

    $finalLogs | ForEach-Object {
        "$($_.timestamp),$($_.problem),$($_.tc),$($_.exec_ms),$($_.status),$($_.phase),$($_.tag)"
    } | Add-Content -Encoding UTF8 $LOG_FILE

    $removed = $logs.Count - $finalLogs.Count
    Write-Host "🧹 removed $removed logs" -ForegroundColor DarkGray
    Write-Host "✔ 로그 정리 완료 (최근 $days일, 문제별 $keepPerProblem개 유지)" -ForegroundColor Green
    Write-Host "🗂 backup created: $backup" -ForegroundColor DarkGray
}

