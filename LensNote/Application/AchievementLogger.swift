//
//  AchievementLogger.swift
//  LensNote
//
//  Req 11 — 목표 기능 달성도 평가 지표.
//  3대 목표 기능의 13개 항목 각각이 "에러 없이 + 다음 단계에 유효한 출력"을 만들면 달성(pass),
//  실패/ nil이면 미달성(fail)으로 os_log에 기록한다. 수동 테스트로 앱을 한 바퀴 돌리면
//  콘솔 로그로 기능별 달성도(기능1: N/4, 기능2: N/4, 기능3: N/5)를 집계할 수 있다.
//
//  항목 목록:
//  [기능 1: 레퍼런스 기반 카메라]
//   1a 레퍼런스 사진 → UIImage 반환
//   1b ShotRecipeAnalyzer → ShotRecipe 생성
//   1c FilterPreset.forConcept → 유효 프리셋
//   1d 라이브 뷰에 프리셋 적용된 프리뷰 진입
//  [기능 2: 실시간 구도 코칭]
//   2a RealTimeInferenceEngine 추론 결과 반환
//   2b ActiveGuidanceHint 문자열 생성
//   2c 구도 안내 배너 노출
//   2d LiveCoachingDelta 코칭 메시지 생성
//  [기능 3: 갤러리형 지도]
//   3a 저장→재조회 동일 데이터
//   3b PhotoPin 지도 표시
//   3c 2개 이상 핀 클러스터링
//   3d 핀 상세 카드 표시
//   3e 기간 필터 적용
//

import os

enum AchievementLogger {
    private static let logger = Logger(subsystem: "com.PTY.LensNote", category: "Achievement")
    /// 프레임/영역 변화로 자주 호출되는 항목을 첫 1회만 기록하기 위한 집합.
    /// 모든 호출이 MainActor에서 일어나 직렬화되므로 별도 락은 두지 않는다.
    private static var loggedOnce = Set<String>()

    /// 고빈도 경로용 — 같은 id는 첫 1회만 기록한다.
    static func passOnce(_ id: String, _ label: String, detail: String = "") {
        guard !loggedOnce.contains(id) else { return }
        loggedOnce.insert(id)
        pass(id, label, detail: detail)
    }

    /// 항목 달성. id는 "1a" 등 항목 코드, label은 사람이 읽는 설명.
    static func pass(_ id: String, _ label: String, detail: String = "") {
        if detail.isEmpty {
            logger.info("✅ [\(id, privacy: .public)] \(label, privacy: .public) 달성")
        } else {
            logger.info("✅ [\(id, privacy: .public)] \(label, privacy: .public) 달성 — \(detail, privacy: .public)")
        }
    }

    /// 항목 미달성. reason은 실패 원인(에러 메시지 또는 nil 반환).
    static func fail(_ id: String, _ label: String, reason: String) {
        logger.error("❌ [\(id, privacy: .public)] \(label, privacy: .public) 미달성 — \(reason, privacy: .public)")
    }
}
