//
//  FilterStyle.swift
//  LensNote
//
//  Created by 박태영 on 12/23/25.
//

import Foundation

public enum FilterStyle: String, Codable, CaseIterable {
    case filmSoft = "film_soft"
    case vivid
    case matte
    case naturalClean = "natural_clean"
    case bwHighContrast = "bw_highcontrast"
    case etc
}

public extension FilterStyle {
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
