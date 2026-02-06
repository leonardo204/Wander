# Wander - Claude Code 개발 가이드

## 프로젝트 개요

**Wander**는 여행 사진의 메타데이터(GPS, 시간)를 분석하여 자동으로 타임라인과 스토리를 생성하는 iOS 앱입니다.

### 핵심 특징
- **서버리스**: 로그인/회원가입 없음, 100% On-Device
- **Google OAuth**: Google 계정으로 Gemini AI 사용 (API Key 직접 입력 UI 제거)
- **3탭 네비게이션**: 홈, 기록, 설정
- **Premium 예정**: 현재 무료, Wander Premium 구독 모델 준비 중

---

## 기술 스택

| 항목 | 선택 |
|------|------|
| iOS 최소 버전 | **iOS 17+** |
| UI 프레임워크 | **SwiftUI Only** |
| 데이터 저장 | **SwiftData** |
| 아키텍처 | **MVVM** |
| 테마 | **Light Mode Only** |

### 필수 프레임워크
```swift
import SwiftUI
import SwiftData
import PhotosUI      // 사진 선택
import Photos        // PhotoKit 메타데이터
import CoreLocation  // GPS, CLGeocoder
import MapKit        // 지도
import Security      // Keychain (API Key 저장)
import LocalAuthentication // Face ID/Touch ID
```

---

## 프로젝트 정보

| 항목 | 값 |
|------|-----|
| 프로젝트 위치 | `/Volumes/MiniExt/main_work/75_AI/Wander/` |
| 소스 코드 | `src/` |
| Bundle ID | `com.zerolive.wander` |
| 프로젝트명 | `Wander` |
| GitHub | https://github.com/leonardo204/Wander |

---

## 폴더 구조

```
Wander/
├── CLAUDE.local.md              ← 이 파일 (개발 가이드)
├── README.md                    ← GitHub README
├── .gitignore
│
├── src/                         ← 소스 코드 (Xcode 프로젝트)
│   ├── WanderApp.swift
│   ├── ContentView.swift
│   ├── project.yml              ← xcodegen 설정
│   ├── Wander.xcodeproj/
│   │
│   ├── Core/
│   │   ├── Design/
│   │   │   ├── WanderColors.swift
│   │   │   ├── WanderTypography.swift
│   │   │   └── WanderSpacing.swift
│   │   └── Utilities/
│   │       ├── KeychainManager.swift
│   │       └── DeepLinkHandler.swift   ← P2P 공유 딥링크 처리
│   │
│   ├── Models/SwiftData/
│   │   ├── TravelRecord.swift
│   │   ├── TravelDay.swift
│   │   ├── Place.swift
│   │   ├── PhotoItem.swift
│   │   ├── RecordCategory.swift
│   │   └── UserPlace.swift
│   │
│   ├── Services/
│   │   ├── AIService/
│   │   │   ├── AIServiceProtocol.swift
│   │   │   ├── OpenAIService.swift
│   │   │   ├── AnthropicService.swift
│   │   │   ├── GoogleAIService.swift
│   │   │   ├── AzureOpenAIService.swift
│   │   │   ├── AIEnhancementModels.swift   ← AI 다듬기 입출력 모델
│   │   │   └── AIEnhancementService.swift  ← AI 다듬기 오케스트레이터
│   │   ├── AnalysisService/
│   │   │   ├── AnalysisEngine.swift
│   │   │   ├── ClusteringService.swift
│   │   │   └── ActivityInferenceService.swift
│   │   ├── SmartAnalysis/           ← Wander Intelligence
│   │   │   ├── SmartAnalysisCoordinator.swift
│   │   │   ├── VisionAnalysisService.swift
│   │   │   ├── FastVLMService.swift
│   │   │   ├── POIService.swift
│   │   │   ├── TravelDNAService.swift
│   │   │   ├── MomentScoreService.swift
│   │   │   ├── StoryWeavingService.swift
│   │   │   └── InsightEngine.swift
│   │   ├── ExportService/
│   │   │   └── ExportService.swift
│   │   ├── ShareService/            ← SNS 공유 서비스
│   │   │   ├── ShareModels.swift
│   │   │   ├── ShareService.swift
│   │   │   └── ShareImageGenerator.swift
│   │   ├── LocationService/
│   │   │   └── GeocodingService.swift
│   │   ├── P2PShare/                    ← P2P 기록 공유 (신규)
│   │   │   ├── P2PShareModels.swift
│   │   │   ├── P2PShareService.swift
│   │   │   ├── CloudKitManager.swift
│   │   │   └── EncryptionService.swift
│   │   └── AuthenticationManager.swift
│   │
│   ├── ViewModels/
│   │   └── PhotoSelection/
│   │       └── PhotoSelectionViewModel.swift
│   │
│   ├── Views/
│   │   ├── Launch/SplashView.swift
│   │   ├── Onboarding/
│   │   │   ├── OnboardingContainerView.swift
│   │   │   ├── OnboardingIntroView.swift
│   │   │   ├── OnboardingPhotoView.swift
│   │   │   └── OnboardingLocationView.swift
│   │   ├── Shared/
│   │   │   └── CustomTabBar.swift       ← 커스텀 하단 탭바
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   └── LookbackView.swift
│   │   ├── PhotoSelection/
│   │   │   ├── PhotoSelectionView.swift
│   │   │   └── CustomPhotoPicker/   ← 커스텀 사진 피커
│   │   │       ├── CustomPhotoPickerView.swift
│   │   │       ├── PhotoPickerWithAnalysis.swift
│   │   │       ├── PhotoAssetManager.swift
│   │   │       └── PhotoGridView.swift
│   │   ├── Analysis/AnalyzingView.swift
│   │   ├── Result/
│   │   │   ├── ResultView.swift
│   │   │   ├── MapDetailView.swift
│   │   │   └── AIStoryView.swift
│   │   ├── Records/
│   │   │   ├── RecordsView.swift
│   │   │   └── HiddenRecordsView.swift
│   │   ├── QuickMode/QuickModeView.swift
│   │   ├── Weekly/WeeklyHighlightView.swift
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift
│   │   │   ├── SecuritySettingsView.swift
│   │   │   ├── CategoryManagementView.swift
│   │   │   └── UserPlacesView.swift
│   │   ├── Share/                   ← SNS 공유 UI (신규)
│   │   │   ├── ShareFlowView.swift
│   │   │   ├── ShareOptionsView.swift
│   │   │   ├── SharePreviewEditorView.swift
│   │   │   └── Components/
│   │   │       └── GlassPanelView.swift
│   │   ├── P2PShare/                   ← P2P 공유 UI (신규)
│   │   │   ├── P2PShareOptionsView.swift
│   │   │   ├── P2PShareCompleteView.swift
│   │   │   └── P2PShareReceiveView.swift
│   │   ├── Auth/PINInputView.swift
│   │   └── Shared/
│   │       ├── SharedRecordView.swift
│   │       └── SharedBadgeView.swift    ← 공유 배지
│   │
│   ├── Resources/
│   │   └── Assets.xcassets/
│   │       └── AppIcon.appiconset/
│   │           ├── AppIcon.png      ← 앱 아이콘 (1024x1024)
│   │           └── Contents.json
│   └── Preview Content/
│
├── Ref-Concepts/                ← 기획/디자인 문서
│   ├── wander_planning_report.md
│   ├── wander_ui_scenario.md
│   └── wander_design_concept.md
│
├── GUI/                         ← UI 목업 (개발 참조용)
│   ├── index.md
│   ├── screens/
│   └── prompts/
│
└── Ref-docs/                    ← 기술 문서
    └── wander_intelligence_algorithm.md  ← 분석 알고리즘 문서
```

---

## 주요 기능

### 핵심 기능
| 기능 | 설명 | 관련 파일 |
|------|------|----------|
| 사진 분석 | GPS/시간 메타데이터 기반 타임라인 생성 | `AnalysisEngine.swift` |
| 장소 클러스터링 | 거리/시간 기반 장소 그룹핑 | `ClusteringService.swift` |
| 역지오코딩 | 좌표 → 주소 변환 | `GeocodingService.swift` |
| 활동 추론 | 규칙 기반 활동 타입 추론 | `ActivityInferenceService.swift` |
| AI 스토리 | BYOK AI로 여행 스토리 생성 | `AIStoryView.swift` |
| AI 다듬기 | 규칙 기반 분석 텍스트를 AI로 자연스럽게 다듬기 | `AIEnhancementService.swift` |
| SNS 공유 | 일반 공유, 글래스모피즘 템플릿 | `ShareService/`, `Views/Share/` |
| P2P 공유 | CloudKit 기반 여행 기록 공유 | `P2PShare/`, `Views/P2PShare/` |
| 내보내기 | 이미지/Markdown 내보내기 | `ExportService.swift` |

### Wander Intelligence (스마트 분석)
| 서비스 | 설명 | iOS 요구사항 |
|--------|------|-------------|
| `SmartAnalysisCoordinator` | 스마트 분석 오케스트레이터 | iOS 17+ |
| `VisionAnalysisService` | 장면 분류 (Vision Framework) | iOS 17+ |
| `FastVLMService` | 온디바이스 VLM 분석 | iOS 18.2+ |
| `POIService` | 주변 핫스팟 검색 (MapKit) | iOS 17+ |
| `TravelDNAService` | 여행자 성향 분석 | iOS 17+ |
| `MomentScoreService` | 순간 점수/등급 계산 | iOS 17+ |
| `StoryWeavingService` | AI 스토리 생성 | iOS 17+ |
| `InsightEngine` | 인사이트 발견 | iOS 17+ |

> 📄 상세 알고리즘: `Ref-docs/wander_intelligence_algorithm.md`

### AI 다듬기 기능
규칙 기반 스마트 분석(80%) 결과의 텍스트를 BYOK AI로 자연스럽게 다듬어 100% 완성도를 달성합니다.

| 항목 | 설명 |
|------|------|
| 트리거 | 사용자가 "AI로 다듬기" 버튼 클릭 (분석 완료 화면 + 기록 상세 화면) |
| API 호출 | 단일 호출로 모든 텍스트 산출물 처리 (maxTokens: 4096) |
| 대상 | 제목, 스토리(오프닝/챕터/클라이맥스/엔딩/태그라인), 인사이트, TravelDNA 설명, 여행 점수 요약, 순간 하이라이트 |
| 원칙 | 팩트(장소명, 시간, 거리) 변경 금지, 새로운 사실 생성 금지 |
| 부분 실패 | 모든 필드 Optional → AI가 누락한 필드는 원본 유지 |
| 프라이버시 | 장소명/시간 정보만 전송, 사진 미전송 |

**관련 파일:**
| 파일 | 역할 |
|------|------|
| `AIEnhancementModels.swift` | 입출력 데이터 모델 (AIEnhancementInput, AIEnhancementResult) |
| `AIEnhancementService.swift` | 오케스트레이터 (buildInput → 프롬프트 → AI 호출 → JSON 파싱 → 머지) |
| `AIServiceProtocol.swift` | `generateContent` 범용 메서드 (4개 프로바이더 공통) |

**데이터 구조 주의사항:**
- `TravelDNA.description`은 computed property → `aiEnhancedDNADescription` 오버레이 필드 사용
- `TravelStory`, `TravelInsight`, `MomentScore`, `TripOverallScore` 모두 `let` 필드 → 머지 시 새 인스턴스 생성 필요
- `TravelInsight`만 커스텀 init 있음 (relatedData 처리)

### 부가 기능
| 기능 | 설명 | 관련 파일 |
|------|------|----------|
| 지금 뭐해? | 오늘 촬영 사진 퀵 분석 | `QuickModeView.swift` |
| 주간 하이라이트 | 이번 주 사진 자동 요약 | `WeeklyHighlightView.swift` |
| 지난 추억 | N년 전 오늘 기록 보기 | `LookbackView.swift` |
| 보안 잠금 | PIN/Face ID 앱 잠금 | `AuthenticationManager.swift` |
| 카테고리 관리 | 기록 분류 (여행/일상/출장) | `CategoryManagementView.swift` |
| 자주 가는 곳 | 사용자 정의 장소 | `UserPlacesView.swift` |

---

## SNS 공유 기능

### 공유 플로우
```
ResultView/RecordsView
  └→ ShareFlowView (sheet)
       ├── Step 1: 공유 대상 선택 (ShareOptionsView)
       │   └── 일반 이미지 공유 (메시지, 카카오톡, 저장 등)
       │
       ├── Step 2: 편집 (ShareEditOptionsView)
       │   ├── 템플릿 스타일 선택
       │   ├── 사진 선택/순서 변경
       │   ├── 캡션 입력
       │   └── 해시태그 입력/추천
       │
       └── Step 3: 최종 미리보기 (ShareFinalPreviewView)
            ├── 생성된 이미지 미리보기
            ├── 핀치 투 줌 확대
            └── 공유 실행
```

### 템플릿 스타일
| 스타일 | 설명 | 레이아웃 |
|--------|------|----------|
| Modern Glass | 글래스모피즘 오버레이 | 사진 배경 + 반투명 정보 패널 |
| Polaroid | 폴라로이드 그리드 | 최대 3장, 회전 배치 |
| Clean Minimal | 미니멀 디자인 | 사진 그리드 + 하단 정보 |

### 이미지 사이즈
| 용도 | 사이즈 | 비율 |
|------|--------|------|
| 일반 공유 | 1080 × 1350 | 4:5 |

### 공유 이미지 구성요소
- 제목 (42pt)
- 날짜 범위 (33pt)
- 통계: 장소 수, 이동거리 (36pt)
- 캡션 (30pt, 최대 2줄)
- 해시태그 (27pt)
- 워터마크: 앱 아이콘 + "Wander" (36pt 아이콘, 24pt 텍스트)

### 관련 파일
| 파일 | 역할 |
|------|------|
| `ShareModels.swift` | 공유 모델/프로토콜/에러 정의 |
| `ShareService.swift` | 공유 서비스 총괄 |
| `ShareImageGenerator.swift` | 템플릿별 이미지 렌더링 |
| `ShareFlowView.swift` | 공유 플로우 컨테이너 + ViewModel |
| `ShareOptionsView.swift` | Step 1: 공유 대상 선택 |
| `ShareEditOptionsView.swift` | Step 2: 편집 화면 |
| `ShareFinalPreviewView.swift` | Step 3: 미리보기 + 줌 뷰어 |

---

## AI 서비스

### Google OAuth (현재 사용)
- `GoogleOAuthService.swift`: NWListener 로컬 HTTP 서버 방식
- Cloud Code Assist API: `cloudcode-pa.googleapis.com/v1internal` 엔드포인트
- Keychain 저장: access_token, refresh_token, token_expiry, project_id
- gemini-2.5-flash 사용 (사고 토큰이 maxOutputTokens 소비 → 4배 보정)

### AI 다듬기
- `AIEnhancementService.swift`: 온디바이스 분석 결과를 AI로 고도화
- 멀티모달: 대표 사진 전송 (320×320, JPEG 0.6, 최대 8장)
- 팩트:감성 7:3 비율, 1~2문장
- corrections: AI가 activityType/sceneCategory 오류 보정

### 레거시 BYOK 프로바이더
> ⚠️ API Key 직접 입력 UI는 v3.0에서 제거. 코드 잔류 (향후 정리 대상)

| 프로바이더 | 서비스 파일 |
|-----------|------------|
| OpenAI | `OpenAIService.swift` |
| Anthropic | `AnthropicService.swift` |
| Google | `GoogleAIService.swift` |
| Azure OpenAI | `AzureOpenAIService.swift` |

---

## 디자인 시스템

> 📄 **상세 디자인 가이드**: `Ref-Concepts/ui-scenarios/design-concept.md`

### 디자인 토큰 사용 규칙

모든 UI 컴포넌트는 **반드시** 디자인 토큰을 사용해야 합니다:

```swift
// ❌ 하드코딩 금지
.background(Color(.systemGray6))
.font(.headline)
.padding(16)

// ✅ 디자인 토큰 사용
.background(WanderColors.surface)
.font(WanderTypography.headline)
.padding(WanderSpacing.space4)
```

### 컬러 토큰 (`WanderColors`)
| 토큰 | Hex | 용도 |
|-----|-----|------|
| `primary` | #87CEEB | 브랜드 컬러, Primary 버튼 |
| `primaryPale` | #E8F6FC | 배경 틴트 |
| `surface` | #F8FBFD | 카드/섹션 배경 (systemGray6 대신 사용) |
| `border` | #E5EEF2 | 테두리, 구분선 |
| `textPrimary` | #1A2B33 | 주요 텍스트 |
| `textSecondary` | #5A6B73 | 보조 텍스트 |
| `textTertiary` | #8A9BA3 | 힌트, 비활성 |
| `success` | #4CAF50 | 성공 상태 |
| `successBackground` | #E8F5E9 | 성공 배경 |
| `warning` | #FF9800 | 경고 상태 |
| `warningBackground` | #FFF3E0 | 경고 배경 |
| `error` | #F44336 | 에러 상태 |
| `errorBackground` | #FFEBEE | 에러 배경 |

### 타이포그래피 토큰 (`WanderTypography`)
| 토큰 | 크기 | Weight | 용도 |
|-----|------|--------|------|
| `display` | 34pt | Bold | 대형 타이틀 |
| `title1` | 28pt | Bold | 페이지 타이틀 |
| `title2` | 22pt | Bold | 섹션 타이틀 |
| `title3` | 20pt | Semibold | 카드 타이틀 |
| `headline` | 17pt | Semibold | 강조 텍스트, 버튼 |
| `body` | 17pt | Regular | 본문 |
| `bodySmall` | 15pt | Regular | 보조 본문 |
| `caption1` | 13pt | Regular | 캡션, 라벨 |
| `caption2` | 12pt | Regular | 작은 캡션 |

### 간격 토큰 (`WanderSpacing`)
| 토큰 | 값 | 용도 |
|-----|-----|------|
| `space1` | 4pt | 아이콘-텍스트 간격 |
| `space2` | 8pt | 인라인 요소 간격 |
| `space3` | 12pt | 작은 요소 간격 |
| `space4` | 16pt | 기본 패딩 |
| `space6` | 24pt | 섹션 내부 패딩 |
| `space7` | 32pt | 섹션 간 간격 |
| `buttonHeight` | 52pt | 버튼 높이 |
| `radiusMedium` | 8pt | 버튼, 입력 필드 |
| `radiusLarge` | 12pt | 카드, 썸네일 |
| `radiusXL` | 16pt | 모달, 시트 |

### 버튼 스타일
```swift
// Primary Button (52pt 높이)
Button { } label: {
    Text("버튼 텍스트")
        .font(WanderTypography.headline)
        .frame(maxWidth: .infinity)
        .frame(height: WanderSpacing.buttonHeight)
        .background(WanderColors.primary)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
}

// Secondary Button (테두리 스타일)
Button { } label: {
    Text("버튼 텍스트")
        .font(WanderTypography.headline)
        .frame(maxWidth: .infinity)
        .frame(height: WanderSpacing.buttonHeight)
        .background(WanderColors.surface)
        .foregroundStyle(WanderColors.textPrimary)
        .overlay(
            RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge)
                .stroke(WanderColors.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: WanderSpacing.radiusLarge))
}
```

### 탭바 구조
```
┌─────────────────────────────────────┐
│   🏠          📚          ⚙️        │
│   홈          기록        설정       │
└─────────────────────────────────────┘
```

### 앱 아이콘
```
┌─────────────────┐
│░░░░░░✦░░░░░░░░░░│  ← AI 스파클
│░░░  ╲    ╱  ░░░░│
│░░░   ╲╱╲╱   ░░░░│  ← W 심볼 (여행 경로)
│░░░░░░░░░░░░░░░░░│
└─────────────────┘
```

| 항목 | 값 |
|------|-----|
| 사이즈 | 1024x1024 (iOS 17+ Universal) |
| 배경 | Sky Blue 그라데이션 (#5DADE2 → #87CEEB) |
| 심볼 | W (여행 경로) + ✦ (AI 스파클) |
| 파일 위치 | `src/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png` |
| 프롬프트 | `GUI/prompts/wander_ai_prompts5.md` |
| 원본 HTML | `GUI/screens/wander_app_icon_C4/icon_only.html` |

---

## 데이터 모델 (SwiftData)

```swift
@Model class TravelRecord {
    var title: String
    var startDate: Date
    var endDate: Date
    var days: [TravelDay]
    var totalDistance: Double
    var aiStory: String?
    var category: RecordCategory?
    var isHidden: Bool
}

@Model class TravelDay {
    var date: Date
    var dayNumber: Int
    var places: [Place]
}

@Model class Place {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var startTime: Date
    var activityLabel: String
    var photos: [PhotoItem]
}
```

---

## 커밋 컨벤션

```
[타입] 간단한 설명

타입:
- [Init] 초기 설정
- [Feature] 새 기능
- [UI] UI 작업
- [Fix] 버그 수정
- [Refactor] 리팩토링
- [Docs] 문서
```

---

## 주석 컨벤션 (LLM 친화적)

코드 주석은 **다음 수정 시 Claude가 빠르게 이해할 수 있도록** 작성합니다.

### 주석 원칙
1. **WHY 중심**: 무엇을 하는지보다 **왜** 그렇게 하는지 설명
2. **Context 제공**: 관련 파일, 연동 포인트, 의존성 명시
3. **Edge Case 설명**: 특이 케이스나 주의사항 기록
4. **TODO 명확화**: 미완성 부분은 `// TODO:` 로 명시

### 주석 패턴

```swift
// MARK: - 섹션명 (파일 구조 파악용)

/// 함수/변수 설명 (DocString 형식)
/// - Parameter name: 파라미터 설명
/// - Returns: 반환값 설명

// NOTE: 특별한 설계 결정 이유 설명
// 예: "sheet(item:) 사용 - isPresented 방식은 타이밍 이슈 발생"

// IMPORTANT: 수정 시 주의사항
// 예: "이 값 변경 시 CustomTabBar.swift도 함께 수정 필요"

// TODO: 미구현 또는 개선 필요 사항
// 예: "// TODO: 오프라인 모드 지원 추가"

// FIXME: 알려진 버그 또는 임시 해결책
// 예: "// FIXME: iOS 18에서 간헐적 크래시 - 원인 조사 필요"

// 연동 포인트 표시
// Related: ContentView.swift (탭 상태), CustomTabBar.swift (UI)
```

### 복잡한 로직 주석 예시

```swift
/// 탭 선택 처리
/// - 같은 탭 재선택 시: 해당 탭의 루트 뷰로 리셋
/// - 다른 탭 선택 시: 해당 탭으로 전환
/// - Related: CustomTabBar.swift (탭바 UI), HomeView.swift (홈 탭 상태)
func selectTab(_ tab: TabItem) {
    if selectedTab == tab {
        // NOTE: 같은 탭 재클릭 = 초기 상태로 리셋
        // 각 탭의 NavigationStack path를 초기화해야 함
        resetTabToRoot(tab)
    } else {
        selectedTab = tab
    }
}
```

---

## 로깅 컨벤션

```swift
import os.log
private let logger = Logger(subsystem: "com.zerolive.wander", category: "CategoryName")

// 이모지 컨벤션
🚀 앱 시작    🏠 홈 화면    📷 사진 관련    📍 위치/클러스터링
🗺️ 지도      🔬 분석      ✨ AI 스토리    ⚙️ 설정
✅ 성공      ❌ 에러      ⚠️ 경고        💾 저장
```

---

## 사진 선택 → 분석 흐름

```
HomeView
  └→ PhotoPickerWithAnalysis (sheet)
       └→ CustomPhotoPickerView (커스텀 피커)
            │   - 날짜 필터 (오늘/이번주/이번달/3개월/전체)
            │   - Swipe drag 다중 선택
            │   - PhotoAssetManager로 PHAsset fetch
            └→ AnalyzingViewWrapper (fullScreenCover, item 기반)
                 └→ AnalyzingView
                      └→ AnalysisEngine.analyze()
                           └→ ResultView (저장/공유)
```

### 핵심 컴포넌트
| 컴포넌트 | 역할 |
|---------|------|
| `PhotoPickerWithAnalysis` | 피커 + 분석 연결 컨테이너 |
| `CustomPhotoPickerView` | 날짜 필터링 커스텀 피커 UI |
| `PhotoAssetManager` | PHAsset fetch/캐싱 관리 |
| `SelectedPhotosWrapper` | fullScreenCover(item:)용 래퍼 |
| `AnalyzingViewWrapper` | PHAsset → ViewModel 변환 래퍼 |

---

## 유용한 명령어

```bash
# Xcode 프로젝트 재생성
cd src && xcodegen generate

# UI 목업 확인
open GUI/screens/SCR-005_home_empty/screen.png

# UI 시나리오 문서 인덱스
open Ref-Concepts/ui-scenarios/index.md
```

---

## xcodegen 주의사항

### DEVELOPMENT_TEAM 설정 유지
`project.yml`의 `DEVELOPMENT_TEAM` 설정을 **절대 삭제하지 말 것**:

```yaml
settings:
  base:
    DEVELOPMENT_TEAM: "XU8HS9JUTS"  # 삭제 금지!
```

- 이 설정이 없으면 Signing & Capabilities에서 TEAM이 사라짐
- 빌드/배포 시 코드 서명 오류 발생

---

## 구현 완료 상태

- ✅ Phase 1: 기본 구조 (앱 구조, 온보딩, 권한)
- ✅ Phase 2: 핵심 기능 (사진 분석, 타임라인, 지도)
- ✅ Phase 3: 부가 기능 (공유, 내보내기, 퀵모드)
- ✅ Phase 4: AI 기능 (BYOK, 스토리 생성)
- ✅ Phase 5: Wander Intelligence (스마트 분석, iOS 17+)
- ✅ 추가 기능: 보안 잠금, 카테고리, 숨김 기록, 자주 가는 곳
- ✅ Phase 6: P2P 공유 (CloudKit, 암호화, Deep Link)
- ✅ Phase 7: AI 다듬기 (Google OAuth + 멀티모달, 스마트 분석 텍스트 고도화)
- ✅ Phase 8: 설정 개편 (API Key → Premium UI, 공유 설정 제거, UI 시나리오 문서 분리)

---

## 개발 주의사항

### SwiftUI fullScreenCover 주의
`fullScreenCover(isPresented:)` 대신 `fullScreenCover(item:)`을 사용해야 합니다:
```swift
// ❌ 문제: 클로저가 미리 평가되어 빈 데이터로 초기화될 수 있음
.fullScreenCover(isPresented: $showAnalysis) {
    AnalyzingViewWrapper(selectedAssets: selectedAssets, ...)
}

// ✅ 해결: item이 설정된 시점에만 뷰 생성
.fullScreenCover(item: $selectedPhotosWrapper) { wrapper in
    AnalyzingViewWrapper(selectedAssets: wrapper.assets, ...)
}
```

### PHImageManager 콜백 주의
`deliveryMode: .opportunistic`은 콜백을 **두 번** 호출할 수 있어 `withCheckedContinuation` 크래시 유발:
```swift
// ❌ 크래시 위험
options.deliveryMode = .opportunistic

// ✅ 안전: 한 번만 호출
options.deliveryMode = .fastFormat
```

### 삭제된 파일 (레거시)
- ~~`DKImagePickerView.swift`~~ → `CustomPhotoPickerView.swift`로 대체
- ~~`DKImagePickerRepresentable.swift`~~ → 삭제됨
- ~~`DKImagePickerController` 패키지~~ → 제거됨

---

## 수정 이력

| 날짜 | 내용 |
|------|------|
| 2026-02-06 | 공유 설정(ShareSettingsView) 제거 - 설정 탭에서 불필요한 공유 옵션 삭제 |
| 2026-02-06 | UI 시나리오 문서 탭별 분리 (20개 파일 → `Ref-Concepts/ui-scenarios/`) |
| 2026-02-06 | 설정 UI 개편: API Key → Wander Premium 플레이스홀더, 개인정보 문구 수정 |
| 2026-02-06 | AI 다듬기 기능 구현 (AIEnhancementService, 4개 프로바이더 generateContent, ResultView + RecordDetailFullView 지원) |
| 2026-02-06 | ResultView에서 이미지 공유/Wander 공유 버튼 제거 (분석 완료 화면 정리) |
| 2026-02-06 | RecordDetailFullView에 AI 다듬기 버튼 및 Sheet 추가 |
| 2026-02-06 | AnalysisResult/TravelRecord에 AI 상태 필드 추가 (isAIEnhanced, aiEnhancedDNADescription 등) |
| 2026-02-05 | P2P 공유 기간 옵션에 '3분' 추가 (테스트용 짧은 만료 시간) |
| 2026-02-05 | 공유 배지 분리: "공유됨" + "D-day" 두 개 배지 (ShareStatusBadgesView, ExpirationBadgeView) |
| 2026-02-05 | 만료된 공유 기록 클릭 시 즉시 삭제 기능 (ExpiredRecordPlaceholder) |
| 2026-02-05 | P2P 공유 기록 만료 시 자동 삭제 기능 추가 (shareExpiresAt 필드, cleanupExpiredSharedRecords) |
| 2026-02-05 | 공유 배지 D-day 표시 기능 (영구: 보라색, 여유: 청록색, 곧 만료: 주황색, 오늘/만료: 빨강색) |
| 2026-02-05 | ShareExpirationStatus enum 추가 (notShared, permanent, normal, soon, today, expired) |
| 2026-02-05 | P2P 공유받은 사진 표시 버그 수정 - localFilePath 지원 추가 (HomeView, RecordsView) |
| 2026-02-05 | P2P 공유 기록 placeCount/photoCount 저장 누락 버그 수정 |
| 2026-02-05 | 홈 화면 RecordCard에 "공유됨" 배지 추가, 배지 디자인 개선 (더 진한 청록색) |
| 2026-02-05 | P2P 공유 서비스에 상세 디버그 로깅 추가 (송신/수신 양쪽) |
| 2026-02-05 | P2P 공유 UI 디자인 가이드 준수 적용 (WanderColors, WanderTypography, WanderSpacing 토큰) |
| 2026-02-05 | CLAUDE.local.md에 디자인 토큰 사용 규칙 문서화 |
| 2026-02-05 | P2P 기록 공유 기능 구현 (CloudKit, AES-256 암호화, Deep Link) |
| 2026-02-05 | Instagram 공유 기능 제거 (Feed/Stories), 일반 공유만 유지 |
| 2026-02-05 | 사진 피커 드래그 선택 버그 수정 (UICollectionView 방식으로 재작성) |
| 2026-02-05 | 미분류 사진(GPS 없음) 지도 표시 제외 - hasValidCoordinate 필터 추가 |
| 2026-02-05 | 공유 템플릿 UI/UX 개선 - 날짜 중복 제거 (통계에 날짜 통합) |
| 2026-02-05 | 감성 키워드(Impression) 기능 추가 (로맨틱 · 힐링 · 도심탈출) |
| 2026-02-05 | ImpressionGenerator 추가 - 활동/지역/계절 기반 키워드 자동 생성 |
| 2026-02-05 | ShareConfiguration에 impression 필드 추가 |
| 2026-02-05 | 텍스트 오버플로우 처리 개선 (truncateText 함수 강화) |
| 2026-02-05 | UI/UX 스펙 문서 작성 (specs/share-template-ui/design-spec.md) |
| 2026-02-04 | SNS 공유 기능 전면 개편 (3단계 플로우, 글래스모피즘 템플릿) |
| 2026-02-04 | 공유 이미지에 캡션/해시태그/AI 스토리 추가 |
| 2026-02-04 | 공유 미리보기 핀치 투 줌 기능 추가 |
| 2026-02-04 | 워터마크 앱 아이콘으로 변경 및 텍스트 크기 최적화 |
| 2026-02-04 | 커스텀 탭바 스크롤 문제 수정 (GeometryReader + ZStack 방식) |
| 2026-02-04 | 모든 탭 하단 패딩 추가 (탭바에 콘텐츠 가려지는 문제 해결) |
| 2026-02-04 | 기록 상세 페이지 여행동선 지도 클릭 시 팝업 표시 기능 추가 |
| 2026-02-04 | fullScreenCover(item:) 패턴으로 사진 전달 버그 수정 |
| 2026-02-04 | DKImagePicker 제거, CustomPhotoPicker로 완전 전환 |
| 2026-02-04 | PHImageManager 콜백 중복 호출 크래시 수정 |
| 2026-02-04 | 메타데이터 추출 로깅 개선 |

---

*최종 업데이트: 2026-02-06*
