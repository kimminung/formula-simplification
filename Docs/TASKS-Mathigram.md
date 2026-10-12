# TASKS — Mathigram (수식그램)

상태 표기: `[x]` 완료 · `[ ]` 미완료 · `[~]` 부분 완료 / 검증 필요

## Phase 0 — 프로젝트 준비
- [x] T0.1 PRD 작성 (`Docs/PRD-Mathigram.md`)
- [x] T0.2 태스크 문서 작성 (이 파일)
- [x] T0.3 타깃을 iPhone 전용으로 설정 (TARGETED_DEVICE_FAMILY=1, SUPPORTED_PLATFORMS=iphoneos/iphonesimulator)
- [x] T0.4 번들 표시 이름 "Mathigram", 사진 보관함 접근 Info.plist 설명 추가
- [x] T0.5 AppModel(@Observable) + 4탭(그리기/변환/갤러리/설정) 스켈레톤
- [x] T0.6 README/LICENSE(Apache 2.0)/.gitignore/.gitattributes, git init
- [x] T0.7 빌드 확인 + iPhone 16 시뮬레이터 스크린샷 → README 반영

## Phase 1 — 수식 엔진 (MathEngine)
- [ ] T1.1 토큰/위치 타입, Lexer (숫자·식별자·기호·공백)
- [ ] T1.2 AST 정의 (Expr: 리터럴/변수/단항/이항/함수호출)
- [ ] T1.3 Parser (우선순위: `+ -` < `* /` < 단항 `-` < `^`, 괄호)
- [ ] T1.4 Evaluator (변수 바인딩 t/k/n, 내장 함수·상수, 0 나눗셈·정의역 오류 처리)
- [ ] T1.5 LayeredFormula 모델 (x(t,k), y(t,k), tRange, kCount, colorRule)
- [ ] T1.6 FormulaFormatter (입력 수식 → 읽기 쉬운 수학 표기: π, 위/아래 첨자)
- [ ] T1.7 Swift Testing 유닛 테스트 (Lexer/Parser/Evaluator/LayeredFormula)

## Phase 2 — 그리기 모드 (수식 → 그림)
- [ ] T2.1 MathCanvasRenderer (LayeredFormula → [Path], 백그라운드 평가)
- [ ] T2.2 FormulaPresets 10종 이상 (하트/장미/리사주/나비/스피로그래프/나선 다발 등) + 요약 텍스트
- [ ] T2.3 DrawView: 수식 편집기 + 프리셋 메뉴 + 실시간 Canvas 미리보기 (디바운스 450ms)
- [ ] T2.4 수식 표기 패널 (FormulaFormatter 사용), 평가 오류 배너
- [ ] T2.5 결과 PNG 내보내기 (사진 앱 저장)

## Phase 3 — 변환 모드 (그림 → 수식)
- [ ] T3.1 PhotosPicker 연동, 선택 이미지 전처리(리사이즈/그레이스케일)
- [ ] T3.2 ContourExtractor (VNDetectContoursRequest, 최장 윤곽 선택, 등간격 리샘플링)
- [ ] T3.3 FourierFit (복소수 DFT → 진폭 상위 K항 추출 → LayeredFormula 변환)
- [ ] T3.4 ConvertView: 원본/재구성 비교, 항 개수(K) 슬라이더, 수식 패널(상위 8항 표시)
- [ ] T3.5 변환 결과 갤러리 저장 연동

## Phase 4 — 갤러리 & 설정
- [ ] T4.1 SwiftData 모델 SavedArtwork (종류/수식 데이터/썸네일/생성일)
- [ ] T4.2 GalleryView 그리드, 탭하여 열기, 스와이프 삭제
- [ ] T4.3 SettingsView (선 색상/색상 순환/굵기/배경/앱 정보·라이선스)
- [ ] T4.4 접근성 점검 (Dynamic Type, accessibilityLabel)

## Phase 5 — 검증 및 마무리
- [ ] T5.1 iPhone 16 시뮬레이터(iOS 27) 전체 탭 전수 테스트
- [ ] T5.2 대량 레이어(4,000×400) 성능 측정, 끊김 여부 확인
- [ ] T5.3 변환 파이프라인 다양한 사진(저대비/복잡한 배경) 케이스 점검
- [ ] T5.4 README 최종화 (전 Phase 스크린샷/내용 정리), 최종 커밋
