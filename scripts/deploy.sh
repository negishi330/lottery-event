#!/bin/bash

# 抽選システム - デプロイスクリプト（SSL証明書含む）

set -e

# AWSプロファイル設定（第5引数として指定可能）
AWS_PROFILE=${5:-AdministratorAccess-320762959220}
export AWS_PROFILE

# 設定
STACK_NAME="LotteryEvent"
TEMPLATE_FILE="templates/cloudformation.yaml"
CERTIFICATE_TEMPLATE_FILE="templates/acm-certificate.yaml"
ENVIRONMENT=${1:-production}
REGION=${2:-ap-northeast-1}
SUB_DOMAIN_NAME=${3:-lottery-event}
HOSTED_ZONE_ID=${4:-Z074122126NSZDXJ4NTEO}

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

# ホストゾーンIDからドメイン名を取得
log_info "ホストゾーンIDからドメイン名を取得中..."
log_info "使用するAWSプロファイル: $AWS_PROFILE"
DOMAIN_NAME=$(aws route53 get-hosted-zone --id $HOSTED_ZONE_ID --region $REGION --query 'HostedZone.Name' --output text | tr -d '\n' | sed 's/\.$//')
if [ $? -ne 0 ] || [ -z "$DOMAIN_NAME" ]; then
    log_error "ホストゾーンID $HOSTED_ZONE_ID からドメイン名を取得できませんでした"
    exit 1
fi
log_info "取得されたドメイン名: $DOMAIN_NAME"

# 引数チェック
if [ "$ENVIRONMENT" != "development" ] && [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    log_error "環境は development, staging, production のいずれかを指定してください"
    exit 1
fi

if [ -z "$SUB_DOMAIN_NAME" ] || [ -z "$HOSTED_ZONE_ID" ]; then
    log_error "サブドメイン名、ホストゾーンIDを指定してください"
    echo "使用方法: $0 <environment> <region> <sub_domain_name> <hosted_zone_id> [aws_profile]"
    echo "例: $0 production ap-northeast-1 lottery-event Z074122126NSZDXJ4NTEO AdministratorAccess-320762959220"
    exit 1
fi

log_info "デプロイを開始します..."
log_info "環境: $ENVIRONMENT"
log_info "リージョン: $REGION"
log_info "ドメイン: $SUB_DOMAIN_NAME.$DOMAIN_NAME"
log_info "ホストゾーンID: $HOSTED_ZONE_ID"
log_info "スタック名: $STACK_NAME-$ENVIRONMENT"

# ACM証明書スタックの作成/更新
log_info "ACM証明書スタックを処理中..."
CERT_STACK_NAME="$STACK_NAME-certificate-$ENVIRONMENT"

# ACM証明書テンプレートの検証
log_info "ACM証明書テンプレートを検証中..."
aws cloudformation validate-template \
    --template-body file://$CERTIFICATE_TEMPLATE_FILE \
    --region us-east-1

if [ $? -eq 0 ]; then
    log_success "ACM証明書テンプレートの検証が完了しました"
else
    log_error "ACM証明書テンプレートの検証に失敗しました"
    exit 1
fi

# ACM証明書スタックの確認
CERT_STACK_EXISTS=$(aws cloudformation describe-stacks \
    --stack-name $CERT_STACK_NAME \
    --region us-east-1 \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "STACK_NOT_FOUND")

if [ "$CERT_STACK_EXISTS" != "STACK_NOT_FOUND" ]; then
    log_info "既存のACM証明書スタックが見つかりました: $CERT_STACK_EXISTS"
    log_info "ACM証明書スタックを更新します..."
    CERT_OPERATION="update-stack"
else
    log_info "新しいACM証明書スタックを作成します..."
    CERT_OPERATION="create-stack"
fi

# ACM証明書スタックのデプロイ
if [ "$CERT_OPERATION" = "create-stack" ]; then
    aws cloudformation create-stack \
        --stack-name $CERT_STACK_NAME \
        --template-body file://$CERTIFICATE_TEMPLATE_FILE \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME \
            ParameterKey=SubDomainName,ParameterValue=$SUB_DOMAIN_NAME \
            ParameterKey=HostedZoneId,ParameterValue=$HOSTED_ZONE_ID \
        --region us-east-1 \
        --tags \
            Key=Environment,Value=$ENVIRONMENT \
            Key=Project,Value=stamp-collection \
            Key=ManagedBy,Value=cloudformation
else
    log_info "ACM証明書スタックの更新を試行中..."
    if aws cloudformation update-stack \
        --stack-name $CERT_STACK_NAME \
        --template-body file://$CERTIFICATE_TEMPLATE_FILE \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME \
            ParameterKey=SubDomainName,ParameterValue=$SUB_DOMAIN_NAME \
            ParameterKey=HostedZoneId,ParameterValue=$HOSTED_ZONE_ID \
        --region us-east-1 \
        --tags \
            Key=Environment,Value=$ENVIRONMENT \
            Key=Project,Value=stamp-collection \
            Key=ManagedBy,Value=cloudformation 2>&1 | grep -q "No updates are to be performed"; then
        log_info "ACM証明書スタックに更新は不要です"
        CERT_OPERATION="skip-update"
    else
        log_success "ACM証明書スタックの更新が開始されました"
    fi
fi

if [ "$CERT_OPERATION" != "skip-update" ]; then
    if [ $? -eq 0 ]; then
        log_success "ACM証明書スタックのデプロイが開始されました"
    else
        log_error "ACM証明書スタックのデプロイに失敗しました"
        exit 1
    fi
fi

# ACM証明書スタックの完了を待機
if [ "$CERT_OPERATION" != "skip-update" ]; then
    log_info "ACM証明書スタックの完了を待機中..."
    if [ "$CERT_OPERATION" = "create-stack" ]; then
        aws cloudformation wait stack-create-complete \
            --stack-name $CERT_STACK_NAME \
            --region us-east-1
    else
        aws cloudformation wait stack-update-complete \
            --stack-name $CERT_STACK_NAME \
            --region us-east-1
    fi

    if [ $? -eq 0 ]; then
        log_success "ACM証明書スタックのデプロイが完了しました"
    else
        log_error "ACM証明書スタックのデプロイが失敗しました"
        exit 1
    fi
else
    log_success "ACM証明書スタックは既に最新です"
fi

# ACM証明書のARNを取得
log_info "ACM証明書のARNを取得中..."
CERTIFICATE_ARN=$(aws cloudformation describe-stacks \
    --stack-name $CERT_STACK_NAME \
    --region us-east-1 \
    --query 'Stacks[0].Outputs[?OutputKey==`CertificateArn`].OutputValue' \
    --output text)

if [ -z "$CERTIFICATE_ARN" ] || [ "$CERTIFICATE_ARN" = "None" ]; then
    log_error "ACM証明書のARNを取得できませんでした"
    exit 1
fi
log_info "取得された証明書ARN: $CERTIFICATE_ARN"

# CloudFormationテンプレートの検証
log_info "CloudFormationテンプレートを検証中..."
aws cloudformation validate-template \
    --template-body file://$TEMPLATE_FILE \
    --region $REGION

if [ $? -eq 0 ]; then
    log_success "テンプレートの検証が完了しました"
else
    log_error "テンプレートの検証に失敗しました"
    exit 1
fi

# 既存のスタックの確認
log_info "既存のスタックを確認中..."
STACK_EXISTS=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].StackStatus' \
    --output text 2>/dev/null || echo "STACK_NOT_FOUND")

if [ "$STACK_EXISTS" != "STACK_NOT_FOUND" ]; then
    log_info "既存のスタックが見つかりました: $STACK_EXISTS"
    log_info "スタックを更新します..."
    OPERATION="update-stack"
else
    log_info "新しいスタックを作成します..."
    OPERATION="create-stack"
fi

# CloudFormationスタックのデプロイ
log_info "CloudFormationスタックをデプロイ中..."

if [ "$OPERATION" = "create-stack" ]; then
    aws cloudformation create-stack \
        --stack-name $STACK_NAME-$ENVIRONMENT \
        --template-body file://$TEMPLATE_FILE \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME \
            ParameterKey=SubDomainName,ParameterValue=$SUB_DOMAIN_NAME \
            ParameterKey=HostedZoneId,ParameterValue=$HOSTED_ZONE_ID \
            ParameterKey=CertificateArn,ParameterValue=$CERTIFICATE_ARN \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION \
        --tags \
            Key=Environment,Value=$ENVIRONMENT \
            Key=Project,Value=stamp-collection \
            Key=ManagedBy,Value=cloudformation
else
    aws cloudformation update-stack \
        --stack-name $STACK_NAME-$ENVIRONMENT \
        --template-body file://$TEMPLATE_FILE \
        --parameters \
            ParameterKey=Environment,ParameterValue=$ENVIRONMENT \
            ParameterKey=DomainName,ParameterValue=$DOMAIN_NAME \
            ParameterKey=SubDomainName,ParameterValue=$SUB_DOMAIN_NAME \
            ParameterKey=HostedZoneId,ParameterValue=$HOSTED_ZONE_ID \
            ParameterKey=CertificateArn,ParameterValue=$CERTIFICATE_ARN \
        --capabilities CAPABILITY_NAMED_IAM \
        --region $REGION \
        --tags \
            Key=Environment,Value=$ENVIRONMENT \
            Key=Project,Value=stamp-collection \
            Key=ManagedBy,Value=cloudformation
fi

if [ $? -eq 0 ]; then
    log_success "CloudFormationスタックのデプロイが開始されました"
else
    log_error "CloudFormationスタックのデプロイに失敗しました"
    exit 1
fi

# スタックの完了を待機
log_info "スタックの完了を待機中..."
if [ "$OPERATION" = "create-stack" ]; then
    aws cloudformation wait stack-create-complete \
        --stack-name $STACK_NAME-$ENVIRONMENT \
        --region $REGION
else
    aws cloudformation wait stack-update-complete \
        --stack-name $STACK_NAME-$ENVIRONMENT \
        --region $REGION
fi

if [ $? -eq 0 ]; then
    log_success "CloudFormationスタックのデプロイが完了しました"
else
    log_error "CloudFormationスタックのデプロイが失敗しました"
    exit 1
fi

# 出力値の取得
log_info "出力値を取得中..."
WEBSITE_URL=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`WebsiteURL`].OutputValue' \
    --output text)

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

CERTIFICATE_ARN=$(aws cloudformation describe-stacks \
    --stack-name $STACK_NAME-$ENVIRONMENT \
    --region $REGION \
    --query 'Stacks[0].Outputs[?OutputKey==`CertificateArn`].OutputValue' \
    --output text)

log_success "デプロイが完了しました！"
echo ""
log_info "=== デプロイ結果 ==="
log_info "Website URL: $WEBSITE_URL"
log_info "S3 Bucket: $BUCKET_NAME"
log_info "CloudFront Distribution ID: $DISTRIBUTION_ID"
log_info "SSL Certificate ARN: $CERTIFICATE_ARN"
echo ""

# 証明書の検証状況を確認
log_info "SSL証明書の検証状況を確認中..."
CERT_STATUS=$(aws acm describe-certificate \
    --certificate-arn $CERTIFICATE_ARN \
    --region us-east-1 \
    --query 'Certificate.Status' \
    --output text)

if [ "$CERT_STATUS" = "ISSUED" ]; then
    log_success "SSL証明書が正常に発行されました"
else
    log_warn "SSL証明書のステータス: $CERT_STATUS"
    log_info "DNS検証が完了するまで数分かかる場合があります"
fi

# ファイルのアップロード
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
aws cloudfront create-invalidation \
    --distribution-id $DISTRIBUTION_ID \
    --paths "/*" \
    --region $REGION

if [ $? -eq 0 ]; then
    log_success "CloudFrontキャッシュの無効化が完了しました"
else
    log_warn "CloudFrontキャッシュの無効化に失敗しました"
fi

# 最終確認
log_info "デプロイの最終確認中..."
sleep 30

# サイトの動作確認
log_info "サイトの動作を確認中..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" $WEBSITE_URL || echo "000")

if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "301" ] || [ "$HTTP_STATUS" = "302" ]; then
    log_success "サイトが正常に動作しています (HTTP Status: $HTTP_STATUS)"
else
    log_warn "サイトの動作確認で問題が発生しました (HTTP Status: $HTTP_STATUS)"
fi

echo ""
log_success "デプロイが完了しました！"
log_info "サイトURL: $WEBSITE_URL"
log_info "SSL証明書の検証状況: $CERT_STATUS"
echo ""
log_info "セキュリティ設定の確認:"
log_info "./scripts/security-check.sh $ENVIRONMENT $REGION" 