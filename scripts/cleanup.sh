#!/bin/bash

# スタンプラリー デモサイト - ファイル整理スクリプト
# 定期的に実行してプロジェクトを整理します

set -e

# 色付きログ出力
log_info() {
    echo -e "\033[32m[INFO]\033[0m $1"
}

log_warn() {
    echo -e "\033[33m[WARN]\033[0m $1"
}

log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
}

# プロジェクトルートディレクトリに移動
cd "$(dirname "$0")/.."

log_info "ファイル整理を開始します..."

# 1. 一時的なJSONファイルをlogsフォルダに移動
log_info "一時的なJSONファイルを整理中..."
find . -maxdepth 1 -name "*.json" -not -path "./logs/*" -not -path "./backup/*" -not -name "package.json" | while read file; do
    if [ -f "$file" ]; then
        log_info "移動: $file -> logs/"
        mv "$file" logs/
    fi
done

# 2. 古いログファイルの削除（30日以上前）
log_info "古いログファイルを削除中..."
find logs/ -name "*.json" -mtime +30 -delete 2>/dev/null || true

# 3. 一時的なCloudFormationファイルをbackupに移動
log_info "古いCloudFormationテンプレートを整理中..."
find templates/ -name "cloudformation-*.yaml" -not -name "cloudformation.yaml" | while read file; do
    if [ -f "$file" ]; then
        log_info "移動: $file -> backup/"
        mv "$file" backup/
    fi
done

# 4. 空のディレクトリを削除
log_info "空のディレクトリを削除中..."
find . -type d -empty -delete 2>/dev/null || true

# 5. 不要なファイルの削除
log_info "不要なファイルを削除中..."
find . -name "*.tmp" -delete 2>/dev/null || true
find . -name "*.swp" -delete 2>/dev/null || true
find . -name "*~" -delete 2>/dev/null || true

# 6. ディスク使用量の確認
log_info "ディスク使用量を確認中..."
du -sh logs/ backup/ 2>/dev/null || true

# 7. 整理結果の表示
log_info "整理完了！"
echo ""
echo "📁 現在のフォルダ構造:"
echo "├── templates/cloudformation.yaml (メインテンプレート)"
echo "├── logs/ (ログファイル)"
echo "├── backup/ (バックアップファイル)"
echo "└── docs/ (ドキュメント)"
echo ""

# 8. 推奨事項の表示
if [ -d "logs" ] && [ "$(ls -A logs 2>/dev/null)" ]; then
    log_warn "logs/フォルダにファイルがあります。必要に応じて手動で削除してください。"
fi

if [ -d "backup" ] && [ "$(ls -A backup 2>/dev/null)" ]; then
    log_warn "backup/フォルダにファイルがあります。定期的に確認してください。"
fi

log_info "ファイル整理が完了しました！" 