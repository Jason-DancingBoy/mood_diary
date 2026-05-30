# 手机远程连接 Ubuntu Claude Code 完整步骤

## 架构

```
手机 (Termux + Tailscale) → Tailscale 内网 → Ubuntu (Tailscale + SSH + Claude Code)
```

---

## 一、Ubuntu 端

### 1. 安装 Tailscale
```bash
curl -fsSL https://tailscale.com/install.sh | sh
```

### 2. 启动并登录
```bash
sudo tailscale up
```
浏览器打开输出的链接，用 Google 账号登录。之后用以下命令确认 IP：
```bash
tailscale ip -4
```
返回 `100.x.x.x`，记下来。

### 3. 确认 SSH 已启动
```bash
sudo systemctl enable ssh --now
```

---

## 二、Windows 端

去 https://tailscale.com/download 下载安装，**同一个 Google 账号**登录。

---

## 三、手机端

### 1. 装 Tailscale
Google Play / APK 安装，**同一个 Google 账号**登录。

### 2. 装 Termux
Google Play / F-Droid 安装。

### 3. Termux 里装 SSH
```bash
pkg update && pkg install openssh -y
```

### 4. 连接
```bash
ssh jason@<Ubuntu的Tailscale IP>
```

### 5. 运行 Claude Code
```bash
cd ~/mood_diary
claude
```

---

## 注意事项

- **三端必须同一个账号**，否则不在同一网络。
- 手机如果之前设了 Clash 代理，Sign in 时报 DNS 错 → WLAN 设置里把代理改为"无"，登录完再设回去。
- 手机端推荐装 tmux：`pkg install tmux -y`，断网后任务不丢，重连 `tmux attach` 恢复。
- Tailscale 不受 WiFi/网络限制，只要能上网就能连。
