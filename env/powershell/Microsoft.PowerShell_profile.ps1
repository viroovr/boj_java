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

$TLE_LIMIT = 2000   # ms

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

function boj {
    param(
        [Parameter(Mandatory)]
        [string]$number
    )

    $problemDir = Join-Path $BOJ_DIR $number
    $filePath  = Join-Path $problemDir "Main.java"
    $readmePath = Join-Path $problemDir "README.md"

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

    Set-Location $problemDir
    code $filePath

    Set-Variable -Name CURRENT_PROBLEM -Value $number -Scope Global
}

# ---- Java runner (정확한 측정용) ----
function Invoke-Java {
    param(
        [Parameter(Mandatory)][string[]]$InputLines,
        [string[]]$JavaArgs = @(),
        [switch]$NoOutput
    )

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "java"
    $psi.Arguments = (($JavaArgs + @("Main")) -join " ")
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

    $out = $p.StandardOutput.ReadToEnd()
    $err = $p.StandardError.ReadToEnd()
    $p.WaitForExit()

    $sw.Stop()

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
        if ($line -match '^\s*#\s*tc\s*=\s*(.+)\s*$') {
            if ($currentTc -ne $null) {
                $blocks += [pscustomobject]@{ tc = $currentTc; lines = $current.ToArray() }
            }
            $currentTc = $matches[1].Trim()
            $current = New-Object System.Collections.Generic.List[string]
            continue
        }
        $current.Add($line)
    }

    if ($currentTc -ne $null) {
        $blocks += [pscustomobject]@{ tc = $currentTc; lines = $current.ToArray() }
    }

    $GLOBAL:__TC_CACHE = [pscustomobject]@{ Stamp = $stamp; Blocks = $blocks }
    return $blocks
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

    if (!(Test-Path "input.txt")) {
        Write-Host "❌ input.txt 없음" -ForegroundColor Red
        return
    }

    javac Main.java
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ 컴파일 실패" -ForegroundColor Red
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

    foreach ($b in $blocks) {
        $res = Invoke-Java -InputLines $b.lines

        [Console]::Out.WriteLine()

        if ($res.ExitCode -ne 0) {
            Write-Host "❌ TC $($b.tc) 실행 실패 (exit=$($res.ExitCode))" -ForegroundColor Red
            continue
        }

        $ms   = $res.Ms
        $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $phase = $GLOBAL:CURRENT_PHASE

        if ($ms -gt $TLE_LIMIT) {
            $status = "TLE_WARN"
            Write-Host "TC $($b.tc) => $ms ms (LIMIT $TLE_LIMIT)" -ForegroundColor Red
        } else {
            $status = "OK"
            Write-Host "TC $($b.tc) => $ms ms" -ForegroundColor Cyan
        }

        # ✅ CSV 컬럼 7개 고정 (tag 비어도 넣어야 Import-Csv가 안 흔들림)
        "$time,$problem,$($b.tc),$ms,$status,$phase," | Add-Content -Encoding UTF8 $LOG_FILE
    }
}


function phase {
    param([Parameter(Mandatory)][string]$name)
    $GLOBAL:CURRENT_PHASE = $name
    Write-Host "▶ CURRENT_PHASE = $name" -ForegroundColor Cyan
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

    $logs = Get-Logs | Where-Object {
        $_.problem -eq $problem -and $_.status -eq "OK"
    }

    if ($logs.Count -eq 0) {
        Write-Host "❌ 분석할 로그 없음" -ForegroundColor Red
        return
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

function jstress {
    param(
        [int]$runs = 100,
        [int]$warmup = 10,
        [string]$problem = $CURRENT_PROBLEM,
        [string[]]$JavaArgs = @()   # 필요하면 "-Xms256m","-Xmx256m","-XX:+UseSerialGC" 등
    )

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

    $blocks = Get-TcBlocks "input.txt"

    Write-Host "▶ Stress Test (runs=$runs, warmup=$warmup, phase=$GLOBAL:CURRENT_PHASE)" -ForegroundColor Yellow

    foreach ($b in $blocks) {
        Write-Host "`n[TC $($b.tc)]" -ForegroundColor Cyan

        $records = New-Object System.Collections.Generic.List[object]

        for ($i = 1; $i -le ($runs + $warmup); $i++) {
            if ($i -le $warmup) {
                [System.GC]::Collect()
                [System.GC]::WaitForPendingFinalizers()
            }

            $res = Invoke-Java -InputLines $b.lines -JavaArgs $JavaArgs -NoOutput

            if ($res.ExitCode -ne 0) { continue }

            $records.Add([pscustomobject]@{ ms = $res.Ms; idx = $i })
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

        foreach ($r in $records) {
            $tag = if ($r.idx -le $warmup) { "warmup" } else { "sample" }

            # sample만 trim 태그 부여
            if ($tag -eq "sample") {
                $pos = [array]::IndexOf($sampleIdxOrder, $r.idx)
                if ($pos -ge 0 -and $pos -lt $lowCut) { $tag = "trim_low" }
                elseif ($pos -ge $highCut)            { $tag = "trim_high" }
            }

            $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            "$time,$problem,$($b.tc),$($r.ms),OK,$GLOBAL:CURRENT_PHASE,$tag" |
                Add-Content -Encoding UTF8 $LOG_FILE
        }

        Write-Host "✔ TC $($b.tc) logged (runs=$runs, warmup=$warmup)" -ForegroundColor Green
    }

    Write-Host "`n✔ Stress Test Complete" -ForegroundColor Green
}

# ---- Normal CDF (Abramowitz–Stegun approximation) ----
function Normal-CDF($z) {
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
function Cohen-D($x1, $x2) {
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
        $phases = $tcRows.phase | Select-Object -Unique

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

            $pval = 2 * (1 - (Normal-CDF([Math]::Abs($t))))
            $pval = [Math]::Round($pval, 5)
            $sig = if ($pval -lt $alpha) { "YES" } else { "NO" }
            
            $d = Cohen-D $x1 $x2
            $effect = Effect-Label $d

            Write-Host "TC $tc : $p1 → $p2 | t=$([Math]::Round($t,3)) p=$([Math]::Round($pval,5)) d=$d ($effect) Significant=$sig"

            $results += [pscustomobject]@{
                TC = $tc
                Phase = "$p1 → $p2"
                T = [Math]::Round($t, 3)
                P = [Math]::Round($pval, 5)
                D = $d
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

| TC | Phase 비교 | t-value | p-value | Cohen’s d | Effect | Significant |
|:--:|:-----------|--------:|--------:|----------:|:------:|:-----------:|

"@

    foreach ($r in $results) {
        $md += "| $($r.TC) | $($r.Phase) | $($r.T) | $($r.P) | $($r.D) | $($r.Effect) | $($r.Sig) |`n"
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
    Write-Host "(p-value: normal approximation, df ignored)" -ForegroundColor DarkGray
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
            $pval = 2 * (1 - (Normal-CDF([Math]::Abs($t))))
            $pval = [Math]::Round($pval, 5)
            $tR = [math]::Round($t, 3)

            $d = Cohen-D $x1 $x2
            $isRegression = (
                $delta -lt 0 -and
                $pval -lt $alpha -and
                [Math]::Abs($d) -ge 0.3
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
                $regressions += [pscustomobject]@{ TC=$tc; Phase="$p1 → $p2"; Delta=$delta; T=$tR; P=$pval; D=$d; Effect=$effect}
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
- p-value는 정규근사 기반이며, df 보정은 생략됨
- p-value는 “우연이 아닐 가능성”
- Cohen’s d는 “개선 규모”
- **p < 0.05 && d ≥ 0.3 → 실질적 영향 가능성**
- **p < 0.05 && d < 0.2 → 통계적이지만 의미 없음**

| TC | Phase | Δ% | t-value | p-value | Cohen’s d | Effect |
|:--:|:------|---:|--------:|--------:|----------:|:------:|

"@

    foreach ($r in $regressions) {
        $md += "| $($r.TC) | $($r.Phase) | $($r.Delta) | $($r.T) | $($r.P) | $($r.D) | $($r.Effect) |`n"
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

    $now = Get-Date
    $cutoff = $now.AddDays(-$days)

    $logs = Get-Logs

    # 1️⃣ 기간 기준 필터
    $recentLogs = $logs | Where-Object {
        [datetime]$_.timestamp -ge $cutoff
    }

    # 2️⃣ 문제별 최신 K개 유지
    $finalLogs = @()

    foreach ($problem in ($recentLogs.problem | Select-Object -Unique)) {
        $subset = $recentLogs |
            Where-Object { $_.problem -eq $problem } |
            Sort-Object { [datetime]$_.timestamp } -Descending |
            Select-Object -First $keepPerProblem

        $finalLogs += $subset
    }

    # 3️⃣ timestamp 기준 재정렬
    $finalLogs = $finalLogs | Sort-Object { [datetime]$_.timestamp }

    # 4️⃣ 덮어쓰기
    "timestamp,problem,tc,exec_ms,status,phase,tag" |
        Set-Content -Encoding UTF8 $LOG_FILE

    $finalLogs | ForEach-Object {
        "$($_.timestamp),$($_.problem),$($_.tc),$($_.exec_ms),$($_.status),$($_.phase),$($_.tag)"
    } | Add-Content -Encoding UTF8 $LOG_FILE

    Write-Host "✔ 로그 정리 완료 (최근 $days일, 문제별 $keepPerProblem개 유지)" -ForegroundColor Green
}

