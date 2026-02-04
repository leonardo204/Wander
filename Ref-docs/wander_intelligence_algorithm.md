# Wander Intelligence 분석 알고리즘

> Wander 앱의 핵심 차별화 요소인 스마트 분석 시스템의 상세 기술 문서

---

## 목차

1. [개요](#1-개요)
2. [시스템 아키텍처](#2-시스템-아키텍처)
3. [분석 파이프라인](#3-분석-파이프라인)
4. [핵심 서비스 상세](#4-핵심-서비스-상세)
   - [4.1 VisionAnalysisService](#41-visionanalysisservice)
   - [4.2 TravelDNAService](#42-traveldnaservice)
   - [4.3 MomentScoreService](#43-momentscoreservice)
   - [4.4 StoryWeavingService](#44-storyweavingservice)
   - [4.5 InsightEngine](#45-insightengine)
   - [4.6 FastVLMService](#46-fastvlmservice-ios-182)
5. [데이터 흐름](#5-데이터-흐름)
6. [점수 계산 공식](#6-점수-계산-공식)
7. [iOS 버전별 기능](#7-ios-버전별-기능)

---

## 1. 개요

### 1.1 Wander Intelligence란?

Wander Intelligence는 사진의 메타데이터와 이미지 분석을 결합하여 단순한 위치 기록을 넘어 **의미 있는 여행 경험**으로 변환하는 On-Device AI 시스템입니다.

### 1.2 핵심 목표

| 목표 | 설명 |
|------|------|
| **개인화** | 사용자의 여행 스타일을 분석하여 맞춤형 인사이트 제공 |
| **차별화** | 경쟁 앱과 구별되는 고유한 분석 결과 생성 |
| **가치 창출** | 단순 기록을 넘어 여행의 의미와 스토리 발견 |
| **프라이버시** | 100% On-Device 처리로 개인정보 보호 |

### 1.3 핵심 구성요소

```mermaid
mindmap
  root((Wander Intelligence))
    Vision Analysis
      Scene Classification
      Object Detection
      Image Quality
    Travel DNA
      Traveler Type
      Travel Traits
      Activity Balance
    Moment Score
      Time Score
      Place Score
      Activity Score
      Uniqueness Score
    Story Weaving
      Mood Detection
      Chapter Generation
      Narrative Building
    Insight Engine
      Pattern Discovery
      Milestone Detection
      Recommendation
```

---

## 2. 시스템 아키텍처

### 2.1 전체 아키텍처

```mermaid
flowchart TB
    subgraph Input["입력 레이어"]
        Photos[("사진 라이브러리")]
        Meta["메타데이터<br/>(GPS, 시간)"]
    end

    subgraph Core["코어 분석 엔진"]
        AE["AnalysisEngine"]
        CS["ClusteringService"]
        GS["GeocodingService"]
    end

    subgraph Smart["스마트 분석 레이어"]
        SAC["SmartAnalysisCoordinator"]

        subgraph Services["분석 서비스"]
            VAS["VisionAnalysisService"]
            POI["POIService"]
            STG["SmartTitleGenerator"]
        end

        subgraph Intelligence["Wander Intelligence"]
            DNA["TravelDNAService"]
            MS["MomentScoreService"]
            SW["StoryWeavingService"]
            IE["InsightEngine"]
        end
    end

    subgraph Output["출력 레이어"]
        AR["AnalysisResult"]
        UI["ResultView"]
    end

    Photos --> AE
    Meta --> AE
    AE --> CS
    AE --> GS
    CS --> SAC
    GS --> SAC

    SAC --> VAS
    SAC --> POI
    SAC --> STG

    VAS --> DNA
    VAS --> MS
    DNA --> SW
    MS --> SW
    MS --> IE
    DNA --> IE

    SW --> AR
    IE --> AR
    MS --> AR
    DNA --> AR

    AR --> UI
```

### 2.2 서비스 의존성

```mermaid
graph LR
    subgraph Layer1["기본 분석"]
        C[ClusteringService]
        G[GeocodingService]
        A[ActivityInferenceService]
    end

    subgraph Layer2["스마트 분석"]
        V[VisionAnalysisService]
        P[POIService]
    end

    subgraph Layer3["Intelligence"]
        D[TravelDNAService]
        M[MomentScoreService]
    end

    subgraph Layer4["고급 기능"]
        S[StoryWeavingService]
        I[InsightEngine]
    end

    C --> V
    G --> P
    V --> D
    V --> M
    P --> M
    D --> S
    M --> S
    D --> I
    M --> I
```

---

## 3. 분석 파이프라인

### 3.1 전체 분석 흐름

```mermaid
sequenceDiagram
    participant User
    participant AE as AnalysisEngine
    participant CS as ClusteringService
    participant GS as GeocodingService
    participant SAC as SmartAnalysisCoordinator
    participant VAS as VisionAnalysisService
    participant DNA as TravelDNAService
    participant MS as MomentScoreService
    participant SW as StoryWeavingService
    participant IE as InsightEngine

    User->>AE: 사진 선택 및 분석 시작

    rect rgb(240, 248, 255)
        Note over AE,GS: Phase 1: 기본 분석
        AE->>AE: 메타데이터 추출
        AE->>CS: 장소 클러스터링
        CS-->>AE: PlaceCluster[]
        AE->>GS: 역지오코딩
        GS-->>AE: 주소 정보
    end

    rect rgb(255, 248, 240)
        Note over SAC,VAS: Phase 2: 스마트 분석
        AE->>SAC: 스마트 분석 요청
        SAC->>VAS: 장면 분류
        VAS-->>SAC: SceneCategory[]
    end

    rect rgb(240, 255, 240)
        Note over DNA,IE: Phase 3: Wander Intelligence
        SAC->>DNA: DNA 분석
        DNA-->>SAC: TravelDNA
        SAC->>MS: 점수 계산
        MS-->>SAC: MomentScore[]
        SAC->>SW: 스토리 생성
        SW-->>SAC: TravelStory
        SAC->>IE: 인사이트 발굴
        IE-->>SAC: TravelInsight[]
    end

    SAC-->>AE: SmartAnalysisResult
    AE-->>User: AnalysisResult
```

### 3.2 분석 단계별 진행률

| 단계 | 가중치 | 누적 | 설명 |
|------|--------|------|------|
| 메타데이터 추출 | 5% | 5% | GPS, 시간 정보 추출 |
| 클러스터링 | 10% | 15% | 시공간 기반 장소 그룹화 |
| 역지오코딩 | 25% | 40% | 좌표 → 주소 변환 |
| Vision 분석 | 20% | 60% | 장면 분류 |
| POI 검색 | 15% | 75% | 주변 정보 검색 |
| Intelligence | 20% | 95% | DNA, Score, Story, Insight |
| 마무리 | 5% | 100% | 결과 병합 |

---

## 4. 핵심 서비스 상세

### 4.1 VisionAnalysisService

#### 개요
Apple Vision Framework를 활용한 이미지 분류 서비스

#### 장면 카테고리

```mermaid
graph TD
    subgraph Natural["자연"]
        beach[해변]
        mountain[산]
        nature[자연]
        park[공원]
    end

    subgraph Urban["도시"]
        city[도시]
        shopping[쇼핑]
        landmark[랜드마크]
    end

    subgraph Culture["문화"]
        museum[박물관]
        temple[사찰]
        culture[문화시설]
    end

    subgraph Dining["식음료"]
        cafe[카페]
        restaurant[레스토랑]
        food[음식]
    end

    subgraph Travel["여행"]
        hotel[숙소]
        airport[공항]
        transportation[교통]
    end

    subgraph People["인물"]
        people[사람들]
        portrait[인물사진]
    end
```

#### 분류 로직

```swift
// 대표 사진 샘플링 (최대 3장)
let samples = sampleAssets(from: assets, count: 3)

// 각 사진 분류
for asset in samples {
    let classifications = await classifyScene(image: image)
    // confidence 기반 가중 투표
}

// 최종 카테고리 결정
return dominantCategory
```

---

### 4.2 TravelDNAService

#### 개요
여행 패턴 분석을 통한 사용자 여행 성향 프로파일링

#### 여행자 유형 (9종)

```mermaid
graph TB
    subgraph Types["여행자 유형"]
        ADV["🏔️ Adventurer<br/>모험가"]
        FOD["🍽️ Foodie<br/>미식가"]
        NAT["🌲 NatureLover<br/>자연인"]
        CUL["🏛️ Culturist<br/>문화탐험가"]
        PHO["📷 Photographer<br/>포토그래퍼"]
        REL["🧘 Relaxer<br/>힐링러"]
        SOC["👥 Socialite<br/>소셜라이터"]
        PLN["📋 Planner<br/>플래너"]
        WAN["🚶 Wanderer<br/>방랑자"]
    end
```

#### DNA 코드 생성

```
DNA 코드 형식: [Primary]-[Secondary]-[TimePreference]

예시:
- ADV-NAT-MOR : 아침형 자연 탐험 모험가
- FOD-CUL-EVE : 저녁형 문화 애호 미식가
- PHO-REL-BAL : 균형형 힐링 포토그래퍼
```

#### 분석 알고리즘

```mermaid
flowchart TD
    Start([클러스터 데이터]) --> A[활동 유형 집계]
    A --> B[시간대 패턴 분석]
    B --> C[장면 카테고리 분석]
    C --> D[Activity Balance 계산]
    D --> E[여행자 유형 결정]
    E --> F[특성 Traits 추출]
    F --> G[점수 계산]
    G --> H[DNA 코드 생성]
    H --> End([TravelDNA])

    subgraph Scores["점수 항목"]
        S1[탐험 지수]
        S2[문화 지수]
        S3[소셜 지수]
    end

    G --> S1
    G --> S2
    G --> S3
```

#### Activity Balance 계산

```
Outdoor vs Indoor:
- 해변, 산, 자연, 공원 → Outdoor +1
- 박물관, 카페, 쇼핑 → Indoor +1

Active vs Relaxing:
- 산, 관광, 쇼핑 → Active +1
- 카페, 숙소, 공원 → Relaxing +1

결과: 각 항목 0-100 백분율
```

---

### 4.3 MomentScoreService

#### 개요
각 장소/순간의 특별함을 0-100점으로 정량화

#### 점수 구성요소

```mermaid
pie title 점수 구성 비율
    "시간 점수" : 20
    "장소 점수" : 20
    "활동 점수" : 20
    "체류 점수" : 15
    "사진 점수" : 15
    "고유성 점수" : 10
```

#### 등급 체계

| 등급 | 점수 범위 | 이모지 | 설명 |
|------|----------|--------|------|
| Legendary | 90-100 | 👑 | 전설의 순간 |
| Epic | 80-89 | ⭐ | 특별한 순간 |
| Memorable | 70-79 | 💫 | 기억될 순간 |
| Pleasant | 60-69 | 😊 | 즐거운 순간 |
| Ordinary | 50-59 | 📍 | 평범한 순간 |
| Casual | 0-49 | 🚶 | 일상의 순간 |

#### 특별 배지 (12종)

```mermaid
graph LR
    subgraph Time["시간 기반"]
        B1["🌅 골든아워"]
        B2["🌌 블루모먼트"]
        B3["☀️ 일출"]
        B4["🌇 일몰"]
        B5["🌃 야경"]
    end

    subgraph Activity["활동 기반"]
        B6["⏰ 오래 머문 곳"]
        B7["📸 포토스팟"]
        B8["💎 숨겨진 보석"]
        B9["🏆 로컬 인기"]
    end

    subgraph Special["특별 이벤트"]
        B10["🆕 첫 방문"]
        B11["🏁 마일스톤"]
        B12["☀️ 완벽한 날씨"]
    end
```

#### 점수 계산 상세

```mermaid
flowchart TD
    subgraph TimeScore["시간 점수 (0-20)"]
        T1["5-7시: 20점<br/>(일출)"]
        T2["17-19시: 20점<br/>(골든아워)"]
        T3["8-10시: 15점<br/>(오전)"]
        T4["11-16시: 10점<br/>(한낮)"]
        T5["20-22시: 15점<br/>(야경)"]
        T6["기타: 5점"]
    end

    subgraph PlaceScore["장소 점수 (0-20)"]
        P1["기본: 10점"]
        P2["특별 장면: +5~8점"]
        P3["주변 핫스팟: +1~5점"]
    end

    subgraph DurationScore["체류 점수 (0-15)"]
        D1["1시간+: 15점"]
        D2["30분-1시간: 12점"]
        D3["15-30분: 8점"]
        D4["15분 미만: 5점"]
    end

    subgraph PhotoScore["사진 점수 (0-15)"]
        PH1["20장+: 15점"]
        PH2["10-19장: 12점"]
        PH3["5-9장: 8점"]
        PH4["2-4장: 5점"]
        PH5["1장: 3점"]
    end

    TimeScore --> Total
    PlaceScore --> Total
    DurationScore --> Total
    PhotoScore --> Total
    ActivityScore["활동 점수<br/>(0-20)"] --> Total
    UniquenessScore["고유성 점수<br/>(0-10)"] --> Total

    Total["총점<br/>(최대 100점)"] --> Grade["등급 결정"]
```

---

### 4.4 StoryWeavingService

#### 개요
분석 결과를 바탕으로 자연어 여행 스토리 자동 생성

#### 스토리 구조

```mermaid
graph TD
    subgraph Story["여행 스토리"]
        Title["제목"]
        Tagline["태그라인"]
        Opening["오프닝"]
        Chapters["챕터들"]
        Climax["클라이맥스"]
        Closing["클로징"]
        Keywords["키워드"]
    end

    subgraph Chapter["챕터 구조"]
        CT["제목"]
        CC["내용"]
        CP["장소명"]
        CE["이모지"]
        CS["점수"]
    end

    Chapters --> Chapter
```

#### 스토리 무드 (7종)

| 무드 | 이모지 | 설명 | 트리거 조건 |
|------|--------|------|-------------|
| Adventurous | 🏔️ | 모험적인 | 산, 자연 활동 위주 |
| Romantic | 💕 | 로맨틱한 | 카페, 일몰, 해변 |
| Peaceful | 🌿 | 평화로운 | 공원, 사찰, 자연 |
| Exciting | ⚡ | 신나는 | 관광, 쇼핑, 도시 |
| Reflective | 🌙 | 성찰적인 | 박물관, 문화시설 |
| Heartwarming | 💝 | 따뜻한 | 맛집, 카페, 사람들 |
| Inspiring | ✨ | 영감 주는 | 랜드마크, 특별 점수 |

#### 스토리 생성 플로우

```mermaid
flowchart TD
    Input([StoryContext]) --> M[무드 결정]
    M --> T[제목 생성]
    T --> TL[태그라인 생성]
    TL --> O[오프닝 생성]
    O --> C[챕터 생성]
    C --> CL[클라이맥스 선정]
    CL --> CLS[클로징 생성]
    CLS --> K[키워드 추출]
    K --> Output([TravelStory])

    subgraph MoodDetermination["무드 결정 로직"]
        M1[DNA 유형 분석]
        M2[장면 카테고리 분석]
        M3[점수 분포 분석]
    end

    M --> M1
    M --> M2
    M --> M3
```

---

### 4.5 InsightEngine

#### 개요
데이터에서 사용자가 인식하지 못한 패턴과 의미 발굴

#### 인사이트 카테고리

```mermaid
graph TB
    subgraph Time["⏰ 시간"]
        I1["골든 모먼트"]
        I2["시간 패턴"]
        I3["완벽한 타이밍"]
    end

    subgraph Place["📍 장소"]
        I4["숨겨진 보석"]
        I5["로컬 인기"]
        I6["예상치 못한 발견"]
    end

    subgraph Activity["🎯 활동"]
        I7["다양한 경험"]
        I8["깊이 있는 탐험"]
        I9["균형 잡힌 여행"]
    end

    subgraph Stats["📊 통계"]
        I10["이동 마일스톤"]
        I11["사진 순간"]
        I12["잘 보낸 시간"]
    end

    subgraph Special["✨ 특별"]
        I13["세렌디피티"]
        I14["개인 기록"]
        I15["추억 트리거"]
    end
```

#### 중요도 레벨

| 레벨 | 값 | 설명 | UI 표시 |
|------|-----|------|---------|
| Minor | 1 | 작은 발견 | 기본 |
| Notable | 2 | 주목할 만한 | 기본 |
| Significant | 3 | 중요한 발견 | 강조 |
| Highlight | 4 | 하이라이트 | ⭐ 표시 |
| Exceptional | 5 | 특별한 순간 | ✨ 표시 |

#### 인사이트 발굴 알고리즘

```mermaid
flowchart TD
    Input([AnalysisContext]) --> T[시간 인사이트]
    Input --> P[장소 인사이트]
    Input --> A[활동 인사이트]
    Input --> S[통계 인사이트]
    Input --> SP[특별 인사이트]

    T --> Merge[인사이트 병합]
    P --> Merge
    A --> Merge
    S --> Merge
    SP --> Merge

    Merge --> Sort[중요도 정렬]
    Sort --> Output([TravelInsight 배열])

    subgraph TimeInsights["시간 인사이트"]
        T1["골든아워 방문 체크"]
        T2["시간대 분포 분석"]
        T3["야경 탐험 감지"]
    end

    subgraph PlaceInsights["장소 인사이트"]
        P1["고유성 점수 ≥ 8"]
        P2["1시간+ 체류"]
        P3["예상치 못한 발견"]
    end

    T --> T1
    T --> T2
    T --> T3
    P --> P1
    P --> P2
    P --> P3
```

---

### 4.6 FastVLMService (iOS 18.2+)

#### 개요
Apple의 Foundation Models API를 활용한 고급 이미지 분석 (iOS 18.2+)

#### 기능

```mermaid
graph LR
    subgraph Input["입력"]
        I1[PHAsset]
        I2[UIImage]
        I3[Asset 배열]
    end

    subgraph Analysis["분석"]
        A1[장면 설명 생성]
        A2[분위기 감지]
        A3[키워드 추출]
        A4[활동 추천]
    end

    subgraph Output["출력"]
        O1[SceneDescription]
        O2[ClusterAnalysis]
    end

    I1 --> A1
    I2 --> A1
    I3 --> A2
    A1 --> O1
    A2 --> O1
    A3 --> O1
    A4 --> O1
    O1 --> O2
```

#### TravelMood (8종)

| 무드 | 이모지 | 한국어 | 연관 장면 |
|------|--------|--------|-----------|
| Peaceful | 🌿 | 평화로운 | 자연, 공원, 카페 |
| Adventurous | 🏔️ | 모험적인 | 산 |
| Romantic | 💕 | 로맨틱한 | - |
| Energetic | ⚡ | 활기찬 | 도시, 쇼핑 |
| Relaxing | 🌊 | 여유로운 | 해변, 자연, 공원 |
| Cultural | 🏛️ | 문화적인 | 박물관, 사찰 |
| Nostalgic | 📷 | 추억이 깃든 | 랜드마크 |
| Joyful | 🎉 | 즐거운 | 레스토랑, 음식 |

---

## 5. 데이터 흐름

### 5.1 입력 데이터

```mermaid
erDiagram
    PHAsset ||--o{ PhotoMetadata : extracts
    PhotoMetadata {
        string assetId
        date capturedAt
        double latitude
        double longitude
        bool hasGPS
    }

    PhotoMetadata ||--o{ PlaceCluster : groups
    PlaceCluster {
        uuid id
        string name
        string address
        double latitude
        double longitude
        date startTime
        date endTime
        array photos
        string activityType
    }
```

### 5.2 분석 결과 데이터

```mermaid
erDiagram
    AnalysisResult ||--o| SmartAnalysisResult : contains
    AnalysisResult ||--o| TravelDNA : contains
    AnalysisResult ||--o{ MomentScore : contains
    AnalysisResult ||--o| TravelStory : contains
    AnalysisResult ||--o{ TravelInsight : contains

    AnalysisResult {
        string title
        date startDate
        date endDate
        array places
        double totalDistance
        int photoCount
    }

    TravelDNA {
        enum primaryType
        enum secondaryType
        array traits
        struct activityBalance
        int explorationScore
        int socialScore
        int cultureScore
        string dnaCode
    }

    MomentScore {
        int totalScore
        enum grade
        struct components
        array highlights
        array specialBadges
    }

    TravelStory {
        string title
        string opening
        array chapters
        string climax
        string closing
        string tagline
        enum mood
        array keywords
    }

    TravelInsight {
        uuid id
        enum type
        string title
        string description
        string emoji
        enum importance
    }
```

---

## 6. 점수 계산 공식

### 6.1 MomentScore 계산

```
TotalScore = min(TimeScore + PlaceScore + ActivityScore + DurationScore + PhotoScore + UniquenessScore, 100)

여기서:
- TimeScore (0-20): 방문 시간대 기반
- PlaceScore (0-20): 장면 카테고리 + 주변 핫스팟
- ActivityScore (0-20): 활동 유형 + 장면 일치 보너스
- DurationScore (0-15): 체류 시간
- PhotoScore (0-15): 촬영 사진 수
- UniquenessScore (0-10): 이 여행 내 고유성
```

### 6.2 TripOverallScore 계산

```
AverageScore = sum(MomentScores) / count(MomentScores)
PeakScore = max(MomentScores)
TotalBadges = count(unique(allBadges))
TripGrade = gradeFrom(AverageScore)
```

### 6.3 TravelDNA 점수

```
ExplorationScore = (uniqueActivityTypes * 10) + (placeCount * 5) + (distanceBonus)
CultureScore = (museumCount + templeCount) * 20 + (landmarkCount * 10)
SocialScore = (restaurantCount + cafeCount) * 10 + (peoplePhotoRatio * 30)

각 점수는 0-100 범위로 정규화
```

---

## 7. iOS 버전별 기능

### 7.1 기능 매트릭스

```mermaid
graph TB
    subgraph iOS17["iOS 17+"]
        F1[기본 분석]
        F2[클러스터링]
        F3[역지오코딩]
        F4[Vision 분류]
        F5[POI 검색]
        F6[스마트 제목]
        F7[TravelDNA]
        F8[MomentScore]
        F9[StoryWeaving]
        F10[InsightEngine]
    end

    subgraph iOS18["iOS 18+ 추가"]
        F11[고급 AI 분석 레벨]
        F12[향상된 장면 분류]
    end

    subgraph iOS182["iOS 18.2+ 추가"]
        F13[FastVLM]
        F14[자연어 장면 설명]
        F15[고급 무드 분석]
    end

    iOS17 --> iOS18
    iOS18 --> iOS182
```

### 7.2 분석 레벨

| 레벨 | iOS 버전 | 기능 |
|------|----------|------|
| Basic | 17+ | 기본 분석 |
| Smart | 17+ | + Vision, POI, 스마트 제목 |
| Advanced | 18+ | + AI 분석, Wander Intelligence |

---

## 부록: 파일 구조

```
Services/SmartAnalysis/
├── SmartAnalysisCoordinator.swift  # 전체 조율
├── VisionAnalysisService.swift     # Vision 분류
├── POIService.swift                # POI 검색
├── SmartTitleGenerator.swift       # 제목 생성
├── TravelDNAService.swift          # DNA 분석
├── MomentScoreService.swift        # 점수 계산
├── StoryWeavingService.swift       # 스토리 생성
├── InsightEngine.swift             # 인사이트 발굴
└── FastVLMService.swift            # VLM 분석 (iOS 18.2+)
```

---

*문서 버전: 1.0*
*최종 업데이트: 2026-02-04*
