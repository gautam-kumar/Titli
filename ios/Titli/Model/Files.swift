import PDFKit
import SwiftUI
import TitliCore
import UniformTypeIdentifiers

/// Photos and documents the person attaches. They live only in the app's own folder on the phone,
/// locked with the phone's passcode, and are never sent anywhere.
enum Files {
    static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("files", isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()

    static func url(_ a: Attachment) -> URL { dir.appendingPathComponent(a.file) }

    static func save(_ data: Data, ext: String, kind: Attachment.Kind, name: String) -> Attachment? {
        let file = UUID().uuidString + "." + (ext.isEmpty ? "dat" : ext.lowercased())
        do { try data.write(to: dir.appendingPathComponent(file), options: [.atomic, .completeFileProtection]) } catch { return nil }
        return Attachment(file: file, kind: kind, name: name)
    }

    static func save(_ image: UIImage) -> Attachment? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        return save(data, ext: "jpg", kind: .image, name: "Photo")
    }

    /// A file picked from the Files app, copied into Titli's own folder.
    static func copy(_ url: URL) -> Attachment? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return nil }
        let ext = url.pathExtension
        let type = UTType(filenameExtension: ext)
        let kind: Attachment.Kind = type?.conforms(to: .image) == true ? .image : type?.conforms(to: .pdf) == true ? .pdf : .file
        return save(data, ext: ext, kind: kind, name: url.deletingPathExtension().lastPathComponent)
    }

    static func delete(_ a: Attachment) { try? FileManager.default.removeItem(at: url(a)) }

    static func thumbnail(_ a: Attachment, size: CGFloat = 240) -> UIImage? {
        switch a.kind {
        case .image:
            guard let img = UIImage(contentsOfFile: url(a).path) else { return nil }
            return img.preparingThumbnail(of: CGSize(width: size, height: size * img.size.height / max(img.size.width, 1))) ?? img
        case .pdf:
            return PDFDocument(url: url(a))?.page(at: 0)?.thumbnail(of: CGSize(width: size, height: size * 1.4), for: .mediaBox)
        case .file:
            return nil
        }
    }

    /// A stand-in document photo for the CI screenshots.
    static func sample() -> Attachment? {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 900, height: 600))
        let img = r.image { ctx in
            UIColor(red: 0.98, green: 0.97, blue: 0.94, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 900, height: 600))
            UIColor(red: 0.93, green: 0.45, blue: 0.2, alpha: 1).setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 900, height: 90))
            let big: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 44), .foregroundColor: UIColor.white]
            ("BIJLI BILL" as NSString).draw(at: CGPoint(x: 40, y: 18), withAttributes: big)
            let line: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 34), .foregroundColor: UIColor.darkGray]
            for (i, t) in ["Upbhokta: Ramesh Kumar", "Mahina: October 2026", "Units: 214", "Rashi: ₹1,860"].enumerated() {
                (t as NSString).draw(at: CGPoint(x: 40, y: CGFloat(140 + i * 90)), withAttributes: line)
            }
        }
        return save(img)
    }
}

/// The phone camera, for photographing a paper.
struct CameraPicker: UIViewControllerRepresentable {
    var done: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(done: done) }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let c = UIImagePickerController()
        c.sourceType = .camera
        c.delegate = context.coordinator
        return c
    }
    func updateUIViewController(_ c: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let done: (UIImage?) -> Void
        init(done: @escaping (UIImage?) -> Void) { self.done = done }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            done(info[.originalImage] as? UIImage)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { done(nil) }
    }
}
