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
   git clone https://github.com/yourusername/dynv6-dns-manager.git
   cd dynv6-dns-manager

2. **安装依赖**
# Ubuntu/Debian
sudo apt-get install curl jq

# CentOS/RHEL
sudo yum install curl jq

3. **配置 API Token**
# 首次运行会自动创建配置文件
./dynv6-updater.sh config-init

# 编辑配置文件
vi ~/.dynv6.conf

4. **测试连接**
./dynv6-updater.sh test-api

文档目录
USAGE.md - 详细使用指南和命令参考

EXAMPLES.md - 实际使用示例

config.example - 配置文件示例

常用命令
# 查看脚本信息
./dynv6-updater.sh info

# 测试 API 连接
./dynv6-updater.sh test-api

# 列出所有区域
./dynv6-updater.sh zone-list

# 列出区域记录
./dynv6-updater.sh record-list your-domain.dynv6.net

# 动态 DNS 更新
./dynv6-updater.sh ddns-update your-domain.dynv6.net @

# 简化记录更新
./dynv6-updater.sh record-update-simple your-domain.dynv6.net www 192.168.1.100


配置文件

# dynv6.com API 配置
API_TOKEN="your_api_token_here"

# 默认区域（可选）
DEFAULT_ZONE="your-default-zone"

# 日志级别（可选）
LOG_LEVEL="INFO"

获取 API Token
登录 dynv6.com

进入账户设置

在 API 部分生成新的 Token


