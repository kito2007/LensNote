//
//  GalleryViewModel.swift
//  LensNote
//
//  Created by 박태영 on 1/4/26.
//

import Foundation
import Combine

@MainActor
final class GalleryViewModel: ObservableObject {

    private let loadPhotosUseCase: LoadPhotosUseCase

    @Published var items: [PhotoItem] = []
    @Published var errorMessage: String? = nil

    init(loadPhotosUseCase: LoadPhotosUseCase) {
        self.loadPhotosUseCase = loadPhotosUseCase
    }

    func reload() {
        do {
            items = try loadPhotosUseCase.execute()
            errorMessage = nil
        } catch {
            errorMessage = String(describing: error)
        }
    }
}
