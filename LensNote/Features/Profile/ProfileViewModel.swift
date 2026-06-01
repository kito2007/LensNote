//
//  ProfileViewModel.swift
//  LensNote
//
//  Req 5 — Profile 통계 로딩/상태 관리.
//

import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {

    /// Profile 통계 로드 상태.
    enum LoadState: Equatable {
        case loading
        case empty                 // 저장된 사진 0건 (Req 5.3)
        case loaded(ProfileStats)
        case failed                // 데이터 읽기 실패 (Req 5.6)
    }

    @Published private(set) var state: LoadState = .loading

    private let fetchUseCase: FetchPhotoPinsUseCase

    init(fetchUseCase: FetchPhotoPinsUseCase) {
        self.fetchUseCase = fetchUseCase
    }

    /// 저장된 PhotoItem을 읽어 통계를 계산한다(동기, 2초 이내 — Req 5.7).
    func load() {
        do {
            let items = try fetchUseCase.execute()
            state = items.isEmpty ? .empty : .loaded(ProfileStatsCalculator.compute(from: items))
        } catch {
            state = .failed
        }
    }
}
