
## 3. USAGE.md 使用指南

```markdown
# 使用指南

## 目录
- [基本概念](#基本概念)
- [命令参考](#命令参考)
- [配置说明](#配置说明)
- [高级用法](#高级用法)

## 基本概念

### 区域 (Zone)
DNS 区域代表一个域名及其所有子域名的集合。

### 记录 (Record)
DNS 记录指定了域名如何解析到 IP 地址或其他资源。

### 记录类型
- **A** - IPv4 地址记录
- **AAAA** - IPv6 地址记录  
- **CNAME** - 别名记录
- **MX** - 邮件交换记录
- **TXT** - 文本记录
- **NS** - 名称服务器记录

## 命令参考

### 脚本信息命令
| 命令 | 描述 |
|------|------|
| `info` | 显示脚本信息和版本 |
| `help` | 显示简洁帮助信息 |
| `test-api` | 测试 API 连接状态 |

### 区域管理命令
| 命令 | 用法 | 描述 |
|------|------|------|
| `zone-list` | `zone-list` | 列出所有区域 |
| `zone-create` | `zone-create <name>` | 创建新区域 |
| `zone-get` | `zone-get [zone]` | 获取区域信息 |
| `zone-update` | `zone-update <zone> '<json>'` | 更新区域 |
| `zone-delete` | `zone-delete [zone]` | 删除区域 |
| `zone-stats` | `zone-stats` | 显示区域统计 |

### 记录管理命令
| 命令 | 用法 | 描述 |
|------|------|------|
| `record-list` | `record-list [zone]` | 列出区域记录 |
| `record-create` | `record-create <zone> <name> <type> <data> [ttl]` | 创建记录 |
| `record-get` | `record-get <zone> <record-id>` | 获取记录信息 |
| `record-update` | `record-update <zone> <record-id> '<json>'` | 更新记录 |
| `record-delete` | `record-delete <zone> <record-id>` | 删除记录 |
| `record-update-simple` | `record-update-simple <zone> <name> <new-data>` | 简化更新记录 |

### 动态 DNS 命令
| 命令 | 用法 | 描述 |
|------|------|------|
| `ddns-update` | `ddns-update [zone] [record]` | 动态更新 IP 地址 |

### 工具命令
| 命令 | 用法 | 描述 |
|------|------|------|
| `get-ip` | `get-ip [ipv4\|ipv6]` | 获取公网 IP 地址 |
| `config-init` | `config-init` | 显示配置信息 |

## 配置说明

### 配置文件位置
`~/.dynv6.conf`

### 配置选项
```bash
# 必需：API Token
API_TOKEN="your_api_token_here"

# 可选：默认区域
DEFAULT_ZONE="your-domain.dynv6.net"

# 可选：日志级别
LOG_LEVEL="INFO"