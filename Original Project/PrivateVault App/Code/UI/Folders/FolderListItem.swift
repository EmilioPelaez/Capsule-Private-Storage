//
//  FolderListItem.swift
//  PrivateVault
//
//  Created by Elena Meneghini on 06/08/2021.
//

import SwiftUI

struct FolderListItem: View {
	let name: String
	let isSelected: Bool
	let isSelectable: Bool
	let action: () -> Void
	
	var body: some View {
		Button(action: action) {
			HStack {
				FolderShape()
					.folderStyle()
					.frame(width: 20 * FolderShape.preferredAspectRatio, height: 20)
				Text(name)
					.foregroundColor(.primary)
				Spacer()
				RadioButton(selected: isSelected, size: 16, color: .blue)
			}
		}
		.disabled(!isSelectable)
		.saturation(isSelectable ? 1 : 0)
	}
}

struct FolderListItem_Previews: PreviewProvider {
	static var previews: some View {
		FolderListItem(name: "Documents", isSelected: true, isSelectable: false) {}
	}
}
