# dynv6
dynv6.net add delete update select zone or record use bash shell

dynv6.com DNS 管理脚本 - 简化更新版本

使用方法: ./dynv6-updater.sh <命令> [参数]

区域管理命令:
  zone-list                          列出所有区域（表格格式）
  zone-create <name>                 创建新区域
  zone-get [zone]                    获取区域信息
  zone-update <zone> '<json>'        更新区域
  zone-delete [zone]                 删除区域
  zone-stats                         显示区域统计信息

记录管理命令:
  record-list [zone]                 列出区域记录
  record-create <zone> <name> <type> <data> [ttl]  创建记录
  record-get <zone> <record-id>      获取记录信息
  record-update <zone> <record-id> '<json>' 更新记录
  record-delete <zone> <record-id>   删除记录
  record-bulk-update <zone> <name> <type> <data> 批量更新记录
  record-find <zone> <search-term>   搜索记录
  record-details <zone> <record-id>  显示记录详情

简化记录更新命令:
  record-update-simple <zone> <name> <new-data>   简化更新（自动获取记录ID和类型）
  record-update-bulk <zone> <name> <new-data>     批量简化更新同名记录
  record-update-smart <zone> <name> <new-value>   智能更新（自动检测类型）

动态DNS命令:
  ddns-update [zone] [record]        动态更新IP
  ddns-update-simple [zone] [record] 简化动态DNS更新

工具命令:
  get-ip [ipv4|ipv6]                 获取公网IP
  config-init                        显示配置信息
  test-api                           测试API连接

示例:
  ./dynv6-updater.sh test-api                        测试API连接
  ./dynv6-updater.sh zone-list                       列出所有区域
  ./dynv6-updater.sh record-list covid.dynv6.net     列出区域记录
  
  # 简化更新示例
  ./dynv6-updater.sh record-update-simple covid.dynv6.net mail 192.168.1.100
  ./dynv6-updater.sh record-update-smart covid.dynv6.net www 192.168.1.200
  ./dynv6-updater.sh ddns-update-simple covid.dynv6.net @


新增诊断命令
test-record-api: 专门测试记录 API，显示原始响应

record-test: 创建测试记录，用于验证功能

3. 使用步骤
bash
# 1. 首先测试记录API
./dynv6-manager.sh test-record-api covid.dynv6.net

# 2. 如果API正常但无记录，创建测试记录
./dynv6-manager.sh record-test covid.dynv6.net

# 3. 再次列出记录
./dynv6-manager.sh record-list covid.dynv6.net

# 4. 如果仍有问题，查看调试信息
./dynv6-manager.sh test-record-api covid.dynv6.net

新增的简化更新命令
1. record-update-simple - 简化更新
只需要提供区域、记录名称和新值，自动获取记录ID和类型：

bash
./dynv6-updater.sh record-update-simple covid.dynv6.net mail 192.168.1.100
2. record-update-bulk - 批量简化更新
更新所有同名的记录：

bash
./dynv6-updater.sh record-update-bulk covid.dynv6.net @ 192.168.1.100
3. record-update-smart - 智能更新
自动检测值类型并选择正确的记录类型：

IPv4地址 → A记录

IPv6地址 → AAAA记录

域名 → CNAME记录

其他 → TXT记录

bash
./dynv6-updater.sh record-update-smart covid.dynv6.net www 192.168.1.200
4. ddns-update-simple - 简化动态DNS更新
自动检测并更新A和AAAA记录：

bash
./dynv6-updater.sh ddns-update-simple covid.dynv6.net @
使用示例
现在您可以使用这些简化的命令：

bash
# 1. 简化更新A记录
./dynv6-updater.sh record-update-simple covid.dynv6.net mail 192.168.1.100

# 2. 智能更新（自动检测类型）
./dynv6-updater.sh record-update-smart covid.dynv6.net www 192.168.1.200

# 3. 简化动态DNS更新
./dynv6-updater.sh ddns-update-simple covid.dynv6.net @

# 4. 批量更新所有同名记录
./dynv6-updater.sh record-update-bulk covid.dynv6.net @ 192.168.1.100
这些新命令大大简化了更新过程，您只需要提供：

区域名称/ID

记录名称

新的数据值

脚本会自动处理：

查找记录ID

确定记录类型

构建正确的JSON数据

执行API调用

这样您就不需要手动构造复杂的JSON数据了！
