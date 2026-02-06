# Wander UI 시나리오 명세서 - 인덱스

## 문서 정보
- **버전**: v3.0
- **작성일**: 2026년 2월 6일
- **기반 문서**: wander_ui_scenario.md v2.3
- **목적**: 탭별 분리된 UI 시나리오 문서의 인덱스

### 변경 이력
| 버전 | 날짜 | 내용 |
|------|------|------|
| v3.0 | 2026-02-06 | 탭별 문서 분리, API Key → Premium 전환, 개인정보 문구 수정 |
| v2.3 | 2026-02-04 | 다국어 지원 추가 |
| v2.2 | 2026-02-04 | 결과 편집, 재분석, Wander Intelligence |
| v2.1 | 2026-02-03 | FAB, 돌아보기, 숨긴 기록, 카테고리, 사용자 장소 |
| v2.0 | 2026-02-02 | 서버리스 전환, 프리미엄/로그인 제거, BYOK |

---

## 전체 화면 목록 (Screen Inventory)

| 화면 ID | 화면명 | 문서 |
|---------|--------|------|
| SCR-001 | 스플래시 | [온보딩](01-onboarding.md) |
| SCR-002 | 온보딩 1 - 서비스 소개 | [온보딩](01-onboarding.md) |
| SCR-003 | 온보딩 2 - 사진 권한 | [온보딩](01-onboarding.md) |
| SCR-004 | 온보딩 3 - 위치 권한 | [온보딩](01-onboarding.md) |
| SCR-005 | 홈 | [홈 메인](tab-home/home-main.md) |
| SCR-006 | 기록 목록 | [기록 목록](tab-records/records-list.md) |
| SCR-006a | 기록 상세 | [결과 화면](common/result-view.md) |
| SCR-007 | 설정 | [설정 메인](tab-settings/settings-main.md) |
| SCR-008 | 사진 선택 | [여행 기록 생성](tab-home/home-create-flow.md) |
| SCR-009 | 분석 중 | [여행 기록 생성](tab-home/home-create-flow.md) |
| SCR-010 | 분석 결과 | [결과 화면](common/result-view.md) |
| SCR-011 | 지도 상세 | [결과 화면](common/result-view.md) |
| SCR-012 | 타임라인 편집 | [결과 화면](common/result-view.md) |
| SCR-013 | AI 스토리 | [결과 화면](common/result-view.md) |
| SCR-014 | 공유 시트 | [공유 및 내보내기](common/share-export.md) |
| SCR-015 | 내보내기 옵션 | [공유 및 내보내기](common/share-export.md) |
| SCR-016 | AI 설정 | [설정 - AI](tab-settings/settings-ai.md) |
| SCR-017 | 공유 설정 (제거됨) | ~~설정 탭에서 제거~~ |
| SCR-018 | 보안 설정 | [설정 - 보안](tab-settings/settings-security.md) |
| SCR-019 | 에러 화면 | [에러 처리](error-handling.md) |
| SCR-020 | API Key 입력 (레거시) | [설정 - AI](tab-settings/settings-ai.md) |
| SCR-021 | 데이터 관리 | [설정 - 데이터](tab-settings/settings-data.md) |
| SCR-022 | 돌아보기 | [돌아보기](common/lookback.md) |
| SCR-023 | 숨긴 기록 | [숨긴 기록](tab-records/records-hidden.md) |
| SCR-024 | 인증 화면 | [설정 - 보안](tab-settings/settings-security.md) |
| SCR-025 | 카테고리 관리 | [설정 - 장소/카테고리](tab-settings/settings-places.md) |
| SCR-026 | 사용자 장소 설정 | [설정 - 장소/카테고리](tab-settings/settings-places.md) |
| SCR-027 | 언어 설정 | [부록](appendix.md) |
| SCR-028 | 앱 정보 | [설정 메인](tab-settings/settings-main.md) |

---

## 문서 구조

### 기본 문서
| 문서 | 설명 |
|------|------|
| [앱 구조](00-app-structure.md) | 전체 앱 구조, 화면 목록 |
| [온보딩](01-onboarding.md) | 앱 진입, 온보딩, 권한 요청 |

### 홈 탭 (`tab-home/`)
| 문서 | 설명 |
|------|------|
| [홈 메인](tab-home/home-main.md) | 홈 화면 구조, 레이아웃, 상호작용 |
| [여행 기록 생성](tab-home/home-create-flow.md) | 사진 선택 → 분석 → 결과 플로우 |
| [퀵 모드](tab-home/home-quick-mode.md) | "지금 뭐해?" 퀵 모드 |
| [주간 하이라이트](tab-home/home-weekly.md) | 이번 주 하이라이트, 일상 기록 |

### 기록 탭 (`tab-records/`)
| 문서 | 설명 |
|------|------|
| [기록 목록](tab-records/records-list.md) | 기록 목록, 검색, 필터, 컨텍스트 메뉴 |
| [숨긴 기록](tab-records/records-hidden.md) | 숨긴 기록, 인증 플로우 |

### 설정 탭 (`tab-settings/`)
| 문서 | 설명 |
|------|------|
| [설정 메인](tab-settings/settings-main.md) | 설정 화면 구조, 레이아웃 |
| [AI 설정](tab-settings/settings-ai.md) | Google OAuth, Premium, API Key (레거시) |
| [데이터 관리](tab-settings/settings-data.md) | 저장 공간, 캐시, 백업 |
| [보안](tab-settings/settings-security.md) | PIN, 생체인증 |
| [장소/카테고리](tab-settings/settings-places.md) | 카테고리 관리, 사용자 장소 |

### 공통 (`common/`)
| 문서 | 설명 |
|------|------|
| [결과 화면](common/result-view.md) | 분석 결과, 타임라인, 지도, 편집 |
| [공유 및 내보내기](common/share-export.md) | 공유 플로우, 내보내기 |
| [돌아보기](common/lookback.md) | 기간별 사진 자동 수집 |

### 디자인
| 문서 | 설명 |
|------|------|
| [디자인 컨셉](design-concept.md) | 컬러, 타이포그래피, 간격, 컴포넌트, 접근성 |

### 시스템
| 문서 | 설명 |
|------|------|
| [에러 처리](error-handling.md) | 예외 케이스, 에러 처리 |
| [상태 관리](state-management.md) | 앱 상태, 데이터 플로우 |
| [부록](appendix.md) | 화면 전환 매트릭스, 에러 코드, 접근성, 다국어 |
