# CloudFlare Argo Tunnel 一键配置脚本

白嫖 CloudFlare 的 Argo Tunnel 隧道，实现内网穿透！本脚本支持 Argo Tunnel [所有受支持的协议](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/ingress)，并自动生成 CloudFlare Argo Tunnel 配置文件；默认以 `screen` 后台运行隧道，SSH 断开后也能保持在线。

如对脚本不放心，可先在沙箱环境试用：<https://killercoda.com/playgrounds/scenario/ubuntu>

## 特性

- 一键安装 / 卸载 `cloudflared` 客户端（支持 Debian / Ubuntu / CentOS / Alma / Rocky / Alpine）
- 交互式创建隧道、绑定域名、生成配置文件
- `screen` 会话托管隧道，支持随时启动 / 停止
- 支持提取 Argo Tunnel 证书
- 脚本自更新

## 使用方法

```shell
wget -N --no-check-certificate https://raw.githubusercontent.com/74496870/CloudFlare-Argo-Tunnel/main/argo.sh && bash argo.sh
```

后续快捷运行：

```shell
bash argo.sh
```

## 菜单说明

| 选项 | 功能 |
| ---- | ---- |
| 1 | 安装并登录 `cloudflared` 客户端 |
| 2 | 配置 Argo Tunnel 隧道（交互式） |
| 3 | 列出已创建的 Argo Tunnel 隧道 |
| 4 | 通过 `screen` 后台运行隧道 |
| 5 | 停止指定 `screen` 会话中的隧道 |
| 6 | 删除 Argo Tunnel 隧道 |
| 7 | 提取 Argo Tunnel 证书到 `/root/cert.crt`、`/root/private.key` |
| 8 | 卸载 `cloudflared` 客户端 |
| 9 | 从官方仓库拉取最新脚本并重启 |
| 0 | 退出脚本 |

## CloudFlare Argo Tunnel TCP 协议连接教程

1. 下载并安装 [cloudflared 客户端](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation)
2. 命令行运行：

    ```bat
    cloudflared access tcp --hostname [绑定域名] --listener [本地监听地址]
    ```

    例如 `cloudflared access tcp --hostname www.example.com --listener localhost:80`，将绑定到 `www.example.com` 的隧道映射到本地 80 端口。

3. 以服务模式运行：

    ```bat
    cloudflared service uninstall
    cloudflared service install
    ```

## 参考资料

- CloudFlare Argo Tunnel 官方文档：<https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation>

## 交流群

- [Telegram](https://t.me/+8Roaafmp5Ko4NDMx)
