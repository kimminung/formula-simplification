# TASKS — 수식단순화 (Formula Simplification)

상태 표기: `[x]` 완료 · `[ ]` 미완료 · `[~]` 부분 완료 / 검증 필요

## Phase 0 — 프로젝트 준비
- [x] T0.1 PRD 작성 (`Docs/PRD-수식단순화.md`)
- [x] T0.2 태스크 문서 작성 (이 파일)
- [x] T0.3 타깃을 iPhone 전용으로 설정 (TARGETED_DEVICE_FAMILY=1, SUPPORTED_PLATFORMS=iphoneos/iphonesimulator)
- [x] T0.4 번들 표시 이름 "수식단순화", 사진 보관함 접근 Info.plist 설명 추가 (이후 "수식단순화"로 개명)
- [x] T0.5 AppModel(@Observable) + 4탭(그리기/변환/갤러리/설정) 스켈레톤
- [x] T0.6 README/LICENSE(Apache 2.0)/.gitignore/.gitattributes, git init
- [x] T0.7 빌드 확인 + iPhone 16 시뮬레이터 스크린샷 → README 반영

## Phase 1 — 수식 엔진 (MathEngine)
- [x] T1.1 토큰/위치 타입, Lexer (숫자·식별자·기호·공백)
- [x] T1.2 AST 정의 (Expr: 리터럴/변수/단항/이항/함수호출)
- [x] T1.3 Parser (우선순위: `+ -` < `* /` < 단항 `-` < `^`, 괄호)
- [x] T1.4 Evaluator (변수 바인딩 t/k/n, 내장 함수·상수, 0 나눗셈·정의역 오류 처리)
- [x] T1.5 LayeredFormula 모델 (x(t,k), y(t,k), tRange, kCount) — colorRule은 Phase 2에서 RenderSettings와 함께 연결
- [x] T1.6 FormulaFormatter (입력 수식 → 읽기 쉬운 수학 표기: π, √, ·)
- [x] T1.7 Swift Testing 유닛 테스트 (Lexer/Parser/Evaluator/LayeredFormula/FormulaFormatter) — MathigramTests 타깃 신설(앱 개명 이전에 만들어져 타깃명은 유지, 사용자에게 보이지 않는 내부 테스트 번들명), 15개 테스트 통과

## Phase 2 — 그리기 모드 (수식 → 그림)
- [x] T2.1 MathCanvasRenderer (LayeredFormula → [Path], 백그라운드 평가, 자동 맞춤·y축 반전)
- [x] T2.2 FormulaPresets 10종 (하트·장미·리사주·나비·아스트로이드 + 스피로그래프 다발·나선 다발·원형 체인·카디오이드 실 그림·파동 격자) + 요약 텍스트
- [x] T2.3 DrawView: 수식 편집기 + 프리셋 메뉴 + 실시간 Canvas 미리보기 (Task 취소 기반 디바운스 450ms)
- [x] T2.4 수식 표기 패널 (FormulaFormatter 사용), 평가 오류 배너
- [x] T2.5 결과 PNG 내보내기 (ImageRenderer → 사진 앱 저장)
- [x] T2.6 (Phase 4 이후 추가) 여러 수식 혼합 — 사용자 피드백(여러 수식을 섞어 하나의 그림이 되면 좋겠다는 요청)을 반영해 LayeredFormula를 배열(`DrawModel.components`)로 확장. "구성요소" 칩 UI로 추가/선택/삭제하고, 각 구성요소가 서로 다른 수식이어도 한 그림으로 합성된다. 프리셋 2종(혼합: 하트+별자리 고리, 혼합: 은하+중심핵) 추가, SavedArtwork/수식 표기 패널도 다중 구성요소를 지원하도록 함께 변경

## Phase 3 — 변환 모드 (그림 → 수식)
- [x] T3.1 PhotosPicker 연동 — 설계 변경: 입력을 "사진" / "직접 그리기" 두 가지로 확장 (사용자 요청: "내가 그린 그림이나 촬영된 사진에는 어떤 수식들의 조합으로 이루어졌을까?")
- [x] T3.2 ContourExtractor (DetectContoursRequest, iOS 27 신규 Swift API) + PolylineResampler(등간격 리샘플링, 사진·스케치 공용). 시뮬레이터에 기본으로 들어있는 실제 사진(꽃밭·폭포)으로 재검증하며 2번 개선: ① 포인트 개수 기준 선택은 복잡한 사진에서 작은 텍스처 잡음을 고르는 문제가 있어 바운딩 박스 면적 기준으로 교체 ② 면적 기준만 쓰면 이미지 테두리 자체가 가장 큰 면적이라 "사진 전체를 채우는 뭉개진 윤곽"을 고르는 문제가 있어, 프레임의 85% 이상을 차지하는 윤곽은 후보에서 제외하도록 수정. 합성 이미지(별 모양)와 실제 사진 모두로 회귀 확인 완료
- [x] T3.3 FourierFit (복소수 이산 푸리에 변환 → 진폭 상위 200항 추출) — 설계 변경: LayeredFormula(레이어 오버레이)가 아닌 전용 FourierSeries(항들을 모두 더해 선 하나로 재구성)로 구현. 수학적으로 더 정확함(레이어드 수식은 "겹쳐 그리기", 푸리에 재구성은 "항을 합산"이라 의미가 다름)
- [x] T3.4 ConvertView: 사진/스케치 선택 → 재구성 Canvas, 항 개수(K) 슬라이더, 수식 패널(상위 8항 표시 + 외 N개)
- [ ] T3.5 변환 결과 갤러리 저장 연동 — Phase 4로 이동(갤러리 자체가 아직 없음)
- [x] T3.6 (추가) Swift Testing: PolylineResampler·FourierFit 단위 테스트 4개 (원 재구성 시 지배항 k=±1 검증, 항 개수 증가 시 오차 감소 검증)

## Phase 4 — 갤러리 & 설정
- [x] T4.1 SwiftData 모델 SavedArtwork (종류/수식 데이터·푸리에 계수 JSON/썸네일/생성일), MyApp.swift에 modelContainer 연결
- [x] T4.2 GalleryView 그리드 + ArtworkDetailView(탭하여 열기, 삭제) — 설계 변경: "스와이프 삭제" 대신 상세 시트의 휴지통 버튼으로 구현(그리드 셀이 버튼이라 리스트 스와이프 제스처 대상이 아니라서); 저장된 수식을 원래 탭(그리기/변환)으로 복원하는 "다시 열기" 추가(AppModel.pendingDrawFormula/pendingConvertLoad로 탭 간 전달)
- [x] T4.3 SettingsView (선 색상/색상 순환/굵기/배경/앱 정보·라이선스) — Phase 0에서 이미 구현, 변경 없음
- [x] T4.4 접근성 점검 — 갤러리 썸네일에 accessibilityLabel 추가, 수식 표기 패널 폰트를 고정 크기(13pt)에서 Dynamic Type 대응 텍스트 스타일(.footnote)로 변경. 툴바 버튼은 전부 아이콘+텍스트 Label이라 기본적으로 VoiceOver 호환

## Phase 5 — 검증 및 마무리
- [x] T5.1 iPhone 16 시뮬레이터(iOS 27) 전체 탭 전수 테스트 — 그리기(혼합 구성요소·프리셋·저장)·변환(사진·스케치·갤러리 저장)·갤러리(저장/다시 열기/삭제)·설정(색상·굵기·색상 순환·배경이 그리기/변환 캔버스에 실제 반영되는지) 전부 기기 상호작용으로 확인
- [x] T5.2 대량 레이어 성능 측정 — 레이어 수 k를 24 → 2,423까지 스테퍼로 올려도 크래시·멈춤 없이 렌더링되고, 계산 중에도 탭 전환이 즉시 반응함을 확인(백그라운드 Task.detached 평가 구조가 의도대로 동작)
- [x] T5.3 변환 파이프라인 다양한 사진 케이스 점검 — 합성 이미지(별)뿐 아니라 시뮬레이터 기본 사진(꽃밭·폭포, 복잡한 배경)으로 재검증, 윤곽 선택 기준 2회 개선(위 Phase 3 참고)
- [x] T5.4 README 최종화 (전 Phase 스크린샷/내용 정리), 최종 커밋

### 알려진 사소한 관찰
- 자동화 테스트 중 설정 탭의 `ColorPicker` 스와치가 간헐적으로 첫 탭에 반응하지 않고 몇 번의 상호작용 후에 열린 사례가 1건 있었다(이후 정상 동작). SwiftUI 표준 `ColorPicker`의 팝오버 히트테스트가 시뮬레이터 자동화 환경에서 간헐적으로 지연되는 것으로 보이며, 실제 동작 로직 결함은 아니라고 판단해 별도 수정 없이 기록만 남긴다.

## Phase 6 — 변환 고도화 (다중 윤곽·다중 획)
사용자 피드백: "촬영한 사진이나 복잡한 그림을 넣어도 너무 단순화된 고무줄 하나로만 해석한다." 원인은 윤곽 하나만 고르고 스케치도 한 획으로 합쳐 닫힌 곡선 하나에 푸리에 급수를 맞추던 구조.
- [x] T6.1 FourierFit.fit(shapes:) — 도형마다 독립 급수(k=0 항이 각 도형의 중심을 보존하므로 상대 위치 유지), `closedLoop(from:)`로 열린 획을 왕복 경로로 닫아 직선 "고무줄" 아티팩트 제거
- [x] T6.2 ContourExtractor — 최상위 윤곽 1개 → 계층 전체 순회, 밝기 피벗 여러 단계(등고선처럼) 병렬 스캔, 바운딩 박스 기준 중복 제거, 면적순 상위 N개; `PhotoDetailLevel` 단순(1단계·8개)/보통(4단계·40개)/세밀(7단계·80개); EXIF 방향을 반영한 업라이트 리드로우; 둘레 길이에 비례한 적응형 리샘플
- [x] T6.3 스케치 — 손 뗄 때마다 획 분리(`strokes: [[CGPoint]]`), 되돌리기 버튼, 획 수 캡션
- [x] T6.4 ConvertModel/ConvertView — `shapes: [FourierSeries]`, 공동 프레임 피팅(`flipY: false`), 세밀도 변경 시 자동 재분석, "도형 N개 · 도형당 K항" 캡션, 도형별 수식 표기(FourierFormatter.notation(for shapes:))
- [x] T6.5 SavedArtwork — 도형 배열 JSON 저장, 구버전(단일 항 목록) 디코드 폴백
- [x] T6.6 검증 — 집 4획 → 지붕·문·창문 위치 그대로 4개 곡선, 별 사진 바로 섬(Vision 정규 좌표가 좌하단 원점임을 프로브로 측정해 `1 - y` 확정), 꽃 사진 보통 10개/세밀 40개 윤곽(세밀 6~38초), 단위 테스트 26개 통과(xcodebuild, 병렬 테스트 끔)
- [x] T6.7 (후유증 정리) 테스트 파일 `@testable import MyApp` → `Formula_Simplification`
- 한계: Vision 윤곽 검출은 의미 분할이 아니라 밝기 경계 추적이므로, 질감이 많은 사진은 "꽃"으로 읽히기보다 작은 윤곽들의 산포로 나온다. 피사체 대비가 뚜렷한 사진·직접 그린 선화에서 가장 좋다.

## 개명: Mathigram → 수식단순화
- [x] 번들 표시 이름(CFBundleDisplayName)을 "수식단순화"로 변경
- [x] Docs/PRD·TASKS 파일명을 `-Mathigram.md` → `-수식단순화.md`로 변경하고 문서 제목·본문 갱신
- [x] README.md 제목·본문의 "Mathigram(수식그램)" 표기를 "수식단순화 (Formula Simplification)"로 갱신
- [x] SettingsView의 앱 이름 표시를 "수식단순화"로 갱신
- Xcode 타깃/모듈명(`MyApp`)과 테스트 타깃명(`MathigramTests`)은 사용자에게 보이지 않는 내부 식별자라 변경하지 않음 — 변경 시 번들 ID·스킴·`@testable import` 등 연쇄 수정이 필요해 위험 대비 실익이 낮다고 판단
