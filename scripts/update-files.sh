#!/bin/bash

# スタンプラリー デモサイト - ファイル更新スクリプト

set -e

# AWSプロファイル設定（第4引数として指定可能）
AWS_PROFILE=${4:-default}
export AWS_PROFILE

# 設定
ENVIRONMENT=${1:-production}
REGION=${2:-ap-northeast-1}
STACK_NAME=${3:-StampCollection}

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

log_success() {
    echo -e "\033[36m[SUCCESS]\033[0m $1"
}

# 引数チェック
if [ "$ENVIRONMENT" != "development" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    log_error "環境は development, staging, production のいずれかを指定してください"
    exit 1
fi

log_info "ファイル更新を開始します..."
log_info "環境: $ENVIRONMENT"
log_info "リージョン: $REGION"
log_info "スタック名: $STACK_NAME-$ENVIRONMENT"
log_info "使用するAWSプロファイル: $AWS_PROFILE"

# CloudFormationスタックから情報を取得
log_info "CloudFormationスタックから情報を取得中..."

# S3バケット名を取得
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucketName`].OutputValue' \
    --output text)

if [ -z "$BUCKET_NAME" ] || [ "$BUCKET_NAME" = "None" ]; then
    log_error "S3バケット名を取得できませんでした"
    exit 1
fi
log_info "S3バケット: $BUCKET_NAME"

# CloudFront Distribution IDを取得
DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text)

if [ -z "$DISTRIBUTION_ID" ] || [ "$DISTRIBUTION_ID" = "None" ]; then
    log_error "CloudFront Distribution IDを取得できませんでした"
    exit 1
fi
log_info "CloudFront Distribution ID: $DISTRIBUTION_ID"

# 静的ファイルをS3にアップロード
log_info "静的ファイルをS3にアップロード中..."
aws s3 sync src/ s3://$BUCKET_NAME/ \
    --delete \
    --region $REGION

if [ $? -eq 0 ]; then
    log_success "ファイルのアップロードが完了しました"
else
    log_error "ファイルのアップロードに失敗しました"
    exit 1
fi

# CloudFrontキャッシュの無効化
log_info "CloudFrontキャッシュを無効化中..."
INVALIDATION_ID=$(aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/*" \
    --region $REGION \
    --query 'Invalidation.Id' \
    --output text)

if [ $? -eq 0 ]; then
    log_success "CloudFrontキャッシュの無効化が開始されました (ID: $INVALIDATION_ID)"
else
    log_warn "CloudFrontキャッシュの無効化に失敗しました"
fi

# 無効化の完了を待機
log_info "CloudFrontキャッシュの無効化完了を待機中..."
aws cloudfront wait invalidation-completed \
    --distribution-id $DISTRIBUTION_ID \
    --id $INVALIDATION_ID \
    --region $REGION

if [ $? -eq 0 ]; then
    log_success "CloudFrontキャッシュの無効化が完了しました"
else
    log_warn "CloudFrontキャッシュの無効化の完了確認に失敗しました"
fi

# 完了メッセージ
log_success "ファイル更新が完了しました！"
echo ""
log_info "=== 更新結果 ==="
log_info "S3バケット: $BUCKET_NAME"
log_info "CloudFront Distribution ID: $DISTRIBUTION_ID"
log_info "キャッシュ無効化ID: $INVALIDATION_ID"
echo ""

# 使用方法を表示
echo "使用方法: $0 <environment> <region> <stack_name> [aws_profile]"
echo "例: $0 production ap-northeast-1 StampCollection AdministratorAccess-727682995566" 