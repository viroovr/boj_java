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

$TLE_LIMIT = 2000   # ms

# ---- Ensure dirs ----
if (!(Test-Path $LOG_DIR)) {
    New-Item -ItemType Directory -Path $LOG_DIR | Out-Null
}

if (!(Test-Path $LOG_FILE)) {
    "timestamp,problem,exec_ms,status" | Set-Content -Encoding UTF8 $LOG_FILE
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

        "$time,$problem,$($b.tc),$ms,$status" |
            Add-Content -Encoding UTF8 $LOG_FILE
    }
}

function prompt {
    "PS $pwd> "
}
