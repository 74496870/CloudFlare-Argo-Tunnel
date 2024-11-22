# CloudFlare Argo Tunnel 一键配置脚本

白嫖CloudFlare的Argo Tunnel隧道，实现内网穿透！！！目前脚本支持Argo Tunnel[支持的协议](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/ingress)的穿透，并保存为CloudFlare Argo Tunnel的配置文件；默认使用Screen运行隧道，让你断开SSH也可以无限链接！！

如对脚本不放心，可使用此沙箱先测一遍再使用：https://killercoda.com/playgrounds/scenario/ubuntu

## 使用方法

```shell
wget -N --no-check-certificate [https://raw.gitmirror.com/74496870/Cloudflare-Zero-Trust/master/argo.sh](https://github.com/74496870/CloudFlare-Argo-Tunnel/blob/main/argo.sh) && bash argo.sh
```

快捷方式 `bash argo.sh`

## CloudFlare Argo Tunnel TCP 协议连接教程

1. 下载并安装：[cloudflared客户端](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation)
2. 命令行输入以下指令

```bat
cloudflared access tcp --hostname [绑定到的域名] --listener [本地监听地址]
```

例如：`cloudflared access tcp --hostname www.example.com --listener localhost:80`，将绑定到www.example.com的隧道映射到本地的80端口

3. 以服务模式运行
```bat
cloudflared service uninstall
```
```bat
cloudflared service install
```

## 参考资料

CloudFlare Argo Tunnel: https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/install-and-setup/installation

## 交流群

[Telegram](https://t.me/+8Roaafmp5Ko4NDMx)

