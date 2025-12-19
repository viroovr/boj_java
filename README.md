# BOJ Java 성능 측정 Workspace 사용 가이드

이 문서는 BOJ Java 알고리즘 풀이 과정에서  
**성능 측정 → 개선 → 회귀 검증 → 결과 문서화**를 자동화하기 위한  
PowerShell Workspace 사용 방법을 설명합니다.

---

## 1. 기본 개념 정리

### 용어

- **problem**: BOJ 문제 번호 (예: 10799)
- **phase**: 구현 단계 구분 (baseline, opt1, opt2 등)
- **tc**: 테스트 케이스 식별자
- **runs / warmup**: 성능 측정 반복 횟수 / 워밍업 횟수

### 로그 파일

- 위치: `logs/exec_log.csv`
- 기록 항목:
```

timestamp,problem,tc,exec_ms,status,phase,tag

```

---

## 2. 최초 문제 생성 및 이동

### ① 문제 디렉토리 생성

```powershell
boj 10799
```

자동으로 생성됨:

* `boj/10799/Main.java`
* `boj/10799/README.md`

---

## 3. 입력 파일 작성 규칙

`input.txt` 파일을 문제 디렉토리에 생성합니다.

### 테스트 케이스 분리 규칙

```txt
# tc=1
입력값...
입력값...

# tc=2
입력값...
```

* `# tc=값` 기준으로 자동 분리
* 여러 줄 입력 지원

---

## 4. Phase 관리 (중요)

### Phase 설정

```powershell
phase baseline
phase opt1
phase opt2
```

* 모든 실행 로그는 **현재 phase 기준으로 기록**
* 성능 비교, 회귀 판단의 핵심 기준

---

## 5. 단일 실행 (빠른 확인용)

### 표준 입력 없이 실행

```powershell
jrun
```

### input.txt 기준 실행

```powershell
jrunin
```

### 특정 TC만 실행

```powershell
jrunin -tc 1
```

> ⚠️ 단일 실행은 참고용
> **정확한 성능 비교에는 stress test 사용 권장**

---

## 6. 성능 측정 (Stress Test)

### 기본 실행

```powershell
jstress
```

기본값:

* runs = 100
* warmup = 10

### 옵션 지정

```powershell
jstress -runs 200 -warmup 20
```

### JVM 옵션 포함

```powershell
jstress -JavaArgs "-Xms256m","-Xmx256m","-XX:+UseG1GC"
```

#### 내부 동작

* warmup 구간: GC 수행
* sample 구간: 성능 측정
* 상·하위 5% 자동 trim
* 결과 로그 기록

---

## 7. 성능 요약 분석 (Analyze)

### 실행

```powershell
analyze
```

### 결과

* 콘솔 출력:

  * phase × tc 평균 실행 시간
  * Δ% (이전 phase 대비 변화율)
* README 자동 반영:

  * `## ⏱ 실행 시간 성능 분석` 섹션 생성/갱신

Δ% 계산 기준:

```txt
(prev_avg - curr_avg) / prev_avg * 100
```

---

## 8. 통계적 유의성 검증 (t-test)

### 실행

```powershell
ttest
```

### 특징

* Welch t-test (독립 2표본)
* 대상: `tag=sample` 데이터만 사용
* p-value는 **정규근사 기반(df 보정 생략)**

README에 자동 반영됨:

```txt
## 📊 통계적 유의성 검증 (Welch t-test)
```

---

## 9. 성능 회귀 검증 (Regression)

### 실행

```powershell
regress
```

### 회귀 판정 기준

* Δ% < 0  (성능 악화)
* p-value < 0.05
* |Cohen’s d| ≥ 0.3

### 결과

* 콘솔:

  * REGRESSION / OK 로그 출력
* README:

  * 회귀 테이블 자동 생성
  * 상단에 한 줄 요약 자동 삽입

예:

```txt
> 🔍 이번 변경의 성능 요약: 일부 테스트에서 small 수준의 성능 저하가 확인되었습니다.
```

---

## 10. 로그 정리 (선택)

### 실행

```powershell
logclean
```

### 옵션

```powershell
logclean -days 7 -keepPerProblem 500
```

* 최근 N일 로그만 유지
* 문제별 최대 K개 로그 보존

---

## 11. 권장 사용 흐름 (Best Practice)

```text
boj 문제번호
↓
input.txt 작성
↓
phase baseline
↓
jstress
↓
코드 개선
↓
phase opt1
↓
jstress
↓
analyze
↓
ttest
↓
regress
```

---

## 12. 주의사항

* 서로 다른 phase는 **동일한 입력 / 동일한 실행 조건**에서 비교해야 함
* JVM 옵션 변경 시 반드시 새로운 phase로 분리
* 단일 실행(jrun)은 성능 비교 근거로 사용 금지

---

## 13. 목적

이 Workspace는 단순한 알고리즘 풀이가 아니라
**성능 개선 과정을 정량적으로 증명하고 문서화**하기 위한 도구입니다.

* 추측이 아닌 수치 기반 판단
* 개선 효과의 재현성 확보
* 회귀 자동 감지

---
