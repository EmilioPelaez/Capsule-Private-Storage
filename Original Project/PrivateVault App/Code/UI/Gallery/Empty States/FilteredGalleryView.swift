//
//  FilteredGalleryView.swift
//  PrivateVault
//
//  Created by Emilio Peláez on 20/2/21.
//

import SwiftUI

struct FilteredGalleryView: View {
	let action: () -> Void

	var body: some View {
		VStack(spacing: 25) {
			Image("GalleryFiltered")
				.resizable()
				.aspectRatio(CGSize(width: 579, height: 622), contentMode: .fit)
				.padding(.horizontal, 45)
			VStack(spacing: 8) {
				Text("No Matches!")
					.font(.title2)
					.multilineTextAlignment(.center)
			}
			Button(action: action) {
				Text("Clear Filters & Search")
					.font(.headline)
					.foregroundColor(.white)
					.padding(.horizontal, 15)
					.padding(.vertical, 10)
					.background(
						RoundedRectangle(cornerRadius: 10, style: .continuous)
							.fill(Color.blue)
					)
			}
		}
		.frame(maxWidth: 300)
	}
}

struct FilteredGalleryView_Previews: PreviewProvider {
	static var previews: some View {
		FilteredGalleryView {}
	}
}
