import AVFoundation
import SwiftUI
import UIKit
import Hybrid12Engine

// MARK: - Camera

/// A plain photo camera: 3:4 frame, front or back lens, optional self-timer.
@Observable
final class CameraModel: NSObject, AVCapturePhotoCaptureDelegate {
    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "hybrid12.camera")
    @ObservationIgnored private var onPhoto: ((UIImage) -> Void)?
    private(set) var position: AVCaptureDevice.Position = .back
    private(set) var denied = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: configure()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { ok in
                DispatchQueue.main.async { ok ? self.configure() : (self.denied = true) }
            }
        default: denied = true
        }
    }

    func stop() { queue.async { self.session.stopRunning() } }

    func flip() {
        position = position == .back ? .front : .back
        configure()
    }

    private func configure() {
        let pos = position
        queue.async {
            self.session.beginConfiguration()
            self.session.sessionPreset = .photo
            self.session.inputs.forEach { self.session.removeInput($0) }
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: pos),
               let input = try? AVCaptureDeviceInput(device: device), self.session.canAddInput(input) {
                self.session.addInput(input)
            }
            if self.session.outputs.isEmpty, self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }
            self.session.commitConfiguration()
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func capture(_ done: @escaping (UIImage) -> Void) {
        onPhoto = done
        queue.async { self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self) }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        DispatchQueue.main.async { self.onPhoto?(image) }
    }
}

private final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.preview.session = session
        v.preview.videoGravity = .resizeAspectFill
        return v
    }
    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

/// Takes front, side and back in a row, each with the last photo of that pose as a ghost.
struct PhotoCaptureView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var camera = CameraModel()
    @State private var poseIndex = 0
    @State private var ghostOpacity = 0.35
    @State private var delay = 10
    @State private var countdown: Int?
    @State private var taken: [PhotoPose: UIImage] = [:]

    private var pose: PhotoPose { PhotoPose.allCases[min(poseIndex, PhotoPose.allCases.count - 1)] }

    var body: some View {
        let look = Theme.look
        let ghost = progress.image(ProgressPhotos.latest(progress.photos, pose: pose))
        VStack(spacing: 12) {
            HStack {
                Button("Close") { camera.stop(); dismiss() }.font(.headline)
                Spacer()
                Text("\(pose.name) · \(poseIndex + 1) of 3").font(.headline)
                Spacer()
                Button { camera.flip() } label: { Image(systemName: "arrow.triangle.2.circlepath.camera").font(.title2) }
                    .accessibilityLabel("Switch camera")
            }
            .padding(.horizontal)
            ZStack {
                if camera.denied {
                    Text("Allow the camera for Hybrid 12 in Settings to take progress photos.")
                        .multilineTextAlignment(.center).padding()
                } else {
                    CameraPreview(session: camera.session)
                    if let ghost {
                        Image(uiImage: ghost).resizable().scaledToFill()
                            .scaleEffect(x: camera.position == .front ? -1 : 1, y: 1)
                            .opacity(ghostOpacity)
                            .allowsHitTesting(false)
                    }
                    if let countdown {
                        Text("\(countdown)").font(.system(size: 120, weight: .black)).foregroundStyle(.white)
                            .shadow(radius: 8)
                    }
                }
            }
            .aspectRatio(3 / 4, contentMode: .fit)
            .clipped()
            .background(Color.black)
            Text(pose.tip).font(.subheadline).foregroundStyle(look.secondary).multilineTextAlignment(.center)
                .padding(.horizontal)
            if ghost != nil {
                HStack {
                    Text("Ghost").font(.caption)
                    Slider(value: $ghostOpacity, in: 0...0.7)
                }
                .padding(.horizontal)
            }
            Picker("Timer", selection: $delay) {
                Text("No timer").tag(0)
                Text("3 sec").tag(3)
                Text("10 sec").tag(10)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            Spacer(minLength: 0)
            HStack(spacing: 12) {
                Button("Skip \(pose.name)") { next() }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: 140, minHeight: 56)
                    .background(look.field, in: RoundedRectangle(cornerRadius: max(look.radius - 4, 2)))
                Button { shoot() } label: {
                    Label(countdown == nil ? "Take \(pose.name)" : "Get set…", systemImage: "camera.fill").accentButton()
                }
                .buttonStyle(.plain)
                .disabled(countdown != nil || camera.denied)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
        .background(look.background)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    private func shoot() {
        guard delay > 0 else { take(); return }
        countdown = delay
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { t in
            guard let c = countdown else { t.invalidate(); return }
            if c <= 1 { t.invalidate(); countdown = nil; take() } else { countdown = c - 1 }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func take() {
        let p = pose
        camera.capture { image in
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            progress.addPhoto(image, pose: p)
            taken[p] = image
            next()
        }
    }

    private func next() {
        if poseIndex >= PhotoPose.allCases.count - 1 {
            camera.stop()
            dismiss()
        } else {
            poseIndex += 1
        }
    }
}

// MARK: - Compare

/// Two photo days of the same pose with a drag-to-reveal slider.
struct CompareView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(\.dismiss) private var dismiss
    @State private var pose: PhotoPose = .front
    @State private var beforeDay: Date?
    @State private var afterDay: Date?
    @State private var split: CGFloat = 0.5
    @State private var confirmDelete: ProgressPhoto?

    var body: some View {
        let look = Theme.look
        let days = ProgressPhotos.days(progress.photos)
        let after = afterDay ?? days.first
        let before = beforeDay ?? days.last
        let afterPhoto = after.flatMap { ProgressPhotos.photo(progress.photos, pose: pose, on: $0) }
        let beforePhoto = before.flatMap { ProgressPhotos.photo(progress.photos, pose: pose, on: $0) }
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Picker("Pose", selection: $pose) {
                        ForEach(PhotoPose.allCases, id: \.self) { Text($0.name).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        dayPicker("Before", selection: Binding(get: { before }, set: { beforeDay = $0 }), days: days)
                        Spacer()
                        dayPicker("After", selection: Binding(get: { after }, set: { afterDay = $0 }), days: days)
                    }
                    GeometryReader { g in
                        ZStack(alignment: .leading) {
                            photoView(afterPhoto)
                            photoView(beforePhoto)
                                .mask(alignment: .leading) { Rectangle().frame(width: g.size.width * split) }
                            Rectangle().fill(.white).frame(width: 3).offset(x: g.size.width * split - 1.5)
                                .shadow(radius: 3)
                            Image(systemName: "arrow.left.and.right.circle.fill")
                                .font(.system(size: 36)).foregroundStyle(.white).shadow(radius: 3)
                                .offset(x: g.size.width * split - 18)
                        }
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { v in
                            split = min(1, max(0, v.location.x / g.size.width))
                        })
                    }
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: look.radius))
                    HStack {
                        Text("◀ Before").font(.caption.weight(.bold))
                        Spacer()
                        Text("Drag to compare").font(.caption).foregroundStyle(look.secondary)
                        Spacer()
                        Text("After ▶").font(.caption.weight(.bold))
                    }
                    if let afterPhoto {
                        Button("Delete this \(pose.name.lowercased()) photo (\(afterPhoto.date.formatted(date: .abbreviated, time: .omitted)))",
                               role: .destructive) { confirmDelete = afterPhoto }
                            .font(.footnote)
                    }
                }
                .padding()
            }
            .background(look.background)
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Delete this photo?", isPresented: Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    if let p = confirmDelete { progress.deletePhoto(p) }
                    confirmDelete = nil
                }
            } message: { Text("It's removed from Hybrid 12. A copy saved to Photos stays there.") }
        }
    }

    @ViewBuilder
    private func photoView(_ photo: ProgressPhoto?) -> some View {
        if let img = progress.image(photo) {
            Image(uiImage: img).resizable().scaledToFill()
        } else {
            Rectangle().fill(Theme.field).overlay(Text("No \(pose.name.lowercased()) photo").font(.caption))
        }
    }

    private func dayPicker(_ label: String, selection: Binding<Date?>, days: [Date]) -> some View {
        Menu {
            ForEach(days, id: \.self) { d in
                Button(d.formatted(date: .abbreviated, time: .omitted)) { selection.wrappedValue = d }
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(Theme.secondary)
                Text(selection.wrappedValue?.formatted(date: .abbreviated, time: .omitted) ?? "--").font(.headline)
            }
        }
    }
}

// MARK: - Progress tab cards

struct ProgressPhotosCard: View {
    @Environment(ProgressStore.self) private var progress
    @State private var capturing = false
    @State private var comparing = false

    var body: some View {
        @Bindable var progress = progress
        let look = Theme.look
        let due = ProgressPhotos.daysUntilDue(progress.photos, now: Date())
        let latestDay = ProgressPhotos.days(progress.photos).first
        Card(title: "Progress photos") {
            Text(due.map { $0 <= 0 ? "Due today. Same spot, same light, same time of day." : "Next photos in \($0) day\($0 == 1 ? "" : "s")." }
                 ?? "Take your first set: front, side and back. Same spot and light every 2 weeks.")
                .font(.subheadline).foregroundStyle(due.map { $0 <= 0 } ?? true ? look.accent : look.secondary)
            if let latestDay {
                HStack(spacing: 8) {
                    ForEach(PhotoPose.allCases, id: \.self) { pose in
                        if let img = progress.image(ProgressPhotos.photo(progress.photos, pose: pose, on: latestDay)) {
                            Image(uiImage: img).resizable().scaledToFill()
                                .frame(maxWidth: .infinity).aspectRatio(3 / 4, contentMode: .fit).clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8).fill(look.field).aspectRatio(3 / 4, contentMode: .fit)
                                .overlay(Text(pose.name).font(.caption2).foregroundStyle(look.secondary))
                        }
                    }
                }
                Text(latestDay.formatted(date: .abbreviated, time: .omitted)).font(.caption).foregroundStyle(look.secondary)
            }
            HStack(spacing: 10) {
                Button { capturing = true } label: { Label("Take photos", systemImage: "camera.fill").accentButton(height: 50) }
                    .buttonStyle(.plain)
                if ProgressPhotos.days(progress.photos).count >= 2 {
                    Button { comparing = true } label: {
                        Label("Compare", systemImage: "rectangle.split.2x1")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                            .background(look.field, in: RoundedRectangle(cornerRadius: max(look.radius - 4, 2)))
                    }
                    .buttonStyle(.plain)
                }
            }
            Toggle("Also save a copy to Photos", isOn: $progress.saveToLibrary).font(.subheadline)
        }
        .fullScreenCover(isPresented: $capturing) { PhotoCaptureView() }
        .sheet(isPresented: $comparing) { CompareView() }
    }
}

struct MeasurementsCard: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        Card(title: "Chest and arms") {
            ForEach(BodyPart.allCases, id: \.self) { part in
                let points = progress.points(part)
                VStack(alignment: .leading, spacing: 8) {
                    Text(part.name).font(.headline)
                    Text(part.how).font(.caption).foregroundStyle(Theme.secondary)
                    MeasureSummary(points: points.map { ($0.date, $0.inches) }, unit: "in") { index in
                        progress.removeMeasurement(points[index])
                    }
                    LogField(placeholder: part == .chest ? "Chest" : "Arm", unit: "in") { progress.addMeasurement($0, part: part) }
                }
                if part != BodyPart.allCases.last { Divider() }
            }
        }
    }
}
