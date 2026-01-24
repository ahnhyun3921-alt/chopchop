//
//  FlowLayout.swift
//  SafeEat
//
//  Created by Claude on 2026-01-24.
//

import SwiftUI

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    @State private var height: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                Color.clear
                self.generateContent(in: geometry)
            }
        }
        .frame(height: height)
    }

    private func generateContent(in geometry: GeometryProxy) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lastHeight: CGFloat = 0

        return ZStack(alignment: .topLeading) {
            ForEach(Array(data.enumerated()), id: \.element) { index, item in
                content(item)
                    .padding(.all, spacing)
                    .alignmentGuide(.leading) { dimension in
                        if abs(width - dimension.width) > geometry.size.width {
                            width = 0
                            height -= lastHeight
                        }
                        let result = width
                        if index == data.count - 1 {
                            width = 0
                        } else {
                            width -= dimension.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { dimension in
                        let result = height
                        if index == data.count - 1 {
                            height = 0
                        }
                        lastHeight = dimension.height
                        return result
                    }
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: HeightPreferenceKey.self,
                    value: geo.size.height
                )
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self) { value in
            self.height = value
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
