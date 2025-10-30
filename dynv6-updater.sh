#!/bin/bash

# dynv6.com DNS 管理脚本 - 修复表格显示问题
# 修复 record-list 表格显示为空的问题

# 配置
CONFIG_FILE="$HOME/.dynv6.conf"
DEFAULT_API_TOKEN=""
DEFAULT_ZONE=""

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志函数
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_debug() { echo -e "${BLUE}[DEBUG]${NC} $1"; }
log_success() { echo -e "${CYAN}[SUCCESS]${NC} $1"; }

# 加载配置
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        log_info "配置已加载: $CONFIG_FILE"
    else
        log_warn "配置文件不存在: $CONFIG_FILE"
        log_info "创建示例配置..."
        cat > "$CONFIG_FILE" << EOF
# dynv6.com API 配置
API_TOKEN="your_api_token_here"
DEFAULT_ZONE="your-zone-id-or-name"
EOF
        chmod 600 "$CONFIG_FILE"
        log_info "请编辑配置文件: $CONFIG_FILE"
        exit 1
    fi
}

# 检查依赖
check_dependencies() {
    local deps=("curl" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "缺少依赖: $dep"
            log_info "请安装: sudo apt-get install $dep"
            exit 1
        fi
    done
}

# API 请求函数
api_request() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    
    local url="https://dynv6.com/api/v2/$endpoint"
    local curl_cmd=("curl" "-s" "-H" "Authorization: Bearer $API_TOKEN")
    
    # 添加 Content-Type 头（对于 POST/PATCH 请求）
    if [ "$method" = "POST" ] || [ "$method" = "PATCH" ]; then
        curl_cmd+=("-H" "Content-Type: application/json")
    fi
    
    case "$method" in
        "GET")
            curl_cmd+=("$url")
            ;;
        "POST"|"PATCH")
            curl_cmd+=("-X" "$method" "-d" "$data" "$url")
            ;;
        "DELETE")
            curl_cmd+=("-X" "DELETE" "$url")
            ;;
    esac
    
    # 执行请求
    local response
    response=$("${curl_cmd[@]}" 2>/dev/null)
    local exit_code=$?
    
    # 输出响应体
    echo "$response"
    
    # 如果curl执行成功且响应不为空，则认为请求成功
    if [ $exit_code -eq 0 ] && [ -n "$response" ]; then
        return 0
    else
        return 1
    fi
}

# 获取区域ID（支持名称或ID）
get_zone_id() {
    local zone_input="$1"
    
    # 如果看起来像ID（只包含数字）
    if [[ "$zone_input" =~ ^[0-9]+$ ]]; then
        echo "$zone_input"
        return 0
    fi
    
    # 通过名称获取ID
    local response
    response=$(api_request "GET" "zones/by-name/$zone_input")
    if [ $? -eq 0 ]; then
        local zone_id=$(echo "$response" | jq -r '.id // empty' 2>/dev/null)
        if [ -n "$zone_id" ] && [ "$zone_id" != "null" ]; then
            echo "$zone_id"
            return 0
        fi
    fi
    
    log_error "无法找到区域: $zone_input"
    return 1
}

# 获取记录ID列表（可能多个）
get_record_ids() {
    local zone_id="$1"
    local record_name="$2"
    local record_type="$3"
    
    local response
    response=$(api_request "GET" "zones/$zone_id/records")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # 构建jq查询
    local jq_query=".[]"
    if [ -n "$record_name" ]; then
        jq_query="$jq_query | select(.name == \"$record_name\")"
    fi
    if [ -n "$record_type" ]; then
        jq_query="$jq_query | select(.type == \"$record_type\")"
    fi
    jq_query="$jq_query | .id"
    
    local record_ids
    record_ids=$(echo "$response" | jq -r "$jq_query" 2>/dev/null)
    
    if [ -n "$record_ids" ] && [ "$record_ids" != "null" ]; then
        echo "$record_ids"
        return 0
    fi
    
    return 1
}

# 获取公网IP
get_public_ip() {
    local ip_type="$1"
    
    case "$ip_type" in
        "ipv4")
            curl -s https://ipv4.cip.cc 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
            ;;
        "ipv6")
            curl -s https://ipv6.cip.cc 2>/dev/null | grep -oE '([a-f0-9:]+:+)+[a-f0-9]+' | head -1
            ;;
        *)
            curl -s https://cip.cc 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -1
            ;;
    esac
}

# 显示格式化表格
print_table() {
    local headers=("$@")
    printf "%-20s %-15s %-8s %-40s %-10s\n" "${headers[@]}"
    echo "------------------------------------------------------------------------------------------------------------------"
}

# 区域管理功能

list_zones() {
    log_info "获取区域列表..."
    local response
    response=$(api_request "GET" "zones")
    
    # 检查响应是否有效
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        echo ""
        printf "%-12s %-25s %-18s %-12s %-25s\n" "ID" "名称" "IPv4地址" "IPv6前缀" "创建时间"
        echo "--------------------------------------------------------------------------------------------------------"
        
        # 使用jq解析JSON数组
        echo "$response" | jq -r '.[] | "\(.id) \(.name) \(.ipv4address) \(.ipv6prefix) \(.createdAt)"' 2>/dev/null | \
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                local id name ipv4 ipv6prefix created_at
                id=$(echo "$line" | awk '{print $1}')
                name=$(echo "$line" | awk '{print $2}')
                ipv4=$(echo "$line" | awk '{print $3}')
                ipv6prefix=$(echo "$line" | awk '{print $4}')
                created_at=$(echo "$line" | awk '{for(i=5;i<=NF;i++) printf $i " "; print ""}' | sed 's/ $//')
                
                # 格式化日期（去掉时区信息）
                created_at=$(echo "$created_at" | sed 's/\+.*//')
                
                printf "%-12s %-25s %-18s %-12s %-25s\n" "$id" "$name" "$ipv4" "$ipv6prefix" "$created_at"
            fi
        done
        echo ""
        
        # 显示统计信息
        local zone_count=$(echo "$response" | jq '. | length' 2>/dev/null)
        log_success "总共找到 $zone_count 个区域"
        
    else
        log_error "获取区域列表失败"
        log_debug "原始响应: $response"
        return 1
    fi
}

# 记录管理功能 - 修复表格显示问题
list_records() {
    local zone_input="$1"
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -eq 0 ]; then
        log_info "获取记录列表: $zone_id"
        local response
        response=$(api_request "GET" "zones/$zone_id/records")
        
        if [ $? -eq 0 ] && [ -n "$response" ]; then
            echo ""
            print_table "ID" "名称" "类型" "数据" "优先级"
            
            # 检查响应是否为数组且不为空
            if echo "$response" | jq -c 'type == "array" and length > 0' >/dev/null 2>&1; then
                # 使用更可靠的jq解析方式
                local record_count=0
                echo "$response" | jq -c '.[]' | while IFS= read -r record; do
                    local id name type data priority
                    id=$(echo "$record" | jq -r '.id')
                    name=$(echo "$record" | jq -r '.name')
                    type=$(echo "$record" | jq -r '.type')
                    data=$(echo "$record" | jq -r '.data')
                    priority=$(echo "$record" | jq -r '.priority // "N/A"')
                    
                    # 处理空名称（根记录）
                    if [ "$name" = "null" ] || [ -z "$name" ]; then
                        name="@"
                    fi
                    
                    # 处理null值
                    if [ "$priority" = "null" ]; then
                        priority="N/A"
                    fi
                    
                    printf "%-20s %-15s %-8s %-40s %-10s\n" "$id" "$name" "$type" "$data" "$priority"
                    record_count=$((record_count + 1))
                done
            else
                log_warn "该区域没有记录或响应格式不正确"
            fi
            echo ""
            
            # 显示记录统计
            local total_records=$(echo "$response" | jq 'length' 2>/dev/null)
            log_success "总共找到 $total_records 条记录"
            
        else
            log_error "获取记录列表失败或响应为空"
            log_debug "API响应: $response"
            return 1
        fi
    else
        return 1
    fi
}

# 创建记录
create_record() {
    local zone_input="$1"
    local name="$2"
    local type="$3"
    local data="$4"
    local ttl="${5:-300}"
    
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -eq 0 ]; then
        log_info "创建记录: $name.$zone_input $type $data TTL:$ttl"
        local record_data="{\"name\":\"$name\",\"type\":\"$type\",\"data\":\"$data\",\"ttl\":$ttl}"
        local response
        response=$(api_request "POST" "zones/$zone_id/records" "$record_data")
        
        if [ $? -eq 0 ]; then
            log_success "记录创建成功"
            echo "$response" | jq '.' 2>/dev/null || echo "$response"
        else
            log_error "记录创建失败"
            echo "$response" | jq '.' 2>/dev/null || echo "$response"
            return 1
        fi
    else
        return 1
    fi
}

# 获取记录详情
get_record() {
    local zone_input="$1"
    local record_id="$2"
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -eq 0 ]; then
        log_info "获取记录信息: $record_id"
        local response
        response=$(api_request "GET" "zones/$zone_id/records/$record_id")
        if [ $? -eq 0 ]; then
            echo "$response" | jq '.' 2>/dev/null || echo "$response"
        else
            log_error "获取记录信息失败"
            return 1
        fi
    else
        return 1
    fi
}

# 更新记录
update_record() {
    local zone_input="$1"
    local record_id="$2"
    local update_data="$3"
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -eq 0 ]; then
        log_info "更新记录: $record_id"
        local response
        response=$(api_request "PATCH" "zones/$zone_id/records/$record_id" "$update_data")
        if [ $? -eq 0 ]; then
            log_success "记录更新成功"
            echo "$response" | jq '.' 2>/dev/null || echo "$response"
        else
            log_error "记录更新失败"
            echo "$response" | jq '.' 2>/dev/null || echo "$response"
            return 1
        fi
    else
        return 1
    fi
}

# 删除记录
delete_record() {
    local zone_input="$1"
    local record_id="$2"
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -eq 0 ]; then
        log_warn "即将删除记录: $record_id"
        read -p "确认删除？(y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            local response
            response=$(api_request "DELETE" "zones/$zone_id/records/$record_id")
            if [ $? -eq 0 ]; then
                log_success "记录删除成功"
            else
                log_error "记录删除失败"
                return 1
            fi
        else
            log_info "取消删除"
        fi
    else
        return 1
    fi
}

# 批量操作记录
bulk_update_records() {
    local zone_input="$1"
    local record_name="$2"
    local record_type="$3"
    local new_data="$4"
    
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    log_info "批量更新记录: $record_name $record_type -> $new_data"
    
    local record_ids
    record_ids=$(get_record_ids "$zone_id" "$record_name" "$record_type")
    
    if [ $? -eq 0 ]; then
        local count=0
        while IFS= read -r record_id; do
            if [ -n "$record_id" ]; then
                local update_data="{\"data\":\"$new_data\"}"
                api_request "PATCH" "zones/$zone_id/records/$record_id" "$update_data" > /dev/null
                if [ $? -eq 0 ]; then
                    log_info "✓ 更新记录: $record_id"
                    count=$((count + 1))
                else
                    log_error "✗ 更新记录失败: $record_id"
                fi
            fi
        done <<< "$record_ids"
        log_success "批量更新完成: $count 条记录已更新"
    else
        log_warn "未找到匹配的记录: $record_name $record_type"
        return 1
    fi
}

# 动态DNS功能
ddns_update() {
    local zone_input="$1"
    local record_name="${2:-@}"
    local update_ipv4="${3:-true}"
    local update_ipv6="${4:-true}"
    
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    log_info "开始动态DNS更新: $zone_input ($record_name)"
    
    # 更新IPv4
    if [ "$update_ipv4" = "true" ]; then
        local ipv4
        ipv4=$(get_public_ip "ipv4")
        if [ -n "$ipv4" ]; then
            log_info "当前IPv4: $ipv4"
            update_or_create_record "$zone_id" "$record_name" "A" "$ipv4"
        else
            log_error "无法获取IPv4地址"
        fi
    fi
    
    # 更新IPv6
    if [ "$update_ipv6" = "true" ]; then
        local ipv6
        ipv6=$(get_public_ip "ipv6")
        if [ -n "$ipv6" ]; then
            log_info "当前IPv6: $ipv6"
            update_or_create_record "$zone_id" "$record_name" "AAAA" "$ipv6"
        else
            log_warn "无法获取IPv6地址（可能没有IPv6连接）"
        fi
    fi
}

update_or_create_record() {
    local zone_id="$1"
    local record_name="$2"
    local record_type="$3"
    local record_data="$4"
    
    local record_ids
    record_ids=$(get_record_ids "$zone_id" "$record_name" "$record_type")
    
    if [ $? -eq 0 ] && [ -n "$record_ids" ]; then
        # 更新现有记录（可能有多个）
        local count=0
        while IFS= read -r record_id; do
            if [ -n "$record_id" ]; then
                local update_data="{\"data\":\"$record_data\"}"
                api_request "PATCH" "zones/$zone_id/records/$record_id" "$update_data" > /dev/null
                if [ $? -eq 0 ]; then
                    log_info "✓ 更新 $record_type 记录: $record_name -> $record_data (ID: $record_id)"
                    count=$((count + 1))
                else
                    log_error "✗ 更新 $record_type 记录失败: $record_id"
                fi
            fi
        done <<< "$record_ids"
        if [ "$count" -eq 0 ]; then
            log_warn "没有找到要更新的 $record_type 记录，尝试创建新记录"
            create_record "$zone_id" "$record_name" "$record_type" "$record_data" "60" > /dev/null
        fi
    else
        # 创建新记录
        create_record "$zone_id" "$record_name" "$record_type" "$record_data" "60" > /dev/null
        if [ $? -eq 0 ]; then
            log_success "✓ 创建 $record_type 记录: $record_name -> $record_data"
        else
            log_error "✗ 创建 $record_type 记录失败"
        fi
    fi
}

# 查找记录
find_records() {
    local zone_input="$1"
    local search_term="$2"
    
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -eq 0 ]; then
        log_info "搜索记录: '$search_term'"
        local response
        response=$(api_request "GET" "zones/$zone_id/records")
        if [ $? -eq 0 ]; then
            echo ""
            print_table "ID" "名称" "类型" "数据" "优先级"
            
            echo "$response" | jq -c ".[] | select(.name | contains(\"$search_term\") or .data | contains(\"$search_term\"))" 2>/dev/null | \
            while IFS= read -r record; do
                local id name type data priority
                id=$(echo "$record" | jq -r '.id')
                name=$(echo "$record" | jq -r '.name')
                type=$(echo "$record" | jq -r '.type')
                data=$(echo "$record" | jq -r '.data')
                priority=$(echo "$record" | jq -r '.priority // "N/A"')
                
                # 处理空名称（根记录）
                if [ "$name" = "null" ] || [ -z "$name" ]; then
                    name="@"
                fi
                
                # 处理null值
                if [ "$priority" = "null" ]; then
                    priority="N/A"
                fi
                
                printf "%-20s %-15s %-8s %-40s %-10s\n" "$id" "$name" "$type" "$data" "$priority"
            done
            echo ""
        else
            log_error "搜索记录失败"
            return 1
        fi
    else
        return 1
    fi
}

# 显示区域统计信息
zone_stats() {
    log_info "获取区域统计信息..."
    local response
    response=$(api_request "GET" "zones")
    if [ $? -eq 0 ]; then
        local total_zones=$(echo "$response" | jq '. | length' 2>/dev/null)
        local zones_with_ipv4=$(echo "$response" | jq '[.[] | select(.ipv4address != "" and .ipv4address != null)] | length' 2>/dev/null)
        local zones_with_ipv6=$(echo "$response" | jq '[.[] | select(.ipv6prefix != "" and .ipv6prefix != null)] | length' 2>/dev/null)
        
        echo ""
        echo "=== 区域统计信息 ==="
        echo "总区域数: $total_zones"
        echo "有IPv4地址的区域: $zones_with_ipv4"
        echo "有IPv6前缀的区域: $zones_with_ipv6"
        echo ""
    else
        log_error "获取统计信息失败"
        return 1
    fi
}

# 测试API连接
test_api() {
    log_info "测试API连接..."
    local response
    response=$(api_request "GET" "zones")
    
    if [ $? -eq 0 ] && [ -n "$response" ]; then
        local zone_count=$(echo "$response" | jq '. | length' 2>/dev/null)
        log_success "API连接正常"
        echo "区域数量: $zone_count"
    else
        log_error "API连接失败"
        echo ""
        echo "可能的原因:"
        echo "1. API Token 不正确"
        echo "2. 网络连接问题"
        echo "3. dynv6.com 服务暂时不可用"
    fi
}

# 显示记录详情（调试用）
show_record_details() {
    local zone_input="$1"
    local record_id="$2"
    
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -eq 0 ]; then
        log_info "记录详情: $record_id"
        local response
        response=$(api_request "GET" "zones/$zone_id/records/$record_id")
        if [ $? -eq 0 ]; then
            echo "完整记录信息:"
            echo "$response" | jq '.' 2>/dev/null
        else
            log_error "获取记录详情失败"
        fi
    else
        log_error "无法获取区域ID"
    fi
}

# dynv6.com DNS 管理脚本 - 简化更新版本
# 添加简化的记录更新命令

# ... (前面的配置、颜色定义、日志函数、加载配置、检查依赖、API请求函数等保持不变)
# 这里只显示新增和修改的部分

# 简化更新记录 - 只需要提供名称和新值
simple_update_record() {
    local zone_input="$1"
    local record_name="$2"
    local new_data="$3"
    
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    log_info "简化更新记录: $record_name -> $new_data"
    
    # 获取记录ID和类型
    local response
    response=$(api_request "GET" "zones/$zone_id/records")
    
    if [ $? -eq 0 ]; then
        # 查找匹配的记录
        local record_info
        record_info=$(echo "$response" | jq -c ".[] | select(.name == \"$record_name\")" | head -1)
        
        if [ -n "$record_info" ] && [ "$record_info" != "null" ]; then
            local record_id record_type
            record_id=$(echo "$record_info" | jq -r '.id')
            record_type=$(echo "$record_info" | jq -r '.type')
            
            log_info "找到记录: $record_name ($record_type), ID: $record_id"
            
            # 构建更新数据
            local update_data="{\"data\":\"$new_data\"}"
            
            # 执行更新
            local update_response
            update_response=$(api_request "PATCH" "zones/$zone_id/records/$record_id" "$update_data")
            
            if [ $? -eq 0 ]; then
                log_success "记录更新成功: $record_name.$zone_input $record_type -> $new_data"
                return 0
            else
                log_error "记录更新失败"
                echo "$update_response" | jq '.' 2>/dev/null || echo "$update_response"
                return 1
            fi
        else
            log_error "未找到记录: $record_name"
            return 1
        fi
    else
        log_error "获取记录列表失败"
        return 1
    fi
}

# 批量简化更新 - 更新所有指定名称的记录
bulk_simple_update() {
    local zone_input="$1"
    local record_name="$2"
    local new_data="$3"
    
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    log_info "批量简化更新: $record_name -> $new_data"
    
    # 获取记录列表
    local response
    response=$(api_request "GET" "zones/$zone_id/records")
    
    if [ $? -eq 0 ]; then
        # 查找所有匹配的记录
        local record_count=0
        local success_count=0
        
        echo "$response" | jq -c ".[] | select(.name == \"$record_name\")" | while IFS= read -r record_info; do
            if [ -n "$record_info" ] && [ "$record_info" != "null" ]; then
                local record_id record_type
                record_id=$(echo "$record_info" | jq -r '.id')
                record_type=$(echo "$record_info" | jq -r '.type')
                
                record_count=$((record_count + 1))
                log_info "更新记录: $record_name ($record_type), ID: $record_id"
                
                # 构建更新数据
                local update_data="{\"data\":\"$new_data\"}"
                
                # 执行更新
                api_request "PATCH" "zones/$zone_id/records/$record_id" "$update_data" > /dev/null
                
                if [ $? -eq 0 ]; then
                    log_info "✓ 更新成功: $record_name.$zone_input $record_type -> $new_data"
                    success_count=$((success_count + 1))
                else
                    log_error "✗ 更新失败: $record_id"
                fi
            fi
        done
        
        if [ "$record_count" -eq 0 ]; then
            log_warn "未找到匹配的记录: $record_name"
            return 1
        else
            log_success "批量更新完成: $success_count/$record_count 条记录已更新"
            return 0
        fi
    else
        log_error "获取记录列表失败"
        return 1
    fi
}

# 智能更新记录 - 自动检测记录类型并更新
smart_update_record() {
    local zone_input="$1"
    local record_name="$2"
    local new_value="$3"
    
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    log_info "智能更新记录: $record_name -> $new_value"
    
    # 自动检测记录类型
    local record_type
    if [[ "$new_value" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        record_type="A"
        log_info "检测到 IPv4 地址，使用 A 记录"
    elif [[ "$new_value" =~ ^([a-f0-9:]+:+)+[a-f0-9]+$ ]]; then
        record_type="AAAA"
        log_info "检测到 IPv6 地址，使用 AAAA 记录"
    elif [[ "$new_value" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        record_type="CNAME"
        log_info "检测到域名，使用 CNAME 记录"
    else
        record_type="TXT"
        log_info "未识别类型，使用 TXT 记录"
    fi
    
    # 获取现有记录ID
    local record_ids
    record_ids=$(get_record_ids "$zone_id" "$record_name" "$record_type")
    
    if [ $? -eq 0 ] && [ -n "$record_ids" ]; then
        # 更新现有记录
        local count=0
        while IFS= read -r record_id; do
            if [ -n "$record_id" ]; then
                local update_data="{\"data\":\"$new_value\"}"
                api_request "PATCH" "zones/$zone_id/records/$record_id" "$update_data" > /dev/null
                if [ $? -eq 0 ]; then
                    log_info "✓ 更新 $record_type 记录: $record_name -> $new_value (ID: $record_id)"
                    count=$((count + 1))
                else
                    log_error "✗ 更新 $record_type 记录失败: $record_id"
                fi
            fi
        done <<< "$record_ids"
        
        if [ "$count" -gt 0 ]; then
            log_success "成功更新 $count 条 $record_type 记录"
            return 0
        fi
    fi
    
    # 如果没有找到现有记录，尝试创建新记录
    log_warn "未找到现有的 $record_type 记录，尝试创建新记录"
    create_record "$zone_id" "$record_name" "$record_type" "$new_value" "300" > /dev/null
    
    if [ $? -eq 0 ]; then
        log_success "✓ 创建 $record_type 记录: $record_name -> $new_value"
        return 0
    else
        log_error "✗ 创建记录失败"
        return 1
    fi
}

# 动态DNS简化更新
simple_ddns_update() {
    local zone_input="$1"
    local record_name="${2:-@}"
    
    local zone_id
    zone_id=$(get_zone_id "$zone_input")
    
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    log_info "简化动态DNS更新: $zone_input ($record_name)"
    
    # 获取当前IP
    local ipv4 ipv6
    ipv4=$(get_public_ip "ipv4")
    ipv6=$(get_public_ip "ipv6")
    
    # 更新IPv4
    if [ -n "$ipv4" ]; then
        log_info "当前IPv4: $ipv4"
        smart_update_record "$zone_id" "$record_name" "$ipv4"
    else
        log_error "无法获取IPv4地址"
    fi
    
    # 更新IPv6（如果有）
    if [ -n "$ipv6" ]; then
        log_info "当前IPv6: $ipv6"
        # 对于IPv6，通常使用相同的记录名称
        smart_update_record "$zone_id" "$record_name" "$ipv6"
    else
        log_warn "无法获取IPv6地址（可能没有IPv6连接）"
    fi
}

# 在主程序中添加新的命令
main() {
    check_dependencies
    load_config
    
    local command="$1"
    shift
    
    case "$command" in
        # ... 其他现有命令保持不变
                # 区域管理
        "zone-list")
            list_zones
            ;;
        "zone-create")
            local name="$1"
            if [ -z "$name" ]; then
                log_error "请提供区域名称"
                exit 1
            fi
            create_zone "$name"
            ;;
        "zone-get")
            local zone_input="${1:-$DEFAULT_ZONE}"
            if [ -z "$zone_input" ]; then
                log_error "请提供区域ID或名称"
                exit 1
            fi
            get_zone "$zone_input"
            ;;
        "zone-update")
            local zone_input="$1"
            local update_data="$2"
            if [ -z "$zone_input" ] || [ -z "$update_data" ]; then
                log_error "用法: $0 zone-update <zone> '<json_data>'"
                exit 1
            fi
            update_zone "$zone_input" "$update_data"
            ;;
        "zone-delete")
            local zone_input="${1:-$DEFAULT_ZONE}"
            if [ -z "$zone_input" ]; then
                log_error "请提供区域ID或名称"
                exit 1
            fi
            delete_zone "$zone_input"
            ;;
        "zone-stats")
            zone_stats
            ;;
        
        # 记录管理
        "record-list")
            local zone_input="${1:-$DEFAULT_ZONE}"
            if [ -z "$zone_input" ]; then
                log_error "请提供区域ID或名称"
                exit 1
            fi
            list_records "$zone_input"
            ;;
        "record-create")
            local zone_input="$1"
            local name="$2"
            local type="$3"
            local data="$4"
            local ttl="$5"
            if [ -z "$zone_input" ] || [ -z "$name" ] || [ -z "$type" ] || [ -z "$data" ]; then
                log_error "用法: $0 record-create <zone> <name> <type> <data> [ttl]"
                exit 1
            fi
            create_record "$zone_input" "$name" "$type" "$data" "$ttl"
            ;;
        "record-get")
            local zone_input="$1"
            local record_id="$2"
            if [ -z "$zone_input" ] || [ -z "$record_id" ]; then
                log_error "用法: $0 record-get <zone> <record-id>"
                exit 1
            fi
            get_record "$zone_input" "$record_id"
            ;;
        "record-update")
            local zone_input="$1"
            local record_id="$2"
            local update_data="$3"
            if [ -z "$zone_input" ] || [ -z "$record_id" ] || [ -z "$update_data" ]; then
                log_error "用法: $0 record-update <zone> <record-id> '<json_data>'"
                exit 1
            fi
            update_record "$zone_input" "$record_id" "$update_data"
            ;;
        "record-delete")
            local zone_input="$1"
            local record_id="$2"
            if [ -z "$zone_input" ] || [ -z "$record_id" ]; then
                log_error "用法: $0 record-delete <zone> <record-id>"
                exit 1
            fi
            delete_record "$zone_input" "$record_id"
            ;;
        "record-bulk-update")
            local zone_input="$1"
            local record_name="$2"
            local record_type="$3"
            local new_data="$4"
            if [ -z "$zone_input" ] || [ -z "$record_name" ] || [ -z "$record_type" ] || [ -z "$new_data" ]; then
                log_error "用法: $0 record-bulk-update <zone> <name> <type> <new-data>"
                exit 1
            fi
            bulk_update_records "$zone_input" "$record_name" "$record_type" "$new_data"
            ;;
        "record-find")
            local zone_input="$1"
            local search_term="$2"
            if [ -z "$zone_input" ] || [ -z "$search_term" ]; then
                log_error "用法: $0 record-find <zone> <search-term>"
                exit 1
            fi
            find_records "$zone_input" "$search_term"
            ;;
        "record-details")
            local zone_input="$1"
            local record_id="$2"
            if [ -z "$zone_input" ] || [ -z "$record_id" ]; then
                log_error "用法: $0 record-details <zone> <record-id>"
                exit 1
            fi
            show_record_details "$zone_input" "$record_id"
            ;;
        
        # 动态DNS
        "ddns-update")
            local zone_input="${1:-$DEFAULT_ZONE}"
            local record_name="${2:-@}"
            if [ -z "$zone_input" ]; then
                log_error "请提供区域ID或名称"
                exit 1
            fi
            ddns_update "$zone_input" "$record_name"
            ;;
        
        # 工具功能
        "get-ip")
            local ip_type="$1"
            get_public_ip "$ip_type"
            ;;
        "config-init")
            log_info "配置文件位置: $CONFIG_FILE"
            if [ -f "$CONFIG_FILE" ]; then
                cat "$CONFIG_FILE"
            fi
            ;;
        "test-api")
            test_api
            ;;

        # 简化记录管理命令
        "record-update-simple")
            local zone_input="$1"
            local record_name="$2"
            local new_data="$3"
            if [ -z "$zone_input" ] || [ -z "$record_name" ] || [ -z "$new_data" ]; then
                log_error "用法: $0 record-update-simple <zone> <name> <new-data>"
                exit 1
            fi
            simple_update_record "$zone_input" "$record_name" "$new_data"
            ;;
        "record-update-bulk")
            local zone_input="$1"
            local record_name="$2"
            local new_data="$3"
            if [ -z "$zone_input" ] || [ -z "$record_name" ] || [ -z "$new_data" ]; then
                log_error "用法: $0 record-update-bulk <zone> <name> <new-data>"
                exit 1
            fi
            bulk_simple_update "$zone_input" "$record_name" "$new_data"
            ;;
        "record-update-smart")
            local zone_input="$1"
            local record_name="$2"
            local new_value="$3"
            if [ -z "$zone_input" ] || [ -z "$record_name" ] || [ -z "$new_value" ]; then
                log_error "用法: $0 record-update-smart <zone> <name> <new-value>"
                exit 1
            fi
            smart_update_record "$zone_input" "$record_name" "$new_value"
            ;;
        "ddns-update-simple")
            local zone_input="${1:-$DEFAULT_ZONE}"
            local record_name="${2:-@}"
            if [ -z "$zone_input" ]; then
                log_error "请提供区域ID或名称"
                exit 1
            fi
            simple_ddns_update "$zone_input" "$record_name"
            ;;
        
        # ... 其他现有命令保持不变
    esac
}

# 更新帮助信息
show_help() {
    cat << EOF
dynv6.com DNS 管理脚本 - 简化更新版本

使用方法: $0 <命令> [参数]

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
  $0 test-api                        测试API连接
  $0 zone-list                       列出所有区域
  $0 record-list covid.dynv6.net     列出区域记录
  
  # 简化更新示例
  $0 record-update-simple covid.dynv6.net mail 192.168.1.100
  $0 record-update-smart covid.dynv6.net www 192.168.1.200
  $0 ddns-update-simple covid.dynv6.net @

配置文件: $CONFIG_FILE
EOF
}

# 运行主程序
if [ $# -eq 0 ]; then
    show_help
else
    main "$@"
fi
