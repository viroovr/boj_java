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
        [string]$file = "Main.java",
        [string]$problem = $CURRENT_PROBLEM
    )

    # 1️⃣ 컴파일
    javac $file
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ 컴파일 실패" -ForegroundColor Red
        return
    }

    # 2️⃣ 입력 파일 체크
    if (!(Test-Path "input.txt")) {
        Write-Host "❌ input.txt 없음" -ForegroundColor Red
        return
    }

    # 3️⃣ 실행 + 시간 측정
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    cmd /c "java Main < input.txt"
    $exitCode = $LASTEXITCODE
    $sw.Stop()

    # 4️⃣ 실행 실패 시 → 기록 안 함
    if ($exitCode -ne 0) {
        Write-Host "❌ 실행 실패 (exit code: $exitCode)" -ForegroundColor Red
        return
    }

    # 5️⃣ 정상 실행만 기록
    $ms   = $sw.ElapsedMilliseconds
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    if ($ms -gt $TLE_LIMIT) {
        $status = "TLE_WARN"
        Write-Host "`n[EXEC TIME] $ms ms (LIMIT $TLE_LIMIT ms)" -ForegroundColor Red
    } else {
        $status = "OK"
        Write-Host "`n[EXEC TIME] $ms ms" -ForegroundColor Cyan
    }

    "$time,$problem,$ms,$status" | Add-Content -Encoding UTF8 $LOG_FILE
}

function prompt {
    "PS $pwd> "
}
