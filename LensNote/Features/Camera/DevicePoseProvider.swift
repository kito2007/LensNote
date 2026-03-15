//
//  DevicePoseProvider.swift
//  LensNote
//
//  Created by Codex on 3/12/26.
//

import Foundation
import CoreMotion

/// CoreMotion에서 가져온 기기 자세/안정성 스냅샷.
struct DevicePose {
    /// 위아래로 기울어진 각도.
    let pitch: Double
    /// 좌우 수평 기울기.
    let roll: Double
    /// 수평면 회전값. 현재는 참고용으로만 저장.
    let yaw: Double
    /// 중력 벡터 X.
    let gravityX: Double
    /// 중력 벡터 Y.
    let gravityY: Double
    /// 중력 벡터 Z.
    let gravityZ: Double
    /// 회전 속도의 크기.
    let rotationRate: Double
    /// 사용자 가속도의 크기.
    let userAcceleration: Double
    /// 흔들림이 충분히 작아서 안정적이라고 볼 수 있는지.
    let isStable: Bool

    /// Motion 데이터가 없을 때 사용하는 중립값.
    static let neutral = DevicePose(
        pitch: 0,
        roll: 0,
        yaw: 0,
        gravityX: 0,
        gravityY: 0,
        gravityZ: -1,
        rotationRate: 0,
        userAcceleration: 0,
        isStable: true
    )
}

/// 카메라 엔진이 motion 구현체를 몰라도 되도록 추상화한 프로토콜.
protocol DevicePoseProviding: AnyObject {
    /// 최근에 측정한 pose.
    var latestPose: DevicePose { get }
    /// motion 업데이트 시작.
    func start()
    /// motion 업데이트 중지.
    func stop()
}

/// CMMotionManager를 감싸는 기본 구현체.
final class DevicePoseProvider: DevicePoseProviding {
    private let motionManager: CMMotionManager
    /// Motion 콜백을 메인 스레드와 분리하기 위한 전용 큐.
    private let queue = OperationQueue()
    /// 최근 pose 접근을 스레드 안전하게 보호.
    private let lock = NSLock()
    private var storedPose = DevicePose.neutral

    init(motionManager: CMMotionManager = CMMotionManager()) {
        self.motionManager = motionManager
        queue.name = "DevicePoseProviderQueue"
        queue.qualityOfService = .userInitiated
    }

    /// 가장 마지막으로 기록된 pose를 thread-safe하게 반환.
    var latestPose: DevicePose {
        lock.lock()
        defer { lock.unlock() }
        return storedPose
    }

    func start() {
        // 기기에서 motion을 지원하지 않으면 아무것도 하지 않는다.
        guard motionManager.isDeviceMotionAvailable else { return }
        // 이미 시작된 경우 중복 시작 방지.
        if motionManager.isDeviceMotionActive { return }

        // 카메라 가이드에는 초고주파 데이터가 필요 없으므로 15fps 수준으로 제한.
        motionManager.deviceMotionUpdateInterval = 1.0 / 15.0
        motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { [weak self] motion, _ in
            guard let self, let motion else { return }
            // 3축 회전 속도를 하나의 스칼라 값으로 합친다.
            let rotationRate = sqrt(
                motion.rotationRate.x * motion.rotationRate.x +
                motion.rotationRate.y * motion.rotationRate.y +
                motion.rotationRate.z * motion.rotationRate.z
            )
            // 3축 사용자 가속도도 하나의 크기 값으로 합친다.
            let userAcceleration = sqrt(
                motion.userAcceleration.x * motion.userAcceleration.x +
                motion.userAcceleration.y * motion.userAcceleration.y +
                motion.userAcceleration.z * motion.userAcceleration.z
            )
            // 엔진에서 그대로 사용할 수 있도록 pose 스냅샷 생성.
            let pose = DevicePose(
                pitch: motion.attitude.pitch,
                roll: motion.attitude.roll,
                yaw: motion.attitude.yaw,
                gravityX: motion.gravity.x,
                gravityY: motion.gravity.y,
                gravityZ: motion.gravity.z,
                rotationRate: rotationRate,
                userAcceleration: userAcceleration,
                // 임계값은 "구도 안내용 안정성" 기준의 보수적인 값.
                isStable: rotationRate < 0.18 && userAcceleration < 0.045
            )
            // 최신값 교체.
            self.lock.lock()
            self.storedPose = pose
            self.lock.unlock()
        }
    }

    func stop() {
        // 세션 종료 시 motion 업데이트도 함께 정리.
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        // 다음 세션 시작 전까지는 중립값으로 되돌린다.
        lock.lock()
        storedPose = .neutral
        lock.unlock()
    }
}
