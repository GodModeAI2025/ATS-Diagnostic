import UIKit
import ATSRecording

@main final class DemoAppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: "SDK Activation", sessionRole: session.role)
        configuration.delegateClass = DemoSceneDelegate.self
        return configuration
    }
}
final class DemoSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var activation: RecordingActivation?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let activation = RecordingActivation()
        let controller = ActivationDemoController(activation: activation)
        activation.handler = { [weak controller] source in controller?.showRecording(source: source) }
        let window = RecordingWindow(windowScene: windowScene)
        window.recordingActivation = activation
        window.rootViewController = UINavigationController(rootViewController: controller)
        self.activation = activation; self.window = window
        window.makeKeyAndVisible()
    }
}
final class ActivationDemoController: UIViewController {
    private let activation: RecordingActivation
    private let stateLabel = UILabel()
    private let toggle = UISwitch()
    init(activation: RecordingActivation) { self.activation = activation; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("Use init(activation:)") }
    override func viewDidLoad() {
        super.viewDidLoad(); title = "SDK-Aktivierung"; view.backgroundColor = .systemGroupedBackground
        let scroll = UIScrollView(); scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 24; stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        let icon = UIImageView(image: UIImage(systemName: "wave.3.right.circle")); icon.tintColor = .systemTeal; icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 56).isActive = true
        let description = UILabel(); description.numberOfLines = 0; description.font = .preferredFont(forTextStyle: .body); description.adjustsFontForContentSizeCategory = true
        description.text = "Eigene Aktion und Schütteln verwenden denselben SDK-Präsentationshook. Die integrierende App entscheidet, welche Ansicht geöffnet wird."
        let toggleRow = UIStackView(); toggleRow.axis = .horizontal; toggleRow.spacing = 16
        let toggleLabel = UILabel(); toggleLabel.text = "Aktivierung einschalten"; toggleLabel.numberOfLines = 0; toggleLabel.font = .preferredFont(forTextStyle: .body); toggleLabel.adjustsFontForContentSizeCategory = true
        toggle.accessibilityLabel = "SDK-Aktivierung"; toggle.addTarget(self, action: #selector(changed), for: .valueChanged)
        toggleRow.addArrangedSubview(toggleLabel); toggleRow.addArrangedSubview(toggle)
        let button = UIButton(type: .system); var configuration = UIButton.Configuration.borderedTinted(); configuration.title = "Eigene Aktion"; configuration.image = UIImage(systemName: "rectangle.on.rectangle"); configuration.imagePadding = 10; button.configuration = configuration
        button.addTarget(self, action: #selector(customAction), for: .touchUpInside); button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        stateLabel.numberOfLines = 0; stateLabel.font = .preferredFont(forTextStyle: .subheadline); stateLabel.adjustsFontForContentSizeCategory = true; stateLabel.text = "Aktivierung deaktiviert"
        [icon, description, toggleRow, button, stateLabel].forEach(stack.addArrangedSubview)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor), scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor), scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 24), stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -24), stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 24), stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24), stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -48)
        ])
    }
    @objc private func changed() { activation.isEnabled = toggle.isOn; stateLabel.text = toggle.isOn ? "Aktivierung bereit" : "Aktivierung deaktiviert" }
    @objc private func customAction() { if !activation.activate() { stateLabel.text = "Aktivierung deaktiviert" } }
    func showRecording(source: RecordingActivationSource) {
        let name = source == .shake ? "Schütteln" : "Eigene Aktion"
        stateLabel.text = "Geöffnet durch: " + name
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "Diagnose geöffnet", message: name, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Schließen", style: .default))
        present(alert, animated: true)
    }
}
