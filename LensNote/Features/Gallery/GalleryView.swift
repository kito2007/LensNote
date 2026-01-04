//
//  GalleryView.swift
//  LensNote
//
//  Created by 박태영 on 1/4/26.
//

import SwiftUI

struct GalleryView: View {

    @StateObject private var viewModel: GalleryViewModel

    init(viewModel: GalleryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            List {
                if viewModel.items.isEmpty {
                    Text("아직 저장된 사진이 없어요. Camera 탭에서 저장해보세요 🙂")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)

                            Text("path: \(item.imagePath)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            if let c = item.coordinate {
                                Text("lat: \(c.latitude), lon: \(c.longitude)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Gallery")
            .onAppear {
                // MVP: 갤러리 탭으로 들어올 때마다 새로 불러오기
                viewModel.reload()
            }
        }
    }
}
