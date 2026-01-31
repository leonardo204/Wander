# Wander AI UI Generation Prompts

## 사용 가이드

### 사용 방법
1. **PROMPT 0 (디자인 시스템)** 을 가장 먼저 입력
2. 원하는 화면의 프롬프트를 복사하여 입력
3. 필요시 첨부 문서 섹션을 함께 복사하여 첨부

### 첨부 문서 표기법
```
📎 첨부 필요: [문서명] > [섹션명]
```
해당 표기가 있으면 지정된 문서의 섹션을 프롬프트와 함께 첨부하세요.

### 권장 도구
- Google AI Studio (Build Mode)
- Google Stitch (Experimental Mode)
- Firebase Studio

---

## PROMPT 0: 디자인 시스템 (필수 - 최초 1회)

> ⚠️ **모든 화면 생성 전에 반드시 먼저 입력하세요**

📎 첨부 필요: 없음 (프롬프트에 포함됨)

```
You are a senior UI/UX designer creating a mobile app called "Wander".

# App Overview
Wander is a travel photo diary app that analyzes photo metadata (GPS, time) to automatically create travel stories and timelines.

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

Remember this design system. I will ask you to create specific screens next.
```

---

## PROMPT 1: 스플래시 화면

📎 첨부 필요: 없음

```
Create the Splash Screen for Wander app.

## Screen Requirements

### Layout (centered)
- App icon placeholder (80pt, centered)
- App name "Wander" below icon
- Subtle loading indicator (optional)

### Styling
- Background: #E8F6FC (Primary Pale)
- Logo/Text color: #87CEEB (Primary)
- Clean, minimal, no other elements

### Specs
- Full screen, no safe area content
- Vertically and horizontally centered

## Output
Generate as a React component with Tailwind CSS.
Mobile viewport: 390 x 844 (iPhone 14)
Light mode only.
```

---

## PROMPT 2: 온보딩 화면 1 - 서비스 소개

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 2.2 (온보딩 화면 상세) - 참고용

```
Create Onboarding Screen 1 (Service Introduction) for Wander app.

## Screen Requirements

### Layout (top to bottom)

1. **Illustration Area** (top 40% of screen)
   - Abstract illustration showing: Photos → Map pins → Story
   - Use primary colors (#87CEEB, #E8F6FC)
   - Simple, clean line art style

2. **Text Content** (centered)
   - Title: "사진 몇 장이면 충분해요"
   - Subtitle (secondary text color):
     "여행인지, 일상인지,
     AI가 자동으로 파악하고
     스토리로 만들어 드려요"

3. **Page Indicator**
   - 3 dots: ● ○ ○ (first active)
   - Active: #87CEEB
   - Inactive: #E5EEF2

4. **Button** (bottom, with safe area padding)
   - Full width primary button
   - Text: "다음"
   - Height: 52pt, radius: 12pt

### Specs
- Background: #FFFFFF
- Content padding: 20pt horizontal
- Button bottom padding: 34pt (safe area)

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## PROMPT 3: 온보딩 화면 2 - 사진 권한 요청

📎 첨부 필요: 없음

```
Create Onboarding Screen 2 (Photo Permission) for Wander app.

## Screen Requirements

### Layout

1. **Icon** (top, centered)
   - Large photo icon (SF Symbol: photo.fill)
   - Size: 64pt
   - Color: #87CEEB

2. **Title**
   - "사진에 접근할 수 있도록 허용해 주세요"
   - Style: Title 2 (22pt Bold)

3. **Info Box** (Surface background)
   - Border radius: 12pt
   - Padding: 16pt
   - Content (with bullet points):
     • "사진의 촬영 시간과 위치 정보를 분석합니다"
     • "사진은 기기 내에서만 처리되며 서버로 전송되지 않습니다"
   - Text: Body style, secondary color

4. **Page Indicator**
   - 3 dots: ○ ● ○ (second active)

5. **Button**
   - Primary button: "사진 접근 허용"
   - Full width

### Specs
- Background: #FFFFFF
- Emphasize privacy message

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## PROMPT 4: 온보딩 화면 3 - 위치 권한 요청

📎 첨부 필요: 없음

```
Create Onboarding Screen 3 (Location Permission) for Wander app.

## Screen Requirements

### Layout

1. **Icon**
   - Location icon (SF Symbol: location.fill)
   - Size: 64pt
   - Color: #87CEEB

2. **Title**
   - "위치 정보 사용을 허용하면 더 정확한 분석이 가능해요"

3. **Info Box**
   - Same style as previous screen
   - Content:
     • "GPS 좌표를 주소로 변환"
     • "장소 이름 자동 인식"
     • "위치 정보는 기기에서만 처리됩니다"

4. **Optional Notice**
   - Light bulb icon + text
   - "💡 허용하지 않아도 기본 기능 사용이 가능합니다"
   - Tertiary text color

5. **Page Indicator**
   - 3 dots: ○ ○ ● (third active)

6. **Buttons** (stacked)
   - Primary: "위치 사용 허용"
   - Secondary (text only): "허용하지 않고 계속"

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## PROMPT 5: 홈 화면 (메인)

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 3.2 (홈 화면 레이아웃)

```
Create the Home Screen for Wander app.

## Screen Requirements

### Layout (top to bottom)

1. **Header** (sticky)
   - Left: "Wander" text logo (Title 1 style, Primary color)
   - Right: Settings gear icon (24pt, secondary color)
   - Height: 44pt + status bar

2. **Greeting Section**
   - Text: "오늘 어떤 이야기를 만들어 볼까요?"
   - Style: Title 2, primary text color
   - Top margin: 24pt

3. **Main Action Card**
   - Background: #E8F6FC (Primary Pale)
   - Border radius: 20pt
   - Padding: 20pt
   - Content:
     - Icon + Title: "🗺️ 여행 기록 만들기"
     - Subtitle: "여행 사진을 선택하면 자동으로 동선을 분석해요"
     - Right arrow indicator
   - Shadow: Elevation 1

4. **Secondary Action Cards** (2 cards, side by side)
   - Gap: 12pt between cards
   - Each card:
     - Background: Surface (#F8FBFD)
     - Border: 1pt #E5EEF2
     - Radius: 16pt
     - Padding: 16pt
   - Card 1: "💬 지금 뭐해?" + "사진 몇 장으로 바로 공유"
   - Card 2: "📅 이번 주 하이라이트" + "주간 요약"

5. **Recent Records Section**
   - Section header: "최근 기록" (Headline style)
   - Record cards (Airbnb style):

     Card structure:
     - Photo area: 4:3 ratio, radius 16pt (top corners)
     - Carousel dots: ● ○ ○ ○
     - Content padding: 16pt
     - Title: "🏝️ 제주도 3박4일" (Title 3)
     - Date: "2026.01.20 ~ 01.23" (Caption, secondary)
     - Stats: "📍 12곳 방문 · 🚗 245km" (Body Small)

   - Show 2 cards with 20pt gap

6. **Tab Bar** (fixed bottom)
   - Height: 49pt + safe area
   - Background: Surface with blur
   - Border top: 0.5pt
   - 3 tabs:
     - 🏠 홈 (Active - Primary color)
     - 📚 기록 (Inactive - Tertiary)
     - ⚙️ 설정 (Inactive - Tertiary)
   - Icon: 24pt, Label: 12pt

### Scrolling
- Content scrollable
- Header and Tab bar fixed

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Include placeholder images for photo areas.
```

---

## PROMPT 6: 홈 화면 - 빈 상태

📎 첨부 필요: 없음

```
Create the Home Screen Empty State for Wander app.

## Screen Requirements

Same as Home Screen but replace "Recent Records" section with:

### Empty State
- Illustration: Simple line art (photo → map pin)
- Size: 120pt x 120pt
- Colors: Primary (#87CEEB) and border (#E5EEF2)

- Title: "아직 기록이 없어요"
- Subtitle: "첫 번째 여행을 기록해 보세요"
- Text colors: Primary for title, Secondary for subtitle

- CTA Button (optional): "여행 기록 만들기" (smaller, secondary style)

### Placement
- Centered in the remaining space below secondary action cards
- Vertical padding: 40pt

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## PROMPT 7: 사진 선택 화면

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 4.2, 4.3 (사진 선택 화면)

```
Create the Photo Selection Screen for Wander app.

## Screen Requirements

### Header (Navigation Bar style)
- Left: ✕ close button (24pt)
- Center: "사진 선택" (Headline)
- Right: "완료(12)" - Primary color when count > 0, disabled color when 0
- Height: 44pt
- Border bottom: 0.5pt

### Search Bar
- Placeholder: "🔍 날짜 또는 장소로 검색"
- Background: Surface
- Border: 1pt
- Radius: 8pt
- Height: 40pt
- Margin: 16pt horizontal, 12pt vertical

### Filter Chips (horizontal scroll)
- Two chips:
  - "📅 기간 선택"
  - "📍 위치 필터"
- Style: Surface background, border, radius 20pt (pill shape)
- Padding: 8pt 16pt
- Gap: 8pt

### Photo Grid
- 4 columns
- Gap: 2pt
- Photos: Square aspect ratio
- Selected state:
  - Blue overlay (Primary, 20% opacity)
  - Checkmark badge top-left corner
  - Badge: Circle, Primary background, white checkmark
  - Badge shows selection number (1, 2, 3...)

### Month Header (sticky while scrolling)
- Text: "2026년 1월" (Headline)
- Background: Background color with slight transparency
- Padding: 12pt horizontal

### Bottom Preview Bar
- Height: 72pt
- Background: Surface
- Border top: 0.5pt
- Horizontal scroll of selected thumbnails
- Thumbnail size: 48pt square, radius 8pt
- Gap: 8pt
- Padding: 12pt

### Sample Data
- Show ~16 photos in grid
- 5 photos selected (numbered 1-5)
- 5 thumbnails in bottom preview

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Use placeholder images with varied colors.
```

---

## PROMPT 8: 날짜 선택기 (바텀 시트)

📎 첨부 필요: 없음

```
Create the Date Range Picker Bottom Sheet for Wander app.

## Screen Requirements

### Sheet Style
- Background: Surface Elevated (#FFFFFF)
- Border radius: 20pt (top corners only)
- Handle bar: 36pt width, 4pt height, centered, #E5EEF2

### Header
- Title: "기간 선택" (Title 3, centered)
- Padding top: 20pt

### Quick Select Chips (horizontal scroll)
- Options: [오늘] [이번 주] [이번 달] [최근 7일] [최근 30일]
- Style: Outlined chips, radius 20pt
- Selected: Primary background, white text

### Calendar
- Month header: "◀ 2026년 1월 ▶"
- Day labels: 일 월 화 수 목 금 토
- Grid: 7 columns
- Date cells:
  - Normal: Primary text
  - Selected range: Primary Pale background
  - Start/End: Primary background, white text
  - Outside month: Tertiary text
  - Today: Primary border (outline)

### Selected Range Display
- Text: "1/16 ~ 1/23 (8일)"
- Style: Body, centered

### Action Buttons
- Row with 2 buttons, gap 12pt
- Left: "초기화" (Secondary)
- Right: "적용" (Primary)
- Button height: 52pt

### Specs
- Sheet height: ~60% of screen
- Padding: 20pt horizontal
- Button area padding bottom: 34pt (safe area)

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show sheet overlaying a dimmed background.
```

---

## PROMPT 9: 분석 중 화면

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 4.5 (분석 중 화면)

```
Create the Analyzing Screen for Wander app.

## Screen Requirements

### Layout (centered vertically)

1. **Loading Animation**
   - Circular progress or pulsing animation
   - Size: 80pt
   - Color: Primary (#87CEEB)
   - Style: Clean, minimal

2. **Status Text**
   - Main: "사진을 분석하고 있어요..." (Title 3)
   - Color: Primary text

3. **Progress Bar**
   - Width: 80% of screen
   - Height: 4pt
   - Background: #E5EEF2
   - Fill: Primary (#87CEEB)
   - Radius: 2pt
   - Progress: 60%

4. **Progress Percentage**
   - "60%" below progress bar
   - Caption style, secondary color

5. **Current Step**
   - "📍 위치 정보 추출 중..."
   - Body style, secondary color
   - Animated ellipsis (optional)

6. **Privacy Notice** (bottom)
   - "💡 Wander는 모든 처리를 기기 내에서 수행해요"
   - Caption style, tertiary color
   - Bottom padding: 48pt

### Background
- Clean white (#FFFFFF)
- No other decorative elements

### Animation States (for reference)
Progress messages cycle through:
- 0-20%: "📸 사진 메타데이터 읽는 중..."
- 20-40%: "📍 위치 정보 추출 중..."
- 40-60%: "🗺️ 주소 정보 변환 중..."
- 60-80%: "📊 동선 분석 중..."
- 80-100%: "✨ 결과 정리 중..."

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show 60% progress state.
```

---

## PROMPT 10: 분석 결과 화면

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 7.1, 7.2 (결과 화면)

```
Create the Analysis Result Screen for Wander app.

## Screen Requirements

### Header
- Left: ✕ close button
- Center (stacked):
  - "제주도 3박4일" (Headline)
  - "2026.01.15 ~ 01.18" (Caption, secondary)
- Right: "···" more menu icon
- Background: Transparent/blur

### Map Section
- Height: 200pt
- Placeholder map with route visualization
- 4 map pins connected by dotted line
- Colors: Primary (#87CEEB) for pins and route
- Bottom right: "확대보기" text button
- Border radius: 0 (full width)

### Stats Bar
- Background: Surface (#F8FBFD)
- 3 columns, equal width:
  - "🚗" + "245km" + "이동"
  - "📍" + "12곳" + "방문"
  - "📸" + "50장" + "사진"
- Numbers: Headline style
- Labels: Caption, secondary
- Padding: 16pt vertical
- Border bottom: 0.5pt

### Timeline Section (scrollable)

**Day Header**
- "📅 Day 1 (1/15)"
- Headline style
- Sticky on scroll
- Padding: 16pt vertical

**Place Card**
```
┌─────────────────────────────────┐
│ 📍 제주공항                      │
│ 🕐 10:30 · ✈️ 도착              │
│ ┌───┬───┬───┐                   │
│ │ 📷│ 📷│ 📷│                   │
│ └───┴───┴───┘                   │
└─────────────────────────────────┘
```
- Background: Surface
- Border radius: 16pt
- Padding: 16pt
- Photo thumbnails: 56pt, radius 8pt, gap 8pt

**Connector**
- Vertical line: 2pt, dashed, border color
- Badge: "32km, 40분"
- Badge style: Caption, tertiary, centered on line

**Second Place Card**
```
┌─────────────────────────────────┐
│ 📍 협재해수욕장                  │
│ 🕐 13:00 · 🏖️ 해변              │
│ ┌───┬───┬───┬───┬───┐          │
│ │ 📷│ 📷│ 📷│ 📷│ 📷│          │
│ └───┴───┴───┴───┴───┘          │
└─────────────────────────────────┘
```

### Bottom Action Bar (fixed)
- Background: Background with blur
- Border top: 0.5pt
- Padding: 16pt horizontal, 12pt vertical + safe area
- 2 buttons side by side, gap 12pt:
  - "공유" (Secondary, flex 1)
  - "💎 AI 스토리" (Primary, flex 1)

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Scrollable content, fixed header and bottom bar.
```

---

## PROMPT 11: 지도 상세 화면 (전체 화면)

📎 첨부 필요: 없음

```
Create the Full Map View Screen for Wander app.

## Screen Requirements

### Header (overlay on map)
- Semi-transparent background: rgba(255,255,255,0.9)
- Left: ✕ close button
- Center: "지도" (Headline)
- Right: "···" more menu

### Map (full screen)
- Takes entire screen behind header
- Show route with 5 numbered pins
- Route line: Dashed, Primary color
- Pins: Primary color, numbered (1, 2, 3, 4, 5)

### Pin Tooltip (show one as example)
```
╭─────────────────────────╮
│ 📍 협재해수욕장          │
│ 🕐 13:00 ~ 15:30        │
│ 📷 8장                  │
│ [상세 보기]             │
╰─────────────────────────╯
```
- Background: White
- Shadow: Elevation 2
- Radius: 12pt
- Pointer/arrow at bottom pointing to pin

### Bottom Controls (overlay)
- Background: White, radius 16pt (top)
- Shadow: Elevation 2

- Info text: "📍 터치하여 장소 정보 보기" (Caption)

- Segmented control:
  - [일자별 보기] [전체 경로]
  - Active: Primary background
  - Inactive: Surface background
  - Radius: 8pt

- Padding: 16pt, bottom safe area

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Map as placeholder with styled pins.
```

---

## PROMPT 12: 퀵모드 - 지금 뭐해? (사진 선택)

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 5.2 (퀵모드 사진 선택)

```
Create the Quick Mode Photo Selection Sheet for Wander app.

## Screen Requirements

### Sheet Style
- Bottom sheet, 70% of screen height
- Radius: 20pt (top corners)
- Handle bar centered

### Header
- Title: "지금 뭐해?" (Title 2)
- Right: ✕ close button

### Subtitle
- "방금 찍은 사진을 공유해 보세요"
- Body, secondary color

### Photo Section
- Label: "최근 사진 (24시간)" (Caption, tertiary)
- Grid: 4 columns, 2 rows visible
- Gap: 2pt
- Selection: Same as photo selection screen
- Show 8 photos, 2 selected

### Action Buttons
- "📷 카메라 열기" - Full width, secondary style
- "🖼️ 갤러리에서 더 선택" - Full width, text button style
- Gap: 8pt

### Submit Button
- "완료 (2장 선택)" - Primary, full width
- Disabled if 0 selected
- Bottom safe area padding

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show as overlay on dimmed home screen.
```

---

## PROMPT 13: 퀵모드 - 결과 카드

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 5.3 (퀵모드 결과 카드)

```
Create the Quick Mode Result Card for Wander app.

## Screen Requirements

### Sheet Style
- Full screen modal
- Background: White

### Header
- Title: "지금 뭐해?" (Headline, centered)
- Right: ✕ close button

### Photo Display
- Horizontal carousel of selected photos
- Height: 280pt
- Radius: 16pt
- Page indicator dots below

### Result Text (main content)
- Primary text: "🎤 홍대 뮤직클럽에서 인디밴드 공연 보는 중!"
- Style: Title 3
- Location: "📍 홍대입구역 근처"
- Time: "🕗 저녁 8시"
- Style: Body, secondary color
- Padding: 20pt

### Edit Button
- "✏️ 문구 수정" - Text button, primary color
- Centered

### Share Grid (2x2)
- 4 buttons:
  - 카카오톡 (yellow icon placeholder)
  - 인스타그램 (gradient icon placeholder)
  - 메시지 (green icon placeholder)
  - 저장 (primary color icon)
- Each: 72pt square, radius 16pt, surface background
- Label below icon: Caption

### Bottom Button
- "이미지로 저장" - Full width, secondary style
- Safe area padding

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## PROMPT 14: 기록 목록 화면

📎 첨부 필요: 없음

```
Create the Records List Screen for Wander app.

## Screen Requirements

### Header
- Title: "기록" (Title 1)
- Right: Filter/sort icon (optional)

### Filter Tabs (horizontal scroll)
- Options: [전체] [여행] [일상] [주간]
- Style: Pill chips
- Active: Primary background
- Gap: 8pt
- Margin: 16pt vertical

### Records List

**Record Card (Large - Travel)**
```
┌─────────────────────────────────┐
│ ┌─────────────────────────────┐ │
│ │      [Photo Carousel]       │ │
│ │          ● ○ ○ ○           │ │
│ └─────────────────────────────┘ │
│                                 │
│  🏝️ 제주도 3박4일              │
│  2026.01.15 ~ 01.18            │
│  📍 12곳 · 🚗 245km · 📸 50장   │
└─────────────────────────────────┘
```
- Photo: 16:9 ratio
- Radius: 20pt
- Shadow: Elevation 1

**Record Card (Small - Daily)**
```
┌─────────────────────────────────┐
│ [Photo] │ ☕ 성수동 카페 투어    │
│  80pt   │ 2026.01.18           │
│ square  │ 📍 4곳 방문           │
└─────────────────────────────────┘
```
- Horizontal layout
- Photo: 80pt square, radius 12pt
- Height: ~96pt total

### List Layout
- Mix of large and small cards
- Gap: 16pt
- Padding: 20pt horizontal

### Tab Bar
- Same as home screen
- "기록" tab active

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show 3-4 record cards.
```

---

## PROMPT 15: 설정 화면

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 9.2 (설정 화면 레이아웃)

```
Create the Settings Screen for Wander app.

## Screen Requirements

### Header
- Title: "설정" (Title 1)
- No back button (tab screen)

### Settings Groups

**Group 1: 계정**
```
┌─────────────────────────────────┐
│ 👤 프로필 설정              >   │
├─────────────────────────────────┤
│ 💎 프리미엄                 >   │
│    현재: 무료 버전               │
└─────────────────────────────────┘
```

**Group 2: AI 설정**
```
┌─────────────────────────────────┐
│ 🤖 AI 프로바이더            >   │
│    현재: 설정 안됨               │
├─────────────────────────────────┤
│ 🔑 API Key 관리            >   │
└─────────────────────────────────┘
```

**Group 3: 앱 설정**
```
┌─────────────────────────────────┐
│ 🔔 알림 설정                >   │
├─────────────────────────────────┤
│ 🗺️ 지도 스타일              >   │
├─────────────────────────────────┤
│ 🔗 공유 설정                >   │
│    출처 표기: 켜짐               │
├─────────────────────────────────┤
│ 💾 데이터 관리              >   │
├─────────────────────────────────┤
│ 🔐 권한 설정                >   │
└─────────────────────────────────┘
```

**Group 4: 정보**
```
┌─────────────────────────────────┐
│ ℹ️ 버전 정보                >   │
│    v1.0.0                       │
├─────────────────────────────────┤
│ 📜 이용약관                 >   │
├─────────────────────────────────┤
│ 🔒 개인정보처리방침          >   │
├─────────────────────────────────┤
│ 💬 문의하기                 >   │
└─────────────────────────────────┘
```

### Styling
- Group label: Caption, tertiary, 8pt margin bottom
- Group background: Surface
- Group radius: 12pt
- Row height: 52pt
- Dividers: 0.5pt, inset 52pt from left
- Chevron: Tertiary color
- Subtitle text: Caption, tertiary
- Gap between groups: 32pt

### Tab Bar
- "설정" tab active

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Scrollable content.
```

---

## PROMPT 16: 공유 시트

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 8.2 (공유 시트)

```
Create the Share Sheet for Wander app.

## Screen Requirements

### Sheet Style
- Bottom sheet, ~50% height
- Radius: 20pt (top corners)
- Handle bar centered

### Header
- Title: "공유하기" (Title 3, centered)
- Padding: 20pt

### Share Format Section
- Label: "공유 형식 선택" (Caption, tertiary)

**Option Card 1 (selected)**
```
┌─────────────────────────────────┐
│ 🖼️ 이미지 카드                  │
│ SNS에 바로 올릴 수 있는         │
│ 예쁜 카드 이미지                │
└─────────────────────────────────┘
```
- Selected: Primary border (2pt)
- Background: Primary pale
- Radius: 12pt

**Option Card 2**
```
┌─────────────────────────────────┐
│ 📝 텍스트만                     │
│ 타임라인 텍스트 복사            │
└─────────────────────────────────┘
```
- Unselected: Border color (1pt)
- Background: Surface

### Quick Share Section
- Label: "바로 공유" (Caption, tertiary)
- 4 icon buttons in a row:
  - 💬 카톡 (Kakao yellow)
  - 📸 인스타 (Instagram gradient)
  - 💬 메시지 (Apple green)
  - ··· 더보기 (tertiary)
- Icon buttons: 56pt, radius 16pt
- Labels below: Caption

### Full Width Button
- "기타 앱으로 공유" - Secondary style
- Full width

### Bottom Padding
- Safe area

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Show as overlay on dimmed background.
```

---

## PROMPT 17: API 설정 화면

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 9.4, 9.5 (AI 프로바이더 설정)

```
Create the AI Provider Settings Screen for Wander app.

## Screen Requirements

### Header (Navigation style)
- Left: ◀ back button
- Center: "AI 프로바이더" (Headline)

### Section 1: 크레딧 구매
```
┌─────────────────────────────────┐
│ 💳 크레딧 구매                  │
│                                 │
│ 잔여 크레딧: 0                  │
│                                 │
│ ┌─────────────────────────────┐ │
│ │  50 크레딧 - ₩3,900        │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 150 크레딧 - ₩9,900        │ │
│ └─────────────────────────────┘ │
│ ┌─────────────────────────────┐ │
│ │ 400 크레딧 - ₩19,900       │ │
│ └─────────────────────────────┘ │
└─────────────────────────────────┘
```
- Card background: Surface
- Options: Secondary button style, full width

### Divider with text
- "또는" centered, line on both sides

### Section 2: BYOK (Bring Your Own Key)
- Section header: "직접 API Key 연결"
- Subheader: "(BYOK - Bring Your Own Key)" - Caption, tertiary

**Provider List**
```
┌─────────────────────────────────┐
│ 🟢 OpenAI                   >   │
│    GPT-4o, GPT-4 Turbo          │
├─────────────────────────────────┤
│ 🟣 Anthropic                >   │
│    Claude 4 Opus, Sonnet        │
├─────────────────────────────────┤
│ 🔵 Azure OpenAI             >   │
│    기업용 Azure 호스팅           │
├─────────────────────────────────┤
│ 🔴 Google Gemini            >   │
│    Gemini Pro, Ultra            │
├─────────────────────────────────┤
│ ⚫ xAI Grok                 >   │
│    Grok                         │
├─────────────────────────────────┤
│ 🟠 AWS Bedrock              >   │
│    Claude, Titan 등             │
└─────────────────────────────────┘
```
- List style same as settings
- Colored dot indicators
- Subtitle: Caption, tertiary

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
Scrollable.
```

---

## PROMPT 18: 에러 화면 (일반)

📎 첨부 필요: 없음

```
Create a General Error Screen for Wander app.

## Screen Requirements

### Layout (centered)

1. **Error Icon**
   - ⚠️ warning icon
   - Size: 64pt
   - Color: Warning (#FF9800)

2. **Title**
   - "문제가 발생했어요"
   - Title 2 style

3. **Message**
   - "일시적인 오류가 발생했습니다. 잠시 후 다시 시도해주세요."
   - Body, secondary color
   - Text align center
   - Max width: 280pt

4. **Action Buttons** (stacked)
   - "다시 시도" - Primary button
   - "홈으로" - Text button, secondary

5. **Help Link** (bottom)
   - "문제가 계속되면 문의하기를 통해 알려주세요"
   - Caption, tertiary
   - "문의하기" underlined, primary color

### Spacing
- Icon to title: 24pt
- Title to message: 12pt
- Message to buttons: 32pt
- Between buttons: 12pt
- Help link: bottom 48pt

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## PROMPT 19: 권한 거부 화면

📎 첨부 필요: `wander_ui_scenario.md` > 섹션 10.2.1 (사진 권한 거부)

```
Create the Permission Denied Screen for Wander app.

## Screen Requirements

### Layout (centered)

1. **Icon**
   - 📷 photo icon with ❌ overlay
   - Size: 80pt
   - Color: Tertiary

2. **Title**
   - "사진 접근 권한이 필요해요"
   - Title 2

3. **Description**
   - "Wander는 사진의 메타데이터를 분석하여 여행 기록을 만들어 드립니다."
   - Body, secondary
   - Centered, max width 300pt

4. **Additional Info**
   - "설정에서 사진 접근을 허용해 주세요."
   - Body, secondary

5. **Buttons**
   - "설정으로 이동" - Primary, full width
   - "취소" - Text button

### Background
- White

### Specs
- Same centering and spacing pattern as error screen

## Output
React component with Tailwind CSS.
Mobile: 390 x 844
```

---

## 사용 체크리스트

### MVP 필수 화면 (순서대로)
- [ ] PROMPT 0: 디자인 시스템
- [ ] PROMPT 5: 홈 화면
- [ ] PROMPT 7: 사진 선택 화면
- [ ] PROMPT 9: 분석 중 화면
- [ ] PROMPT 10: 분석 결과 화면
- [ ] PROMPT 12: 퀵모드 사진 선택
- [ ] PROMPT 13: 퀵모드 결과

### 온보딩
- [ ] PROMPT 1: 스플래시
- [ ] PROMPT 2: 온보딩 1
- [ ] PROMPT 3: 온보딩 2
- [ ] PROMPT 4: 온보딩 3

### 부가 화면
- [ ] PROMPT 6: 홈 빈 상태
- [ ] PROMPT 8: 날짜 선택기
- [ ] PROMPT 11: 지도 상세
- [ ] PROMPT 14: 기록 목록
- [ ] PROMPT 15: 설정 화면
- [ ] PROMPT 16: 공유 시트
- [ ] PROMPT 17: API 설정
- [ ] PROMPT 18: 에러 화면
- [ ] PROMPT 19: 권한 거부

---

*Document Version: v1.0*
*Last Updated: 2026년 1월 30일*
