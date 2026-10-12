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
- [x] T1.1 토큰/위치 타입, Lexer (숫자·식별자·기호·공백)
- [x] T1.2 AST 정의 (Expr: 리터럴/변수/단항/이항/함수호출)
- [x] T1.3 Parser (우선순위: `+ -` < `* /` < 단항 `-` < `^`, 괄호)
- [x] T1.4 Evaluator (변수 바인딩 t/k/n, 내장 함수·상수, 0 나눗셈·정의역 오류 처리)
- [x] T1.5 LayeredFormula 모델 (x(t,k), y(t,k), tRange, kCount) — colorRule은 Phase 2에서 RenderSettings와 함께 연결
- [x] T1.6 FormulaFormatter (입력 수식 → 읽기 쉬운 수학 표기: π, √, ·)
- [x] T1.7 Swift Testing 유닛 테스트 (Lexer/Parser/Evaluator/LayeredFormula/FormulaFormatter) — MathigramTests 타깃 신설, 15개 테스트 통과

## Phase 2 — 그리기 모드 (수식 → 그림)
- [x] T2.1 MathCanvasRenderer (LayeredFormula → [Path], 백그라운드 평가, 자동 맞춤·y축 반전)
- [x] T2.2 FormulaPresets 10종 (하트·장미·리사주·나비·아스트로이드 + 스피로그래프 다발·나선 다발·원형 체인·카디오이드 실 그림·파동 격자) + 요약 텍스트
- [x] T2.3 DrawView: 수식 편집기 + 프리셋 메뉴 + 실시간 Canvas 미리보기 (Task 취소 기반 디바운스 450ms)
- [x] T2.4 수식 표기 패널 (FormulaFormatter 사용), 평가 오류 배너
- [x] T2.5 결과 PNG 내보내기 (ImageRenderer → 사진 앱 저장)
- [x] T2.6 (Phase 4 이후 추가) 여러 수식 혼합 — 사용자 피드백 "Hamid Naderi Yeganeh처럼 여러 수식을 섞어 하나의 그림이 되면 됩니다"를 반영해 LayeredFormula를 배열(`DrawModel.components`)로 확장. "구성요소" 칩 UI로 추가/선택/삭제하고, 각 구성요소가 서로 다른 수식이어도 한 그림으로 합성된다. 프리셋 2종(혼합: 하트+별자리 고리, 혼합: 은하+중심핵) 추가, SavedArtwork/수식 표기 패널도 다중 구성요소를 지원하도록 함께 변경

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
- [ ] T5.1 iPhone 16 시뮬레이터(iOS 27) 전체 탭 전수 테스트
- [ ] T5.2 대량 레이어(4,000×400) 성능 측정, 끊김 여부 확인
- [ ] T5.3 변환 파이프라인 다양한 사진(저대비/복잡한 배경) 케이스 점검
- [ ] T5.4 README 최종화 (전 Phase 스크린샷/내용 정리), 최종 커밋
