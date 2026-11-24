# SR - 系统重装管理菜单

基于开源项目 [bin456789/reinstall](https://github.com/bin456789/reinstall) 的交互式终端管理菜单，安装后可通过快捷命令 **`SR`**（或小写 `sr`）一键调出。

> [!CAUTION]
> **数据安全提醒**：系统重装与 DD 操作会清除目标硬盘上的**全部数据**。请务必提前做好重要数据备份；`SR` 会在执行前展示完整命令并要求二次输入 `YES` 确认。

## 特性

* **轻量外壳，紧跟上游**：不魔改 `reinstall.sh` 核心逻辑，自动拉取并缓存官方脚本，支持一键更新和指定 `commit_id` 回退。
* **大小写双命令**：自动注册 `/usr/local/bin/sr` 与软链接 `/usr/local/bin/SR`，安装前自动检测系统同名命令冲突。
* **零外部依赖**：纯 Shell/Bash 实现，兼容 Debian/Ubuntu/RHEL 系/Arch 及极简 Alpine Linux（自动处理 Bash 引导）。
* **全功能覆盖**：
  1. 重装主流 Linux 发行版（Debian / Ubuntu / Alpine / Rocky / Alma / CentOS / Oracle / Fedora / openSUSE / Arch / Kali / Anolis / OpenCloudOS / openEuler / NixOS / Gentoo / AOSC / fnOS / FygoOS / Red Hat qcow2）
  2. 重装 Windows（官方原版 ISO 自动查找或自定义 `--iso` / 磁力链接，支持驱动、RDP 端口、允许 Ping 等）
  3. 自定义 DD 镜像（`--img`，支持 Linux cloud-init `--cloud-data` 与 Windows DD 选项）
  4. 救援与网络引导（Alpine Live OS `--hold 1` 内存系统、`netboot.xyz`、`talos` 维护模式）
  5. 取消已安排的重装（`reset`，重启前有效）
* **预设配置持久化**：支持保存默认 SSH 公钥（含 `github:用户名`）、默认 SSH 端口、Web 观察端口、国内镜像偏好（`cnb.cool` / `--force-cn`）等，避免每次重复输入。
* **安全防呆**：执行前显示系统信息、检测 OpenVZ/LXC 不兼容环境、支持密码脱敏预览与 Dry-run 输出完整命令。

## 一键安装

> 将仓库推送到你的 GitHub 后，把命令中的 `<YOUR_USER>/<YOUR_REPO>` 替换为你的用户名和仓库名（并同步修改 [`install.sh`](install.sh) 顶部的 `DEFAULT_REPO_RAW`）。

### 国外服务器

```bash
curl -fsSL https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/install.sh | bash
```

### 国内服务器（默认启用 CN 镜像偏好）

```bash
curl -fsSL https://raw.githubusercontent.com/<YOUR_USER>/<YOUR_REPO>/main/install.sh | bash -s -- --cn
```

### 本地仓库安装（测试/自用）

```bash
bash install.sh
```

### 安装脚本可选参数

* `--cn`：默认配置使用国内源（`cnb.cool`）拉取 `reinstall.sh` 并开启 `--force-cn`
* `--no-prefetch`：安装时不预拉取 `reinstall.sh`
* `--force` / `-f`：如果系统中已有非 SR 的同名 `sr`/`SR` 命令则强制覆盖
* `--user`：安装到 `~/.local/bin`（非 root 预览测试用）
* `--raw-url URL`：自定义托管 `sr` 的 Raw 基础 URL
* `--uninstall`：彻底卸载 `sr`/`SR` 及缓存与配置

## 使用方法

安装完成后，在终端直接输入：

```bash
SR
```

或使用 CLI 快捷子命令：

```bash
sr                  # 启动交互式管理菜单
sr update           # 立即更新缓存的 reinstall.sh
sr reset            # 取消尚未重启的重装任务
sr config           # 直接进入预设配置管理
sr uninstall        # 卸载 SR 及其缓存和配置
sr -- <参数>        # 直接透传参数给底层 reinstall.sh，例如: sr -- debian 12 --ssh-port 2222
sr help             # 查看帮助
```

## 致谢

* 核心重装能力全部由 [bin456789/reinstall](https://github.com/bin456789/reinstall) 提供。
