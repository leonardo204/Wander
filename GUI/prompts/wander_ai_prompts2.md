# Wander AI UI Generation Prompts v3.0

## Document Info
- **Version**: v3.0
- **Date**: 2026-01-31
- **Purpose**: Create all screens for Google Stitch (fresh generation)
- **Architecture**: Serverless, no premium/login, BYOK as base feature, 3-tab navigation

---

## Usage Guide

### How to Use
1. **Always input PROMPT 0 (Design System v2.0) first** - this is mandatory
2. Copy the desired screen prompt and paste into Google Stitch
3. If attachment is indicated (📎), attach the specified document section

### Attachment Notation
```
📎 Attach: [document name] > [section]
```
When you see this, attach the specified document section along with the prompt.

### Recommended Tools
- Google AI Studio (Build Mode)
- Google Stitch (Experimental Mode)
- Firebase Studio

### Important Design Constraints
```
❌ NO login/profile features (serverless app)
❌ NO premium badges or indicators
❌ NO credit purchase UI
❌ NO 4-tab or 5-tab navigation
✅ Exactly 3 tabs: 홈 (Home), 기록 (Records), 설정 (Settings)
✅ BYOK is the only AI connection method
✅ All UI text must be in Korean (except "Wander" logo)
```

---

## Screens Reference

The following screens are referenced in this document:

| Screen ID | Screen Name | Description | Status |
|-----------|-------------|-------------|--------|
| SCR-012 | 타임라인 편집 | Timeline edit mode | ✅ Exists in ui_scenario |
| SCR-013 | AI 스토리 | AI generated story display | ✅ Added (NEW-05) |
| SCR-015 | 내보내기 옵션 | Export format selection | ✅ Exists in ui_scenario |
| SCR-017 | 공유 설정 | Share attribution settings | ✅ Added (NEW-06) |
| SCR-020 | API Key 입력 | BYOK API key input screen | ✅ Added to ui_scenario |
| SCR-021 | 데이터 관리 | Data management settings | ✅ Added to ui_scenario |

---

## PROMPT 0: Design System v2.0 (Required - Input First)

> ⚠️ **MANDATORY: Input this before creating any screen**

📎 Attach: None (included in prompt)

```
You are a senior UI/UX designer creating a mobile app called "Wander".

# App Overview
Wander is a travel photo diary app that analyzes photo metadata (GPS, time) to automatically create travel stories and timelines. This is a SERVERLESS app with NO login/account features.

# Critical Requirements (v2.0)
- NO profile/login UI anywhere
- NO premium badges or diamond (💎) icons
- NO credit purchase sections
- Tab bar MUST have exactly 3 tabs (not 4, not 5)
- All UI text in KOREAN (except "Wander" logo)
- BYOK (Bring Your Own Key) is the ONLY AI connection method

# Design System

## Brand Personality
- Style: Clean, minimal, photo-focused (inspired by Airbnb & Pinterest)
- Mood: Light, airy, friendly, calm
- Tone: Warm minimal - not cold, approachable

## Color Palette

### Light Mode (Primary)
- Primary: #87CEEB (Pastel Sky Blue)
- Primary Light: #B0E0F0
- Primary Pale: #E8F6FC
- Primary Dark: #5BA3C0
- Background: #FFFFFF
- Surface (Cards): #F8FBFD (slight blue tint)
- Border: #E5EEF2
- Text Primary: #1A2B33
- Text Secondary: #5A6B73
- Text Tertiary: #8A9BA3

### Semantic Colors
- Success: #4CAF50, Background: #E8F5E9
- Warning: #FF9800, Background: #FFF3E0
- Error: #F44336, Background: #FFEBEE
- Info: #2196F3, Background: #E3F2FD

### Activity Label Colors (Pastel)
- Cafe: #F5E6D3
- Restaurant: #FFE4E1
- Beach: #E0F4F8
- Mountain: #E8F5E9
- Shopping: #FCE4EC
- Culture: #EDE7F6

## Typography
- Font: SF Pro (iOS system font)
- Display: 34pt Bold
- Title 1: 28pt Bold
- Title 2: 22pt Bold
- Title 3: 20pt Semibold
- Headline: 17pt Semibold
- Body: 17pt Regular
- Caption: 13pt Regular
- Footnote: 11pt Regular

## Spacing (4pt base)
- space-2: 8pt
- space-3: 12pt
- space-4: 16pt
- space-5: 20pt
- space-6: 24pt
- space-7: 32pt
- Screen margin: 20pt

## Border Radius
- Small (tags): 4pt
- Medium (buttons, inputs): 8pt
- Large (cards, thumbnails): 12pt
- XL (modals): 16pt
- XXL (large cards): 20pt
- Full (avatars): 9999pt

## Shadows
- Elevation 1 (cards): 0 1px 3px rgba(26,43,51,0.08)
- Elevation 2 (hover): 0 4px 12px rgba(26,43,51,0.12)
- Elevation 3 (modals): 0 8px 24px rgba(26,43,51,0.16)

## Icons
- Library: SF Symbols
- Weight: Regular (default), Medium (emphasis)
- Sizes: 16pt (inline), 24pt (navigation), 32pt (empty states)

## Components Style
- Buttons: Height 52pt, radius 12pt, subtle shadow
- Cards: Radius 16-20pt, photo bleeds to edge
- Inputs: Height 48pt, radius 8pt, 1pt border
- Tab Bar: 49pt + safe area, 0.5pt top border

## Tab Bar Specification (CRITICAL)
MUST have exactly 3 tabs:
```
┌─────────────────────────────────────────┐
│   🏠          📚          ⚙️           │
│   홈          기록        설정          │
└─────────────────────────────────────────┘
```
- Tab 1: 홈 (Home) - SF Symbol: house.fill
- Tab 2: 기록 (Records) - SF Symbol: book.fill
- Tab 3: 설정 (Settings) - SF Symbol: gearshape.fill
- Active color: #87CEEB
- Inactive color: #8A9BA3
- Height: 49pt + 34pt safe area = 83pt total
- Background: #F8FBFD
- Top border: 0.5pt #E5EEF2

## Header Specification
- Left: Hamburger menu (≡) or back button (◀)
- Center: "Wander" logo or screen title
- Right: Empty (NO profile icon)
- Height: 44pt + status bar

Remember this design system. I will ask you to create specific screens next.
```

---

# Part A: Core Screens (Tab Bar Screens)

These prompts create the main tab bar screens from scratch.

---

## SCREEN-01: Home Screen Empty State (SCR-005)

📎 Attach: `wander_ui_scenario.md` > 3.2 홈 화면 레이아웃, 3.4 빈 상태 화면

```
Create the Home Screen (Empty State) for Wander app.

## Critical Requirements
- Remove profile icon from header
- Change tab bar from 4 tabs to 3 tabs
- Change all English text to Korean
- Tab bar must show: 홈, 기록, 설정 (NOT Home, Map, Records, Profile)

## Screen Layout (top to bottom)

### 1. Header
- Left: Hamburger menu icon (≡), 24pt
- Center: "Wander" text logo, Title 1 style, Primary color (#87CEEB)
- Right: EMPTY (no icon, no profile)
- Height: 44pt + status bar
- Background: White

### 2. Action Cards Section
Two cards side by side, 12pt gap:

**Card 1 (Left)**
```
┌────────────────────┐
│ 📷                 │
│ 새 여행 기록하기    │
│ 사진으로 여행 기록  │
└────────────────────┘
```

**Card 2 (Right)**
```
┌────────────────────┐
│ 🗺️                 │
│ 지도에서 보기       │
│ 여행 발자취        │
└────────────────────┘
```

- Background: #F8FBFD (Surface)
- Border: 1pt #E5EEF2
- Radius: 16pt
- Padding: 16pt
- Icon size: 32pt
- Title: Headline style
- Subtitle: Caption, secondary color

### 3. Recent Records Section (Empty State)
- Section title: "최근 기록" (Headline style)
- Empty state illustration: Dashed path + location pin (120pt x 80pt)
- Colors: Primary (#87CEEB) and Border (#E5EEF2)
- Text: "아직 기록이 없어요" (Title 3)
- Subtitle: "첫 번째 여행을 기록해 보세요" (Body, secondary)
- Button: "+ 여행 기록 만들기" (Primary button, 280pt width)
- Centered vertically in remaining space

### 4. Tab Bar (CRITICAL - Must be 3 tabs)
```
┌─────────────────────────────────────────┐
│   🏠          📚          ⚙️           │
│   홈          기록        설정          │
│ (active)                               │
└─────────────────────────────────────────┘
```
- EXACTLY 3 tabs only
- Tab 1: 홈 (house.fill) - ACTIVE state (#87CEEB)
- Tab 2: 기록 (book.fill) - inactive (#8A9BA3)
- Tab 3: 설정 (gearshape.fill) - inactive (#8A9BA3)
- Height: 49pt + 34pt safe area
- Background: #F8FBFD
- Top border: 0.5pt #E5EEF2
- Icon: 24pt, Label: 12pt
- Korean labels only

## Output
React component with Tailwind CSS.
Mobile viewport: 390 x 844 (iPhone 14)
Light mode only.
```

---

## SCREEN-02: Home Screen With Records (SCR-005)

📎 Attach: `wander_ui_scenario.md` > 3.2 홈 화면 레이아웃 (SCR-005)

```
Create the Home Screen (with existing records) for Wander app.

## Critical Requirements
- Tab bar must have exactly 3 tabs (홈, 기록, 설정)
- No profile icon in header
- All text in Korean

## Screen Layout

### 1. Header
- Left: Hamburger menu (≡)
- Center: "Wander" logo (Title 1, Primary)
- Right: EMPTY

### 2. Greeting Section
- Text: "오늘 어떤 이야기를 만들어 볼까요?"
- Style: Title 2, Primary text color
- Top margin: 24pt

### 3. Main Action Card
```
┌─────────────────────────────────────┐
│ 🗺️ 여행 기록 만들기                  │
│                                     │
│ 여행 사진을 선택하면 자동으로        │
│ 동선을 분석해요                     →│
└─────────────────────────────────────┘
```
- Background: #E8F6FC (Primary Pale)
- Radius: 20pt
- Padding: 20pt
- Shadow: Elevation 1
- Arrow icon on right

### 4. Secondary Action Cards (2 cards, side by side)
```
┌───────────────┐ ┌───────────────┐
│ 💬 지금 뭐해? │ │ 📅 이번 주    │
│               │ │ 하이라이트    │
│ 사진 몇 장으로│ │               │
│ 바로 공유     │ │ 주간 요약     │
└───────────────┘ └───────────────┘
```
- Background: Surface (#F8FBFD)
- Border: 1pt #E5EEF2
- Radius: 16pt
- Gap: 12pt

### 5. Recent Records Section
- Title: "최근 기록" (Headline)
- 2 record cards (Airbnb style):

**Record Card**
```
┌─────────────────────────────────────┐
│ [Photo Area - 16:9]                 │
│              ● ○ ○ ○               │
├─────────────────────────────────────┤
│ 🏝️ 제주도 3박4일                    │
│ 2026.01.20 ~ 01.23                  │
│ 📍 12곳 방문 · 🚗 245km             │
└─────────────────────────────────────┘
```
- Radius: 20pt
- Shadow: Elevation 1
- Gap between cards: 20pt

### 6. Tab Bar
- 3 tabs: 홈 (active), 기록, 설정
- Same spec as FIX-01

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Scrollable content, fixed header and tab bar.
```

---

## SCREEN-03: Records Library Screen (SCR-006)

📎 Attach: None (ui_scenario에 SCR-006 전용 섹션 없음 - 아래 레이아웃 참조)

```
Create the Records Library Screen for Wander app.

## Critical Requirements
- Tab bar must have exactly 3 tabs
- 기록 tab must be active

## Screen Layout

### 1. Header
- Title: "기록" (Title 1)
- No back button (this is a tab screen)

### 2. Filter Tabs (horizontal scroll)
- Options: [전체] [최근 여행] [일상 기록]
- Style: Pill chips, radius 20pt
- Active: Primary background (#87CEEB), white text
- Inactive: Surface background, border
- Gap: 8pt
- Padding: 16pt horizontal

### 3. Sections

**Section: 최근 여행**
- Header: "최근 여행" (Headline)
- Horizontal scroll of travel cards
- Card: Photo + Title + Date + Stats

**Section: 최근 일상 기록**
- Header: "최근 일상 기록" (Headline)
- Smaller cards, list style

**Section: 나의 여행 발자취**
- Header: "나의 여행 발자취" (Headline)
- Mini map preview
- "지도에서 보기" link

### 4. Tab Bar
```
┌─────────────────────────────────────────┐
│   🏠          📚          ⚙️           │
│   홈          기록        설정          │
│            (active)                     │
└─────────────────────────────────────────┘
```
- 기록 tab active (#87CEEB)
- Other tabs inactive (#8A9BA3)

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## SCREEN-04: Settings Screen (SCR-007)

📎 Attach: `wander_ui_scenario.md` > 9.2 설정 화면 레이아웃

```
Create the Settings Screen for Wander app.

## Critical: This is a SERVERLESS app
- NO account/profile section
- NO user name or email display
- NO premium badges
- NO logout button
- Tab bar must have 3 tabs: 홈, 기록, 설정

## Screen Layout

### 1. Header
- Title: "설정" (Title 1, large style like iOS Settings)
- No back button (tab screen)

### 2. Settings Groups (iOS Grouped Table View style)

**Group 1: AI 설정**
```
┌─────────────────────────────────────┐
│ 🤖 AI 엔진                      >   │
│    현재: GPT-4o (연결됨)             │
├─────────────────────────────────────┤
│ 🔑 API 키 관리                  >   │
└─────────────────────────────────────┘
```

**Group 2: 앱 설정**
```
┌─────────────────────────────────────┐
│ 🔔 알림 설정                    >   │
├─────────────────────────────────────┤
│ 🗺️ 지도 스타일                  >   │
│    부드러운 테마                     │
├─────────────────────────────────────┤
│ 🔗 공유 설정                    >   │
│    출처 표기: 켜짐                   │
├─────────────────────────────────────┤
│ 💾 데이터 관리                  >   │
├─────────────────────────────────────┤
│ 🔐 권한 설정                    >   │
└─────────────────────────────────────┘
```

**Group 3: 정보**
```
┌─────────────────────────────────────┐
│ ℹ️ 버전 정보                    >   │
│    v1.0.0                           │
├─────────────────────────────────────┤
│ 📜 이용약관                     >   │
├─────────────────────────────────────┤
│ 🔒 개인정보처리방침              >   │
├─────────────────────────────────────┤
│ 💬 문의하기                     >   │
└─────────────────────────────────────┘
```

### 3. Styling
- Group label: Caption, tertiary, left aligned, 8pt margin bottom
- Group background: Surface (#F8FBFD)
- Group radius: 12pt
- Row height: 52pt
- Dividers: 0.5pt, inset 52pt from left
- Chevron (>): Tertiary color
- Subtitle: Caption, tertiary
- Gap between groups: 32pt
- Screen padding: 20pt horizontal

### 4. Tab Bar (CRITICAL)
```
┌─────────────────────────────────────────┐
│   🏠          📚          ⚙️           │
│   홈          기록        설정          │
│                        (active)         │
└─────────────────────────────────────────┘
```
- 설정 tab active (#87CEEB)
- Exactly 3 tabs
- Korean labels

## Elements to REMOVE (do not include)
- ❌ Any account/profile section
- ❌ User avatar, name, or email
- ❌ Premium/subscription section
- ❌ Logout button
- ❌ Any 4th or 5th tab

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Scrollable content, fixed tab bar.
```

---

## SCREEN-05: AI Provider Settings (SCR-016)

📎 Attach: `wander_ui_scenario.md` > 9.4 AI 프로바이더 설정 화면

```
Create the AI Provider Settings Screen for Wander app.

## Critical: BYOK Only
- NO credit purchase option
- NO remaining credits display
- NO pricing buttons
- BYOK is the ONLY way to use AI features

## Screen Layout

### 1. Header (Navigation style)
- Left: ◀ back button (24pt)
- Center: "AI 설정" (Headline)
- Right: Empty

### 2. Info Card
```
┌─────────────────────────────────────┐
│ 💡 본인의 API 키로 AI 기능을        │
│    무료로 이용할 수 있어요           │
│                                     │
│    비용은 각 프로바이더 정책에       │
│    따릅니다.                        │
└─────────────────────────────────────┘
```
- Background: #E8F6FC (Primary Pale)
- Radius: 12pt
- Padding: 16pt
- Margin: 20pt horizontal, 16pt vertical

### 3. Provider List
- Section label: "AI 프로바이더 선택" (Caption, tertiary)

```
┌─────────────────────────────────────┐
│ 🟢 OpenAI                       >   │
│    GPT-4o, GPT-4 Turbo              │
├─────────────────────────────────────┤
│ ⚫ Anthropic                    >   │
│    Claude 3.5 Sonnet, Haiku         │
├─────────────────────────────────────┤
│ ⚫ Azure OpenAI                 >   │
│    Enterprise Scale Models          │
├─────────────────────────────────────┤
│ ⚫ Google Gemini                >   │
│    Gemini 1.5 Pro, Flash            │
├─────────────────────────────────────┤
│ ⚫ xAI                          >   │
│    Grok-1.5                         │
├─────────────────────────────────────┤
│ ⚫ AWS Bedrock                  >   │
│    Llama 3, Claude, Mistral         │
└─────────────────────────────────────┘
```

- Status indicator:
  - 🟢 Green dot = Connected
  - ⚫ Gray dot = Not connected
- List background: Surface (#F8FBFD)
- Radius: 12pt
- Row height: 64pt
- Provider name: Body, primary text
- Models: Caption, tertiary
- Chevron: Tertiary

### 4. Security Notice (bottom)
```
┌─────────────────────────────────────┐
│ ℹ️ API 키는 기기 내에 안전하게       │
│    저장되며 서버로 전송되지          │
│    않습니다.                        │
└─────────────────────────────────────┘
```
- Background: #E3F2FD (Info background)
- Radius: 8pt
- Padding: 12pt
- Caption text

## Elements to REMOVE (do not include)
- ❌ Credit purchase section entirely
- ❌ "잔여 크레딧" display
- ❌ Price buttons (₩1,500, etc.)
- ❌ "또는" divider
- ❌ Any payment-related UI

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## SCREEN-06: General Error Screen (SCR-019)

📎 Attach: `wander_ui_scenario.md` > 10.6 에러 화면 템플릿 (SCR-019)

```
Create the General Error Screen for Wander app.

## Critical Requirements
- Tab bar must have exactly 3 tabs: 홈, 기록, 설정

## Screen Layout (centered vertically)

### 1. Header
- Left: ◀ back button (or ✕ close)
- Center: Empty
- Right: Empty

### 2. Error Content (centered)

**Icon**
- ⚠️ Warning triangle icon
- Size: 64pt
- Color: Warning (#FF9800)

**Title**
- "문제가 발생했어요"
- Title 2 style
- Margin top: 24pt

**Message**
- "일시적인 오류가 발생했습니다."
- "잠시 후 다시 시도해주세요."
- Body style, secondary color
- Text align center
- Max width: 280pt
- Margin top: 12pt

### 3. Action Buttons (centered)
- Gap: 12pt
- Margin top: 32pt

**Primary Button**
- Text: "다시 시도"
- Style: Primary (#87CEEB)
- Width: 200pt
- Height: 52pt
- Radius: 12pt

**Text Button**
- Text: "홈으로"
- Style: Text button, secondary color

### 4. Help Link (bottom)
- "문제가 계속되면 문의하기를 통해 알려주세요"
- Caption, tertiary
- "문의하기" - underlined, primary color
- Bottom padding: 48pt

### 5. Tab Bar (CRITICAL)
```
┌─────────────────────────────────────────┐
│   🏠          📚          ⚙️           │
│   홈          기록        설정          │
└─────────────────────────────────────────┘
```
- All tabs inactive (error state)
- Exactly 3 tabs
- Korean labels only

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

# Part B: Sub Screens (Detail & Modal Screens)

These prompts create detail screens, sheets, and modals.

---

## SCREEN-07: API Key Input Screen (SCR-020)

📎 Attach: None (new screen)

```
Create the API Key Input Screen for Wander app.

## Context
This screen appears when user taps a provider (e.g., OpenAI) from the AI settings list.

## Screen Layout

### 1. Header (Navigation style)
- Left: ◀ back button
- Center: "OpenAI 연결" (Headline) - changes per provider
- Right: "저장" (Primary color, disabled until valid input)

### 2. Provider Icon
- Provider logo/icon
- Size: 64pt
- Centered
- Margin top: 24pt

### 3. Input Section

**Label**
- "API 키를 입력해주세요"
- Body style
- "(sk-로 시작하는 키)" - Caption, tertiary

**Input Field**
```
┌─────────────────────────────────────┐
│ sk-xxxx...xxxx                  👁️ │
└─────────────────────────────────────┘
```
- Height: 48pt
- Background: Surface
- Border: 1pt, focus state 2pt Primary
- Radius: 8pt
- Secure text entry (masked)
- Eye icon toggle visibility
- Monospace font for key display

### 4. Security Notice
```
┌─────────────────────────────────────┐
│ 🔒 API 키는 기기의 Keychain에       │
│    안전하게 저장됩니다               │
│ ✓ 서버로 전송되지 않습니다           │
└─────────────────────────────────────┘
```
- Background: #E3F2FD
- Radius: 8pt
- Padding: 12pt
- Checkmark: Success color (#4CAF50)
- Margin top: 16pt

### 5. Model Selection (optional section)
- Label: "모델 선택" (Caption, tertiary)

```
┌─────────────────────────────────────┐
│ ● GPT-4o                    (추천) │
├─────────────────────────────────────┤
│ ○ GPT-4 Turbo                      │
├─────────────────────────────────────┤
│ ○ GPT-3.5 Turbo                    │
└─────────────────────────────────────┘
```
- Radio buttons, Primary when selected
- "(추천)" badge: Primary color

### 6. Test Button
```
[          연결 테스트          ]
```
- Secondary style
- Full width
- Height: 52pt
- Shows loading spinner when testing

### 7. Test Result States

**Success**
```
✅ 연결 성공!
   사용 가능한 모델: GPT-4o
```
- Success color (#4CAF50)

**Error**
```
❌ 연결 실패
   API 키가 올바르지 않습니다.
```
- Error color (#F44336)

### 8. Help Link
- "API 키는 어디서 찾나요?" →
- Text link, Primary color
- Margin top: 24pt

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show success state after test.
```

---

## SCREEN-08: Data Management Screen (SCR-021)

📎 Attach: None (new screen)

```
Create the Data Management Screen for Wander app.

## Screen Layout

### 1. Header (Navigation style)
- Left: ◀ back button
- Center: "데이터 관리" (Headline)

### 2. Storage Usage Section
```
┌─────────────────────────────────────┐
│ 저장 공간 사용량                     │
│                                     │
│ ████████████░░░░░░░░  1.2GB / 5GB   │
│                                     │
│ · 여행 기록      800MB              │
│ · 캐시          234MB              │
│ · 기타          166MB              │
└─────────────────────────────────────┘
```
- Background: Surface
- Radius: 12pt
- Progress bar: Primary color (#87CEEB)
- Breakdown list: Caption, tertiary

### 3. Data Management Options
```
┌─────────────────────────────────────┐
│ 캐시 삭제                   234MB > │
├─────────────────────────────────────┤
│ 분석 데이터 초기화               >  │
├─────────────────────────────────────┤
│ 모든 기록 삭제                   >  │
└─────────────────────────────────────┘
```
- "모든 기록 삭제" - Error color (#F44336) text
- Row height: 52pt
- Surface background
- Radius: 12pt

### 4. Backup Section
```
┌─────────────────────────────────────┐
│ iCloud 백업                    🔘   │
│ 마지막 백업: 2024.01.15             │
└─────────────────────────────────────┘
```
- Toggle: iOS style, Primary when on
- Subtitle: Caption, tertiary

### 5. Danger Zone (for delete confirmation)
When "모든 기록 삭제" tapped, show modal:
```
╭─────────────────────────────────────╮
│                                     │
│   정말 삭제하시겠어요?               │
│                                     │
│   모든 여행 기록이 영구적으로        │
│   삭제됩니다.                        │
│   이 작업은 되돌릴 수 없습니다.      │
│                                     │
│   [    취소    ] [    삭제    ]     │
│                                     │
╰─────────────────────────────────────╯
```
- "삭제" button: Error color (#F44336)
- Modal background: White, radius 16pt

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## SCREEN-09: Timeline Edit Mode Screen (SCR-012)

📎 Attach: `wander_ui_scenario.md` > 7.5 타임라인 편집 화면 (SCR-012)

```
Create the Timeline Edit Mode Screen for Wander app.

## Context
This is the edit mode of the Analysis Result screen. User can reorder places, edit names, change activity labels, and add memos.

## Screen Layout

### 1. Header
- Left: "취소" text button (Secondary color)
- Center: "편집 모드" (Headline)
- Right: "완료" text button (Primary color)

### 2. Day Header (sticky)
- "📅 Day 1 (1/15)"
- Headline style
- Padding: 16pt vertical

### 3. Editable Place Card
```
┌─────────────────────────────────────┐
│ ≡  📍 제주공항              ✏️  🗑️ │
│    🕐 10:30 · ✈️ 도착               │
│                                     │
│    활동: [ ✈️ 공항/이동 ▾ ]         │
│                                     │
│    ┌───┬───┬───┐  [+ 사진 추가]    │
│    │ 📷│ 📷│ 📷│                   │
│    └───┴───┴───┘                   │
│                                     │
│    메모: 탭하여 추가                │
└─────────────────────────────────────┘
```

**Card Elements**:
- ≡ Drag handle: Left side, tertiary color, for reordering
- ✏️ Edit icon: Opens place name inline edit
- 🗑️ Delete icon: Shows delete confirmation
- Activity dropdown: Current label, tappable
- Photos: 56pt thumbnails with X button overlay
- "+ 사진 추가" button
- Memo field: Placeholder "탭하여 추가"

**Card Styling**:
- Background: Surface (#F8FBFD)
- Radius: 16pt
- Padding: 16pt
- Shadow: Elevation 1

### 4. Connector (between cards)
- Vertical line: 2pt, dashed, border color
- Badge: "32km, 40분" centered on line
- Badge style: Caption, tertiary, white background

### 5. Activity Label Dropdown Options
```
┌─────────────────────────┐
│ ✈️ 공항/이동           │
│ ☕ 카페                │
│ 🍽️ 식사               │
│ 🏖️ 해변               │
│ ⛰️ 등산/산책          │
│ 🛍️ 쇼핑               │
│ 🏛️ 관광지             │
│ 🎭 공연/문화          │
│ 🏨 숙소               │
│ 📍 기타               │
└─────────────────────────┘
```
- Each with pastel background color
- Selected shows checkmark

### 6. Add New Place Button (bottom of list)
```
┌─────────────────────────────────────┐
│           + 새 장소 추가            │
└─────────────────────────────────────┘
```
- Dashed border (2pt, border color)
- Tertiary text color
- Height: 56pt
- Radius: 12pt

### 7. Interactions
- Drag cards to reorder (shadow elevation on drag)
- Tap ✏️ for inline edit
- Tap 🗑️ shows confirmation dialog

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show 2 place cards in edit mode.
```

---

## SCREEN-10: Export Options Sheet (SCR-015)

📎 Attach: `wander_ui_scenario.md` > 8.5 내보내기 플로우, 8.6 내보내기 옵션 시트

```
Create the Export Options Sheet for Wander app.

## Screen Layout

### 1. Sheet Style
- Bottom sheet, ~60% height
- Radius: 20pt (top corners only)
- Handle bar: 36pt x 4pt, centered, #E5EEF2
- Shadow: Elevation 3

### 2. Header
- Title: "내보내기" (Title 3, centered)
- Padding top: 20pt

### 3. Format Selection Section
- Label: "파일 형식" (Caption, tertiary)

**Option Cards (vertical stack, radio style)**

```
┌─────────────────────────────────────┐
│ ●  📝 Markdown (.md)                │
│    블로그 포스팅에 적합              │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ ○  🌐 HTML (.html)                  │
│    웹페이지 형식                     │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ ○  📄 텍스트 (.txt)                 │
│    순수 텍스트                       │
└─────────────────────────────────────┘
```

- Selected: Primary border (2pt), Primary pale background
- Unselected: Border color (1pt), Surface background
- Radio dot: Primary when selected, border when not
- Padding: 16pt
- Radius: 12pt
- Gap: 12pt

### 4. Content Options Section
- Label: "포함 내용" (Caption, tertiary)

```
☑️ 타임라인
☑️ 통계 정보
☐ AI 스토리 (BYOK 연결 필요)
☑️ 사진 파일명
```
- Checkbox: 24pt, Primary when checked
- "(BYOK 연결 필요)" - Caption, tertiary, only shown if not connected
- Disabled checkbox appearance if BYOK not connected

### 5. Source Attribution Note
- "📍 출처 표기가 파일 하단에 포함됩니다"
- Caption, tertiary
- Centered
- Margin top: 12pt

### 6. Action Button
```
[          내보내기 시작          ]
```
- Primary button, full width
- Height: 52pt
- Radius: 12pt
- Bottom safe area padding

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show as overlay on dimmed background.
```

---

## SCREEN-11: AI Story Screen (SCR-013)

📎 Attach: `wander_ui_scenario.md` > 7.1 결과 화면 구조, 10.4.2 AI API 오류

```
Create the AI Story Screen for Wander app.

## Context
This screen appears when user taps "AI 스토리" button from the analysis result screen.
Only available when BYOK (API key) is connected. Shows AI-generated travel narrative based on the timeline data.

## Screen Layout

### 1. Header (Navigation style)
- Left: ◀ back button
- Center: "AI 스토리" (Headline)
- Right: "복사" text button (Primary color)

### 2. Story Container (scrollable)

**Title Section**
```
┌─────────────────────────────────────┐
│                                     │
│  🏝️ 바다와 커피향이 함께한          │
│     제주 여행                       │
│                                     │
│  2026.01.15 ~ 01.18 · 3박 4일       │
│                                     │
└─────────────────────────────────────┘
```
- Title: Title 1 style, Primary text
- Generated by AI based on travel content
- Date range: Caption, secondary

**Story Body**
```
┌─────────────────────────────────────┐
│                                     │
│  비행기가 제주공항에 내리자마자      │
│  느껴지는 바다 냄새. 렌터카를 빌려   │
│  곧장 협재해수욕장으로 향했다.       │
│                                     │
│  에메랄드빛 바다와 하얀 모래사장이   │
│  펼쳐진 풍경에 감탄사가 절로 나왔다. │
│  파도 소리를 들으며 먹은 흑돼지      │
│  바베큐의 맛은 잊을 수 없다.         │
│                                     │
│  ...                                │
│                                     │
└─────────────────────────────────────┘
```
- Body style, primary text
- Line height: 1.7 (reading optimized)
- Paragraph spacing: 20pt
- Background: Surface (#F8FBFD)
- Padding: 20pt
- Radius: 16pt

**Inline Photos (optional)**
- Photos can be embedded between paragraphs
- Photo size: Full width, 16:9 ratio
- Radius: 12pt
- Caption below: Caption style, secondary

### 3. Metadata Footer
```
┌─────────────────────────────────────┐
│  ✨ GPT-4o로 생성됨                  │
│  📅 2026.01.18 15:30                │
└─────────────────────────────────────┘
```
- Caption style, tertiary
- Shows which AI model generated the story
- Generation timestamp

### 4. Action Buttons (bottom, fixed)
```
┌─────────────────────────────────────┐
│ [   📋 복사   ] [   📤 공유   ]     │
│                                     │
│ [       🔄 다시 생성하기       ]    │
└─────────────────────────────────────┘
```
- Copy & Share: Side by side, secondary style
- Regenerate: Full width, text button style
- Bottom safe area padding

### 5. Loading State (while generating)
```
┌─────────────────────────────────────┐
│                                     │
│         🤖                          │
│                                     │
│    스토리를 작성하고 있어요...       │
│                                     │
│    ████████░░░░░░░  45%             │
│                                     │
│    여행의 감동을 담는 중             │
│                                     │
└─────────────────────────────────────┘
```
- Centered vertically
- Robot icon: 48pt, animated bounce
- Progress bar: Primary color
- Loading message: Body, secondary

### 6. Error State
```
┌─────────────────────────────────────┐
│                                     │
│         ⚠️                          │
│                                     │
│    스토리 생성에 실패했어요          │
│                                     │
│    API 요청 한도에 도달했습니다.     │
│    잠시 후 다시 시도해주세요.        │
│                                     │
│    [      다시 시도      ]          │
│    [    기본 정보로 보기   ]         │
│                                     │
└─────────────────────────────────────┘
```
- Warning icon: 48pt, Warning color (#FF9800)
- Error message: Body, secondary
- Retry button: Primary style
- Fallback button: Text button

### 7. BYOK Not Connected State
```
┌─────────────────────────────────────┐
│                                     │
│         🔑                          │
│                                     │
│    AI 기능을 사용하려면              │
│    API 키 연결이 필요해요            │
│                                     │
│    [     AI 설정으로 이동     ]      │
│                                     │
└─────────────────────────────────────┘
```
- Key icon: 48pt, Primary color
- Button navigates to SCR-016

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show the success state with generated story content.
```

---

## SCREEN-12: Share Settings Screen (SCR-017)

📎 Attach: `wander_ui_scenario.md` > 8.3.4 출처 설정 옵션 (설정 화면)

```
Create the Share Settings Screen for Wander app.

## Context
This screen is accessed from Settings > 공유 설정.
Allows user to configure source attribution options when sharing content.

## Screen Layout

### 1. Header (Navigation style)
- Left: ◀ back button
- Center: "공유 설정" (Headline)
- Right: Empty

### 2. Source Attribution Toggle Section
```
┌─────────────────────────────────────┐
│  출처 표기                          │
│                                     │
│ ┌─────────────────────────────────┐ │
│ │ 📍 공유 시 출처 포함        🔘  │ │
│ ├─────────────────────────────────┤ │
│ │                                 │ │
│ │ 공유하는 텍스트 끝에 앱 출처가  │ │
│ │ 자동으로 추가됩니다.            │ │
│ │                                 │ │
│ │ SNS에서 자유롭게 편집/삭제할    │ │
│ │ 수 있어요.                      │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```
- Section label: "출처 표기" (Caption, tertiary)
- Toggle: iOS style, Primary (#87CEEB) when on
- Description: Caption, secondary
- Card background: Surface (#F8FBFD)
- Card radius: 12pt
- Padding: 16pt

### 3. Source Style Selection (radio group)
- Label: "출처 문구 스타일" (Caption, tertiary)
- Only visible when toggle is ON

```
┌─────────────────────────────────────┐
│ ● 📍 Wander로 기록했어요            │
├─────────────────────────────────────┤
│ ○ Made with Wander ✨               │
├─────────────────────────────────────┤
│ ○ via Wander                        │
├─────────────────────────────────────┤
│ ○ #Wander                           │
└─────────────────────────────────────┘
```
- Radio button: Primary when selected
- Row height: 52pt
- Surface background
- Radius: 12pt
- Selected row: Primary pale background (#E8F6FC)

### 4. Image Watermark Options
- Label: "이미지 카드 출처" (Caption, tertiary)

```
┌─────────────────────────────────────┐
│ ● 워터마크 (이미지 내)               │
│   이미지 우하단에 작은 로고          │
├─────────────────────────────────────┤
│ ○ 캡션으로 (편집 가능)               │
│   이미지와 별도의 텍스트로 추가       │
├─────────────────────────────────────┤
│ ○ 표시 안 함                         │
│   출처 없이 이미지만                 │
└─────────────────────────────────────┘
```
- Radio with description
- Description: Caption, tertiary
- Row height: 72pt (taller for description)

### 5. Preview Section
- Label: "미리보기" (Caption, tertiary)

```
┌─────────────────────────────────────┐
│  텍스트 공유 예시                    │
│ ┌─────────────────────────────────┐ │
│ │ 🏝️ 제주도 3박 4일 여행           │ │
│ │                                 │ │
│ │ 📅 Day 1 (1/15)                 │ │
│ │ 📍 제주공항 → 협재해수욕장       │ │
│ │                                 │ │
│ │ ─────────────────               │ │
│ │ 📍 Wander로 기록했어요          │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
```
- Preview updates when style selection changes
- Background: #F8FBFD
- Border: 1pt dashed, border color
- Radius: 8pt
- Caption style text

### 6. Info Note (bottom)
```
┌─────────────────────────────────────┐
│ 💡 출처를 포함하면 더 많은 사람들이  │
│    Wander를 알게 돼요               │
└─────────────────────────────────────┘
```
- Background: #E8F6FC (Primary Pale)
- Radius: 8pt
- Padding: 12pt
- Caption style
- Light bulb icon: Primary color

## Styling
- Screen padding: 20pt horizontal
- Section gap: 32pt
- Scrollable content
- No tab bar (sub-screen)

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show with source attribution enabled and first style selected.
```

---

# Checklist

## Part A: Core Screens (Tab Bar)
- [ ] SCREEN-01: Home Screen Empty State (SCR-005)
- [ ] SCREEN-02: Home Screen With Records (SCR-005)
- [ ] SCREEN-03: Records Library Screen (SCR-006)
- [ ] SCREEN-04: Settings Screen (SCR-007)
- [ ] SCREEN-05: AI Provider Settings (SCR-016)
- [ ] SCREEN-06: General Error Screen (SCR-019)

## Part B: Sub Screens (Detail & Modal)
- [ ] SCREEN-07: API Key Input Screen (SCR-020)
- [ ] SCREEN-08: Data Management Screen (SCR-021)
- [ ] SCREEN-09: Timeline Edit Mode (SCR-012)
- [ ] SCREEN-10: Export Options Sheet (SCR-015)
- [ ] SCREEN-11: AI Story Screen (SCR-013)
- [ ] SCREEN-12: Share Settings Screen (SCR-017)

## Verification Checklist (After Each Screen)
- [ ] Tab bar has exactly 3 tabs (홈, 기록, 설정)
- [ ] Tab labels are in Korean
- [ ] No profile icon in header
- [ ] No premium/diamond badges
- [ ] No credit purchase UI
- [ ] No logout button
- [ ] All UI text is in Korean
- [ ] Primary color is #87CEEB

---

*Document Version: v3.0*
*Last Updated: 2026-01-31*
*Generated by Claude - Wander UI Generation Prompts*
