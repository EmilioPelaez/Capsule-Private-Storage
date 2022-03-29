//
//  GalleryGridFolder.swift
//  PrivateVault
//
//  Created by Elena Meneghini on 17/07/2021.
//

import SwiftUI

struct GalleryGridFolderCell: View {
	enum Style {
		case compact
		case folder
	}

	let folder: Folder
	let style: Style
	
	var body: some View {
		switch style {
		case .compact:
			HStack {
				Image(systemName: "folder.fill")
					.folderStyle()
					.font(.title)
				Text(folder.name ?? "Untitled Folder")
					.lineLimit(1)
					.font(.headline)
				Spacer()
			}
			.padding(8)
			.background(Color(.quaternarySystemFill))
			.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
		case .folder:
			ZStack {
				FolderShape()
					.folderStyle()
					.aspectRatio(FolderShape.preferredAspectRatio, contentMode: .fill)
				GeometryReader { proxy in
					ZStack {
						Color.clear
						Text(folder.name ?? "Untitled Folder")
							.font(.headline)
							.multilineTextAlignment(.center)
							.lineLimit(2)
							.foregroundColor(.black)
							.padding(4)
							.padding(.top, ceil(proxy.size.height * FolderShape.tabHeightFactor))
					}
				}
			}
			.padding(8)
		}
	}
}

struct GalleryGridFolder_Previews: PreviewProvider {
	static let preview = PreviewEnvironment()
	
	static var previews: some View {
		GalleryGridFolderCell(folder: preview.folder, style: .compact)
		GalleryGridFolderCell(folder: preview.folder, style: .folder)
	}
}
