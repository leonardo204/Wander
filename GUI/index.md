# Wander UI 스크린 인덱스

## 개요
Google Stitch로 생성된 UI 스크린 레퍼런스입니다.
Swift 앱 구현 시 디자인 참조용으로 사용합니다.

## 폴더 구조
```
GUI/
├── index.md (이 파일)
├── prompts/         ← Google Stitch 프롬프트
│   ├── wander_ai_prompts.md
│   ├── wander_ai_prompts2.md
│   ├── wander_ai_prompts3.md
│   └── wander_ai_prompts4.md  ← v2.1 신규 화면
└── screens/
    ├── SCR-XXX_name/
    │   ├── screen.png   ← UI 스크린샷
    │   └── code.html    ← HTML/CSS 코드 (참조용)
    └── ...
```

---

## 전체 화면 목록 (39개)

### 온보딩 (4개)

| 폴더명 | 설명 |
|--------|------|
| `SCR-001_splash` | 스플래시 화면 |
| `SCR-002_onboarding_intro` | 온보딩 - 서비스 소개 |
| `SCR-003_onboarding_photo` | 온보딩 - 사진 권한 |
| `SCR-004_onboarding_location` | 온보딩 - 위치 권한 |

### 메인 탭 (5개)

| 폴더명 | 설명 | 버전 |
|--------|------|------|
| `SCR-005_home_empty` | 홈 (빈 상태) | v2.0 |
| `SCR-005B_home_with_records` | 홈 (기록 있음) | v2.0 |
| `wander_home_screen_with_fab` | 홈 (FAB 포함) | **v2.1** |
| `SCR-006_records_library` | 기록 목록 | |
| `SCR-007_settings` | 설정 | |

### 여행 기록 플로우 (7개)

| 폴더명 | 설명 | 버전 |
|--------|------|------|
| `SCR-008_photo_selection` | 사진 선택 | |
| `SCR-009_analysis_progress` | 분석 중 로딩 | |
| `SCR-010_analysis_result` | 분석 결과 | |
| `SCR-010B_quick_mode_result` | 퀵 모드 결과 | |
| `SCR-011_map_detail` | 지도 상세 | |
| `SCR-022_weekly_photo_collection` | 주간 사진 수집 | |
| `lookback_selection_screen` | 돌아보기 (기간 선택) | **v2.1** |

### 편집 & 스토리 (2개)

| 폴더명 | 설명 |
|--------|------|
| `SCR-012_timeline_edit` | 타임라인 편집 |
| `SCR-013_ai_story` | AI 스토리 |

### 공유 & 내보내기 (5개)

| 폴더명 | 설명 | 버전 |
|--------|------|------|
| `SCR-014_share_sheet` | 공유 옵션 시트 | |
| `SCR-015_export_options` | 내보내기 옵션 | v2.0 |
| `export_options_screen_with_image_format` | 내보내기 (이미지 포함) | **v2.1** |
| `SCR-017_share_settings` | 공유 설정 | |
| `SCR-024_card_style` | 카드 스타일 선택 | |

### 설정 상세 (8개)

| 폴더명 | 설명 | 버전 |
|--------|------|------|
| `SCR-016_ai_provider` | AI 프로바이더 설정 | |
| `SCR-020_api_key_input` | API Key 입력 | |
| `SCR-021_data_management` | 데이터 관리 | |
| `SCR-025_notification_settings` | 알림 설정 | |
| `SCR-026_map_style` | 지도 스타일 | |
| `SCR-027_permission_settings` | 권한 설정 | |
| `category_management_screen` | 카테고리 관리 | **v2.1** |
| `user_places_management_screen` | 내 장소 설정 | **v2.1** |

### 보안/프라이버시 (2개) - v2.1 신규

| 폴더명 | 설명 | 버전 |
|--------|------|------|
| `hidden_travel_records_screen` | 숨긴 기록 목록 | **v2.1** |
| `pin_authentication_screen` | PIN 인증 화면 | **v2.1** |

### 에러 화면 (2개)

| 폴더명 | 설명 |
|--------|------|
| `SCR-019_error` | 일반 에러 |
| `SCR-019_permission_denied` | 권한 거부 에러 |

### 뷰어 & 시트 & 모달 (4개)

| 폴더명 | 설명 |
|--------|------|
| `SCR-023_photo_viewer` | 사진 뷰어 (풀스크린) |
| `SHEET-001_date_picker` | 날짜 선택 시트 |
| `SHEET-002_quick_select` | 퀵 선택 시트 |
| `SHEET-003_place_detail` | 장소 상세 시트 |
| `MODAL-001_delete_confirm` | 삭제 확인 모달 |

---

## v2.1 신규 화면 요약 (7개)

| 폴더명 | 화면 ID | 설명 |
|--------|---------|------|
| `wander_home_screen_with_fab` | SCR-005 (updated) | FAB 포함 홈 화면 |
| `lookback_selection_screen` | SCR-022 | 돌아보기 기간 선택 |
| `hidden_travel_records_screen` | SCR-023 | 숨긴 기록 목록 |
| `pin_authentication_screen` | SCR-024 | PIN/생체 인증 |
| `category_management_screen` | SCR-025 | 카테고리 관리 |
| `user_places_management_screen` | SCR-026 | 내 장소 설정 |
| `export_options_screen_with_image_format` | SCR-015 (updated) | 이미지 내보내기 |

---

## 디자인 시스템 요약

| 항목 | 값 |
|------|-----|
| Primary Color | `#87CEEB` |
| Background | `#FFFFFF` |
| Surface | `#F8FBFD` |
| Text Primary | `#1A2B33` |
| 탭바 | 3개 (홈, 기록, 설정) |
| 뷰포트 | iPhone 14 (390 x 844) |

---

*최종 업데이트: 2026-02-01 (총 39개 화면, v2.1 신규 7개)*
