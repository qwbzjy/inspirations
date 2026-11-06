import AVFoundation
import Combine
import Foundation
import Speech
import UIKit

/// 语音转文字：实时识别，结果通过 transcript 发布
@MainActor
final class SpeechRecognizer: ObservableObject {
    enum State: Equatable {
        case idle
        case requesting
        case recording
        case denied
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript: String = ""

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var observers: [NSObjectProtocol] = []

    var isRecording: Bool { state == .recording }

    /// 允许在视图属性默认值（非隔离上下文）中创建
    nonisolated init() {}

    /// 中文设备跟随系统语言，否则固定 zh-CN
    private var recognizer: SFSpeechRecognizer? {
        let current = Locale.current
        let isChinese = current.language.languageCode?.identifier == "zh"
        let locale = isChinese ? current : Locale(identifier: "zh-CN")
        return SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
    }

    func start() {
        guard state != .recording, state != .requesting else { return }
        state = .requesting
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard granted else {
                    self.state = .denied
                    return
                }
                self.requestSpeechAuthorization()
            }
        }
    }

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch status {
                case .authorized:
                    self.beginSession()
                case .denied, .restricted:
                    self.state = .denied
                case .notDetermined:
                    self.state = .failed("语音识别权限未授权")
                @unknown default:
                    self.state = .failed("语音识别不可用")
                }
            }
        }
    }

    private func beginSession() {
        guard let recognizer, recognizer.isAvailable else {
            state = .failed("语音识别当前不可用")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            state = .failed("无法启动麦克风：\(error.localizedDescription)")
            return
        }

        let engine = AVAudioEngine()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            req.requiresOnDeviceRecognition = true
        }

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        guard format.sampleRate > 0 else {
            state = .failed("无法访问麦克风输入")
            return
        }
        inputNode.installTap(onBus: 0, bufferSize: 2048, format: format) { buffer, _ in
            req.append(buffer)
        }

        transcript = ""
        audioEngine = engine
        request = req
        state = .recording

        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.finishSession()
                }
            }
        }

        registerObservers()
        engine.prepare()
        do {
            try engine.start()
        } catch {
            finishSession()
            state = .failed("无法启动麦克风：\(error.localizedDescription)")
        }
    }

    /// 停止录音并保留当前转写结果
    func stop() {
        guard state == .recording || state == .requesting else { return }
        request?.endAudio()
        task?.finish()
        finishSession()
    }

    /// 放弃本次录音（清空转写）
    func cancel() {
        guard state == .recording || state == .requesting else { return }
        request?.endAudio()
        task?.cancel()
        finishSession()
        transcript = ""
    }

    private func finishSession() {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
        observers.removeAll()
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        audioEngine = nil
        request = nil
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        state = .idle
    }

    private func registerObservers() {
        observers.append(NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.stop() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue),
                  type == .began else { return }
            Task { @MainActor [weak self] in self?.stop() }
        })
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
