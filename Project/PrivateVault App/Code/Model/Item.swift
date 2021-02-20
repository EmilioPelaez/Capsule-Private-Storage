//
//  Item.swift
//  PrivateVault
//
//  Created by Emilio Peláez on 19/2/21.
//

import SwiftUI
import UIKit

struct Item: Identifiable {
	
	let id: String
	let title: String
	let url: URL
	
	private var _placeholder: Image?
	var placeholder: Image {
		if let _placeholder = _placeholder { return _placeholder }
		return Image(systemName: "xmark.octagon")
	}
}

extension Item {
	init(image: UIImage) {
		let id = UUID().uuidString
		self.id = id
		self.title = ""
		self._placeholder = Image(uiImage: image)
		
		do {
			let data = image.pngData()
			let folder = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
				.appendingPathComponent("data")
			let url = folder
				.appendingPathComponent(id)
				.appendingPathExtension("png")
			
			try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
			
			//	For now this will write the data to disk on init and will never be removed
			//	TODO: Write to disk as needed
			try data?.write(to: url)
			
			self.url = url
		} catch {
			print("Uh oh", error)
			self.url = URL(fileURLWithPath: "~")
		}
	}
}


