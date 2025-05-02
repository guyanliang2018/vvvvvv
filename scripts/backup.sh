#!/bin/bash
# backup.sh - Marzban面板及节点配置备份脚本
# 用法: ./backup.sh [--restore backup_file.tar.gz]

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 配置
CONFIG_DIR="/Users/xigua/vpn3"
MARZBAN_DIR="$CONFIG_DIR/marzban"
NETMAKER_DIR="$CONFIG_DIR/netmaker"
BACKUP_DIR="$CONFIG_DIR/backups"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/vpn_backup_$DATE.tar.gz"
RESTORE_MODE=false
RESTORE_FILE=""

# 检查参数
for i in "$@"; do
  case $i in
    --restore=*)
      RESTORE_MODE=true
      RESTORE_FILE="${i#*=}"
      ;;
    --restore)
      RESTORE_MODE=true
      shift
      RESTORE_FILE="$1"
      ;;
  esac
done

# 确保备份目录存在
mkdir -p "$BACKUP_DIR"

# 恢复模式
if [ "$RESTORE_MODE" = true ]; then
  if [ -z "$RESTORE_FILE" ]; then
    echo -e "${RED}错误: 未指定恢复文件${NC}"
    exit 1
  fi
  
  if [ ! -f "$RESTORE_FILE" ]; then
    echo -e "${RED}错误: 恢复文件不存在: $RESTORE_FILE${NC}"
    exit 1
  fi
  
  echo -e "${YELLOW}准备恢复数据从: $RESTORE_FILE${NC}"
  
  # 停止服务
  echo -e "${BLUE}停止服务...${NC}"
  cd "$MARZBAN_DIR" && docker-compose down
  cd "$NETMAKER_DIR" && docker-compose down
  
  # 解压备份
  echo -e "${BLUE}解压备份文件...${NC}"
  TMP_DIR=$(mktemp -d)
  tar -xzf "$RESTORE_FILE" -C "$TMP_DIR"
  
  # 恢复Marzban数据
  echo -e "${BLUE}恢复Marzban数据...${NC}"
  rsync -a "$TMP_DIR/marzban/data/" "$MARZBAN_DIR/data/"
  rsync -a "$TMP_DIR/marzban/mysql/" "$MARZBAN_DIR/mysql/"
  rsync -a "$TMP_DIR/marzban/certs/" "$MARZBAN_DIR/certs/"
  
  # 恢复Netmaker数据
  echo -e "${BLUE}恢复Netmaker数据...${NC}"
  rsync -a "$TMP_DIR/netmaker/data/" "$NETMAKER_DIR/data/"
  
  # 恢复凭证
  echo -e "${BLUE}恢复凭证文件...${NC}"
  cp "$TMP_DIR/credentials.env" "$CONFIG_DIR/credentials.env"
  
  # 清理
  rm -rf "$TMP_DIR"
  
  # 重启服务
  echo -e "${BLUE}重启服务...${NC}"
  cd "$NETMAKER_DIR" && docker-compose up -d
  cd "$MARZBAN_DIR" && docker-compose up -d
  
  echo -e "${GREEN}恢复完成!${NC}"
  exit 0
fi

# 备份模式
echo -e "${BLUE}开始备份...${NC}"

# 创建临时目录
TMP_DIR=$(mktemp -d)
mkdir -p "$TMP_DIR/marzban/data"
mkdir -p "$TMP_DIR/marzban/mysql"
mkdir -p "$TMP_DIR/marzban/certs"
mkdir -p "$TMP_DIR/netmaker/data"

# 备份Marzban数据
echo -e "${BLUE}备份Marzban数据...${NC}"
if [ -d "$MARZBAN_DIR/data" ]; then
  rsync -a "$MARZBAN_DIR/data/" "$TMP_DIR/marzban/data/"
fi

if [ -d "$MARZBAN_DIR/mysql" ]; then
  # 创建MySQL转储 (更安全的方式)
  echo -e "${BLUE}备份MySQL数据库...${NC}"
  cd "$MARZBAN_DIR"
  docker-compose exec -T mariadb mysqldump -u root -p"${MYSQL_ROOT_PASSWORD}" --all-databases > "$TMP_DIR/marzban/mysql/all_databases.sql"
fi

if [ -d "$MARZBAN_DIR/certs" ]; then
  rsync -a "$MARZBAN_DIR/certs/" "$TMP_DIR/marzban/certs/"
fi

# 备份Netmaker数据
echo -e "${BLUE}备份Netmaker数据...${NC}"
if [ -d "$NETMAKER_DIR/data" ]; then
  rsync -a "$NETMAKER_DIR/data/" "$TMP_DIR/netmaker/data/"
fi

# 备份凭证
echo -e "${BLUE}备份凭证文件...${NC}"
if [ -f "$CONFIG_DIR/credentials.env" ]; then
  cp "$CONFIG_DIR/credentials.env" "$TMP_DIR/"
fi

# 创建备份文件
echo -e "${BLUE}创建备份压缩文件...${NC}"
tar -czf "$BACKUP_FILE" -C "$TMP_DIR" .

# 清理
rm -rf "$TMP_DIR"

# 保留最近10个备份
echo -e "${BLUE}清理旧备份...${NC}"
ls -tp "$BACKUP_DIR/"vpn_backup_* | grep -v '/$' | tail -n +11 | xargs -I {} rm -- {}

echo -e "${GREEN}备份完成: $BACKUP_FILE${NC}"
echo -e "${YELLOW}要恢复此备份，请运行: $0 --restore=$BACKUP_FILE${NC}"

# 同步到远程存储 (可选)
if [ -n "$REMOTE_BACKUP_ENABLED" ] && [ "$REMOTE_BACKUP_ENABLED" = true ]; then
  echo -e "${BLUE}同步到远程存储...${NC}"
  
  # 可以使用不同的远程存储方式，如S3、SFTP等
  if [ -n "$S3_BUCKET" ]; then
    echo -e "${BLUE}上传到S3...${NC}"
    aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/backups/"
  fi
  
  if [ -n "$SFTP_HOST" ]; then
    echo -e "${BLUE}上传到SFTP...${NC}"
    scp "$BACKUP_FILE" "$SFTP_USER@$SFTP_HOST:$SFTP_PATH"
  fi
fi
