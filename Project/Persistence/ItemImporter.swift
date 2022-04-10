//
//  ItemImporter.swift
//  Persistence
//
//  Created by Emilio Peláez on 09/04/22.
//

import AVFoundation
import CGMath
import Combine
import CoreData
import CoreGraphics
import Foundation
import LinkPresentation
import Photos
import QuickLook
import UIKit
import VisionKit

public class ItemImporter {
	
	let operationQueue = ObservableOperationQueue()
	let container: NSPersistentContainer
	var context: NSManagedObjectContext { container.viewContext }
	
	@Published public private(set) var creatingFiles = false
	@Published public private(set) var errorString = ""
	var importErrors: [ImportError] = [] {
		didSet { errorString = importErrors.displayMessage }
	}
	
	let previewSize: CGFloat = 500
	var bag: Set<AnyCancellable> = []
	
	public init(container: NSPersistentContainer, operations: Int = 4) {
		self.container = container
		
		operationQueue.maxConcurrentOperationCount = operations
		
		combine()
	}
	
	private func combine() {
		operationQueue.$isRunning.assign(to: &$creatingFiles)
	}
	
	func addOperation(block: @escaping (@escaping () -> Void) -> Void) {
		let operation = AsynchronousOperation(block: block)
		operationQueue.addOperation(operation)
	}
	
	func flushErrors() {
		importErrors = []
	}
	
	func save() {}
	
	func receiveCapturedImage(_ image: UIImage, folder: Folder?) {
		receiveImage(image, name: "New Photo", fileExtension: "jpg", folder: folder)
	}
	
	func receiveImage(_ image: UIImage, name: String, fileExtension: String, folder: Folder?) {
		addOperation { [weak self] complete in
			self?.storeImage(image: image, name: name, fileExtension: fileExtension, folder: folder) { [weak self] in
				self?.processResult($0, completion: complete)
			}
		}
	}
	
	func receiveScan(_ scan: VNDocumentCameraScan, folder: Folder?) {
		addOperation { [weak self] complete in
			self?.storeScan(scan, name: "Scanned Document", fileExtension: "pdf", folder: folder) { [weak self] in
				self?.processResult($0, completion: complete)
			}
		}
	}
	
	func receiveURLs(_ urls: [URL], folder: Folder?) {
		urls.forEach { url in
			addOperation { [weak self] complete in
				self?.storeItem(at: url, folder: folder) { [weak self] in
					self?.processResult($0, completion: complete)
				}
			}
		}
	}
	
	func receiveItems(_ items: [NSItemProvider], folder: Folder?) {
		items.forEach { item in
			addOperation { [weak self] complete in
				self?.storeItem(item, folder: folder) { [weak self] in
					self?.processResult($0, completion: complete)
				}
			}
		}
	}
	
	private func storeImage(image: UIImage, name: String, fileExtension: String, folder: Folder?, completion: @escaping (Result<Void, ImportError>) -> Void) {
		let image = image.fixOrientation()
		let data: Data?
		if fileExtension == "png" {
			data = image.pngData()
		} else {
			data = image.jpegData(compressionQuality: 0.85)
		}
		let previewData = image.square(previewSize)?.jpegData(compressionQuality: 0.85)
		guard let data = data, let previewData = previewData else {
			return DispatchQueue.main.async {
				completion(.failure(.cantLoadPDF))
			}
		}
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			_ = StoredItem(context: self.context, data: data, previewData: previewData, type: .image, name: name, fileExtension: fileExtension, folder: folder)
			self.save()
			completion(.success(()))
		}
	}
	
	private func storeScan(_ scan: VNDocumentCameraScan, name: String, fileExtension: String, folder: Folder?, completion: @escaping (Result<Void, ImportError>) -> Void) {
		let pdf = scan.generatePDF()
		let preview = scan.imageOfPage(at: 0).fixOrientation()
		let previewData = preview.resized(toFit: CGSize(side: previewSize))?.jpegData(compressionQuality: 0.85)
		let data = pdf.dataRepresentation()
		guard let data = data, let previewData = previewData else {
			return DispatchQueue.main.async {
				completion(.failure(.cantLoadImage))
			}
		}
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			_ = StoredItem(context: self.context, data: data, previewData: previewData, type: .file, name: name, fileExtension: fileExtension, folder: folder)
			self.save()
			completion(.success(()))
		}
	}
	
	private func storeItem(at url: URL, folder: Folder?, completion: @escaping (Result<Void, ImportError>) -> Void) {
		guard let type = (try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier).flatMap(UTType.init) else {
			return completion(.failure(.cantReadFile))
		}
		storeItem(at: url, folder: folder, type: type, completion: completion)
	}
	
	private func storeItem(_ item: NSItemProvider, folder: Folder?, completion: @escaping (Result<Void, ImportError>) -> Void) {
		guard let typeIdentifier = item.registeredTypeIdentifiers.first, let type = UTType(typeIdentifier) else {
			return completion(.failure(.cantReadFile))
		}
		guard !type.conforms(to: .url) else {
			_ = item.loadObject(ofClass: URL.self) { [weak self] url, error in
				guard let url = url else {
					assertionFailure("Error: \(error?.localizedDescription ?? "Unknown error")")
					return completion(.failure(.cantLoadURL))
				}
				self?.storeRemoteUrl(url, folder: folder, completion: completion)
			}
			return
		}
		item.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] url, error in
			guard let self = self else { return }
			guard let url = url else {
				assertionFailure("Error: \(error?.localizedDescription ?? "Unknown error")")
				return completion(.failure(.cantReadFile))
			}
			guard FileManager.default.fileExists(atPath: url.absoluteString) else {
				return self.storeItemFallback(item, url: url, type: type, folder: folder, completion: completion)
			}
			self.storeItem(at: url, folder: folder, type: type, completion: completion)
		}
	}
	
	//	If NSItemProvider fails to provide a file at the given URL, but can provide the data,
	private func storeItemFallback(_ item: NSItemProvider, url: URL, type: UTType, folder: Folder?, completion: @escaping (Result<Void, ImportError>) -> Void) {
		item.loadDataRepresentation(forTypeIdentifier: type.identifier) { [weak self] data, error in
			guard let self = self else { return }
			guard let data = data else {
				assertionFailure("Error: \(error?.localizedDescription ?? "Unknown error")")
				return completion(.failure(.cantReadFile))
			}
			do {
				let tempFolder = FileManager.default.temporaryDirectory.appendingPathComponent("temp")
				let newURL = tempFolder
					.appendingPathComponent(url.lastPathComponent)
				try FileManager.default.createDirectory(at: tempFolder, withIntermediateDirectories: true, attributes: nil)
				try data.write(to: newURL)
				
				self.storeItem(at: newURL, folder: folder, type: type, completion: completion)
			} catch {
				assertionFailure("Error \(error.localizedDescription)")
				completion(.failure(.cantReadFile))
			}
		}
	}
	
	private func storeItem(at url: URL, folder: Folder?, type: UTType, completion: @escaping (Result<Void, ImportError>) -> Void) {
		if type.conforms(to: .image) {
			storeImage(at: url, folder: folder, completion: completion)
		} else if type.conforms(to: .audiovisualContent) {
			storeVideo(at: url, folder: folder, completion: completion)
		} else if type.isSupported {
			storeFile(at: url, folder: folder, completion: completion)
		} else if type.identifier == "com.apple.live-photo-bundle" {
			completion(.failure(.livePhotoUnsupported))
		} else {
			completion(.failure(.unsupportedFile))
		}
	}
	
	private func storeImage(at url: URL, folder: Folder?, completion: @escaping (Result<Void, ImportError>) -> Void) {
		guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else {
			return completion(.failure(.cantLoadImage))
		}
		storeImage(image: image, name: url.filename, fileExtension: url.pathExtension, folder: folder, completion: completion)
	}
	
	private func storeVideo(at url: URL, folder: Folder?, completion: @escaping (Result<Void, ImportError>) -> Void) {
		guard let data = try? Data(contentsOf: url) else {
			return completion(.failure(.cantLoadVideo))
		}
		let previewGenerator = AVAssetImageGenerator(asset: AVAsset(url: url))
		previewGenerator.appliesPreferredTrackTransform = true
		let cgImage = try? previewGenerator.copyCGImage(at: .zero, actualTime: nil)
		let image = cgImage.map(UIImage.init)?.square(previewSize)
		let previewData = image?.pngData()
		DispatchQueue.main.async { [weak self] in
			guard let self = self else { return }
			_ = StoredItem(context: self.context, data: data, previewData: previewData, type: .video, name: url.filename, fileExtension: url.pathExtension, folder: folder)
			completion(.success(()))
		}
	}
	
	private func storeFile(at url: URL, folder: Folder?, completion: @escaping (Result<Void, ImportError>) -> Void) {
		guard let data = try? Data(contentsOf: url) else {
			return completion(.failure(.cantReadFile))
		}
		let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(side: previewSize), scale: 2, representationTypes: [.thumbnail])
		QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
			let previewData = representation?.uiImage.pngData()
			DispatchQueue.main.async { [weak self] in
				guard let self = self else { return }
				_ = StoredItem(context: self.context, data: data, previewData: previewData, type: .file, name: url.filename, fileExtension: url.pathExtension, folder: folder)
				completion(.success(()))
			}
		}
	}
	
	private func storeRemoteUrl(_ url: URL, folder: Folder?, completion: @escaping (Result<Void, ImportError>) -> Void) {
		DispatchQueue.main.async {
			let provider = LPMetadataProvider()
			provider.startFetchingMetadata(for: url) { metadata, error in
				func createItem(name: String? = nil, preview: Data? = nil) {
					DispatchQueue.main.async { [weak self] in
						guard let self = self else { return }
						_ = StoredItem(context: self.context, url: url, previewData: preview, name: name ?? url.absoluteString, folder: folder)
						completion(.success(()))
					}
				}
				guard let metadata = metadata else { return createItem() }
				let name = metadata.title
				guard let imageProvider = metadata.imageProvider else { return createItem(name: name) }
				imageProvider.loadObject(ofClass: UIImage.self) { image, error in
					guard let image = image as? UIImage, let previewData = image.square(self.previewSize)?.jpegData(compressionQuality: 0.85) else {
						assertionFailure("Error: \(error?.localizedDescription ?? "Unknown error")")
						return createItem(name: name)
					}
					createItem(name: name, preview: previewData)
				}
			}
		}
	}
	
	private func processResult(_ result: Result<Void, ImportError>, completion: () -> Void) {
		if case let .failure(error) = result {
			self.importErrors.append(error)
		}
		completion()
	}
	
}
