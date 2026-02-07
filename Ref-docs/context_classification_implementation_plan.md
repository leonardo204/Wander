# Context Classification v3.2: H3 + DBSCAN 풀 도입 구현 계획

> **중요**: context compaction 시 이 파일을 참조하여 작업 맥락을 유지하세요.
> **작성일**: 2026-02-07
> **상태**: 구현 완료 (Xcode 빌드 확인 필요)

---

## 현재 진행 상태 (TODO)

- [x] Step 1: 연구 문서 업데이트 (context_classification_research.md Section 8)
- [x] Step 2: ui-scenarios 문서 업데이트
- [x] Step 3: CLAUDE.local.md 업데이트
- [x] Step 4: SPM 의존성 추가 (project.yml)
- [x] Step 5: Model 레이어 (UserPlace H3 필드, LearnedPlace 전면 재작성)
- [x] Step 6: Service 레이어 (ClusteringService DBSCAN, ContextClassificationService H3, AnalysisEngine H3Info)
- [x] Step 7: View 레이어 (UserPlacesView computeH3Indices + 마이그레이션, WanderApp 레거시 정리)
- [x] Step 8: xcodegen generate 완료

---

## Context (왜 이 변경이 필요한가)

현재 Context Classification v3.1은 CLGeocoder 기반 행정구역 문자열 비교(`administrativeArea`/`locality`/`subLocality`)를 사용합니다. 연구 결과, 다음 접근법이 더 우수합니다:

1. **SwiftyH3** (Apache 2.0): H3 헥사곤 그리드로 오프라인 즉시 분류
2. **NSHipster DBSCAN** (MIT): 밀도 기반 클러스터링으로 기존 순차 알고리즘 대체
3. **HoWDe 비율 기반 알고리즘** (MIT): 절대 카운트 대신 비율로 집/회사 감지 (97% 정확도)

---

## 작업 순서

### Step 2: ui-scenarios 문서 업데이트

**파일 목록:**

1. `Ref-Concepts/ui-scenarios/tab-settings/settings-places.md`
   - "거리 레벨 정의" 테이블을 H3 해상도 기반으로 변경
   - LearnedPlace 모델 스니펫을 HoWDe 비율 기반으로 변경
   - Context Classification 연동 플로우차트에서 "행정구역 비교" → "H3 셀 비교" 변경

2. `Ref-Concepts/ui-scenarios/common/result-view.md`
   - Section 7.1 Context 분류 기준 테이블에 H3 해상도 매핑 추가
   - 분류 알고리즘에 "오프라인 H3 비교 → 경계 케이스만 CLGeocoder" 명시

3. `Ref-Concepts/ui-scenarios/01-onboarding.md`
   - 장소 등록 시 H3 인덱스 자동 계산 언급 (내부 구현, UX 변경 없음)

### Step 3: CLAUDE.local.md 업데이트

- 기술 스택 테이블에 SwiftyH3 (Apache 2.0), DBSCAN (MIT) 추가
- 필수 프레임워크에 `import SwiftyH3`, `import DBSCAN` 추가
- 폴더 구조에 ContextClassificationService.swift, LearnedPlace.swift 추가
- 핵심 기능 테이블에 Context Classification 행 추가
- 데이터 모델에 LearnedPlace 클래스 스니펫 추가

### Step 4: SPM 의존성 추가

**파일**: `src/project.yml`

```yaml
packages:
  Parchment:
    url: https://github.com/rechsteiner/Parchment
    from: "4.0.0"
  SwiftyH3:
    url: https://github.com/pawelmajcher/SwiftyH3.git
    minorVersion: "0.5.0"
  DBSCAN:
    url: https://github.com/NSHipster/DBSCAN
    from: "0.0.1"
```

dependencies에 `SwiftyH3`, `DBSCAN` 추가 후 `cd src && xcodegen generate` 실행

### Step 5: Model 레이어

#### 5-1. UserPlace.swift - H3 셀 인덱스 추가
- `h3CellRes4`, `h3CellRes5`, `h3CellRes7`, `h3CellRes9` (String?) 필드 추가
- `computeH3Indices()` 메서드: SwiftyH3로 좌표→H3 셀 변환
- `hasH3Indices` computed property
- 기존 `administrativeArea`/`locality`/`subLocality` 유지 (표시용)

#### 5-2. LearnedPlace.swift - HoWDe + H3 전면 재작성
- H3 res9를 장소 ID (문자열 행정구역명 대체)
- 절대 카운트 → 비율 기반:
  - `visitLogJSON`: 방문 날짜 배열 (JSON, 90일 제한)
  - `nightVisitProportion` > 0.3 → 집 추천
  - `weekdayDaytimeProportion` > 0.25 → 회사 추천
  - 슬라이딩 윈도우: 집 28일, 회사 42일

### Step 6: Service 레이어

#### 6-1. ClusteringService.swift - DBSCAN 전면 재작성
```
1. splitByTimeGap(): 30분 간격 시간 세그먼트 분리
2. dbscanCluster(): NSHipster DBSCAN (epsilon=200m, minPts=1, Haversine)
3. mergeNearbyClusters(): 세그먼트 간 200m 이내 클러스터 병합
```

#### 6-2. ContextClassificationService.swift - H3 기반 재작성
- `DistanceLevel` → `H3DistanceLevel` (sameBuilding~differentProvince)
- `ClusterAdminInfo` → `ClusterH3Info` (H3 셀 인덱스 기반)
- 분류: res7 일치=일상, res5 일치=외출, res4 일치=근교여행, 불일치=여행
- `TravelContext` enum 유지 (daily, outing, travel, mixed)

#### 6-3. AnalysisEngine.swift - 최소 변경
- `classifyContext()` 헬퍼: `ClusterAdminInfo` → `ClusterH3Info`
- Step 6.6: `updateLearnedPlaces()` 추가

### Step 7: View 레이어 (최소)

- UserPlacesView.swift: 장소 저장 시 `computeH3Indices()` 호출 + 마이그레이션
- WanderApp.swift: 레거시 LearnedPlace (H3 없는) 정리

---

## H3 해상도 매핑

| Level | H3 Resolution | Cell Size | Wander 분류 |
|-------|--------------|-----------|------------|
| 0 | res 9 match | ~0.11 km² | 같은 건물 → 일상 |
| 1 | res 7 match | ~5.16 km² | 같은 동네 → 일상 |
| 2 | res 5 match | ~253 km² | 같은 시/군 → 외출 |
| 3 | res 4 match | ~1,770 km² | 같은 시/도 → 근교여행 |
| 4 | no match | - | 다른 시/도 → 여행 |

---

## 마이그레이션

| 데이터 | 전략 |
|--------|------|
| UserPlace | 레이지 마이그레이션 (H3 인덱스 계산, 순수 수학) |
| LearnedPlace | 레거시 레코드 삭제, 자동 재학습 |
| TravelRecord | 변경 없음 |
| SwiftData 스키마 | Optional 필드 추가, 비파괴적 |

---

## 주요 파일 목록

| 파일 | 변경 유형 |
|------|----------|
| `src/project.yml` | SPM 의존성 추가 |
| `src/Models/SwiftData/UserPlace.swift` | H3 셀 필드 추가 |
| `src/Models/SwiftData/LearnedPlace.swift` | 전면 재작성 |
| `src/Services/AnalysisService/ClusteringService.swift` | 전면 재작성 |
| `src/Services/AnalysisService/ContextClassificationService.swift` | 핵심 로직 재작성 |
| `src/Services/AnalysisService/AnalysisEngine.swift` | ClusterH3Info 변경 |
| `src/Views/Settings/UserPlacesView.swift` | computeH3Indices() 추가 |
| `src/WanderApp.swift` | 레거시 정리 |
| `Ref-Concepts/ui-scenarios/tab-settings/settings-places.md` | H3 세부사항 |
| `Ref-Concepts/ui-scenarios/common/result-view.md` | H3 분류 기준 |
| `Ref-Concepts/ui-scenarios/01-onboarding.md` | H3 구현 언급 |
| `CLAUDE.local.md` | 의존성/아키텍처 |

---

*최종 업데이트: 2026-02-07*
