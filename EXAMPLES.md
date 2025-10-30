
## 4. EXAMPLES.md 使用示例

```markdown
# 使用示例

## 目录
- [快速开始](#快速开始)
- [区域管理示例](#区域管理示例)
- [记录管理示例](#记录管理示例)
- [动态DNS示例](#动态dns示例)
- [高级用法示例](#高级用法示例)

## 快速开始

### 1. 初始设置
```bash
# 下载脚本
git clone https://github.com/yourusername/dynv6-dns-manager.git
cd dynv6-dns-manager

# 安装依赖 (Ubuntu/Debian)
sudo apt-get install curl jq

# 首次运行创建配置
./dynv6-updater.sh config-init

# 编辑配置文件
vi ~/.dynv6.conf