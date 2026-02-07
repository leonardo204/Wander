# Context Classification 연구 리포트

> 사진 기반 일상/외출/여행 분류 알고리즘 조사

**작성일**: 2026-02-07
**목적**: Wander 앱의 Context Classification 기능 개선을 위한 기술 조사

---

## 1. 핵심 문제 정의

### 1.1 현재 Wander의 한계
- 모든 분석이 "여행"에 초점 → 일상/회사/학교 생활에 부적합
- TravelDNA, 여행 점수 등 근거 불명확한 기능 제공
- 사용자가 일상+여행 사진을 혼합 제출 시 처리 미흡

### 1.2 목표
- **일상 vs 여행 분류 정확도 90% 이상** 달성
- 맥락별 차별화된 결과 제공:
  - **일상**: 간단한 description + tags
  - **여행**: 타임라인, 이동거리, 활동 분석, 인사이트

---

## 2. Google Photos 분석

### 2.1 여행 감지 방식

Google Photos는 다음 요소를 조합하여 여행을 감지합니다:

| 요소 | 설명 |
|------|------|
| **카메라 메타데이터** | GPS, 촬영 시간 |
| **집에서 떨어진 기간** | 사용자가 집을 비운 시간 분석 |
| **Google Now 데이터** | 항공권 영수증, 호텔 예약 등 |
| **랜드마크 인식** | 255,000개 이상의 랜드마크 자동 인식 |

> *"Google Photos determines how long a vacation lasted by examining how long a user has been away from home."*
> — [CSMonitor](https://www.csmonitor.com/Technology/2016/0324/How-Google-Photos-uses-machine-learning-to-create-customized-albums)

### 2.2 PlaNet 신경망

Google Research의 [PlaNet](https://research.google/pubs/planet-photo-geolocation-with-convolutional-neural-networks/) 논문:

- 지구 표면을 **26,000개 이상의 다중 스케일 셀**로 분할
- 수백만 개의 지오태그 이미지로 딥러닝 모델 훈련
- GPS 없이도 이미지만으로 위치 추정 가능 (superhuman accuracy)

### 2.3 2024 Timeline 업데이트

[Google Maps Wrapped](https://techwiser.com/google-maps-wrapped-how-to-see-your-2024-travel-recap/):
- 연간 여행 요약 (Spotify Wrapped 스타일)
- Timeline 히스토리 기반 총 이동 거리, 방문 장소 통계

### 2.4 한계점

- 정확한 "여행 vs 일상" 구분 임계값(거리, 시간)은 **비공개**
- 외부 데이터(항공권, 예약 등) 의존도 높음

---

## 3. Apple Photos 분석

### 3.1 ANSA (Apple Neural Scene Analyzer)

[Apple ML Research](https://machinelearning.apple.com/research/on-device-scene-analysis)에 따르면:

- 2016년부터 **완전 온디바이스** 장면 분석 배포
- 단일 백본으로 여러 태스크 처리: 장면 분류, 얼굴 인식, 물체 감지

### 3.2 온디바이스 Knowledge Graph

[Apple ML Research - People Recognition](https://machinelearning.apple.com/research/recognizing-people-photos):

> *"Photos can learn from identity information to build a private, on-device knowledge graph that identifies interesting patterns: important groups of people, frequent places, past trips, events, and more."*

### 3.3 iOS 18 Trips 기능

[Apple Community 토론](https://discussions.apple.com/thread/255713589)에서 확인된 사항:

| 특징 | 설명 |
|------|------|
| **분류 기준** | 위치 기반, 집에서 멀리 떨어진 사진 |
| **알려진 문제** | 출퇴근이 "Trip"으로 분류되는 경우 발생 |
| **과거 주소** | 이전 집 주소는 인식 못함 |
| **장거리 여행** | 경유지가 별도 Trip으로 분리될 수 있음 |

### 3.4 Differential Privacy 기반 장소 분류

[Learning Iconic Scenes with Differential Privacy](https://machinelearning.apple.com/research/scenes-differential-privacy):

- **450만 개** 위치-카테고리 쌍 학습
- **150만 개** 고유 위치, **100개** 카테고리
- iOS 16부터 Memories 키 포토 선택에 활용
- iOS 17 Places Map 랭킹에 활용

### 3.5 Significant Locations

[iOS Significant Locations](https://www.makeuseof.com/hidden-list-everywhere-you-go-iphone/):

- **빈도 + 체류 시간** 기반으로 중요 장소 자동 학습
- 백그라운드에서 자동 수집 (사용자 액션 불필요)
- 암호화되어 저장, Apple도 접근 불가

---

## 4. 학술 연구

### 4.1 Home Detection Algorithm (HDA)

[EPJ Data Science 연구](https://epjdatascience.springeropen.com/articles/10.1140/epjds/s13688-023-00447-w):

#### 핵심 발견:
```
집 방문 피크: 자정 ~ 오전 6시
회사 방문 피크: 오전 9시 ~ 오후 4시 (평일)
```

#### 권장 방법:
- **집 위치**: 야간 시간대 데이터 활용 (요일 무관)
- **회사 위치**: 평일 주간 시간대 데이터 활용
- 데이터의 **시공간 연속성**이 데이터 양보다 중요

#### 5가지 HDA 비교:
| 알고리즘 | 방식 | 정확도 |
|----------|------|--------|
| Baseline (최다 빈도) | 가장 많이 방문한 위치 | 낮음 |
| 시간 필터링 | 야간 시간대만 사용 | 중간 |
| DBSCAN 클러스터링 | 밀도 기반 | 높음 |
| Random Forest | 지도 학습 | 높음 |
| AdaBoost | 앙상블 | 높음 |

### 4.2 Stay Point Detection

[MDPI Sensors 연구](https://www.mdpi.com/1424-8220/23/7/3749):

#### 전통적 방식:
```
거리 임계값: 200m
시간 임계값: 20분
→ 200m 반경 내에서 20분 이상 체류 시 Stay Point로 인식
```

#### ST-DBSCAN (시공간 밀도 클러스터링):
- 시간-거리 복합 밀도 클러스터링
- 5분 간격까지 높은 정확도 유지
- [GitHub 구현](https://github.com/Yurui-Li/Stay-Point-Identification)

#### D-StaR 알고리즘:
- 거리 임계값 ε, 슬라이딩 윈도우, 지속 시간 임계값 사용
- 폰 데이터에서 실제 체류 지점 F1 점수 **20% 향상**

### 4.3 Trip Segmentation

[PMC 연구](https://pmc.ncbi.nlm.nih.gov/articles/PMC5134621/):

#### Trip vs Activity 구분:
```
Activity: 집, 회사, 쇼핑 등에서 보낸 시간
Trip: Activity 간 이동
```

#### 세그먼트 방법:
| 방법 | 설명 |
|------|------|
| Walking-based | 도보 구간 기준 분할 |
| Clustering-based | 클러스터링 기반 분할 |
| State-based | 상태 기계 기반 분할 |
| **시간 간격 기반** | 연속 GPS 포인트 간 20분 이상 간격 시 분할 |

#### PELT (Pruned Exact Linear Time) 알고리즘:
- 속도, 방향 변화율 기반 변화점 감지
- 이동 수단 변경 지점 자동 탐지

---

## 5. 오픈소스 프로젝트

### 5.1 PhotoPrism

[PhotoPrism](https://www.photoprism.app/):

| 기능 | 설명 |
|------|------|
| **위치 클러스터링** | 6개 고해상도 맵 지원 |
| **3D Earth View** | 글로브 형태 사진 위치 시각화 |
| **얼굴 인식** | 유사도 기반 그룹핑 |
| **온디바이스** | 인터넷 없이 동작 |

한계:
- 자동 Trip 감지 기능 없음
- 객체 감지 정확도 보통

### 5.2 Immich

[Immich](https://github.com/immich-app):

| 기능 | 설명 |
|------|------|
| **Google Photos 유사** | UI/UX가 Google Photos와 유사 |
| **객체 감지** | PhotoPrism보다 우수 |
| **공유 기능** | 다중 사용자 라이브러리 지원 |

한계:
- 자동 Trip 감지 기능 없음

### 5.3 NLR OpenPATH

[NLR OpenPATH](https://www.nlr.gov/transportation/openpath):

> **유일하게 자동 Trip 감지 지원**

| 기능 | 설명 |
|------|------|
| **반자동 Travel Diary** | 센서 + 설문 데이터 조합 |
| **오픈소스** | GitHub에서 포크 가능 |
| **UC Berkeley 출신** | 학술 연구 기반 |

### 5.4 AdventureLog

[AdventureLog](https://github.com/seanmorley15/AdventureLog):

- 셀프 호스팅 여행 트래커
- 사진, 평점, 상세 메모리 저장
- **자동 감지 없음** (수동 입력)

---

## 6. Geofencing 기술

### 6.1 기본 개념

[Geofencing Wikipedia](https://en.wikipedia.org/wiki/Geo-fence):

> *"A geofence can be dynamically generated (radius around a point) or match a predefined set of boundaries (school zones, neighborhood boundaries)."*

### 6.2 행정 경계 기반 Geofencing

[연구 논문](https://link.springer.com/article/10.3758/s13428-023-02213-2)에 따르면:

| 반경 | 용도 | 연구 사례 |
|------|------|----------|
| 10-30m | 실내 위치 구분 | Wray et al. (2019) |
| 100m | 일반 장소 구분 | Naughton et al. (2016) |
| 200m+ | 넓은 지역 구분 | 일반적 권장 |

### 6.3 iOS/Android 구현

| 플랫폼 | API | 특징 |
|--------|-----|------|
| iOS | `CLLocationManager.startMonitoringVisits()` | 배터리 효율적, 빈번한/장기 체류 장소 감지 |
| Android | Fused Location API + Geofencing | 최대 100개 geofence 등록 가능 |

### 6.4 In-Device 알고리즘

[IEEE 연구](https://ieeexplore.ieee.org/document/9034346/):

- **Geo-Tree 구조**: 트리 형태로 geofence 정렬
- 낮은 계산 비용으로 모바일 디바이스 내에서 직접 처리
- 네트워크 비용 절감 + 위치 데이터 보안 유지

---

## 7. Wander 앱 개선 제안

### 7.1 Context Classification 알고리즘

#### Phase 1: 기준 장소 확립

```
1. 사용자 등록 장소 (집, 회사, 학교) 활용
2. 미등록 시 → 자동 학습 (LearnedPlace)
   - 야간(00:00-06:00) 빈번 방문 → 집 추정
   - 평일 주간(09:00-18:00) 빈번 방문 → 회사/학교 추정
```

#### Phase 2: 행정 경계 기반 분류

Google/Apple처럼 거리만 사용하지 말고, **행정 경계** 활용:

```swift
enum DistanceLevel: Int {
    case level0 = 0  // 같은 동/읍/면 (일상)
    case level1 = 1  // 같은 구/군 (일상)
    case level2 = 2  // 같은 시/도, 다른 구/군 (외출)
    case level3 = 3  // 다른 시/도 (여행)
    case level4 = 4  // 50km 이상 (확실한 여행)
}
```

#### Phase 3: 분류 규칙

| 조건 | 분류 | 신뢰도 |
|------|------|--------|
| 등록 장소 300m 내 + 1일 | 🏠 일상 | 95% |
| Level 0-1 + 1일 | 🏠 일상 | 90% |
| Level 2 + 당일 | 🚶 외출 | 85% |
| Level 3-4 또는 2일+ | ✈️ 여행 | 90% |
| 일상+여행 혼합 | 🔀 혼합 | 분리 제안 |

### 7.2 혼합 사진 처리

```
사용자가 일상 + 여행 사진 혼합 제출 시:
1. 클러스터별 DistanceLevel 계산
2. Level 0-1 클러스터와 Level 3+ 클러스터가 공존하면 "혼합" 감지
3. 사용자에게 분리 여부 확인 팝업 표시
4. 분리 선택 시 → 각각 별도 분석
```

### 7.3 장소 미등록 시 학습 전략

**권장: 점진적 학습 (Passive Learning)**

| 접근법 | 장점 | 단점 |
|--------|------|------|
| 온보딩 강제 등록 | 초기 정확도 높음 | 사용자 이탈 위험 |
| 분석 후 확인 질문 | 자연스러운 UX | 추가 단계 필요 |
| **자동 학습** | 무간섭 UX | 초기 몇 번은 부정확 |

**권장 하이브리드 접근:**
1. 온보딩에서 **선택적** 등록 (건너뛰기 가능)
2. 분석 시 패턴 학습 (야간 방문 → 집 추정)
3. 3회 이상 동일 패턴 시 → 조용히 확인 질문
4. 확인된 장소는 UserPlace로 승격

### 7.4 제거/단순화 대상 기능

| 기능 | 현재 상태 | 권장 |
|------|----------|------|
| TravelDNA | 근거 불명확 | **제거** |
| 여행 점수 | 주관적 판단 | **제거** |
| MomentScore | 기준 불명확 | **제거** |
| StoryWeaving | AI 의존 | 일상: 제거, 여행: 유지 |
| InsightEngine | 유용할 수 있음 | 여행에만 유지 (인사이트 없으면 숨김) |

### 7.5 맥락별 결과 UI

#### 일상 (Daily) 결과:
```
┌─────────────────────────────┐
│ 📸 2월 4일 점심              │
│ 서초동 · 식사                │
│                             │
│ [사진 그리드]                │
│                             │
│ 태그: #점심 #서초동 #일상     │
└─────────────────────────────┘
```

#### 여행 (Travel) 결과:
```
┌─────────────────────────────┐
│ ✈️ 제주도 2박 3일 여행        │
│ 2024.01.15 - 01.17          │
│                             │
│ 📍 타임라인                  │
│ ├─ Day 1: 공항 → 성산일출봉   │
│ ├─ Day 2: 우도 → 협재해변    │
│ └─ Day 3: 한라산             │
│                             │
│ 🚗 총 이동거리: 156km        │
│ 📸 사진: 48장                │
│                             │
│ 💡 인사이트 (있는 경우만)     │
│ "자연 탐방 중심의 여행"       │
│                             │
│ 태그: #제주도 #가족여행 #자연  │
└─────────────────────────────┘
```

---

## 8. 재사용 가능한 오픈소스 라이브러리/알고리즘 조사

> 2026-02-07 추가 조사: Wander에 직접 활용하거나 포팅 가능한 MIT/Apache/BSD 라이센스 프로젝트

---

### 8.1 Python 모빌리티 분석 라이브러리

#### 8.1.1 scikit-mobility

| 항목 | 내용 |
|------|------|
| **GitHub** | [scikit-mobility/scikit-mobility](https://github.com/scikit-mobility/scikit-mobility) |
| **Stars** | ~793 |
| **License** | BSD-3-Clause |
| **언어** | Python |
| **최종 업데이트** | 2023-02 (안정/유지보수 단계) |
| **논문** | [arXiv:1907.07062](https://arxiv.org/abs/1907.07062) |

**핵심 알고리즘 (Wander 포팅 대상):**

1. **Stay Location Detection** (`skmob/preprocessing/detection.py`):
   ```python
   stay_locations(tdf,
       stop_radius_factor=0.5,     # 공간 반경 배수
       minutes_for_a_stop=20.0,    # 최소 체류 시간 (분)
       spatial_radius_km=0.2,      # 탐색 반경 (km)
       no_data_for_minutes=1e12,   # 데이터 갭 임계값
       min_speed_kmh=None          # 최소 속도 필터
   )
   ```
   - 기준점으로부터 `stop_radius_factor * spatial_radius_km` 내에서 `minutes_for_a_stop` 이상 체류 시 Stop 생성
   - Stop 좌표 = 클러스터 내 포인트의 **중앙값(median)** 사용
   - 데이터 갭이 `no_data_for_minutes` 초과 시 윈도우 리셋

2. **Stop Clustering** (`skmob/preprocessing/clustering.py`):
   ```python
   cluster(tdf,
       cluster_radius_km=0.1,  # 클러스터 반경
       min_samples=1            # DBSCAN min_samples
   )
   ```
   - sklearn DBSCAN 기반 공간 클러스터링
   - 인접한 Stop들을 하나의 Location으로 그룹핑

3. **Trajectory Filtering/Compression**:
   - `filter()`: `max_speed_kmh=500` 초과 포인트 제거 (노이즈 필터)
   - `compress()`: `spatial_radius_km=0.2` 내 포인트를 단일 포인트로 압축

**Wander 활용도**: ★★★★★ (매우 높음)
- Stay Point Detection 알고리즘을 Swift로 포팅 (중앙값 기반, 비교적 단순)
- 파라미터 기본값(`200m`, `20분`)이 사진 GPS 데이터에도 적합
- Filtering/Compression 로직으로 사진 메타데이터 전처리 가능

---

#### 8.1.2 trackintel (ETH Zurich)

| 항목 | 내용 |
|------|------|
| **GitHub** | [mie-lab/trackintel](https://github.com/mie-lab/trackintel) |
| **Stars** | ~258 |
| **License** | **MIT** |
| **언어** | Python (Pandas/GeoPandas) |
| **최종 업데이트** | 2025-10 (v1.4.2, 활발히 유지보수) |
| **논문** | [ScienceDirect](https://www.sciencedirect.com/science/article/pii/S0198971523000017) |

**핵심 데이터 모델 (Wander 참고 대상):**

```
Positionfixes (GPS 포인트)
  → Staypoints (체류 지점) ← generate_staypoints()
    → Locations (자주 가는 장소) ← generate_locations()
  → Triplegs (이동 구간)
    → Trips (여행/이동) ← generate_trips()
      → Tours (왕복 여정) ← generate_tours()
```

**주요 함수 & 파라미터:**

1. **generate_staypoints()** - 슬라이딩 윈도우 방식:
   ```python
   pfs.generate_staypoints(
       method='sliding',
       dist_threshold=100,      # 100m 이동 시 새 staypoint
       time_threshold=5.0,      # 최소 5분 체류
       gap_threshold=15          # 15분 데이터 갭 시 분리
   )
   ```

2. **generate_locations()** - DBSCAN 클러스터링:
   ```python
   sp.generate_locations(
       method='dbscan',
       epsilon=100,             # 100m 반경
       num_samples=1,           # 최소 1개 staypoint
       distance_metric='haversine'
   )
   ```

3. **generate_trips()** - Staypoint 간 이동 추출:
   ```python
   sp.generate_trips(
       gap_threshold=15          # 15분 갭 시 trip 경계
   )
   ```

4. **generate_tours()** - 왕복 여정 감지:
   ```python
   trips.generate_tours(
       max_dist=100,            # 출발/도착 100m 내
       max_time='1 day',        # 1일 내 왕복
       max_nr_gaps=0
   )
   ```

**Wander 활용도**: ★★★★★ (매우 높음)
- **MIT 라이센스** → 상용 앱에서 자유롭게 사용 가능
- 계층적 데이터 모델(Positionfixes → Staypoints → Locations → Trips)이 Wander의 사진 분석 파이프라인과 완벽히 매핑됨
- Staypoint Detection의 슬라이딩 윈도우 알고리즘이 사진 시간순 데이터에 적합
- `generate_tours()`로 "집에서 출발 → 여행 → 집으로 복귀" 패턴 감지 가능
- **포팅 난이도**: 중간 (알고리즘 자체는 단순하나 GeoPandas 의존성 분리 필요)

---

#### 8.1.3 MovingPandas

| 항목 | 내용 |
|------|------|
| **GitHub** | [movingpandas/movingpandas](https://github.com/movingpandas/movingpandas) |
| **Stars** | ~1,400 |
| **License** | BSD-3-Clause |
| **언어** | Python (GeoPandas/HoloViz) |
| **최종 업데이트** | 활발 (779 commits) |
| **문서** | [readthedocs](https://movingpandas.readthedocs.io/) |

**핵심 기능:**

1. **Stop Detection**: 궤적에서 정지점 감지, 포인트 또는 세그먼트로 추출
2. **Trajectory Splitting**: Stop 기반으로 궤적을 Trip으로 분할
3. **Trajectory Generalization**: 시공간 압축 (Douglas-Peucker 등)
4. **Kalman Filter**: 노이즈 제거 및 궤적 스무딩
5. **Outlier Removal**: 이상값 제거

**Wander 활용도**: ★★★☆☆ (중간)
- Stop Detection + Trajectory Splitting 개념은 유용
- 실제 알고리즘은 scikit-mobility/trackintel이 더 상세하고 문서화 잘 됨
- Kalman Filter 기반 GPS 노이즈 제거 로직은 포팅 가치 있음

---

#### 8.1.4 Infostop

| 항목 | 내용 |
|------|------|
| **GitHub** | [ulfaslak/infostop](https://github.com/ulfaslak/infostop) |
| **Stars** | ~66 |
| **License** | **MIT** |
| **언어** | Python + C++ (핵심 연산) |
| **논문** | [arXiv:2003.14370](https://arxiv.org/abs/2003.14370) |

**알고리즘 (3단계):**

```
1. 위치 트레이스를 정지 이벤트의 중앙값(median)으로 축소 (C++ 최적화)
2. 근접 위치 간 네트워크 구성 (Ball Search Tree)
3. Infomap 네트워크 클러스터링으로 고유 정지 장소 식별
```

**사용 예시:**
```python
from infostop import Infostop
model = Infostop()
labels = model.fit_predict(data)  # NumPy [lat, lng, timestamp]
```

**독특한 장점**: 다중 사용자 궤적을 동시 처리하여 **공유 정지 장소** 발견 가능

**Wander 활용도**: ★★★☆☆ (중간)
- 네트워크 클러스터링 접근법이 독특하나 C++ 의존성으로 iOS 포팅 복잡
- 단일 사용자 사진 GPS에는 trackintel/scikit-mobility가 더 적합
- 향후 다중 사용자 공유 분석(P2P) 시 참고 가치

---

### 8.2 집/직장 위치 감지

#### 8.2.1 HoWDe (Home and Work Detection)

| 항목 | 내용 |
|------|------|
| **GitHub** | [LLucchini/HoWDe](https://github.com/LLucchini/HoWDe) |
| **Stars** | ~10 |
| **License** | **MIT** |
| **언어** | Python (PySpark) |
| **최종 업데이트** | 2025-01 |
| **논문** | [arXiv:2506.20679](https://arxiv.org/abs/2506.20679) |
| **정확도** | Home 97%, Work 88% (검증됨) |

**핵심 알고리즘:**

```
Home Detection:
- 야간 시간대에 가장 빈번하게 방문하는 위치
- 절대 시간이 아닌 비율(proportion) 기반 → 데이터 희소성 대응

Work Detection:
- 근무 시간대에 반복적으로 방문하는 위치
- 슬라이딩 윈도우(ΔT_H=28일, ΔT_W=42일)로 거주지/직장 변경 감지

핵심 파라미터:
- ΔT_H, ΔT_W: 윈도우 크기
- C_hours, C_days: 최소 데이터 커버리지
- f_hours, f_days: 최소 방문 비율 임계값
```

**Wander 활용도**: ★★★★☆ (높음)
- MIT 라이센스, 97% 정확도로 검증된 알고리즘
- PySpark 의존성은 iOS 불가 → 핵심 로직만 Swift로 포팅
- **비율 기반 접근법**이 Wander에 특히 유용 (사진 데이터는 간헐적이므로)
- 포팅 대상: `HoWDe_labelling()` 함수의 시간대별 방문 비율 계산 로직

---

#### 8.2.2 Apple CLVisit (iOS 네이티브)

| 항목 | 내용 |
|------|------|
| **API** | `CLLocationManager.startMonitoringVisits()` |
| **최소 iOS** | iOS 8+ |
| **문서** | [Apple CLVisit](https://developer.apple.com/documentation/corelocation/clvisit) |

**특징:**
- iOS가 자동으로 의미있는 장소 방문을 감지 (집, 직장, 자주 가는 곳)
- `arrivalDate`, `departureDate`, `coordinate`, `horizontalAccuracy` 제공
- **가장 배터리 효율적인** 위치 모니터링 방식
- 백그라운드에서도 동작, 앱 종료 후에도 이벤트 전달

**한계:**
- 정밀도 낮음 (1-2분 오차)
- Visit 경계가 모호할 수 있음
- 사용자가 이미 촬영한 사진의 과거 GPS 분석에는 사용 불가 (실시간 전용)

**Wander 활용도**: ★★★☆☆ (보조적)
- 실시간 Visit 모니터링으로 LearnedPlace 자동 학습에 활용 가능
- 사진 분석 파이프라인 자체에는 부적합 (과거 데이터 분석이므로)
- **보완적 사용**: CLVisit으로 집/직장 학습 → 사진 분석 시 참조 장소로 활용

---

### 8.3 GPS 궤적 세그먼트/Trip 감지

#### 8.3.1 TrackToTrip

| 항목 | 내용 |
|------|------|
| **GitHub** | [ruipgil/TrackToTrip](https://github.com/ruipgil/TrackToTrip) |
| **Stars** | ~41 |
| **License** | **MIT** |
| **언어** | Python 2 |
| **최종 업데이트** | 2022-06 |

**알고리즘 파이프라인:**

```
1. Kalman Filter → GPS 노이즈 스무딩
2. DBSCAN spatiotemporal_segmentation() → 시공간 클러스터 발견
3. Douglas-Ramer-Peucker → 궤적 압축
4. Transportation Mode Classification → 이동 수단 분류 (sklearn, 84-86% 정확도)
```

**핵심 클래스:**
- `Track`: GPX 파일 로딩/처리
- `Segment`: 이동 구간 (포인트, 교통수단, 시작/끝 의미 장소)
- `spatiotemporal_segmentation()`: DBSCAN 기반 시공간 분할

**Wander 활용도**: ★★★☆☆ (중간)
- MIT 라이센스이나 Python 2로 구식
- DBSCAN 기반 시공간 세그먼테이션 로직은 참고 가치
- Kalman Filter + DRP 궤적 압축 조합 패턴은 포팅 가치

---

#### 8.3.2 stopdetection (R 패키지)

| 항목 | 내용 |
|------|------|
| **GitHub** | [daniellemccool/stopdetection](https://github.com/daniellemccool/stopdetection) |
| **Stars** | 소규모 |
| **License** | GPL-3.0 (**주의: 카피레프트**) |
| **언어** | R (75.5%) + C++ (16.5%) |
| **알고리즘** | Ye et al. (2009) |

**핵심 함수:**
```r
stopFinder(thetaD=200,    # 거리 반경 (m)
           thetaT=300,    # 체류 시간 임계값 (초)
           max_dist=...,  # 정지점 병합 최대 거리
           small_track_action="exclude")
```

**알고리즘 로직**: 시작 위치로부터 `thetaD` 이내의 모든 후속 위치가 `thetaT` 이상 지속되면 Stop 생성

**Wander 활용도**: ★★☆☆☆ (낮음)
- **GPL-3.0** → 상용 앱에서 직접 사용 시 라이센스 전파 위험
- 알고리즘 자체(Ye et al. 2009)는 공개 논문이므로 독립 구현 가능
- scikit-mobility의 BSD-3 구현이 동일 알고리즘을 더 안전하게 제공

---

#### 8.3.3 GeoPulse

| 항목 | 내용 |
|------|------|
| **GitHub** | [tess1o/geopulse](https://github.com/tess1o/geopulse) |
| **Stars** | ~495 |
| **License** | **BSL 1.1** (비상업 무료, 상업 사용 금지) |
| **기술 스택** | Java/Quarkus + PostGIS + Vue.js |

**기능:**
- 자동 Stay/Trip 분류 알고리즘
- 타임라인 감도 조절 기능
- Immich 사진 통합
- Google Timeline 데이터 가져오기

**Wander 활용도**: ★★☆☆☆ (낮음)
- BSL 1.1 → 상업 사용 금지
- 서버 기반(PostGIS) → 온디바이스 iOS와 아키텍처 불일치
- Stay/Trip 분류 **개념**만 참고 (구현은 사용 불가)

---

### 8.4 Swift/iOS 클러스터링 라이브러리

#### 8.4.1 NSHipster DBSCAN (★ 추천)

| 항목 | 내용 |
|------|------|
| **GitHub** | [NSHipster/DBSCAN](https://github.com/NSHipster/DBSCAN) |
| **Stars** | ~94 |
| **License** | **MIT** |
| **언어** | Swift |
| **SPM 지원** | O (`https://github.com/NSHipster/DBSCAN`, from: "0.0.1") |

**사용 예시:**
```swift
import DBSCAN

let points: [SIMD3<Double>] = [...]  // 3D 좌표 배열
let (clusters, outliers) = DBSCAN(
    points,
    epsilon: 10,          // 이웃 탐색 반경
    minimumNumberOfPoints: 1,  // 최소 포인트 수
    distanceFunction: { simd_distance($0, $1) }
)
```

**Wander 활용도**: ★★★★★ (매우 높음)
- **MIT + Swift + SPM** → 즉시 Wander에 통합 가능
- 제네릭 구현 → CLLocationCoordinate2D + Haversine 거리 함수로 커스터마이즈
- 현재 Wander의 ClusteringService.swift를 이 라이브러리로 대체/보강 가능
- **주의**: `distanceFunction`에 Haversine 거리 함수를 직접 제공해야 함

**GPS 클러스터링 적용 예시 (포팅 패턴):**
```swift
import DBSCAN
import CoreLocation

let photoLocations: [CLLocationCoordinate2D] = [...]

let (clusters, outliers) = DBSCAN(
    photoLocations,
    epsilon: 200,  // 200m
    minimumNumberOfPoints: 1,
    distanceFunction: { coord1, coord2 in
        CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
            .distance(from: CLLocation(latitude: coord2.latitude, longitude: coord2.longitude))
    }
)
```

---

#### 8.4.2 tinyfool/DBSCAN-swift

| 항목 | 내용 |
|------|------|
| **GitHub** | [tinyfool/DBSCAN-swift](https://github.com/tinyfool/DBSCAN-swift) |
| **Stars** | ~7 |
| **License** | 명시되지 않음 (Wikipedia 기반 구현) |
| **언어** | Swift |

**Wander 활용도**: ★★☆☆☆ (낮음)
- 라이센스 불명확 → 사용 위험
- NSHipster DBSCAN이 모든 면에서 우월

---

#### 8.4.3 SwiftLocation

| 항목 | 내용 |
|------|------|
| **GitHub** | [malcommac/SwiftLocation](https://github.com/malcommac/SwiftLocation) |
| **Stars** | ~3,400 |
| **License** | **MIT** |
| **언어** | Swift (async/await) |
| **최소 iOS** | iOS 14+ |

**핵심 기능:**
- `startMonitoringVisits()`: Visit 모니터링 (도착/출발 시간)
- `startMonitoringLocations()`: 연속 위치 추적
- Significant Location Change 모니터링
- async/await 기반 현대적 API

**Wander 활용도**: ★★★☆☆ (보조적)
- Visit 모니터링으로 집/직장 자동 학습에 유용
- 기존 사진 GPS 분석에는 직접 적용 불가 (실시간 전용)
- 향후 "실시간 위치 학습" 기능 추가 시 활용

---

### 8.5 H3 (Uber 헥사곤 그리드 시스템)

#### 8.5.1 H3 Core

| 항목 | 내용 |
|------|------|
| **GitHub** | [uber/h3](https://github.com/uber/h3) |
| **Stars** | ~6,000 |
| **License** | **Apache 2.0** |
| **언어** | C (79%) |
| **문서** | [h3geo.org](https://h3geo.org/) |

**해상도 테이블 (Wander 활용 관점):**

| 해상도 | 평균 셀 면적 | 평균 변 길이 | Wander 활용 |
|--------|-------------|-------------|------------|
| 4 | 1,770 km² | 26 km | 광역시/도 단위 |
| 5 | 253 km² | 9.85 km | 시/군/구 단위 |
| 6 | 36 km² | 3.72 km | 읍/면/동 단위 |
| 7 | 5.16 km² | 1.41 km | 동네 단위 |
| 8 | 0.74 km² | 531 m | 블록 단위 |
| 9 | 0.11 km² | 200 m | 건물/시설 단위 |
| 10 | 0.015 km² | 76 m | 개별 건물 |

**행정 경계 대체 가능성:**

```
기존 접근: CLGeocoder → "서울특별시 강남구 역삼동" 파싱
문제점: API 호출 필요, 국가마다 주소 형식 다름, 오프라인 불가

H3 접근: GPS → H3 Cell ID (해상도별)
장점:
- 오프라인 계산 가능 (순수 수학 연산)
- 국가/언어 무관 (글로벌 통일 그리드)
- 해상도별 비교로 "같은 동네" vs "다른 도시" 판별

구현 예시:
- 집 위치: H3 Cell (해상도 7) = "872a1072bffffff"
- 사진 위치: H3 Cell (해상도 7) = "872a1072bffffff" → 같은 셀 = 일상
- 사진 위치: H3 Cell (해상도 7) = "872a10735ffffff" → 다른 셀 = 확인 필요
- 사진 위치: H3 Cell (해상도 4) = "842a107ffffffff" → 다른 셀 = 여행
```

**Wander Context Classification 적용 방안:**

```swift
// Phase 1: 집/직장 H3 인덱스 저장
let homeH3_res7 = h3.cellIndex(for: homeCoord, resolution: 7)  // 동네 (~5km²)
let homeH3_res5 = h3.cellIndex(for: homeCoord, resolution: 5)  // 시/군 (~253km²)
let homeH3_res4 = h3.cellIndex(for: homeCoord, resolution: 4)  // 광역 (~1770km²)

// Phase 2: 사진 위치와 비교
let photoH3_res7 = h3.cellIndex(for: photoCoord, resolution: 7)

if photoH3_res7 == homeH3_res7 {
    return .daily          // 같은 동네 = 일상
} else if photoH3_res5 == homeH3_res5 {
    return .outing         // 같은 시/군, 다른 동네 = 외출
} else if photoH3_res4 == homeH3_res4 {
    return .shortTrip      // 같은 광역, 다른 시/군 = 근교 여행
} else {
    return .travel         // 다른 광역 = 여행
}
```

---

#### 8.5.2 SwiftyH3 (★ 추천 Swift 바인딩)

| 항목 | 내용 |
|------|------|
| **GitHub** | [pawelmajcher/SwiftyH3](https://github.com/pawelmajcher/SwiftyH3) |
| **Stars** | ~12 |
| **License** | **Apache 2.0** |
| **언어** | Swift |
| **최소 Swift** | 5.9+ |
| **SPM 지원** | O (`https://github.com/pawelmajcher/SwiftyH3.git`, "0.5.0"..<"0.6.0") |
| **최종 업데이트** | 2025-07 |

**핵심 API:**
```swift
import SwiftyH3

// CLLocationCoordinate2D → H3 Cell Index
let cellIndex = coordinate.cell(at: .resolution7)

// 이웃 셀 조회
let neighbors = cellIndex.neighbors(ringLevel: 1)

// 셀 경계 폴리곤 (MapKit 호환)
let polygon: MKPolygon = cellIndex.boundary

// 부모/자식 셀 (해상도 변경)
let parentCell = cellIndex.parent  // 더 넓은 영역
let childCells = cellIndex.children  // 더 좁은 영역

// 거리 계산
let gridDistance = cellIndex1.gridDistance(to: cellIndex2)
```

**MapKit/CoreLocation 통합**: `CLLocationCoordinate2D`, `MKPolygon`, `MKMultiPolygon` 직접 지원

**Wander 활용도**: ★★★★★ (매우 높음)
- Apache 2.0 + Swift + SPM → 즉시 통합 가능
- CoreLocation/MapKit 타입 직접 지원
- 오프라인 계산 → CLGeocoder 의존도 감소
- **행정 경계 대체**: 해상도 4-7로 동네/시/도 수준 비교 가능
- 성능: C 라이브러리 기반으로 밀리초 단위 연산

---

#### 8.5.3 H3kit (대안 Swift 바인딩)

| 항목 | 내용 |
|------|------|
| **GitHub** | [ehmjaysee/H3kit](https://github.com/ehmjaysee/H3kit) |
| **Stars** | ~6 |
| **License** | **Apache 2.0** |
| **언어** | Swift |
| **설치** | CocoaPods |
| **최종 업데이트** | 2020-11 |

**Wander 활용도**: ★★☆☆☆ (낮음)
- CocoaPods 전용 (SPM 미지원) → 프로젝트 의존성 관리 불편
- SwiftyH3가 더 최신이고 SPM 지원

---

### 8.6 Stay Point Detection 전용 라이브러리

#### 8.6.1 StayPointDetection (Python)

| 항목 | 내용 |
|------|------|
| **GitHub** | [zhang35/StayPointDetection](https://github.com/zhang35/StayPointDetection) |
| **License** | 명시되지 않음 |
| **언어** | Python 3 |
| **데이터셋** | GeoLife Trajectories 1.3 (Microsoft Research) |

**두 가지 구현:**
1. `stayPointDetection_basic.py`: Li et al. 기본 알고리즘
2. `stayPointDetection_density.py`: Yuan et al. 밀도 기반 알고리즘

**Wander 활용도**: ★★☆☆☆ (참고용)
- 라이센스 불명확 → 직접 포팅 위험
- 알고리즘 참고용으로만 활용 (동일 알고리즘은 scikit-mobility에서 BSD-3으로 구현)

---

#### 8.6.2 Stay-Point-Identification

| 항목 | 내용 |
|------|------|
| **GitHub** | [Yurui-Li/Stay-Point-Identification](https://github.com/Yurui-Li/Stay-Point-Identification) |
| **License** | 명시되지 않음 |
| **데이터셋** | GeoLife (17,621 궤적, 1,292,951km) |

**특징**: 시간 연속성과 양방향성을 고려한 개선된 Stay Point 감지

**Wander 활용도**: ★★☆☆☆ (참고용) - 라이센스 불명확

---

### 8.7 행정 경계 및 역지오코딩 API

#### 8.7.1 CLGeocoder (iOS 네이티브, 현재 Wander 사용 중)

```swift
let geocoder = CLGeocoder()
let placemarks = try await geocoder.reverseGeocodeLocation(location)
// placemark.administrativeArea    → 시/도
// placemark.subAdministrativeArea → 구/군
// placemark.locality              → 시/읍
// placemark.subLocality           → 동/면/리
// placemark.country               → 국가
// placemark.isoCountryCode        → 국가 코드
```

**장점**: 무료, 추가 의존성 없음, 행정 경계 정보 포함
**단점**: 네트워크 필요, 속도 제한, 응답 형식이 국가마다 다름

#### 8.7.2 BigDataCloud (무료 API)

| 항목 | 내용 |
|------|------|
| **URL** | [bigdatacloud.com](https://www.bigdatacloud.com/free-api/free-reverse-geocode-to-city-api) |
| **가격** | 클라이언트 사이드 무료 (API 키 불필요) |
| **특징** | 행정/비행정 경계 기반 결과 최초 제공 |

**응답 필드**: `countryName`, `principalSubdivision` (시/도), `city`, `locality`, `postcode`

#### 8.7.3 CLGeocoder + H3 하이브리드 접근 (★ 권장)

```
1차: H3 해상도 비교 (오프라인, 즉시)
  → 집과 같은 H3 셀(res 7) = 일상 (확정)
  → 집과 다른 H3 셀(res 4) = 여행 (확정)

2차: 경계 케이스만 CLGeocoder (온라인)
  → 같은 res 5, 다른 res 7 = CLGeocoder로 구/군 비교
  → 행정 경계 교차 여부 정밀 확인
```

이 접근법의 장점:
- 대부분의 케이스를 **오프라인**으로 즉시 처리 (H3)
- 경계 케이스만 **온라인** API 호출 (CLGeocoder)
- API 호출 횟수 최소화 (CLGeocoder 속도 제한 회피)

---

### 8.8 종합 평가: Wander 직접 도입 추천 라이브러리

| 우선순위 | 라이브러리 | 라이센스 | 용도 | 도입 방식 |
|---------|-----------|---------|------|----------|
| **1** | **SwiftyH3** | Apache 2.0 | 행정 경계 대체, 오프라인 분류 | SPM 직접 통합 |
| **2** | **NSHipster DBSCAN** | MIT | GPS 포인트 클러스터링 | SPM 직접 통합 |
| **3** | **trackintel** | MIT | 알고리즘 참조 (Swift 포팅) | 슬라이딩 윈도우 Stay Point + Trip 감지 포팅 |
| **4** | **scikit-mobility** | BSD-3 | 알고리즘 참조 (Swift 포팅) | Stop Detection + Clustering 파라미터 참조 |
| **5** | **HoWDe** | MIT | 집/직장 감지 로직 참조 | 시간대별 방문 비율 알고리즘 포팅 |
| **6** | **Apple CLVisit** | N/A | 실시간 장소 학습 | 네이티브 API 직접 사용 |

**포팅 대상 알고리즘 요약:**

```
[Swift 직접 사용]
1. SwiftyH3 → GPS → H3 Cell 비교 → 일상/외출/여행 1차 분류
2. NSHipster DBSCAN → 사진 GPS 클러스터링 (200m epsilon)

[Python → Swift 포팅]
3. trackintel generate_staypoints() → 슬라이딩 윈도우 Stay Point 감지
   - dist_threshold: 100m, time_threshold: 5min
4. trackintel generate_locations() → DBSCAN 기반 Location 생성
   - epsilon: 100m, num_samples: 1
5. scikit-mobility stay_locations() → 중앙값 기반 Stop 좌표 계산
   - spatial_radius: 200m, minutes_for_a_stop: 20
6. HoWDe → 시간대별 방문 비율 기반 집/직장 감지
   - 야간(00-06) 최빈 위치 = 집, 평일 주간(09-18) 최빈 위치 = 직장

[보조적 활용]
7. CLVisit → 백그라운드 장소 학습 (LearnedPlace 자동 생성)
8. CLGeocoder → H3 경계 케이스 정밀 확인용
```

---

## 9. 참고 자료

### 학술 논문
- [Comparison of home detection algorithms using smartphone GPS data](https://epjdatascience.springeropen.com/articles/10.1140/epjds/s13688-023-00447-w)
- [Identification of Stopping Points in GPS Trajectories](https://www.mdpi.com/1424-8220/23/7/3749)
- [Automated Urban Travel Interpretation](https://pmc.ncbi.nlm.nih.gov/articles/PMC5134621/)
- [PlaNet - Photo Geolocation with CNNs](https://research.google/pubs/planet-photo-geolocation-with-convolutional-neural-networks/)
- [Infostop: Scalable stop-location detection](https://arxiv.org/abs/2003.14370)
- [HoWDe: Establishing validated standards for Home and Work location Detection](https://arxiv.org/abs/2506.20679)
- [Trackintel: An open-source Python library for human mobility analysis](https://www.sciencedirect.com/science/article/pii/S0198971523000017)
- [scikit-mobility: A Python Library for Mobility Data Analysis](https://arxiv.org/abs/1907.07062)

### Apple 기술 문서
- [A Multi-Task Neural Architecture for On-Device Scene Analysis](https://machinelearning.apple.com/research/on-device-scene-analysis)
- [Recognizing People in Photos Through Private On-Device ML](https://machinelearning.apple.com/research/recognizing-people-photos)
- [Learning Iconic Scenes with Differential Privacy](https://machinelearning.apple.com/research/scenes-differential-privacy)
- [CLVisit Documentation](https://developer.apple.com/documentation/corelocation/clvisit)
- [CLGeocoder Documentation](https://developer.apple.com/documentation/corelocation/clgeocoder)

### 오픈소스 프로젝트 (라이센스별)
**MIT License:**
- [trackintel (ETH Zurich)](https://github.com/mie-lab/trackintel) - ★258, 모빌리티 분석 프레임워크
- [NSHipster DBSCAN](https://github.com/NSHipster/DBSCAN) - ★94, Swift DBSCAN
- [HoWDe](https://github.com/LLucchini/HoWDe) - ★10, 집/직장 감지
- [TrackToTrip](https://github.com/ruipgil/TrackToTrip) - ★41, GPS→Trip 변환
- [Infostop](https://github.com/ulfaslak/infostop) - ★66, Stop 감지
- [SwiftLocation](https://github.com/malcommac/SwiftLocation) - ★3,400, iOS 위치 래퍼

**Apache 2.0 License:**
- [Uber H3](https://github.com/uber/h3) - ★6,000, 헥사곤 그리드
- [SwiftyH3](https://github.com/pawelmajcher/SwiftyH3) - ★12, H3 Swift 바인딩
- [H3kit](https://github.com/ehmjaysee/H3kit) - ★6, H3 iOS 래퍼

**BSD-3-Clause License:**
- [scikit-mobility](https://github.com/scikit-mobility/scikit-mobility) - ★793, 모빌리티 분석
- [MovingPandas](https://github.com/movingpandas/movingpandas) - ★1,400, 궤적 분석

**기타 (상업 사용 주의):**
- [GeoPulse](https://github.com/tess1o/geopulse) - BSL 1.1 (비상업만 무료)
- [stopdetection](https://github.com/daniellemccool/stopdetection) - GPL-3.0 (카피레프트)
- [PhotoPrism](https://www.photoprism.app/)
- [Immich](https://github.com/immich-app)
- [AdventureLog](https://github.com/seanmorley15/AdventureLog)
- [NLR OpenPATH](https://www.nlr.gov/transportation/openpath)

### 기술 블로그
- [How Google Photos uses machine learning](https://www.csmonitor.com/Technology/2016/0324/How-Google-Photos-uses-machine-learning-to-create-customized-albums)
- [Geofencing in location-based behavioral research](https://link.springer.com/article/10.3758/s13428-023-02213-2)
- [Extracting Stays from GPS Points](https://medium.com/@brandonsegal/extracting-stays-from-gps-points-1e69df7ac35e)
- [H3 Resolution Statistics](https://h3geo.org/docs/core-library/restable/)
- [Guide to Uber's H3 for Spatial Indexing](https://www.analyticsvidhya.com/blog/2025/03/ubers-h3-for-spatial-indexing/)
- [trackintel Preprocessing Documentation](https://trackintel.readthedocs.io/en/latest/modules/preprocessing.html)
- [scikit-mobility Preprocessing Reference](https://scikit-mobility.github.io/scikit-mobility/reference/preprocessing.html)

---

## 10. 결론

### 핵심 인사이트

1. **Google/Apple 모두 "집에서 떨어진 거리/시간"이 핵심 기준**
   - 하지만 정확한 임계값은 비공개
   - Apple은 출퇴근이 Trip으로 잘못 분류되는 문제 있음

2. **행정 경계 기반 분류가 거리 기반보다 직관적**
   - "50km 떨어진 곳" vs "다른 시/도" → 후자가 사용자 인식과 일치
   - **H3 헥사곤 그리드로 오프라인 행정 경계 근사 가능** (Section 8.5)

3. **시간대 패턴이 장소 유형 추론에 핵심**
   - 야간 빈번 방문 → 집
   - 평일 주간 빈번 방문 → 회사/학교
   - **HoWDe 알고리즘 (MIT)이 비율 기반 접근법으로 97% 정확도 달성** (Section 8.2.1)

4. **혼합 사진 처리는 필수**
   - Apple도 이 문제를 완벽히 해결 못함
   - 사용자 확인 UI가 현실적 해결책

5. **불필요한 기능 제거로 신뢰성 향상**
   - 근거 불명확한 점수/DNA는 오히려 신뢰도 하락
   - 단순하고 정확한 것이 복잡하고 부정확한 것보다 나음

6. **즉시 도입 가능한 Swift 라이브러리 존재** (Section 8.8)
   - SwiftyH3 (Apache 2.0): 오프라인 GPS → 지역 분류
   - NSHipster DBSCAN (MIT): GPS 포인트 클러스터링
   - 두 라이브러리 모두 SPM 지원, 추가 의존성 최소

7. **trackintel의 계층적 모델이 Wander 파이프라인에 최적** (Section 8.1.2)
   - Positionfixes → Staypoints → Locations → Trips 데이터 모델
   - 사진의 GPS 포인트 → 체류 장소 → 자주 가는 곳 → 여행 으로 직접 매핑

---

*작성: Claude Code*
*최종 업데이트: 2026-02-07*
