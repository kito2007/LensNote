//
//  FilterStyle.swift
//  LensNote
//
//  Created by 박태영 on 12/23/25.
//

import Foundation

/// 후처리 필터의 기본 스타일 분류.
/// 현재는 고정 enum이지만, 추후 서버/모델 기반 추천값으로 확장 가능하다.
public enum FilterStyle: String, Codable, CaseIterable {
    case filmSoft = "film_soft"
    case vivid
    case matte
    case naturalClean = "natural_clean"
    case bwHighContrast = "bw_highcontrast"
    case etc
}

public extension FilterStyle {
    /// UI에서 사용하는 한국어 표시 이름.
    var displayNameKR: String {
        switch self {
        case .filmSoft: return "필름 소프트"
        case .vivid: return "비비드"
        case .matte: return "매트"
        case .naturalClean: return "내추럴 클린"
        case .bwHighContrast: return "흑백 고대비"
        case .etc: return "기타"
        }
    }
}
