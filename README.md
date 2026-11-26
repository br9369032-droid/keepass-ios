# KeePass iOS (Capacitor wrapper)

把 [KeePass 网页版](https://keepass.666415.xyz/)（`~/workspace/keepass-pages/`）用
[Capacitor](https://capacitorjs.com/) 套一个 iOS 原生壳，打成 IPA 装到 iPhone 上。
App 里面跑的还是同一个网页（WKWebView，本地 `www/` 文件），功能和网页版
基本一样，但原生 App 多了三样网页版做不到的事：**面容 ID 解锁**、**坚果云直连**、
**本地文件直接写回原文件**（见下文）。

- App 名字：KeePass
- Bundle ID：`xyz.666415.keepass`
- Capacitor：8.x（见 `package.json`）
- 当前版本：`faceid-refresh-20261126`

## 网页文件从哪来

`www/` 里的文件就是 `~/workspace/keepass-pages/` 的那 9 个（`index.html`、
`kdbxweb.min.js`、`argon2-bundled.min.js`、`argon2.wasm`、`manifest.json`、
`apple-touch-icon.png`、`icon-192.png`、`icon-512.png`、`favicon.png`），
原样复制，不改内容。网页版更新后，把新文件拷进 `www/` 再跑一次
`npx cap sync ios` 即可。`_headers` 和部署脚本是 Cloudflare 专用的，不用拷。

**注意：仓库里只放文本文件。**`www/` 里的 5 个二进制文件（`argon2.wasm` +
4 个 PNG 图标）不在仓库里（GitHub connector 只能推文本文件），由工作流在
构建时从线上下载；`ios/App/App/public/` 是 `cap sync` 生成的，也不在仓库里。
`.gitignore` 里都排除了。

## 原生 App 专属功能（网页版没有）

### 1. 面容 ID 解锁

网页版做不到（网页访问不了 iOS 钥匙串），原生 App 可以：

- 解锁页：原生 App 里、设备支持面容 ID、且之前给当前文件开过面容 ID 时，
  会出现「🔒 使用面容 ID 解锁」按钮。点一下弹面容 ID，过了就直接开库，
  不用输主密码。面容 ID 没过或密码对不上（比如在别的软件里改了主密码），
  就清掉存的密码，提示「面容 ID 解锁失败，请用主密码解锁」，再用主密码开。
- 设置页：开库后，设置里有「面容 ID 解锁」卡片。打开开关时，把当前主密码
  存进 **iOS 钥匙串**（`@capgo/capacitor-native-biometric`，`setData` 带
  `accessControl: 1`，读之前必须先过面容 ID），同时记下是哪个文件（坚果云
  是文件地址，本地文件是文件名）。关掉开关就从钥匙串里删掉。
- 主密码只存在钥匙串里，**不进 localStorage、不进 .kdbx 文件**。改主密码后，
  如果面容 ID 是开着的，存的密码会顺手更新成新密码；更新失败就清掉并提示。
- 用了密钥文件的库不能开面容 ID（开关会禁用并说明），因为只存主密码解不开。
- 插件：`@capgo/capacitor-native-biometric@8.9.3`（Capacitor 8 兼容，一个插件
  同时做生物识别验证 + 钥匙串存储）。`Info.plist` 里加了
  `NSFaceIDUsageDescription`（没有它，用面容 ID 时 App 会崩溃）。

### 2. 坚果云直连（不走 Cloudflare 代理）

网页版在浏览器里会被 CORS 拦住，所以要走你自己的 Worker 代理
`https://keepass-proxy.666415.xyz/`。原生 App 不用：`capacitor.config.ts`
里开了 `plugins.CapacitorHttp.enabled = true`，WebView 里的 `fetch()` 会走
原生 NSURLSession，绕过 CORS 限制，直接连 `dav.jianguoyun.com`。页面里的
`davReqUrl()` 会判断：原生就直接用你填的坚果云文件地址，网页版才拼代理前缀。
Basic 认证头、GET/PUT/HEAD 都走同一条路，所以**刷新功能在原生 App 里也是直连**。
（这条路在 Linux 上测不了，只能代码检查 + 真机验证。）

### 3. 本地 .kdbx 文件直接写回原文件

网页版在 iOS Safari 里只能导出下载（没有 File System Access API）。原生 App
可以：

- 打开本地文件时用系统文件选择器（`@capawesome/capacitor-file-picker@8.1.1`，
  从文件 App 里选 iCloud 云盘 / 本机里的 `.kdbx`），读出字节并**记下文件路径**
  （`file://` URI）。
- 点「保存」时，如果记了原生文件路径，就用 `@capacitor/filesystem@8.1.5` 的
  `writeFile` 直接把新字节写回同一个文件，不下载、不产生重复文件，成功提示
  「已保存」。写失败就回落到原来的导出下载，并告诉你。
- 桌面 Edge/Chrome 的 File System Access 直接保存不受影响；iOS Safari 还是
  只能导出。
- **待真机验证**：文件选择器返回的 `path` 是 `file://` URL，
  `Filesystem.writeFile` 能不能直接写它、以及 iCloud 云盘文件是否需要
  security-scoped 访问（这个插件 iOS 代码里没有调
  `startAccessingSecurityScopedResource`），在 Linux 上验证不了。
  **请在真机上用文件 App 里的文件验证一次保存回写。**

## 刷新：不用退出就拉取坚果云最新文件

密码库页筛选行里多了个「↻」按钮（只在坚果云模式出现，手机上一行放得下，
纯图标）。点它重新从坚果云拉一份：

- 远程没变 → 提示「已经是最新版本」，什么都不动。
- 远程变了 → 用当前主密码（+密钥文件）解密新文件，解不开就报错、原库不动；
  解开了就替换内存里的库、重新渲染、未保存标记清掉，提示「已刷新到最新版本」。
  当前分组/搜索尽量保持。
- 有未保存修改时，先弹三选一：**保存并刷新**（先存回坚果云再拉）、
  **丢弃并刷新**（本地改动不要了，直接拉）、**取消**。
- 网络卡住 30 秒没响应就报超时，按钮恢复可点。

网页版和原生 App 都能用（原生走直连，见上文）。

## 在云端打包（不用 Mac）

仓库里有 GitHub Actions 工作流 `.github/workflows/build-ios.yml`：

1. 把这个目录推到 GitHub（新建一个仓库，`git push` 到 `main` 分支）。
2. 打开仓库的 **Actions** 标签页，找到 **Build iOS IPA (unsigned)**，
   点 **Run workflow**（或等推到 `main` 后自动跑）。
3. 跑完后在那次运行的页面底部下载 artifact **`KeePass-ipa`**，
   里面是 `KeePass.ipa`。

工作流在 GitHub 免费的 `macos-latest` 机器上跑：

1. `npm ci`
2. **下载二进制 www/ 资源**：用 `curl --fail` 从 `https://keepass.666415.xyz/`
   下载 `argon2.wasm`、`apple-touch-icon.png`、`icon-192.png`、`icon-512.png`、
   `favicon.png` 到 `www/`（任何一个失败就让构建失败），再用 `file` 命令
   核对一下格式。
3. **生成 AppIcon**：用 macOS 自带的 `sips` 把下载的 `icon-512.png`
   放大成 1024×1024 的 `AppIcon-512@2x.png`，放到
   `ios/App/App/Assets.xcassets/AppIcon.appiconset/`（它的 `Contents.json`
   是文本文件，留在仓库里）。
4. `npx cap sync ios`（把 `www/` 拷进 `ios/App/App/public/`，并注册插件）
5. `xcodebuild` 编 `Release`（未签名）
6. 把 `App.app` 打包成 `KeePass.ipa` 并上传 artifact

Splash 图片集已从资源目录删掉（没有用到 splash 插件），构建时不会再找它。

## 这个 IPA 是未签名的

打出来的 IPA **没有签名**，直接装不上。装之前要自己重签：

1. 把 `KeePass.ipa` 传到手机上（用全能签/ESign/轻松签导入，或 AirDrop/文件 App）。
2. 在全能签/ESign 里用你自己的证书给它签名（免费 Apple ID 证书签完只能用
   7 天；$99/年的开发者账号证书能用 1 年；共享证书可能被苹果吊销）。
3. 签完点安装。

注意：证书和 Apple ID 只在你自己的手机和签名工具里用，**不要**放进这个仓库，
仓库里没有任何密码、令牌或证书。

## 本地开发（有 Mac 才需要）

```bash
npm install
npx cap sync ios
npx cap open ios   # 用 Xcode 打开 ios/App/App.xcodeproj
```

没有 Mac 就不用管上面这些，走上面的 GitHub Actions 云打包就行。

## 已知的一点

Capacitor 的 CLI 校验 App ID 时要求每段都以字母开头，而 `xyz.666415.keepass`
里的 `666415` 是数字开头，会被 `npx cap add ios` 拒绝。处理办法是：先用
`xyz.keepass.app` 生成 iOS 工程，再把 `ios/App/App.xcodeproj/project.pbxproj`
里的 `PRODUCT_BUNDLE_IDENTIFIER` 改成 `xyz.666415.keepass`，同时把
`capacitor.config.ts` 的 `appId` 改回 `xyz.666415.keepass`。
`npx cap sync ios` 不会改 Bundle ID（只有 `cap add` 会写它），所以改完后
每次同步都不会被覆盖。GitHub Actions 工作流里只跑 `cap sync`，不会碰这个问题。
