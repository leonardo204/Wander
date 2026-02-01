# Wander - 기능 개선 구현 목록 (todo.md)

> v2.1 기능 구현을 위한 작업 목록
> 기획 완료, GUI 완료, 구현 대기 상태

---

## 결정 사항 요약 (2026-02-01)

| 항목 | 결정 |
|------|------|
| 홈 화면 명칭 | "돌아보기" + 기간 선택 (이번 주/지난 주/이번 달/최근 30일) |
| 홈 화면 레이아웃 | FAB 우하단 (여행 기록하기), 2열 카드 (지금 뭐해?, 돌아보기) |
| 내보내기 이미지 | PNG, 1080x1920 고정 |
| 워터마크 | 우하단, 로고만 |
| 숨긴 기록 접근 | 기록 탭 내 "숨긴 기록" 섹션 |
| 인증 방식 | 생체인증 우선, 실패 시 4자리 PIN |
| 앱 잠금 | 숨긴 기록만 보호 (앱 전체 잠금 없음) |
| 사용자 장소 | 기본(집, 회사/학교) + 사용자 정의 (최대 5개) |
| 카테고리 | 기본 4개 숨기기 가능 + 사용자 정의 추가 가능 |

---

## Phase 1: 홈 화면 & 네비게이션 개선

### 1.1 홈 화면 FAB 도입 ✅
- **파일**: `src/Views/Home/HomeView.swift`
- **GUI**: `wander_home_screen_with_fab/screen.png`
- **작업 내용**:
  - [x] 기존 "여행 기록 만들기" 큰 카드 제거
  - [x] FAB 컴포넌트 추가 (우하단, 56pt, Primary 색상)
  - [x] FAB 탭 시 PhotoSelectionView 표시
  - [x] 퀵 액션 카드 2열 레이아웃으로 변경

### 1.2 "돌아보기" 기능 구현 ✅
- **파일**: `src/Views/Home/LookbackView.swift` (신규)
- **GUI**: `lookback_selection_screen/screen.png`
- **작업 내용**:
  - [x] 기간 선택 Segmented Control (이번 주/지난 주/이번 달/최근 30일)
  - [x] 기간별 사진 자동 로드 (GPS 있는 사진만)
  - [x] 사진 선택/해제 그리드
  - [x] "하이라이트 만들기" → 분석 플로우 연결

### 1.3 탭 네비게이션 개선 ✅
- **파일**: `src/ContentView.swift`
- **작업 내용**:
  - [x] 탭 클릭 시 NavigationPath 초기화 (루트로 이동)
  - [x] ~~(선택) 탭 간 스와이프 이동 검토~~ - PASS (표준 iOS UX 유지)

---

## Phase 2: 보안 & 프라이버시

### 2.1 기록 숨기기 기능 ✅
- **모델**: `src/Models/SwiftData/TravelRecord.swift`
- **뷰**: `src/Views/Records/HiddenRecordsView.swift` (신규)
- **GUI**: `hidden_travel_records_screen/screen.png`
- **작업 내용**:
  - [x] TravelRecord에 `isHidden: Bool` 필드 추가
  - [x] 기록 상세 > 더보기 메뉴에 "숨기기" 옵션 추가
  - [x] RecordsView 하단에 "숨긴 기록 (N)" 섹션 추가
  - [x] HiddenRecordsView 구현 (인증 후 표시)
  - [x] "숨김 해제" 기능 구현

### 2.2 인증 시스템 구현 ✅
- **파일**: `src/Views/Auth/PINInputView.swift` (신규)
- **파일**: `src/Services/AuthenticationManager.swift` (신규)
- **GUI**: `pin_authentication_screen/screen.png`
- **작업 내용**:
  - [x] LocalAuthentication 프레임워크 연동 (Face ID/Touch ID)
  - [x] 4자리 PIN 입력 화면 구현
  - [x] PIN 저장 (Keychain)
  - [x] 생체인증 실패 시 PIN 폴백
  - [x] 3회 실패 시 30초 잠금
  - [x] 인증 성공 후 5분간 유지

### 2.3 인증 설정 화면 ✅
- **파일**: `src/Views/Settings/SecuritySettingsView.swift` (신규)
- **작업 내용**:
  - [x] 설정 > 보안 섹션 추가
  - [x] PIN 설정/변경/삭제
  - [x] 생체인증 토글

---

## Phase 2: 사용자 정의 기능

### 2.4 카테고리 관리 ✅
- **모델**: `src/Models/SwiftData/RecordCategory.swift` (신규)
- **뷰**: `src/Views/Settings/CategoryManagementView.swift` (신규)
- **GUI**: `category_management_screen/screen.png`
- **작업 내용**:
  - [x] RecordCategory SwiftData 모델 생성
    ```swift
    @Model class RecordCategory {
        var id: UUID
        var name: String
        var icon: String  // emoji
        var color: String // hex
        var isDefault: Bool
        var isHidden: Bool
        var order: Int
    }
    ```
  - [x] 기본 카테고리 4개 시드 (여행, 일상, 주간, 출장)
  - [x] 카테고리 표시/숨기기 토글
  - [x] 사용자 카테고리 추가 (아이콘, 색상 선택)
  - [x] 사용자 카테고리 편집/삭제
  - [x] TravelRecord.recordType → RecordCategory 관계 변경

### 2.5 사용자 장소 설정 ✅
- **모델**: `src/Models/SwiftData/UserPlace.swift` (신규)
- **뷰**: `src/Views/Settings/UserPlacesView.swift` (신규)
- **GUI**: `user_places_management_screen/screen.png`
- **작업 내용**:
  - [x] UserPlace SwiftData 모델 생성
    ```swift
    @Model class UserPlace {
        var id: UUID
        var name: String
        var icon: String
        var latitude: Double
        var longitude: Double
        var address: String
        var isDefault: Bool  // 집, 회사/학교
        var order: Int
    }
    ```
  - [x] 기본 장소 (집, 회사/학교) UI
  - [x] 사용자 장소 추가 (최대 5개)
  - [x] 주소 검색 또는 현재 위치 사용
  - [x] 지도 미리보기
  - [x] 분석 시 등록 장소 매칭 (반경 100m) - 3.5에서 구현 완료

---

## Phase 2: 내보내기 개편

### 2.6 이미지 내보내기 ✅
- **파일**: `src/Services/ExportService/ExportService.swift`
- **뷰**: `src/Views/Result/ResultView.swift` (ShareSheetView)
- **GUI**: `export_options_screen_with_image_format/screen.png`
- **작업 내용**:
  - [x] 내보내기 옵션에 "이미지 (PNG)" 추가
  - [x] RecordImageGenerator 구현 (ExportService 내)
    - 1080x1920 세로형
    - 타임라인 + 통계 레이아웃
    - UIGraphicsImageRenderer 사용
  - [x] 워터마크 옵션 (우하단 로고)
  - [x] iOS 공유 시트 연동
  - [x] 텍스트/Markdown 내보내기 지원

---

## Phase 3: AI 기능 확장

### 3.1 BYOK 기능 검증 ✅
- **파일**: `src/Services/AIService/*.swift`
- **작업 내용**:
  - [x] OpenAI API 호출 구현 (GPT-4o-mini)
  - [x] Anthropic API 호출 구현 (Claude 3.5 Sonnet)
  - [x] Google Gemini API 호출 구현 (Gemini 1.5 Flash)
  - [x] API Key 저장/로드 검증 (Keychain)
  - [x] 에러 핸들링 (잘못된 키, 네트워크 오류, Rate Limit)

### 3.2 Azure OpenAI 지원 ✅
- **파일**: `src/Services/AIService/AzureOpenAIService.swift` (신규)
- **작업 내용**:
  - [x] AzureOpenAIService 구현 (AIServiceProtocol)
  - [x] Endpoint, Deployment Name, API Version 설정 UI
  - [x] AI 프로바이더 목록에 Azure 추가

---

## Phase 3: 공유 기능 개편

### 3.3 딥링크 구현 ✅
- **파일**: `src/WanderApp.swift`, `src/Info.plist`
- **작업 내용**:
  - [x] URL Scheme 등록 (wander://)
  - [x] onOpenURL 핸들러 구현
  - [x] 공유 시 딥링크 생성 기능 (ExportService)
  - [ ] 유니버셜 링크 설정 (앱스토어 출시 후)

### 3.4 공유받은 기록 보기 ✅
- **뷰**: `src/Views/Shared/SharedRecordView.swift` (신규)
- **작업 내용**:
  - [x] 딥링크로 공유 데이터 수신 (Base64 디코딩)
  - [x] 임시 뷰어 화면 구현 (지도, 타임라인, 통계)
  - [x] "내 기록으로 저장" 옵션

---

## Phase 3: 분석 고도화

### 3.5 사용자 장소 매칭 ✅
- **파일**: `src/Services/AnalysisService/AnalysisEngine.swift`
- **작업 내용**:
  - [x] 분석 시 UserPlace 좌표 매칭
  - [x] 매칭된 장소명으로 라벨링 (사용자 등록 이름 사용)
  - [x] 반경 설정 (기본 100m) - UserPlace.matchingRadius

---

## 구현 우선순위 체크리스트

### Phase 1 (단기) - 1주 ✅ 완료
- [x] 1.1 홈 화면 FAB 도입
- [x] 1.2 돌아보기 기능
- [x] 1.3 탭 네비게이션 개선

### Phase 2 (중기) - 2주 ✅ 완료
- [x] 2.1 기록 숨기기 ✅
- [x] 2.2 인증 시스템 ✅
- [x] 2.3 인증 설정 ✅
- [x] 2.4 카테고리 관리 ✅
- [x] 2.5 사용자 장소 설정 ✅
- [x] 2.6 이미지 내보내기 ✅

### Phase 3 (장기) ✅ 완료
- [x] 3.1 BYOK 검증 ✅
- [x] 3.2 Azure OpenAI ✅
- [x] 3.3 딥링크 ✅
- [x] 3.4 공유받은 기록 ✅
- [x] 3.5 분석 고도화 (사용자 장소 매칭) ✅

---

## 참조 문서

| 문서 | 용도 |
|------|------|
| `Ref-Concepts/wander_ui_scenario.md` | UI 플로우, 상세 시나리오 (v2.1) |
| `GUI/index.md` | 화면 목업 인덱스 (39개) |
| `GUI/screens/` | 화면별 PNG 목업 |
| `fix.md` | 버그 수정 목록 (완료됨) |

---

*최종 업데이트: 2026-02-01*
*상태: Phase 1 완료, Phase 2 완료, Phase 3 완료 🎉*
