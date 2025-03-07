//  SiteView.swift
//  CloudbaseUtah
//  Created by Brown, Mike on 3/6/25.

import SwiftUI

struct WeatherView: View {
    @State private var image: Image? = nil
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        VStack {
            if isLoading {
                ProgressView("Loading...")
            } else {
                image?
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(x: offset.width, y: offset.height)
                    .gesture(MagnificationGesture()
                        .onChanged { value in
                            self.scale = max(1.0, value.magnitude)
                        }
                    )
                    .gesture(DragGesture()
                        .onChanged { value in
                            self.offset = CGSize(width: value.translation.width + self.lastOffset.width, height: value.translation.height + self.lastOffset.height)
                        }
                        .onEnded { value in
                            self.lastOffset = self.offset
                        }
                    )
            }
        }
        .onAppear {
            loadImage()
        }
    }

    func loadImage() {
        guard let url = URL(string: "https://weather.rap.ucar.edu/upper/displayUpper.php?img=KSLC.png&endDate=-1&endTime=-1&duration=0") else {
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.image = Image(uiImage: uiImage)
                    self.isLoading = false
                }
            } else {
                // Handle error
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
        task.resume()
    }
}

#Preview {
    WeatherView()
}
