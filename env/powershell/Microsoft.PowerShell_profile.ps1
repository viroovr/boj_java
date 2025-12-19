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
    "timestamp,problem,tc,exec_ms,status,phase" | Set-Content -Encoding UTF8 $LOG_FILE
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
        [string]$tc      # 선택 실행 (옵션)
    )

    if (!(Test-Path "input.txt")) {
        Write-Host "❌ input.txt 없음" -ForegroundColor Red
        return
    }

    # 컴파일
    javac Main.java
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ 컴파일 실패" -ForegroundColor Red
        return
    }

    # input.txt 파싱
    $content = Get-Content "input.txt"

    $blocks = @()
    $current = @()
    $currentTc = $null

    foreach ($line in $content) {
        if ($line -match '^#\s*tc\s*=\s*(.+)$') {
            if ($currentTc -ne $null) {
                $blocks += [pscustomobject]@{
                    tc    = $currentTc
                    lines = $current
                }
            }
            $currentTc = $matches[1].Trim()
            $current = @()
            continue
        }
        $current += $line
    }

    if ($currentTc -ne $null) {
        $blocks += [pscustomobject]@{
            tc    = $currentTc
            lines = $current
        }
    }

    if ($blocks.Count -eq 0) {
        Write-Host "❌ tc 블록을 찾지 못함" -ForegroundColor Red
        return
    }

    # tc 선택 필터
    if ($tc) {
        $blocks = $blocks | Where-Object { $_.tc -eq $tc }
        if ($blocks.Count -eq 0) {
            Write-Host "❌ tc=$tc 없음" -ForegroundColor Red
            return
        }
    }

    # 실행
    foreach ($b in $blocks) {
        $tmp = New-TemporaryFile
        $b.lines | Set-Content -Encoding UTF8 $tmp

        $sw = [System.Diagnostics.Stopwatch]::StartNew()

        Get-Content $tmp | & java Main

        [Console]::Out.WriteLine()
        $exitCode = $LASTEXITCODE
        $sw.Stop()

        Remove-Item $tmp

        if ($exitCode -ne 0) {
            Write-Host "❌ TC $($b.tc) 실행 실패" -ForegroundColor Red
            continue
        }

        $ms = $sw.ElapsedMilliseconds
        $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

        if ($ms -gt $TLE_LIMIT) {
            $status = "TLE_WARN"
            Write-Host "TC $($b.tc) => $ms ms (LIMIT $TLE_LIMIT)" -ForegroundColor Red
        } else {
            $status = "OK"
            Write-Host "TC $($b.tc) => $ms ms" -ForegroundColor Cyan
        }

        $phase = $GLOBAL:CURRENT_PHASE

        "$time,$problem,$($b.tc),$ms,$status,$phase" |
            Add-Content -Encoding UTF8 $LOG_FILE
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

    $logs = Import-Csv $LOG_FILE | Where-Object {
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

        $avg = ($times | Measure-Object -Average).Average
        $std = [math]::Sqrt(
            ($times | ForEach-Object { ($_ - $avg) * ($_ - $avg) } |
             Measure-Object -Sum).Sum / $n
        )

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
    $phaseOrder = $rows.Phase | Select-Object -Unique
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

| Phase | TC | Avg(ms) | Δ% | StdDev | CV(%) | N |
|:----:|:--:|-------:|---:|-------:|------:|--:|

"@

    foreach ($r in $ordered) {
        $md += "| $($r.Phase) | $($r.TC) | $($r.Avg) | $($r.Delta) | $($r.StdDev) | $($r.CV) | $($r.Count) |`n"
    }

    # 기존 분석 섹션 제거 후 재작성
    (Get-Content $readmePath -Raw) `
        -replace "(?s)## ⏱ 실행 시간 성능 분석.*", "" |
        Set-Content -Encoding UTF8 $readmePath

    Add-Content -Encoding UTF8 $readmePath "`n$md"

    Write-Host "`n✔ phase 간 개선율 분석 완료 및 README 업데이트" -ForegroundColor Green
}