# dynv6.com DNS 管理脚本

一个功能完整的 Bash 脚本，用于管理 dynv6.com 的 DNS 区域和记录。

## 功能特性

- ✅ **完整的区域管理** - 创建、查看、更新、删除 DNS 区域
- ✅ **记录管理** - 管理各种 DNS 记录类型 (A, AAAA, CNAME, MX, TXT 等)
- ✅ **动态 DNS 更新** - 自动检测并更新公网 IP 地址
- ✅ **批量操作** - 支持批量更新和管理操作
- ✅ **简化命令** - 提供简单易用的高级命令
- ✅ **日志记录** - 完整的操作日志
- ✅ **配置管理** - 安全的配置文件管理

## 系统要求

- Linux/Unix 系统
- Bash 4.0+
- curl
- jq

## 快速开始

1. **下载脚本**
   ```bash
   git clone https://github.com/lucaswang0/dynv6-dns-manager.git
   cd dynv6-dns-manager
