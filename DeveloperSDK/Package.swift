// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "ATSRecording", platforms: [.iOS(.v18), .macOS(.v15)], products: [.library(name: "ATSRecording", targets: ["ATSRecording"])], targets: [.target(name: "ATSRecording"), .testTarget(name: "ATSRecordingTests", dependencies: ["ATSRecording"])])
