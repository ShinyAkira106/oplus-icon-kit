# O+iconKit

每次 O+ Connect 更新之后，它在 macOS 上的图标常常会变成一个普通文件夹。O+iconKit 会在后台监视这个应用，一旦检测到更新完成，就自动让系统重新识别它并刷新程序坞，你不用再手动处理。如果你愿意，它还可以在每次更新后自动套上你自己选的图标。

After every O+ Connect update, its icon on macOS often turns into a plain folder. O+iconKit watches the app in the background and, as soon as an update finishes, makes macOS re-register it and refreshes the Dock, so you no longer have to fix it by hand. If you like, it can also reapply an icon of your own choosing after every update.

## 原理 / How it works

更新程序会整个替换应用包，而 macOS 的图标缓存没有及时登记新版本，于是把它当成文件夹显示。O+iconKit 安装一个用户级的 LaunchAgent，用 launchd 的 WatchPaths 监视应用路径。路径一有变化，脚本先等更新程序写完文件，再调用 lsregister 重新登记应用；如果 O+ Connect 显示在程序坞里，还会重启程序坞来刷新图标。自定义图标通过 NSWorkspace 写入，因为它存放在应用包内部，每次更新都会被抹掉，所以脚本会在每次更新后重新写一次。脚本会记录已处理过的版本，避免自己写入图标时又触发自己。

The updater replaces the entire app bundle, and the macOS icon cache doesn't register the new version in time, so it shows up as a folder. O+iconKit installs a per user LaunchAgent that uses launchd's WatchPaths to watch the app's path. When the path changes, the script waits for the updater to finish writing, then calls lsregister to re-register the app, and restarts the Dock to refresh the icon if O+ Connect is shown there. A custom icon is written through NSWorkspace; since it lives inside the app bundle and is wiped by every update, the script writes it again after each update. The script remembers which version it has already handled, so writing the icon doesn't trigger itself again.

## 安装 / Install

下载或克隆本仓库，在终端进入文件夹后运行下面的命令。只修复文件夹图标：

Download or clone this repository, open Terminal in the folder, and run the commands below. To only fix the folder icon:

```bash
git clone https://github.com/ShinyAkira106/oplus-icon-kit.git
cd oplus-icon-kit
chmod +x install.sh uninstall.sh
./install.sh
```

> [!NOTE]
> **桌面会闪一下是正常的。** 安装时以及每次 O+ Connect 更新之后，屏幕上的程序坞、桌面和壁纸可能会短暂消失再重新出现，大约一两秒。这是 O+iconKit 在重启程序坞来刷新图标，不会关闭任何应用，也不会丢失任何内容。平时开机登录不会出现。如果不想看到这个闪烁，可以用 `./install.sh --dock never` 安装，详见下方“程序坞刷新”一节。
>
> **A brief screen flash is normal.** During installation and after each O+ Connect update, the Dock, desktop and wallpaper may disappear and reappear for a second or two. This is O+iconKit restarting the Dock to refresh the icon; it doesn't close any apps or lose anything. It never happens on ordinary logins. If you'd rather not see it, install with `./install.sh --dock never`; see the Dock refresh section below for details.

同时使用自定义图标（建议 1024×1024 的正方形 PNG，也支持 ICNS 和 JPG）：

To also use a custom icon (a square 1024×1024 PNG is recommended; ICNS and JPG also work):

```bash
./install.sh --icon ~/Pictures/my_icon.png
```

如果你的应用名称或位置不同，用 --app 指定：

If your app has a different name or location, pass it with --app:

```bash
./install.sh --app "/Applications/O+Connect.app" --icon ~/Pictures/my_icon.png
```

也可以直接把图标文件命名为 custom.icns 或 custom.png 放进本文件夹，然后只运行 ./install.sh，安装程序会自动使用它。这两个文件名已写进 .gitignore，不会被上传到 GitHub，适合放只供自己使用的图标。

You can also name your icon custom.icns or custom.png, drop it into this folder, and simply run ./install.sh; the installer picks it up automatically. Both names are listed in .gitignore, so they are never uploaded to GitHub, which suits icons meant only for your own use.

安装时会把图标复制一份保存，所以之后移动或删除原图片都没关系。想换图标时，用新的图片再运行一次安装命令即可。

The installer keeps its own copy of the icon, so moving or deleting the original image afterwards is fine. To change the icon, simply run the install command again with the new image.

## 权限说明 / About permissions

如果 O+ Connect 是通过安装包装进 /Applications 的，它可能属于系统管理员账户，这时脚本无法写入自定义图标，日志里会给出提示。可以运行下面的命令把应用的所有者改成你自己，之后就能正常写入。只修复文件夹图标的功能不受这个影响。

If O+ Connect was installed into /Applications by an installer package, it may be owned by the administrator account. In that case the script can't write the custom icon, and the log will say so. Run the command below to make yourself the owner of the app, after which writing works normally. The folder icon fix itself is not affected by this.

```bash
sudo chown -R "$(whoami)" "/Applications/O+Connect.app"
```

## 手动运行与日志 / Manual run and log

想立即执行一次，可以运行下面的命令。运行记录保存在 ~/Library/Logs/OplusIconKit.log，出问题时先看这里。

To run it immediately, use the command below. Activity is logged to ~/Library/Logs/OplusIconKit.log; check there first if anything goes wrong.

```bash
~/Library/Application\ Support/OplusIconKit/O+iconKit.app/Contents/MacOS/O+iconKit --force
```

在系统设置的“登录项与扩展”里，O+iconKit 会以自己的名字出现在后台项目中，可以随时在那里关闭。

In System Settings under Login Items & Extensions, O+iconKit appears under its own name among the background items, and you can switch it off there at any time.

## 程序坞刷新 / Dock refresh

程序坞有自己的图标缓存，只有重启才会重新读取，而重启程序坞会让桌面和壁纸短暂重绘一下。所以默认的 auto 模式只在 O+ Connect 固定在程序坞或正在运行时才重启程序坞，并且只在应用真正更新之后发生，平时登录不会触发。也可以用 --dock always 每次都刷新，或用 --dock never 完全不刷新，这时访达里的图标仍会更新，程序坞里的图标要等下次重启电脑或注销后才变。

The Dock keeps its own icon cache and only reloads it when it restarts, and restarting the Dock briefly redraws the desktop and wallpaper. So the default auto mode only restarts the Dock when O+ Connect is pinned there or running, and only after the app has actually updated; ordinary logins never trigger it. You can also use --dock always to refresh every time, or --dock never to never refresh; Finder still updates in that case, while the Dock icon changes after your next restart or log out.

```bash
./install.sh --dock never
```

## 卸载 / Uninstall

停止监视并移除 O+iconKit：

To stop watching and remove O+iconKit:

```bash
./uninstall.sh
```

同时把应用恢复成原本的图标：

To also restore the app's original icon:

```bash
./uninstall.sh --restore-icon
```

## 系统要求 / Requirements

需要 macOS，使用系统自带的 bash、osascript 和 launchd，不需要额外安装任何东西。

Requires macOS. It uses the built in bash, osascript and launchd, and needs nothing else installed.

## 声明 / Disclaimer

本项目是个人开发的非官方工具，与 OPPO 没有任何关联。O+ Connect 是其各自所有者的商标。

This is an unofficial personal tool and is not affiliated with OPPO in any way. O+ Connect is a trademark of its respective owner.

## 反馈 / Feedback

遇到问题或有建议，欢迎在 GitHub 提交 Issue，附上 ~/Library/Logs/OplusIconKit.log 里的相关内容会更容易定位。

If you run into a problem or have a suggestion, please open an issue on GitHub; including the relevant lines from ~/Library/Logs/OplusIconKit.log makes it much easier to track down.

[https://github.com/ShinyAkira106/oplus-icon-kit/issues/new](https://github.com/ShinyAkira106/oplus-icon-kit/issues/new)

## 许可证 / License

MIT License. Copyright © 2026 ShinyAkira.

由 ShinyAkira 制作 / Made by ShinyAkira
