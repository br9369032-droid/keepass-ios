// KeePass Credential Provider Extension — 最小测试版
//
// 只验证一件事：带 autofill-credential-provider 权限的扩展，打进 IPA、
// 经免费证书重签安装后，能不能出现在 iOS「设置 → 通用 → 自动填充与密码」里。
// 不提供真实凭证、不读密码库、不做数据共享（App Groups 是下一步的事）。
// 如果设置里能看到 KeePass，再往下做真正的选密码界面。
//
// 注意：用的是当前（iOS 17+）的 ASCredentialProviderViewController API：
// prepareCredentialList / prepareInterfaceToProvideCredential /
// prepareInterfaceForExtensionConfiguration 都没有 completionHandler，
// provideCredentialWithoutUserInteraction 接的是 any ASCredentialRequest。
// 旧的带 completionHandler / ASPasswordCredentialIdentity 的写法在当前 SDK
// 里已经不存在，写了会编译失败。

import AuthenticationServices
import UIKit

class CredentialProviderViewController: ASCredentialProviderViewController {

    private let label = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        label.text = "KeePass 测试扩展\n（最小测试，未提供凭证）"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])
    }

    // 用户在登录框点钥匙图标时调用。最小测试：只证明扩展能被系统加载。
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        // 列表界面就是 viewDidLoad 里那行测试文字，不用再准备什么。
    }

    // 快捷填充（不弹界面）。最小测试：直接取消，让系统回落到列表界面。
    override func provideCredentialWithoutUserInteraction(for credentialRequest: any ASCredentialRequest) {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.Code.userInteractionRequired.rawValue))
    }

    // 用户在列表里选中某条凭证时调用。最小测试：不提供。
    override func prepareInterfaceToProvideCredential(for credentialRequest: any ASCredentialRequest) {
        // 界面就是 viewDidLoad 里那行测试文字，不用再准备什么。
    }

    // 用户在设置里点开扩展的配置时调用。最小测试：直接关掉。
    override func prepareInterfaceForExtensionConfiguration() {
        extensionContext.completeExtensionConfigurationRequest()
    }
}
