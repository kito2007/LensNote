//
//  PhotoRepo.swift
//  LensNote
//
//  Created by 박태영 on 12/24/25.
//

import Foundation

protocol PhotoRepositoryProtocol {
    func save(photo: PhotoItem) throws
    func fetchAll() throws -> [PhotoItem]
}
