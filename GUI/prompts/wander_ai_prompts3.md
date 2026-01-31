# Wander AI UI Generation Prompts v3.0 (Supplementary)

## Document Info
- **Version**: v3.0 (Supplementary)
- **Date**: 2026-01-31
- **Purpose**: Additional screens not covered in prompts2.md
- **Base**: wander_ai_prompts2.md v3.0

---

## Usage Guide

1. **PROMPT 0 (Design System v2.0)** must be input first (see prompts2.md)
2. These are supplementary screens for complete app coverage

---

## SCREEN-13: Weekly Photo Collection Screen

📎 Attach: `wander_ui_scenario.md` > 6.2 주간 사진 자동 수집 화면

```
Create the Weekly Photo Collection Screen for Wander app.

## Context
This screen is for the "이번 주 하이라이트" (This Week's Highlight) feature.
It automatically finds photos with GPS from the past week and groups them by day.
Users can select/deselect photos before generating a weekly summary.

## Screen Layout

### 1. Header (Navigation style)
- Left: ✕ close button (24pt)
- Center: "이번 주 하이라이트" (Headline)
- Right: "완료" text button (Primary color, disabled if no photos selected)

### 2. Date Range Banner
```
┌─────────────────────────────────────┐
│                                     │
│  📅 1/20 (월) ~ 1/26 (일)           │
│                                     │
│  GPS가 있는 사진 23장을              │
│  자동으로 찾았어요                   │
│                                     │
└─────────────────────────────────────┘
```
- Background: Primary Pale (#E8F6FC)
- Radius: 12pt
- Padding: 16pt
- Date: Title 3 style
- Description: Body, secondary

### 3. Day Sections (scrollable)

**Day Header**
- Format: "월요일 (4장)" or "수요일 (사진 없음)"
- Style: Headline, left aligned
- Margin top: 24pt (between days)

**Photo Grid**
```
┌───┬───┬───┬───┐
│ ✓ │ ✓ │ ✓ │ ✓ │
└───┴───┴───┴───┘
```
- 4 columns
- Thumbnail size: (screen width - 48) / 4 - 4 = ~80pt
- Gap: 4pt
- Radius: 8pt
- Selected: Blue checkmark overlay (top-right corner)
- Checkmark background: Primary (#87CEEB), 20pt circle
- Tap to toggle selection

**Empty Day**
- Text: "(사진 없음)" in Caption, tertiary
- No grid shown

### 4. Selection State

**All photos selected by default**
- Tap to deselect
- Tap again to re-select

**Selection Counter** (sticky at bottom of scroll area)
```
┌─────────────────────────────────────┐
│  23장 중 21장 선택됨                 │
└─────────────────────────────────────┘
```
- Caption style, centered
- Background: Surface, top border

### 5. Bottom Action
```
┌─────────────────────────────────────┐
│  [    갤러리에서 더 추가    ]        │
└─────────────────────────────────────┘
```
- Secondary style button
- Full width with 20pt margin
- Opens photo picker to add more photos
- Safe area padding below

### 6. Empty State (No GPS photos this week)
```
┌─────────────────────────────────────────┐
│                                         │
│              📍                         │
│                                         │
│    이번 주에 위치 정보가 있는           │
│    사진이 없어요                        │
│                                         │
│    사진을 직접 선택해서                 │
│    주간 요약을 만들어 보세요            │
│                                         │
│    [     사진 선택하기     ]            │
│                                         │
└─────────────────────────────────────────┘
```
- Pin icon: 48pt, Primary color
- Text: Body, secondary, center aligned
- Button: Primary style

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show state with multiple days of photos, some selected.
```

---

## SCREEN-14: Place Detail Sheet

📎 Attach: `wander_ui_scenario.md` > 7.3 타임라인 상호작용

```
Create the Place Detail Bottom Sheet for Wander app.

## Context
This bottom sheet appears when user taps a place card in the timeline of the result screen (SCR-010).
Shows detailed information about a specific place visit.

## Sheet Layout

### 1. Sheet Style
- Bottom sheet, ~50% height
- Radius: 20pt (top corners only)
- Handle bar: 36pt x 4pt, centered, #E5EEF2
- Shadow: Elevation 3
- Drag to dismiss

### 2. Place Header
```
┌─────────────────────────────────────┐
│  📍 협재해수욕장                     │
│  🏖️ 해변                            │
│                                     │
│  제주특별자치도 제주시 한림읍         │
│  협재리 2497-1                       │
│                                     │
│  🕐 13:00 ~ 15:30 (2시간 30분)      │
└─────────────────────────────────────┘
```
- Place name: Title 2
- Activity label: Caption with colored badge (Beach: #E0F4F8)
- Address: Body, secondary (tappable to copy)
- Time: Caption, tertiary

### 3. Photo Gallery Section
- Label: "사진 8장" (Caption, tertiary)

```
┌─────────────────────────────────────┐
│ ┌─────────────────────────────────┐ │
│ │                                 │ │
│ │      [Main Photo 16:9]          │ │
│ │                                 │ │
│ └─────────────────────────────────┘ │
│                                     │
│ ┌───┬───┬───┬───┬───┬───┐          │
│ │ 📷│ 📷│ 📷│ 📷│ 📷│+3│          │
│ └───┴───┴───┴───┴───┴───┘          │
└─────────────────────────────────────┘
```
- Main photo: Full width, 16:9, radius 12pt
- Thumbnails: 56pt, radius 8pt, horizontal scroll
- "+N" badge for overflow: Primary background, white text
- Tap any photo to open full-screen viewer

### 4. Action Buttons
```
┌──────────────┬──────────────┐
│  🗺️ 지도에서   │  ✏️ 메모     │
│     보기      │    추가      │
└──────────────┴──────────────┘
```
- Two buttons side by side
- Secondary style
- Height: 44pt
- Gap: 12pt

### 5. Memo Section (if memo exists)
```
┌─────────────────────────────────────┐
│  💬 메모                            │
│                                     │
│  "물이 정말 맑고 예뻤다.            │
│   다음에 또 오고 싶은 곳!"          │
│                                     │
└─────────────────────────────────────┘
```
- Background: Surface (#F8FBFD)
- Radius: 8pt
- Padding: 12pt
- Caption label, Body text

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show as overlay on dimmed background.
```

---

## SCREEN-15: Photo Viewer

📎 Attach: None (common component)

```
Create the Full-Screen Photo Viewer for Wander app.

## Context
Opens when user taps a photo thumbnail anywhere in the app.
Supports swipe navigation, zoom, and metadata view.

## Screen Layout (Full Screen, Dark Background)

### 1. Header (overlay on photo)
```
┌─────────────────────────────────────┐
│  ✕                           ℹ️     │
│                                     │
```
- Background: Gradient from black (top) to transparent
- Close button: Left, white, 24pt
- Info button: Right, white, 24pt (toggles metadata)
- Fade in/out with tap

### 2. Photo Display
```
┌─────────────────────────────────────┐
│                                     │
│                                     │
│         [Full Screen Photo]         │
│                                     │
│                                     │
└─────────────────────────────────────┘
```
- Photo centered and aspect-fit
- Background: Black (#000000)
- Pinch to zoom (up to 3x)
- Double-tap to toggle zoom
- Pan when zoomed

### 3. Photo Counter (bottom center)
```
│           3 / 8                     │
```
- Style: Caption, white, center
- Shows current index / total

### 4. Navigation
- Swipe left/right to navigate between photos
- Smooth animation

### 5. Metadata Panel (toggle with ℹ️)
```
┌─────────────────────────────────────┐
│  📷 사진 정보                        │
│                                     │
│  📅 2026.01.15 13:24               │
│  📍 제주시 한림읍 협재리             │
│     33.3942° N, 126.2397° E        │
│  📱 iPhone 15 Pro                   │
│  🔲 4032 x 3024                     │
└─────────────────────────────────────┘
```
- Bottom sheet style, ~30% height
- Background: Dark gray (#1A1A1A)
- Text: White/light gray
- Radius: 16pt (top corners)

### 6. Gestures
- Tap: Toggle header/footer visibility
- Swipe down: Close viewer
- Pinch: Zoom
- Double-tap: Toggle 2x zoom

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show photo with metadata panel visible.
```

---

## SCREEN-16: Image Card Style Selection

📎 Attach: `wander_ui_scenario.md` > 8.4 공유 카드 이미지 옵션

```
Create the Image Card Style Selection Screen for Wander app.

## Context
This screen appears when user chooses "이미지 카드" from share options.
Allows customization of the share card before sharing to SNS.

## Screen Layout

### 1. Header (Navigation style)
- Left: ◀ back button
- Center: "카드 스타일" (Headline)
- Right: "공유" text button (Primary color)

### 2. Card Preview
```
┌─────────────────────────────────────┐
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │    [Live Card Preview]      │   │
│  │                             │   │
│  │    🗺️ Map + 📊 Stats        │   │
│  │                        🏷️   │   │
│  │                    Wander   │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
```
- Card preview: Centered, with shadow
- Preview updates live as options change
- Aspect ratio: 4:5 (Instagram optimal)
- Margin: 20pt all sides

### 3. Style Selection
- Label: "스타일" (Caption, tertiary)

```
┌─────────┬─────────┬─────────┐
│  심플   │ 사진중심 │타임라인 │
│   ✓     │         │         │
└─────────┴─────────┴─────────┘
```
- Horizontal segment control
- Selected: Primary background, white text
- Unselected: Surface background, primary text
- Height: 36pt
- Radius: 8pt

### 4. Background Color
- Label: "배경색" (Caption, tertiary)

```
⚪ ⚫ 🔵 🟢 🟡 🟠 🔴 🟣
```
- Color circles: 32pt diameter
- Selected: 2pt Primary border
- Gap: 12pt
- Horizontal scroll if needed

Colors:
- White (#FFFFFF)
- Black (#1A1A1A)
- Blue (#87CEEB)
- Green (#A8E6CF)
- Yellow (#FFE66D)
- Orange (#FFB347)
- Red (#FF6B6B)
- Purple (#DDA0DD)

### 5. Display Info (Checkboxes)
- Label: "표시 정보" (Caption, tertiary)

```
┌─────────────────────────────────────┐
│ ☑️ 지도        ☑️ 날짜             │
│ ☑️ 통계        ☐ 정확한 주소       │
│ ☑️ 장소명                          │
└─────────────────────────────────────┘
```
- Checkbox: 24pt, Primary when checked
- Two columns layout
- Surface background
- Radius: 8pt
- Padding: 12pt

### 6. Source Attribution
- Label: "출처 표기" (Caption, tertiary)

```
┌─────────────────────────────────────┐
│ ● 워터마크 (이미지 내)               │
│ ○ 캡션으로 (편집 가능)               │
│ ○ 표시 안 함                         │
└─────────────────────────────────────┘
```
- Radio buttons
- Surface background
- Radius: 8pt

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show with "심플" style selected and preview.
```

---

## SCREEN-17: Settings Sub-Screens

### SCREEN-17A: Notification Settings

📎 Attach: None

```
Create the Notification Settings Screen for Wander app.

## Screen Layout

### 1. Header
- Left: ◀ back button
- Center: "알림 설정" (Headline)

### 2. Main Toggles
```
┌─────────────────────────────────────┐
│  알림 허용                       🔘 │
│  모든 알림을 켜거나 끕니다           │
└─────────────────────────────────────┘
```
- Master toggle at top
- When off, other options are disabled/dimmed

### 3. Notification Types
```
┌─────────────────────────────────────┐
│  📅 추억 리마인드               🔘  │
│  "1년 전 오늘" 알림                 │
├─────────────────────────────────────┤
│  📍 주간 요약 알림              🔘  │
│  매주 일요일 하이라이트 알림        │
├─────────────────────────────────────┤
│  🤖 분석 완료 알림              🔘  │
│  백그라운드 분석 완료 시            │
└─────────────────────────────────────┘
```
- Toggle: iOS style, Primary when on
- Title: Body
- Description: Caption, tertiary
- Surface background, radius 12pt

### 4. Reminder Time (if 추억 리마인드 on)
```
┌─────────────────────────────────────┐
│  알림 시간                    오전 9시 > │
└─────────────────────────────────────┘
```
- Opens time picker when tapped

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

### SCREEN-17B: Map Style Settings

📎 Attach: None

```
Create the Map Style Settings Screen for Wander app.

## Screen Layout

### 1. Header
- Left: ◀ back button
- Center: "지도 스타일" (Headline)

### 2. Map Preview
```
┌─────────────────────────────────────┐
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │    [Map Preview]            │   │
│  │                             │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```
- Live preview of selected style
- Height: 200pt
- Radius: 12pt

### 3. Style Options (Radio)
```
┌─────────────────────────────────────┐
│ ● 기본                              │
│   Apple Maps 기본 스타일            │
├─────────────────────────────────────┤
│ ○ 부드러운 테마                     │
│   파스텔 톤, Wander 브랜드 컬러     │
├─────────────────────────────────────┤
│ ○ 위성                              │
│   위성 이미지 기반                  │
├─────────────────────────────────────┤
│ ○ 하이브리드                        │
│   위성 + 도로/라벨                  │
└─────────────────────────────────────┘
```
- Radio button: Primary when selected
- Surface background, radius 12pt
- Row height: 64pt

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show with "부드러운 테마" selected.
```

---

### SCREEN-17C: Permission Settings

📎 Attach: `wander_ui_scenario.md` > 10.2 권한 관련 예외 처리

```
Create the Permission Settings Screen for Wander app.

## Screen Layout

### 1. Header
- Left: ◀ back button
- Center: "권한 설정" (Headline)

### 2. Permission Status Cards

**Photo Permission**
```
┌─────────────────────────────────────┐
│  📷 사진 접근                        │
│                                     │
│  ✅ 전체 접근 허용됨                 │
│                                     │
│  앱이 모든 사진에 접근할 수 있어요   │
│                                     │
│  [     iOS 설정에서 변경     ]       │
└─────────────────────────────────────┘
```

**Location Permission**
```
┌─────────────────────────────────────┐
│  📍 위치 접근                        │
│                                     │
│  ⚠️ 허용 안 됨                       │
│                                     │
│  위치 권한을 허용하면 사진의 GPS     │
│  정보를 더 정확하게 분석할 수 있어요 │
│                                     │
│  [     권한 허용하기     ]           │
└─────────────────────────────────────┘
```

### 3. Status Indicators
- ✅ Allowed: Success color (#4CAF50)
- ⚠️ Limited/Denied: Warning color (#FF9800)
- ❌ Denied: Error color (#F44336)

### 4. Card Styling
- Surface background
- Radius: 12pt
- Padding: 16pt
- Gap between cards: 16pt

### 5. Info Note
```
┌─────────────────────────────────────┐
│ ℹ️ 권한을 변경하면 앱이 재시작될     │
│    수 있습니다                       │
└─────────────────────────────────────┘
```
- Info background (#E3F2FD)
- Radius: 8pt
- Caption style

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show with photo allowed, location denied.
```

---

# Checklist

## Supplementary Screens
- [ ] SCREEN-13: Weekly Photo Collection (P1)
- [ ] SCREEN-14: Place Detail Sheet (P2)
- [ ] SCREEN-15: Photo Viewer (P2)
- [ ] SCREEN-16: Image Card Style Selection (P2)
- [ ] SCREEN-17A: Notification Settings (P3)
- [ ] SCREEN-17B: Map Style Settings (P3)
- [ ] SCREEN-17C: Permission Settings (P3)

---

*Document Version: v3.0 (Supplementary)*
*Last Updated: 2026-01-31*
