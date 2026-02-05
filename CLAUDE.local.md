# Wander - Claude Code 개발 가이드

## 프로젝트 개요

**Wander**는 여행 사진의 메타데이터(GPS, 시간)를 분석하여 자동으로 타임라인과 스토리를 생성하는 iOS 앱입니다.

### 핵심 특징
- **서버리스**: 로그인/회원가입 없음, 100% On-Device
- **BYOK (Bring Your Own Key)**: 사용자가 직접 AI API 키 입력
- **3탭 네비게이션**: 홈, 기록, 설정
- **프리미엄 없음**: 모든 기능 무료

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
│   │       └── KeychainManager.swift
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
│   │   │   └── AzureOpenAIService.swift
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
│   │   ├── Auth/PINInputView.swift
│   │   └── Shared/SharedRecordView.swift
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
| SNS 공유 | 일반 공유, 글래스모피즘 템플릿 | `ShareService/`, `Views/Share/` |
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

## AI 서비스 (BYOK)

### 지원 프로바이더
| 프로바이더 | 서비스 파일 | 지원 모델 |
|-----------|------------|----------|
| OpenAI | `OpenAIService.swift` | GPT-4o, GPT-4o Mini |
| Anthropic | `AnthropicService.swift` | Claude 3.5 Sonnet, Claude 3 Haiku |
| Google | `GoogleAIService.swift` | Gemini 2.0 Flash, 2.0 Flash Lite, 1.5 Pro, 1.5 Flash |
| Azure OpenAI | `AzureOpenAIService.swift` | GPT-4o (Azure 배포) |

### 모델별 토큰 설정
| 프로바이더 | 모델 | maxTokens | temperature |
|-----------|------|-----------|-------------|
| OpenAI | GPT-4o | 1024 | 0.8 |
| OpenAI | GPT-4o Mini | 800 | 0.7 |
| Anthropic | Claude 3.5 Sonnet | 1024 | - |
| Anthropic | Claude 3 Haiku | 600 | - |
| Google | Gemini 2.0 Flash | 1024 | 0.7 |
| Google | Gemini 2.0 Flash Lite | 512 | 0.6 |
| Google | Gemini 1.5 Pro | 1024 | 0.8 |
| Google | Gemini 1.5 Flash | 800 | 0.7 |

### 모델 선택 기능
- 설정 > AI 설정 > 프로바이더 선택 시 모델 Picker 제공
- 선택된 모델은 `UserDefaults`에 저장
- 연결 테스트 시 최소 토큰(1) 사용으로 비용 절감
- 429 Rate Limit은 연결 성공으로 처리 (API 키 유효 확인)

### API Key 저장
- Keychain에 안전하게 저장 (`KeychainManager.swift`)
- 앱 내에서만 접근 가능
- 기존 키는 마스킹 표시 (`abcd••••••••efgh`)

---

## 디자인 시스템

### 컬러 (Light Mode)
```swift
// Primary - Sky Blue
static let primary = Color(hex: "#87CEEB")
static let primaryPale = Color(hex: "#E8F6FC")

// Text
static let textPrimary = Color(hex: "#1A2B33")
static let textSecondary = Color(hex: "#5A6B73")

// Semantic
static let success = Color(hex: "#4CAF50")
static let error = Color(hex: "#F44336")
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

# 특정 화면 시나리오 검색
grep -n "SCR-010" Ref-Concepts/wander_ui_scenario.md
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

*최종 업데이트: 2026-02-05*
