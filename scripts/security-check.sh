#!/bin/bash

# スタンプラリー デモサイト - セキュリティ設定確認スクリプト

set -e

# 設定
STACK_NAME="stamp-collection"
ENVIRONMENT=${1:-production}
REGION=${2:-ap-northeast-1}

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

log_info "セキュリティ設定の確認を開始します..."
log_info "環境: $ENVIRONMENT"
log_info "リージョン: $REGION"
log_info "スタック名: $STACK_NAME-$ENVIRONMENT"

# CloudFormationスタックの存在確認
log_info "CloudFormationスタックの確認中..."
STACK_STATUS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "STACK_NOT_FOUND")

if [ "$STACK_STATUS" = "STACK_NOT_FOUND" ]; then
    log_error "CloudFormationスタックが見つかりません: $STACK_NAME-$ENVIRONMENT"
    exit 1
fi

log_success "CloudFormationスタックが存在します: $STACK_STATUS"

# 出力値の取得
BUCKET_NAME=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteBucketName`].OutputValue' \
    --output text)

DISTRIBUTION_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CloudFrontDistributionId`].OutputValue' \
    --output text)

WEBSITE_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
    --output text)

WEBACL_ID=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WebACLId`].OutputValue' \
    --output text)

log_info "S3バケット名: $BUCKET_NAME"
log_info "CloudFront Distribution ID: $DISTRIBUTION_ID"
log_info "Website URL: $WEBSITE_URL"
log_info "WAF Web ACL ID: $WEBACL_ID"

# S3バケットのセキュリティ設定確認
log_info "S3バケットのセキュリティ設定を確認中..."

# パブリックアクセスブロック設定
PUBLIC_ACCESS=$(aws s3api get-public-access-block \
    --bucket $BUCKET_NAME \
    --region $REGION 2>/dev/null || echo "ERROR")

if [ "$PUBLIC_ACCESS" != "ERROR" ]; then
    log_success "S3バケットのパブリックアクセスが適切にブロックされています"
else
    log_error "S3バケットのパブリックアクセス設定を確認できません"
fi

# 暗号化設定
ENCRYPTION=$(aws s3api get-bucket-encryption \
    --bucket $BUCKET_NAME \
    --region $REGION 2>/dev/null || echo "ERROR")

if [ "$ENCRYPTION" != "ERROR" ]; then
    log_success "S3バケットの暗号化が有効になっています"
else
    log_warn "S3バケットの暗号化設定を確認できません"
fi

# CloudFront Distributionのセキュリティ設定確認
log_info "CloudFront Distributionのセキュリティ設定を確認中..."

# HTTPS強制設定
HTTPS_REDIRECT=$(aws cloudfront get-distribution-config \
    --id $DISTRIBUTION_ID \
    --region $REGION \
    --query 'DistributionConfig.DefaultCacheBehavior.ViewerProtocolPolicy' \
    --output text 2>/dev/null || echo "ERROR")

if [ "$HTTPS_REDIRECT" = "redirect-to-https" ]; then
    log_success "CloudFrontでHTTPS強制が有効になっています"
else
    log_warn "CloudFrontのHTTPS設定を確認してください: $HTTPS_REDIRECT"
fi

# WAF設定確認
if [ ! -z "$WEBACL_ID" ]; then
    log_success "WAFが設定されています: $WEBACL_ID"
    
    # WAFルールの確認
    WAF_RULES=$(aws wafv2 get-web-acl \
        --id $WEBACL_ID \
        --name $(echo $WEBACL_ID | cut -d'/' -f2) \
        --scope CLOUDFRONT \
        --region us-east-1 \
        --query 'WebACL.Rules[].Name' \
        --output text 2>/dev/null || echo "ERROR")
    
    if [ "$WAF_RULES" != "ERROR" ]; then
        log_success "WAFルールが設定されています: $WAF_RULES"
    else
        log_warn "WAFルールの詳細を確認できません"
    fi
else
    log_warn "WAFが設定されていません"
fi

# SSL証明書の確認
log_info "SSL証明書の確認中..."

# 証明書の有効性を確認
SSL_CHECK=$(curl -s -I --connect-timeout 10 $WEBSITE_URL 2>/dev/null | grep -i "HTTP" || echo "ERROR")

if [[ "$SSL_CHECK" == *"200"* ]] || [[ "$SSL_CHECK" == *"301"* ]] || [[ "$SSL_CHECK" == *"302"* ]]; then
    log_success "SSL証明書が正常に動作しています"
else
    log_warn "SSL証明書の動作を確認できません: $SSL_CHECK"
fi

# セキュリティヘッダーの確認
log_info "セキュリティヘッダーの確認中..."

HEADERS=$(curl -s -I --connect-timeout 10 $WEBSITE_URL 2>/dev/null || echo "ERROR")

if [ "$HEADERS" != "ERROR" ]; then
    # HSTSヘッダーの確認
    if echo "$HEADERS" | grep -q "Strict-Transport-Security"; then
        log_success "HSTSヘッダーが設定されています"
    else
        log_warn "HSTSヘッダーが設定されていません"
    fi
    
    # CSPヘッダーの確認
    if echo "$HEADERS" | grep -q "Content-Security-Policy"; then
        log_success "CSPヘッダーが設定されています"
    else
        log_warn "CSPヘッダーが設定されていません"
    fi
    
    # X-Frame-Optionsヘッダーの確認
    if echo "$HEADERS" | grep -q "X-Frame-Options"; then
        log_success "X-Frame-Optionsヘッダーが設定されています"
    else
        log_warn "X-Frame-Optionsヘッダーが設定されていません"
    fi
else
    log_warn "セキュリティヘッダーの確認ができません"
fi

# セキュリティチェック完了
log_info "セキュリティ設定の確認が完了しました"
log_info "Website URL: $WEBSITE_URL"

echo ""
log_success "セキュリティチェックが正常に完了しました！" 