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
| 테마 | **Light Mode Only** (우선) |

### 필수 프레임워크
```swift
import SwiftUI
import SwiftData
import PhotosUI      // 사진 선택
import Photos        // PhotoKit 메타데이터
import CoreLocation  // GPS, CLGeocoder
import MapKit        // 지도
import Security      // Keychain (API Key 저장)
```

---

## 프로젝트 정보

| 항목 | 값 |
|------|-----|
| 프로젝트 위치 | `/Volumes/MiniExt/main_work/75_AI/Wander/` |
| Bundle ID | `com.zerolive.wander` |
| 프로젝트명 | `Wander` |
| GitHub | https://github.com/leonardo204/Wander |

---

## 문서 구조

```
Wander/
├── claude.local.md              ← 이 파일 (개발 가이드)
├── wander_planning_report.md    ← 기획서
├── wander_ui_scenario.md        ← UI 시나리오
├── wander_design_concept.md     ← 디자인 시스템
├── GUI/                         ← UI 목업 (개발 참조용)
│   ├── index.md                 ← UI 목업 인덱스
│   ├── screens/                 ← 32개 화면 PNG 목업
│   └── prompts/                 ← Google Stitch 프롬프트 (개발 불필요)
│       ├── wander_ai_prompts.md
│       ├── wander_ai_prompts2.md
│       └── wander_ai_prompts3.md
└── Ref-docs/                    ← 참조 문서
    ├── CLAUDE_CODE_HANDOFF.md   ← 구버전 핸드오프 (참고용)
    └── google-stitch/           ← 구버전 UI 목업 백업
```

### 개발 시 참조 필수 문서

| 파일 | 용도 | 참조 시점 |
|------|------|----------|
| `wander_planning_report.md` | 기획서, 기능 정의, 비즈니스 로직 | 기능 구현 전 |
| `wander_ui_scenario.md` | UI 시나리오, 플로우, 상태 정의 | 화면 구현 시 |
| `wander_design_concept.md` | 디자인 시스템 (컬러, 타이포, 컴포넌트) | UI 스타일링 시 |
| `GUI/index.md` | UI 목업 인덱스 (32개 화면) | 디자인 참조 시 |
| `GUI/screens/` | 화면별 PNG 목업 | 레이아웃 참조 시 |

### 개발에 불필요한 파일

| 폴더/파일 | 설명 |
|-----------|------|
| `GUI/prompts/` | Google Stitch 프롬프트 파일들 (UI 생성용) |
| `Ref-docs/` | 구버전 참조 문서 (백업용) |

---

## 디자인 시스템 요약

### 컬러 (Light Mode)

```swift
// Primary
static let primary = Color(hex: "#87CEEB")        // Sky Blue
static let primaryLight = Color(hex: "#B0E0F0")
static let primaryPale = Color(hex: "#E8F6FC")
static let primaryDark = Color(hex: "#5BA3C0")

// Background & Surface
static let background = Color.white               // #FFFFFF
static let surface = Color(hex: "#F8FBFD")        // 약간 블루틴트
static let border = Color(hex: "#E5EEF2")

// Text
static let textPrimary = Color(hex: "#1A2B33")
static let textSecondary = Color(hex: "#5A6B73")
static let textTertiary = Color(hex: "#8A9BA3")

// Semantic
static let success = Color(hex: "#4CAF50")
static let warning = Color(hex: "#FF9800")
static let error = Color(hex: "#F44336")
static let info = Color(hex: "#2196F3")
```

### 타이포그래피

```swift
// SF Pro (시스템 폰트) 사용
.font(.system(size: 34, weight: .bold))    // Display
.font(.system(size: 28, weight: .bold))    // Title 1
.font(.system(size: 22, weight: .bold))    // Title 2
.font(.system(size: 20, weight: .semibold)) // Title 3
.font(.system(size: 17, weight: .semibold)) // Headline
.font(.system(size: 17, weight: .regular))  // Body
.font(.system(size: 13, weight: .regular))  // Caption
```

### 스페이싱 (4pt 기반)

```swift
static let space2: CGFloat = 8
static let space3: CGFloat = 12
static let space4: CGFloat = 16
static let space5: CGFloat = 20
static let space6: CGFloat = 24
static let screenMargin: CGFloat = 20
```

### Border Radius

```swift
static let radiusSmall: CGFloat = 4    // 태그
static let radiusMedium: CGFloat = 8   // 버튼, 인풋
static let radiusLarge: CGFloat = 12   // 카드
static let radiusXL: CGFloat = 16      // 모달
static let radiusXXL: CGFloat = 20     // 큰 카드
```

---

## 화면 구조 (32개)

### 앱 플로우
```
앱 실행 → 스플래시 → 첫 실행? → 온보딩(3단계) → 홈
                          ↓
                     재실행 → 홈
```

### 탭바 구조
```
┌─────────────────────────────────────┐
│   🏠          📚          ⚙️        │
│   홈          기록        설정       │
└─────────────────────────────────────┘
```
- 아이콘: SF Symbols (house.fill, book.fill, gearshape.fill)
- Active: #87CEEB / Inactive: #8A9BA3
- 높이: 49pt + SafeArea

### 주요 화면 매핑

| 화면 ID | 화면명 | SwiftUI View |
|---------|--------|--------------|
| SCR-001 | 스플래시 | `SplashView` |
| SCR-002~004 | 온보딩 | `OnboardingView` |
| SCR-005 | 홈 | `HomeView` |
| SCR-006 | 기록 목록 | `RecordsView` |
| SCR-007 | 설정 | `SettingsView` |
| SCR-008 | 사진 선택 | `PhotoSelectionView` |
| SCR-009 | 분석 중 | `AnalyzingView` |
| SCR-010 | 분석 결과 | `ResultView` |
| SCR-011 | 지도 상세 | `MapDetailView` |
| SCR-012 | 타임라인 편집 | `TimelineEditView` |
| SCR-013 | AI 스토리 | `AIStoryView` |

---

## 데이터 모델 (SwiftData)

### 핵심 모델

```swift
@Model
class TravelRecord {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var places: [Place]
    var totalDistance: Double
    var createdAt: Date
    var aiStory: String?
}

@Model
class Place {
    var id: UUID
    var name: String
    var address: String
    var coordinate: CLLocationCoordinate2D
    var visitTime: Date
    var duration: TimeInterval
    var activityType: ActivityType
    var photos: [PhotoItem]
    var memo: String?
}

enum ActivityType: String, Codable {
    case cafe, restaurant, beach, mountain
    case shopping, culture, airport, other
}
```

---

## 커밋 전략

### 규칙
- **작은 단위, Feature 별로 커밋**
- 기능 완료 시점마다 커밋
- 의미 있는 커밋 메시지 작성

### 커밋 메시지 형식
```
[타입] 간단한 설명

예시:
[Init] Xcode 프로젝트 초기 설정
[Feature] 스플래시 화면 구현
[Feature] 온보딩 플로우 구현
[UI] 홈 화면 레이아웃 완성
[Fix] 사진 권한 요청 버그 수정
[Refactor] 컬러 시스템 분리
```

### 타입
- `[Init]` - 초기 설정
- `[Feature]` - 새 기능
- `[UI]` - UI 작업
- `[Fix]` - 버그 수정
- `[Refactor]` - 리팩토링
- `[Docs]` - 문서

---

## 구현 상태 (2026-01-31)

### ✅ Phase 1: 기본 구조 - 완료
- [x] Xcode 프로젝트 생성 (xcodegen)
- [x] 디자인 시스템 (WanderColors, WanderTypography, WanderSpacing)
- [x] 앱 구조 (3탭 TabView)
- [x] 스플래시 & 온보딩 (3단계)
- [x] 권한 요청 (사진, 위치)

### ✅ Phase 2: 핵심 기능 - 완료
- [x] 홈 화면 (빈 상태 / 기록 있음)
- [x] 사진 선택 & 메타데이터 추출
- [x] 분석 로직 (GPS 클러스터링, Reverse Geocoding)
- [x] 결과 화면 (타임라인, 지도)
- [x] 기록 저장 (SwiftData)

### ✅ Phase 3: 부가 기능 - 완료
- [x] 기록 목록 & 상세
- [x] 설정 화면 (AI설정, 데이터관리, 권한, 공유, 앱정보)
- [ ] 공유 기능 (플레이스홀더)
- [ ] 내보내기 (플레이스홀더)

### ✅ Phase 4: AI 기능 (BYOK) - 완료
- [x] KeychainManager (API Key 저장)
- [x] AI 서비스 프로토콜 및 구현체 (OpenAI, Anthropic, Google)
- [x] AI 스토리 생성 화면

---

## 로깅 가이드라인

### 로깅 규칙 (필수)

모든 새로운 코드에는 `os.log`를 사용한 로깅을 추가해야 합니다.

```swift
import os.log

// 파일 상단에 logger 선언 (private)
private let logger = Logger(subsystem: "com.zerolive.wander", category: "카테고리명")
```

### 로깅 위치 (필수 추가)

| 위치 | 로깅 내용 |
|------|----------|
| View의 `onAppear` | 화면 진입, 주요 상태값 |
| 버튼/액션 핸들러 | 사용자 액션 |
| 비동기 작업 시작/완료 | API 호출, 분석 시작/완료 |
| 에러 발생 시 | 에러 메시지, 컨텍스트 |
| 상태 변경 시 | `onChange`에서 중요 상태 변경 |
| 권한 요청/응답 | 권한 상태 변화 |

### 로깅 형식

```swift
// View 진입
logger.info("🏠 [HomeView] 나타남 - records: \(records.count)개")

// 사용자 액션
logger.info("📷 [PhotoSelection] 사진 선택: \(asset.localIdentifier)")

// 비동기 작업
logger.info("🔬 [AnalysisEngine] 분석 시작 - photos: \(count)장")
logger.info("✅ [AnalysisEngine] 분석 완료 - places: \(places.count)개")

// 에러
logger.error("❌ [GeocodingService] 실패: \(error.localizedDescription)")

// 경고
logger.warning("⚠️ [Clustering] GPS 없는 사진 스킵")
```

### 이모지 컨벤션

| 이모지 | 용도 |
|--------|------|
| 🚀 | 앱 시작, 초기화 |
| 🏠 | 홈 화면 |
| 📷 | 사진 관련 |
| 📍 | 위치/클러스터링 |
| 🗺️ | 지도/지오코딩 |
| 🔬 | 분석 엔진 |
| ✨ | AI 스토리 |
| ⚙️ | 설정 |
| 🔐 | 키체인/보안 |
| 🤖 | OpenAI |
| 🧠 | Anthropic |
| 💎 | Google AI |
| ✅ | 성공 |
| ❌ | 에러 |
| ⚠️ | 경고 |
| 📖 | 기록 상세 |
| 👋 | 온보딩 |

### 로그 카테고리 목록

| 카테고리 | 파일 |
|----------|------|
| `WanderApp` | WanderApp.swift |
| `ContentView` | ContentView.swift |
| `HomeView` | HomeView.swift |
| `RecordsView` | RecordsView.swift |
| `PhotoSelectionView` | PhotoSelectionView.swift |
| `PhotoSelectionVM` | PhotoSelectionViewModel.swift |
| `AnalyzingView` | AnalyzingView.swift |
| `AnalysisEngine` | AnalysisEngine.swift |
| `ClusteringService` | ClusteringService.swift |
| `GeocodingService` | GeocodingService.swift |
| `ActivityInference` | ActivityInferenceService.swift |
| `ResultView` | ResultView.swift |
| `MapDetailView` | MapDetailView.swift |
| `AIStoryView` | AIStoryView.swift |
| `SettingsView` | SettingsView.swift |
| `OpenAIService` | OpenAIService.swift |
| `AnthropicService` | AnthropicService.swift |
| `GoogleAIService` | GoogleAIService.swift |
| `KeychainManager` | KeychainManager.swift |
| `SplashView` | SplashView.swift |
| `Onboarding` | OnboardingContainerView.swift |
| `OnboardingIntro` | OnboardingIntroView.swift |
| `OnboardingPhoto` | OnboardingPhotoView.swift |
| `OnboardingLocation` | OnboardingLocationView.swift |

### Console.app에서 확인

1. Mac에서 **Console.app** 실행
2. 왼쪽 패널에서 연결된 **iPhone** 선택
3. 검색창에 `com.zerolive.wander` 입력
4. 실시간 로그 확인

**팁:**
- `subsystem:com.zerolive.wander`로 필터링
- `category:AnalysisEngine`으로 특정 카테고리만 필터링

---

## 프로젝트 구조 (실제 파일)

```
Wander/
├── WanderApp.swift
├── ContentView.swift
├── project.yml                    # xcodegen 설정
├── Core/
│   ├── Design/
│   │   ├── WanderColors.swift
│   │   ├── WanderTypography.swift
│   │   └── WanderSpacing.swift
│   └── Utilities/
│       └── KeychainManager.swift
├── Models/SwiftData/
│   ├── TravelRecord.swift
│   ├── TravelDay.swift
│   ├── Place.swift
│   └── PhotoItem.swift
├── Services/
│   ├── AIService/
│   │   ├── AIServiceProtocol.swift
│   │   ├── OpenAIService.swift
│   │   ├── AnthropicService.swift
│   │   └── GoogleAIService.swift
│   ├── AnalysisService/
│   │   ├── AnalysisEngine.swift
│   │   ├── ClusteringService.swift
│   │   └── ActivityInferenceService.swift
│   └── LocationService/
│       └── GeocodingService.swift
├── ViewModels/
│   └── PhotoSelection/
│       └── PhotoSelectionViewModel.swift
└── Views/
    ├── Launch/SplashView.swift
    ├── Onboarding/
    ├── Home/HomeView.swift
    ├── PhotoSelection/PhotoSelectionView.swift
    ├── Analysis/AnalyzingView.swift
    ├── Result/
    │   ├── ResultView.swift
    │   ├── MapDetailView.swift
    │   └── AIStoryView.swift
    ├── Records/RecordsView.swift
    └── Settings/SettingsView.swift
```

---

## 주의사항

### 아키텍처
- **MVVM 패턴** 준수
- View는 순수 UI만, 비즈니스 로직은 ViewModel에
- `@Observable` 매크로 활용 (iOS 17+)

### 권한 처리
- 사진 권한: `.readWrite` 또는 `.addOnly`
- 위치 권한: `.whenInUse` (배터리 최적화)
- 권한 거부 시 적절한 대체 UI 제공

### 데이터 프라이버시
- 모든 데이터 On-Device 처리
- API Key는 Keychain에 저장
- AI API 호출 시 최소 데이터만 전송 (사진 원본 X)

### UI/UX
- 모든 텍스트 **한국어**
- 탭바 **3개** 고정 (홈, 기록, 설정)
- 프로필/로그인 UI **없음**
- 프리미엄/크레딧 UI **없음**

---

## 유용한 참조

### UI 목업 확인
```bash
open GUI/screens/SCR-005_home_empty/screen.png
```

### 특정 화면 시나리오 검색
```bash
grep -n "SCR-010" wander_ui_scenario.md
```

### 디자인 컬러 검색
```bash
grep -n "#87CEEB" wander_design_concept.md
```

---

*최종 업데이트: 2026-01-31*
*작성: Claude Code*
