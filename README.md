<div align="center">

# Mathigram (수식그램)

**수식으로 그리고, 그림을 수식으로.**

이란의 수학자 Hamid Naderi Yeganeh는 수만 개의 곡선을 정의하는 수식만으로 얼굴·동물 같은 구체적인 그림을 그려낸다.
Mathigram은 이 아이디어를 iPhone에서 양방향으로 체험하는 앱이다 — 수식을 쓰면 그림이 나오고, 사진을 넣으면 그 윤곽을 근사하는 실제 수식이 나온다.

[![Platform](https://img.shields.io/badge/platform-iOS%2027%20(iPhone)-black?logo=apple)](#요구-사항)
[![Swift](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)](#)
[![SwiftUI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)](#)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue)](LICENSE)

</div>

---

## 목차

- [이게 뭔가요](#이게-뭔가요)
- [진행 상황](#진행-상황)
- [Phase 0 — 프로젝트 기반](#phase-0--프로젝트-기반)
- [Phase 1 — 수식 엔진](#phase-1--수식-엔진)
- [요구 사항](#요구-사항)
- [프로젝트 구조](#프로젝트-구조)
- [라이선스](#라이선스)

## 이게 뭔가요

Mathigram은 두 가지 방향의 변환을 제공하는 iPhone 전용 앱이다.

1. **그리기 (수식 → 그림)**: 매개변수 `t`와 레이어 인덱스 `k`에 대한 수식 `x(t,k)`, `y(t,k)`를 입력하면, 앱이 `k`에 대해 수백~수천 번 반복해 곡선을 겹쳐 그린다. 선 하나하나가 모여 하나의 그림이 된다.
2. **변환 (그림 → 수식)**: 사진을 가져오면 Vision으로 윤곽을 추출하고, 이산 푸리에 변환(DFT)으로 그 윤곽을 근사하는 실제 삼각함수 급수 `x(t) = Σ rₖ·cos(kt+φₖ)`를 계산해 보여준다. 항의 개수를 조절하면 그림이 단순해지거나 원본에 가까워진다.

자세한 기능 요구사항은 [`Docs/PRD-Mathigram.md`](Docs/PRD-Mathigram.md), 진행 상황은 [`Docs/TASKS-Mathigram.md`](Docs/TASKS-Mathigram.md)에 있다.

## 진행 상황

| Phase | 내용 | 상태 |
|---|---|:-:|
| 0 | 프로젝트 기반 (문서·타깃 설정·탭 스켈레톤) | ✅ |
| 1 | 수식 엔진 (렉서/파서/평가기) | ✅ |
| 2 | 그리기 모드 (수식 → 그림) | ⬜️ |
| 3 | 변환 모드 (그림 → 수식) | ⬜️ |
| 4 | 갤러리 & 설정 | ⬜️ |
| 5 | 검증 및 마무리 | ⬜️ |

## Phase 0 — 프로젝트 기반

4개 탭(그리기·변환·갤러리·설정)의 뼈대를 세우고, 타깃을 iPhone 전용(iOS 27)으로 설정했다. `그리기` 탭은 다음 단계에 들어올 수식 엔진 자리에 데모용 하트 곡선(`x(t)=16sin³t`, `y(t)=13cos t − 5cos2t − 2cos3t − cos4t`)을 그려 전체 파이프라인의 모양을 먼저 보여준다.

<div align="center">
<img src="Media/Screenshots/phase0-draw.png" width="23%" alt="그리기 탭 — 데모 하트 곡선" />
<img src="Media/Screenshots/phase0-convert.png" width="23%" alt="변환 탭 — 준비 중 안내" />
<img src="Media/Screenshots/phase0-gallery.png" width="23%" alt="갤러리 탭 — 빈 상태" />
<img src="Media/Screenshots/phase0-settings.png" width="23%" alt="설정 탭 — 선 색상·굵기·배경" />
<br/>
<sub>iPhone 16 시뮬레이터(iOS 27) · 그리기 / 변환 / 갤러리 / 설정</sub>
</div>

- **그리기**: `Canvas` 기반 렌더러 자리에 데모 곡선을 그려 디자인을 먼저 고정했다.
- **변환**: 사진 선택·윤곽 추출·푸리에 근사는 Phase 3에서 구현된다.
- **갤러리**: SwiftData 저장소는 Phase 4에서 연결된다.
- **설정**: 선 색상·굵기·색상 순환·배경 토글은 이미 실제로 동작하며, `그리기`/`변환` 캔버스가 공유할 `RenderSettings` 모델에 바로 반영된다.

## Phase 1 — 수식 엔진

`그리기`/`변환` 두 모드가 공유할 **MathEngine**을 추가했다. 사용자가 입력하는 `x(t,k)`, `y(t,k)` 같은 문자열을 임의 코드 실행 없이 안전하게 해석·평가하는 자체 렉서/파서/평가기다.

- **렉서/파서**: 숫자·식별자·`+ - * / ^`·괄호·쉼표를 토큰화하고, `+ -` < `* /` < 단항 `-` < `^`(우결합) 우선순위로 재귀 하강 파싱한다. 모든 구문 오류는 열(column) 번호를 포함한다.
- **평가기**: 변수 `t`(매개변수) · `k`(레이어 인덱스) · `n`(총 레이어 수)과 상수 `pi` · `e`, 함수 `sin cos tan asin acos atan atan2 sqrt abs exp log min max floor ceil round`을 지원한다. 0으로 나누기·`sqrt`의 음수 인자·정의되지 않은 변수는 즉시 오류로 보고한다.
- **LayeredFormula**: 하나의 수식을 `k = 0 … kCount-1`만큼 반복해 겹쳐진 폴리라인 배열로 만든다 (레이어 최대 4,000개 · 레이어당 샘플 최대 400개로 자동 클램프) — Naderi Yeganeh 스타일 "수천 개 선으로 이루어진 그림" 기법의 핵심이다.
- **FormulaFormatter**: 입력 문자열을 `pi → π`, `sqrt → √`, `* → ·` 같은 읽기 쉬운 수학 표기로 바꾼다.

새 `MathigramTests` 타깃(Swift Testing)에 렉서·파서·평가기·LayeredFormula·포매터를 검증하는 테스트 15개를 추가했고 전부 통과한다. 아직 화면에 연결되지 않은 순수 엔진 단계라 새 스크린샷은 없다 — Phase 2에서 `그리기` 탭이 이 엔진으로 실시간 렌더링을 하면 눈에 보이는 변화가 생긴다.

```bash
# Xcode에서 Cmd+U, 또는 커맨드라인에서
xcodebuild test -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 16'
```

## 요구 사항

- Xcode (iOS 27 SDK 포함)
- iPhone 16 시뮬레이터 (또는 실제 iPhone, iOS 18+)

```bash
open "Untitled Project.xcodeproj"
```

실행 대상을 **iPhone 16** 시뮬레이터로 선택하고 `Cmd + R`로 빌드·실행한다.

## 프로젝트 구조

```
MyApp/
├─ MyApp.swift, ContentView.swift      # 4탭 루트
├─ Model/                              # AppModel, RenderSettings
├─ MathEngine/                         # 수식 렉서/파서/평가기, LayeredFormula, FormulaFormatter
├─ Fourier/                            # (Phase 3) 윤곽 추출 + DFT 피팅
├─ Rendering/                          # (Phase 2) MathCanvasRenderer
├─ Persistence/                        # (Phase 4) SwiftData SavedArtwork
└─ Views/                              # DrawView, ConvertView, GalleryView, SettingsView
Docs/                                  # PRD, TASKS
Media/Screenshots/                     # README 이미지
```

## 라이선스

[Apache License 2.0](LICENSE)
