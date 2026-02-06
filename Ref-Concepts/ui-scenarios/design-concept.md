← [인덱스](index.md)

---

# Wander Design Concept

## Document Info
- **Version**: v1.0
- **Date**: 2026년 1월 30일
- **Design Direction**: Pastel Skyblue, Clean & Minimal
- **Reference**: Airbnb, Pinterest (Card-centric, Photo-focused)

---

## 1. Design Principles

### 1.1 핵심 디자인 원칙

```
┌─────────────────────────────────────────────────────────────┐
│                    Wander Design Principles                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 📷 Photo First                                          │
│     사진이 주인공, UI는 사진을 돋보이게 하는 프레임          │
│                                                             │
│  2. ☁️ Light & Airy                                         │
│     Pastel skyblue 톤의 가볍고 청량한 느낌                  │
│                                                             │
│  3. ✨ Clean & Minimal                                       │
│     군더더기 없는 심플함, 필수 요소만 표시                   │
│                                                             │
│  4. 🎯 Content-Focused                                       │
│     장식 최소화, 콘텐츠에 집중                              │
│                                                             │
│  5. 🌊 Calm & Trustworthy                                   │
│     차분하고 신뢰감 있는 톤앤매너                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 1.2 디자인 키워드

| Keyword | Description |
|---------|-------------|
| **Soft** | 부드러운 곡선, 은은한 그림자 |
| **Breathable** | 충분한 여백, 답답하지 않은 레이아웃 |
| **Warm Minimal** | 차갑지 않은 미니멀, 따뜻한 느낌 유지 |
| **Inviting** | 친근하고 접근하기 쉬운 인터페이스 |

---

## 2. Color Palette

### 2.1 Primary Colors

#### Light Mode

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| **Sky Blue** | `#87CEEB` | 135, 206, 235 | Primary Brand Color |
| **Sky Blue Light** | `#B0E0F0` | 176, 224, 240 | Hover, Pressed states |
| **Sky Blue Pale** | `#E8F6FC` | 232, 246, 252 | Background tint, Cards |
| **Sky Blue Dark** | `#5BA3C0` | 91, 163, 192 | Text on light bg |

#### Dark Mode

| Name | Hex | RGB | Usage |
|------|-----|-----|-------|
| **Sky Blue** | `#87CEEB` | 135, 206, 235 | Primary (same) |
| **Sky Blue Muted** | `#6BA8C2` | 107, 168, 194 | Adjusted for dark bg |
| **Sky Blue Glow** | `#A8D8EA` | 168, 216, 234 | Accent highlights |

### 2.2 Semantic Colors

#### Light Mode

| Name | Hex | Usage |
|------|-----|-------|
| **Success** | `#4CAF50` | 완료, 성공 상태 |
| **Success Background** | `#E8F5E9` | 성공 배경 |
| **Warning** | `#FF9800` | 경고, 주의 |
| **Warning Background** | `#FFF3E0` | 경고 배경 |
| **Error** | `#F44336` | 에러, 실패 |
| **Error Background** | `#FFEBEE` | 에러 배경 |
| **Info** | `#2196F3` | 정보, 안내 |
| **Info Background** | `#E3F2FD` | 정보 배경 |

#### Dark Mode

| Name | Hex | Usage |
|------|-----|-------|
| **Success** | `#66BB6A` | 밝기 조정 |
| **Success Background** | `#1B3D1F` | 어두운 배경 |
| **Warning** | `#FFA726` | 밝기 조정 |
| **Warning Background** | `#3D2E1A` | 어두운 배경 |
| **Error** | `#EF5350` | 밝기 조정 |
| **Error Background** | `#3D1A1A` | 어두운 배경 |
| **Info** | `#42A5F5` | 밝기 조정 |
| **Info Background** | `#1A2D3D` | 어두운 배경 |

### 2.3 Neutral Colors

#### Light Mode

| Name | Hex | Usage |
|------|-----|-------|
| **Background** | `#FFFFFF` | 메인 배경 |
| **Surface** | `#F8FBFD` | 카드, 섹션 배경 (약간의 블루틴트) |
| **Surface Elevated** | `#FFFFFF` | 떠있는 요소 (모달, 시트) |
| **Border** | `#E5EEF2` | 구분선, 테두리 |
| **Border Strong** | `#C8D9E0` | 강조 테두리 |
| **Text Primary** | `#1A2B33` | 주요 텍스트 |
| **Text Secondary** | `#5A6B73` | 보조 텍스트 |
| **Text Tertiary** | `#8A9BA3` | 힌트, 플레이스홀더 |
| **Text Disabled** | `#B8C8D0` | 비활성 텍스트 |

#### Dark Mode

| Name | Hex | Usage |
|------|-----|-------|
| **Background** | `#0D1B21` | 메인 배경 (깊은 네이비) |
| **Surface** | `#152830` | 카드, 섹션 배경 |
| **Surface Elevated** | `#1E3640` | 떠있는 요소 |
| **Border** | `#2A4550` | 구분선, 테두리 |
| **Border Strong** | `#3A5560` | 강조 테두리 |
| **Text Primary** | `#F0F8FA` | 주요 텍스트 |
| **Text Secondary** | `#A8C0CA` | 보조 텍스트 |
| **Text Tertiary** | `#6A8A98` | 힌트, 플레이스홀더 |
| **Text Disabled** | `#4A6A78` | 비활성 텍스트 |

### 2.4 Activity Label Colors

여행 활동 라벨에 사용되는 파스텔 톤 컬러:

| Activity | Light Mode | Dark Mode | Emoji |
|----------|------------|-----------|-------|
| 카페/브런치 | `#F5E6D3` | `#3D3228` | ☕ |
| 식사 | `#FFE4E1` | `#3D2828` | 🍽️ |
| 해변/바다 | `#E0F4F8` | `#1E3338` | 🏖️ |
| 산/등산 | `#E8F5E9` | `#1E3320` | ⛰️ |
| 관광지 | `#FFF8E1` | `#38351E` | 🏛️ |
| 쇼핑 | `#FCE4EC` | `#38202A` | 🛍️ |
| 공연/문화 | `#EDE7F6` | `#2A2038` | 🎭 |
| 공항/이동 | `#ECEFF1` | `#252830` | ✈️ |

### 2.5 Color Palette 시각화

```
Light Mode
─────────────────────────────────────────────────────────────

Primary Scale:
┌────────┬────────┬────────┬────────┬────────┐
│ Pale   │ Light  │ Base   │ Dark   │        │
│#E8F6FC │#B0E0F0 │#87CEEB │#5BA3C0 │        │
│ ░░░░░░ │ ░░░░░░ │ ████░░ │ ██████ │        │
└────────┴────────┴────────┴────────┴────────┘

Neutral Scale:
┌────────┬────────┬────────┬────────┬────────┐
│ White  │Surface │Border  │Sec Text│Pri Text│
│#FFFFFF │#F8FBFD │#E5EEF2 │#5A6B73 │#1A2B33 │
│        │ ░░░░░░ │ ░░░░░░ │ ██░░░░ │ ██████ │
└────────┴────────┴────────┴────────┴────────┘


Dark Mode
─────────────────────────────────────────────────────────────

Primary Scale:
┌────────┬────────┬────────┬────────┬────────┐
│ Glow   │ Base   │ Muted  │        │        │
│#A8D8EA │#87CEEB │#6BA8C2 │        │        │
│ ░░░░░░ │ ████░░ │ ██████ │        │        │
└────────┴────────┴────────┴────────┴────────┘

Neutral Scale:
┌────────┬────────┬────────┬────────┬────────┐
│Elevated│Surface │  BG    │Sec Text│Pri Text│
│#1E3640 │#152830 │#0D1B21 │#A8C0CA │#F0F8FA │
│ ░░░░░░ │ ██░░░░ │ ██████ │ ░░░░░░ │        │
└────────┴────────┴────────┴────────┴────────┘
```

---

## 3. Typography

### 3.1 Font Family

| Platform | Primary Font | Fallback |
|----------|--------------|----------|
| iOS | **SF Pro** | System Default |
| 한글 | **Apple SD Gothic Neo** | System Default |

### 3.2 Type Scale

| Style | Size | Weight | Line Height | Letter Spacing | Usage |
|-------|------|--------|-------------|----------------|-------|
| **Display** | 34pt | Bold (700) | 41pt (1.2) | -0.4pt | 대형 타이틀 |
| **Title 1** | 28pt | Bold (700) | 34pt (1.2) | -0.3pt | 페이지 타이틀 |
| **Title 2** | 22pt | Bold (700) | 28pt (1.27) | -0.2pt | 섹션 타이틀 |
| **Title 3** | 20pt | Semibold (600) | 25pt (1.25) | -0.1pt | 카드 타이틀 |
| **Headline** | 17pt | Semibold (600) | 22pt (1.29) | 0pt | 강조 텍스트 |
| **Body** | 17pt | Regular (400) | 24pt (1.41) | 0pt | 본문 |
| **Body Small** | 15pt | Regular (400) | 21pt (1.4) | 0pt | 보조 본문 |
| **Caption 1** | 13pt | Regular (400) | 18pt (1.38) | 0pt | 캡션, 라벨 |
| **Caption 2** | 12pt | Regular (400) | 16pt (1.33) | 0pt | 작은 캡션 |
| **Footnote** | 11pt | Regular (400) | 14pt (1.27) | 0pt | 각주, 타임스탬프 |

### 3.3 Typography 사용 예시

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  Display (34pt Bold)                                        │
│  제주도 3박 4일                                              │
│                                                             │
│  Title 2 (22pt Bold)                                        │
│  Day 1 - 첫째 날                                            │
│                                                             │
│  Headline (17pt Semibold)                                   │
│  협재해수욕장                                                │
│                                                             │
│  Body (17pt Regular)                                        │
│  에메랄드빛 바다가 눈앞에 펼쳐졌다. 제주의 첫 인상은        │
│  예상보다 훨씬 아름다웠다.                                   │
│                                                             │
│  Caption 1 (13pt Regular)                                   │
│  📍 제주시 한림읍 · 🕐 13:00 - 15:30                        │
│                                                             │
│  Footnote (11pt Regular)                                    │
│  2026.01.15 · 사진 8장                                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Spacing System

### 4.1 Base Unit

기본 단위: **4pt**

모든 간격은 4의 배수로 설정합니다.

### 4.2 Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `space-0` | 0pt | - |
| `space-1` | 4pt | 아이콘과 텍스트 사이 |
| `space-2` | 8pt | 인라인 요소 간격 |
| `space-3` | 12pt | 작은 요소 간격 |
| `space-4` | 16pt | 기본 내부 패딩 |
| `space-5` | 20pt | 컴포넌트 간 간격 |
| `space-6` | 24pt | 섹션 내부 패딩 |
| `space-7` | 32pt | 섹션 간 간격 |
| `space-8` | 40pt | 큰 섹션 간격 |
| `space-9` | 48pt | 페이지 상단/하단 |
| `space-10` | 64pt | 대형 여백 |

### 4.3 Screen Margins

| Device | Horizontal Margin |
|--------|-------------------|
| iPhone SE | 16pt |
| iPhone 14 | 20pt |
| iPhone 14 Pro Max | 20pt |

### 4.4 Spacing 시각화

```
┌─────────────────────────────────────────────────────────────┐
│                                                             │
│  ←─────────────── 20pt margin ───────────────→             │
│                                                             │
│  ┌───────────────────────────────────────────┐             │
│  │            ← 16pt padding →               │             │
│  │  ┌─────────────────────────────────────┐  │             │
│  │  │                                     │  │             │
│  │  │           Content Area              │  │             │
│  │  │                                     │  │             │
│  │  └─────────────────────────────────────┘  │             │
│  │                                           │             │
│  │  ↕ 24pt (space-6) between sections        │             │
│  │                                           │             │
│  │  ┌─────────────────────────────────────┐  │             │
│  │  │                                     │  │             │
│  │  │           Content Area              │  │             │
│  │  │                                     │  │             │
│  │  └─────────────────────────────────────┘  │             │
│  └───────────────────────────────────────────┘             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 5. Border Radius

### 5.1 Radius Scale

| Token | Value | Usage |
|-------|-------|-------|
| `radius-none` | 0pt | 직각 요소 |
| `radius-sm` | 4pt | 작은 태그, 뱃지 |
| `radius-md` | 8pt | 버튼, 입력 필드 |
| `radius-lg` | 12pt | 카드, 썸네일 |
| `radius-xl` | 16pt | 모달, 시트 |
| `radius-2xl` | 20pt | 대형 카드 |
| `radius-full` | 9999pt | 원형 (아바타, 플로팅 버튼) |

---

## 6. Shadows & Elevation

### 6.1 Shadow Scale

#### Light Mode

| Level | Shadow | Usage |
|-------|--------|-------|
| **Elevation 0** | none | 기본 요소 |
| **Elevation 1** | `0 1px 3px rgba(26,43,51,0.08)` | 카드, 버튼 |
| **Elevation 2** | `0 4px 12px rgba(26,43,51,0.12)` | 호버 상태, 드롭다운 |
| **Elevation 3** | `0 8px 24px rgba(26,43,51,0.16)` | 모달, 팝업 |
| **Elevation 4** | `0 16px 48px rgba(26,43,51,0.20)` | 풀스크린 오버레이 |

#### Dark Mode

| Level | Shadow | Usage |
|-------|--------|-------|
| **Elevation 0** | none | 기본 요소 |
| **Elevation 1** | `0 1px 3px rgba(0,0,0,0.24)` | 카드, 버튼 |
| **Elevation 2** | `0 4px 12px rgba(0,0,0,0.32)` | 호버 상태, 드롭다운 |
| **Elevation 3** | `0 8px 24px rgba(0,0,0,0.40)` | 모달, 팝업 |
| **Elevation 4** | `0 16px 48px rgba(0,0,0,0.48)` | 풀스크린 오버레이 |

### 6.2 그림자 적용 원칙

- **가볍게**: 그림자는 최소한으로, 무거워 보이지 않게
- **일관성**: 같은 레벨의 요소는 같은 그림자
- **의미있게**: elevation은 요소의 계층을 나타냄

---

## 7. Components

### 7.1 Buttons

#### Primary Button

```
╭────────────────────╮
│    여행 기록 만들기   │
│    #87CEEB bg       │
│    #1A2B33 text     │
╰────────────────────╯

Specs:
- Height: 52pt
- Padding: 16pt horizontal
- Border Radius: 12pt
- Font: Headline (17pt Semibold)
- Shadow: Elevation 1
```

#### Secondary Button

```
╭────────────────────╮
│       취소         │
│    #F8FBFD bg      │
│    #5A6B73 text    │
│    #E5EEF2 border  │
╰────────────────────╯

Specs:
- Height: 52pt
- Border: 1pt
- Border Radius: 12pt
```

#### Button States

| State | Background | Text | Border |
|-------|------------|------|--------|
| Default | `#87CEEB` | `#1A2B33` | - |
| Hover/Pressed | `#5BA3C0` | `#FFFFFF` | - |
| Disabled | `#E5EEF2` | `#B8C8D0` | - |
| Loading | `#87CEEB` 50% | Spinner | - |

### 7.2 Cards

#### Record Card (Airbnb Style)

- Width: 100% (full width card)
- Border Radius: 20pt
- Shadow: Elevation 1
- Photo: 4:3 ratio, carousel
- Content padding: 16pt
- Gap between cards: 20pt

#### Photo Card (Pinterest Style)

- Width: Flexible (grid column)
- Border Radius: 16pt
- Shadow: Elevation 1
- Photo: Dynamic height (masonry layout)
- Content padding: 16pt

### 7.3 Navigation

#### Tab Bar

- Height: 49pt + Safe Area
- Background: Surface (#F8FBFD / #152830)
- Border Top: 0.5pt Border color
- Icon size: 24pt
- Label: Caption 2 (12pt)
- Active color: Primary (#87CEEB)
- Inactive color: Text Tertiary

#### Navigation Bar

- Height: 44pt + Status Bar
- Background: Transparent / Blur
- Title: Headline (17pt Semibold), centered
- Back button: SF Symbol `chevron.left`

### 7.4 Input Fields

- Height: 48pt
- Padding: 16pt horizontal
- Border Radius: 8pt
- Background: Surface
- Border: 1pt (default), 2pt (focused, #87CEEB), 2pt (error, #F44336)

### 7.5 Tags & Badges

- Padding: 6pt 10pt
- Border Radius: 4pt
- Font: Caption 1 (13pt)
- Activity Tags: 파스텔 배경 + 이모지

---

## 8. Iconography

### 8.1 Icon Style

| Property | Value |
|----------|-------|
| **Library** | SF Symbols |
| **Weight** | Regular (기본), Medium (강조) |
| **Scale** | Medium |
| **Style** | Outlined (기본), Filled (선택됨) |

### 8.2 Icon Sizes

| Size | Usage |
|------|-------|
| 16pt | 인라인 아이콘, 작은 버튼 |
| 20pt | 리스트 아이콘, 작은 액션 |
| 24pt | 탭바, 네비게이션 아이콘 |
| 28pt | 중형 아이콘 |
| 32pt | 대형 아이콘, 빈 상태 |
| 48pt+ | 온보딩, 빈 상태 일러스트 |

### 8.3 App Icons Usage

| Feature | SF Symbol | Fallback Emoji |
|---------|-----------|----------------|
| 홈 | `house.fill` | 🏠 |
| 기록 | `book.fill` | 📚 |
| 설정 | `gearshape.fill` | ⚙️ |
| 사진 | `photo.fill` | 📷 |
| 지도 | `map.fill` | 🗺️ |
| 위치 | `mappin` | 📍 |
| 시간 | `clock` | 🕐 |
| 공유 | `square.and.arrow.up` | - |
| 편집 | `pencil` | ✏️ |
| 삭제 | `trash` | 🗑️ |
| 추가 | `plus` | ➕ |
| 닫기 | `xmark` | ✕ |
| 뒤로 | `chevron.left` | ◀ |

---

## 9. Motion & Animation

### 9.1 Animation Principles

1. **Natural & Fluid** - 물 흐르듯 자연스럽게
2. **Purposeful** - 의미 있는 애니메이션만
3. **Quick & Responsive** - 빠른 피드백
4. **Consistent** - 같은 유형 = 같은 애니메이션

### 9.2 Duration Scale

| Duration | Usage |
|----------|-------|
| **100ms** | 즉각적 피드백 (버튼 프레스, 토글) |
| **200ms** | 작은 전환 (탭 전환, 드롭다운) |
| **300ms** | 중간 전환 (카드 확장, 모달) |
| **400ms** | 큰 전환 (페이지 전환) |
| **500ms+** | 특별한 애니메이션 (온보딩, 성공 화면) |

### 9.3 Easing

| Type | Curve | Usage |
|------|-------|-------|
| **Ease Out** | `cubic-bezier(0, 0, 0.2, 1)` | 요소 나타남 |
| **Ease In** | `cubic-bezier(0.4, 0, 1, 1)` | 요소 사라짐 |
| **Ease In Out** | `cubic-bezier(0.4, 0, 0.2, 1)` | 일반 전환 |
| **Spring** | `mass: 1, stiffness: 200, damping: 20` | 탄성 있는 움직임 |

### 9.4 Micro-interactions

| Interaction | Animation |
|-------------|-----------|
| 버튼 탭 | Scale 0.98 → 1.0, 100ms |
| 카드 탭 | Scale 0.99 → 1.0, opacity pulse, 150ms |
| 스위치 토글 | Spring animation, 200ms |
| 체크박스 | Checkmark draw animation, 200ms |
| 로딩 | 부드러운 회전 또는 pulse |
| Pull to refresh | Rubber band effect |

---

## 10. Accessibility

### 10.1 Color Contrast

WCAG 2.1 AA 기준 충족:

| Element | Light Mode Contrast | Dark Mode Contrast |
|---------|--------------------|--------------------|
| Primary Text | 12.5:1 | 14.2:1 |
| Secondary Text | 5.8:1 | 6.1:1 |
| Primary Button | 4.6:1 | 4.8:1 |

### 10.2 Touch Targets

- 최소 터치 영역: **44pt x 44pt**

### 10.3 Dynamic Type Support

- 최소: `xSmall` ~ 최대: `xxxLarge`

### 10.4 Reduce Motion

- `@Environment(\.accessibilityReduceMotion)` 체크
- true일 경우 모든 애니메이션 비활성화 또는 단순화

---

## 11. Dark Mode

- Primary Color (`#87CEEB`)는 두 모드에서 동일하게 유지
- Background는 순수 검정(#000000)이 아닌 Deep Navy (`#0D1B21`) 사용
- Card는 Background보다 약간 밝게 → 레이어 구분
- 그림자는 더 어둡고 강하게 → 깊이감 유지

---

## 12. Asset Specifications

### 12.1 App Icon

- Concept: W 심볼 (여행 경로) + AI 스파클
- Primary: `#87CEEB`
- Background: Gradient (`#5DADE2` → `#87CEEB`)
- Size: 1024x1024 (iOS 17+ Universal)

### 12.2 Launch Screen

- Background: `#E8F6FC` (Light) / `#0D1B21` (Dark)
- Logo color: `#87CEEB`
- Text: `#1A2B33` (Light) / `#F0F8FA` (Dark)

### 12.3 Empty State Illustrations

- 스타일: Line art + Pastel fill
- 선 두께: 2pt, 선 색상: Text Secondary
- 채움: Activity Label colors (pastel)
- 크기: 120pt x 120pt

---

## Appendix: Design Tokens (SwiftUI)

### Color Tokens

```swift
// WanderColors.swift
extension Color {
    static let wanderPrimary = Color("SkyBlue")           // #87CEEB
    static let wanderPrimaryLight = Color("SkyBlueLight") // #B0E0F0
    static let wanderPrimaryPale = Color("SkyBluePale")   // #E8F6FC
    static let wanderPrimaryDark = Color("SkyBlueDark")   // #5BA3C0

    static let wanderSuccess = Color("Success")
    static let wanderWarning = Color("Warning")
    static let wanderError = Color("Error")

    static let wanderBackground = Color("Background")
    static let wanderSurface = Color("Surface")
    static let wanderBorder = Color("Border")

    static let wanderTextPrimary = Color("TextPrimary")
    static let wanderTextSecondary = Color("TextSecondary")
    static let wanderTextTertiary = Color("TextTertiary")
}
```

### Typography Tokens

```swift
// WanderTypography.swift
extension Font {
    static let wanderDisplay = Font.system(size: 34, weight: .bold)
    static let wanderTitle1 = Font.system(size: 28, weight: .bold)
    static let wanderTitle2 = Font.system(size: 22, weight: .bold)
    static let wanderTitle3 = Font.system(size: 20, weight: .semibold)
    static let wanderHeadline = Font.system(size: 17, weight: .semibold)
    static let wanderBody = Font.system(size: 17, weight: .regular)
    static let wanderBodySmall = Font.system(size: 15, weight: .regular)
    static let wanderCaption1 = Font.system(size: 13, weight: .regular)
    static let wanderCaption2 = Font.system(size: 12, weight: .regular)
}
```

### Spacing Tokens

```swift
// WanderSpacing.swift
enum WanderSpacing {
    static let space1: CGFloat = 4
    static let space2: CGFloat = 8
    static let space3: CGFloat = 12
    static let space4: CGFloat = 16
    static let space5: CGFloat = 20
    static let space6: CGFloat = 24
    static let space7: CGFloat = 32
    static let screenMargin: CGFloat = 20
}
```

### Border Radius Tokens

```swift
// WanderRadius.swift
enum WanderRadius {
    static let sm: CGFloat = 4
    static let md: CGFloat = 8
    static let lg: CGFloat = 12
    static let xl: CGFloat = 16
    static let xxl: CGFloat = 20
    static let full: CGFloat = 9999
}
```

---

*Document Version: v1.0*
*Last Updated: 2026년 1월 30일*
