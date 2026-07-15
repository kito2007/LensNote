//
//  CameraPreviewRenderer.swift
//  LensNote
//
//  Phase 1 Path B — 라이브 프리뷰를 MTKView + Core Image로 렌더링해 활성 프리셋의
//  색보정을 실시간 적용(R2). 저장 경로와 동일한 FilterChainBuilder를 써 WYSIWYG(R3).
//
//  설계:
//  - captureOutput(백그라운드)이 매 프레임 pixelBuffer를 enqueue → 최신 프레임만 유지.
//  - MTKView는 30fps 자체 구동(display ↔ capture 분리, R4). draw에서 최신 프레임에
//    체인 적용 후 drawable에 렌더.
//  - Metal 디바이스가 없으면(구형/프리뷰 캔버스) 렌더를 건너뛰고 clearColor 표시(nil-safe, P3).
//

import MetalKit
import CoreImage
import CoreVideo

final class CameraPreviewRenderer: NSObject, MTKViewDelegate {
    let device: MTLDevice?
    private let commandQueue: MTLCommandQueue?
    private let ciContext: CIContext?
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    // 최신 프레임/프리셋을 렌더 스레드와 캡처/메인 스레드가 공유하므로 락으로 보호.
    private let lock = NSLock()
    private var latestImage: CIImage?
    private var preset: FilterPreset?

    override init() {
        let device = MTLCreateSystemDefaultDevice()
        self.device = device
        self.commandQueue = device?.makeCommandQueue()
        self.ciContext = device.map { CIContext(mtlDevice: $0, options: [.useSoftwareRenderer: false]) }
        super.init()
    }

    /// 활성 프리셋을 갱신한다(메인). 저장 경로와 같은 프리셋을 써 프리뷰-저장이 일치.
    func updatePreset(_ preset: FilterPreset?) {
        lock.lock()
        self.preset = preset
        lock.unlock()
    }

    /// 매 프레임 픽셀버퍼를 받아 최신 프레임으로 보관한다(captureOutput 큐, 고빈도).
    func enqueue(pixelBuffer: CVPixelBuffer) {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        lock.lock()
        latestImage = image
        lock.unlock()
    }

    // MARK: - MTKViewDelegate

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        guard let ciContext, let commandQueue, let drawable = view.currentDrawable else { return }

        lock.lock()
        let image = latestImage
        let activePreset = preset
        lock.unlock()

        // 아직 프레임이 없으면 clearColor(검정) 그대로 둔다.
        guard let image, image.extent.width > 0, image.extent.height > 0 else { return }

        // 저장 경로와 동일한 체인. nil/중립 프리셋이면 원본 통과(R5).
        let filtered = activePreset.map { FilterChainBuilder.makeChain(from: $0)(image) } ?? image

        // resizeAspectFill: 드로어블을 꽉 채우도록 스케일 후 중앙 정렬(AVCaptureVideoPreviewLayer 대체).
        let drawableSize = view.drawableSize
        let extent = filtered.extent
        let scaleX: CGFloat = drawableSize.width / extent.width
        let scaleY: CGFloat = drawableSize.height / extent.height
        let scale: CGFloat = max(scaleX, scaleY)
        let scaledWidth: CGFloat = extent.width * scale
        let scaledHeight: CGFloat = extent.height * scale
        let tx: CGFloat = (drawableSize.width - scaledWidth) / 2 - extent.origin.x * scale
        let ty: CGFloat = (drawableSize.height - scaledHeight) / 2 - extent.origin.y * scale
        let scaleTransform = CGAffineTransform(scaleX: scale, y: scale)
        let translateTransform = CGAffineTransform(translationX: tx, y: ty)
        let rendered = filtered.transformed(by: scaleTransform).transformed(by: translateTransform)

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        ciContext.render(rendered,
                         to: drawable.texture,
                         commandBuffer: commandBuffer,
                         bounds: CGRect(origin: .zero, size: drawableSize),
                         colorSpace: colorSpace)
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
