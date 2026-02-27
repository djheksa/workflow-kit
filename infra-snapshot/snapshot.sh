#!/bin/bash
# AWS 인프라 스냅샷 수집 스크립트
# 주기적으로 실행되어 로컬 파일에 인프라 정보를 덤프

set -euo pipefail
export PATH="/usr/local/bin:/opt/homebrew/bin:$PATH"

OUTPUT_FILE="/tmp/infra-snapshot.md"
STATUS_FILE="/tmp/infra-snapshot-status.json"
REGION="ap-northeast-2"

update_status() {
  echo "{\"state\":\"$1\",\"phase\":\"$2\",\"updated\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > "$STATUS_FILE"
}

update_status "running" "starting"

{
echo "# AWS 인프라 스냅샷"
echo "마지막 업데이트: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. ECS 클러스터/서비스
update_status "running" "ecs"
echo "## ECS 클러스터/서비스"
echo ""
echo "| 클러스터 | 서비스 | Task Definition | 컨테이너 |"
echo "|---------|--------|----------------|---------|"

for cluster_arn in $(aws ecs list-clusters --region $REGION --output text --query 'clusterArns[]' 2>/dev/null); do
  cluster=$(echo "$cluster_arn" | awk -F/ '{print $NF}')
  for svc_arn in $(aws ecs list-services --cluster "$cluster" --region $REGION --output text --query 'serviceArns[]' 2>/dev/null); do
    svc=$(echo "$svc_arn" | awk -F/ '{print $NF}')
    td_arn=$(aws ecs describe-services --cluster "$cluster" --services "$svc" --region $REGION --query 'services[0].taskDefinition' --output text 2>/dev/null)
    td=$(echo "$td_arn" | awk -F/ '{print $NF}')

    containers=$(aws ecs describe-task-definition --task-definition "$td" --region $REGION --output json 2>/dev/null | \
      python3 -c "
import sys,json
data=json.load(sys.stdin)['taskDefinition']
parts=[]
for c in data['containerDefinitions']:
    ports=','.join([str(p['containerPort']) for p in c.get('portMappings',[])])
    img=c['image'].split('/')[-1].split(':')[0]
    parts.append(f\"{c['name']}({ports})\")
print(' / '.join(parts))
" 2>/dev/null || echo "?")

    echo "| $cluster | $svc | $td | $containers |"
  done
done
echo ""

# 2. Route53 도메인
update_status "running" "route53"
echo "## 도메인 (Route53)"
echo ""
echo "| 도메인 | 타입 | 대상 |"
echo "|-------|------|------|"

for zone_id in $(aws route53 list-hosted-zones --output text --query 'HostedZones[].Id' 2>/dev/null); do
  aws route53 list-resource-record-sets --hosted-zone-id "$zone_id" --output json 2>/dev/null | \
    python3 -c "
import sys,json
data=json.load(sys.stdin)
for r in data['ResourceRecordSets']:
    name=r['Name'].rstrip('.')
    rtype=r['Type']
    if rtype in ('A','CNAME') and not name.startswith('_'):
        alias=r.get('AliasTarget',{}).get('DNSName','').rstrip('.')
        values=[v.get('Value','') for v in r.get('ResourceRecords',[])]
        target=alias or ', '.join(values)
        if target:
            # 짧게 표시
            if 'cloudfront' in target: target='CloudFront: '+target.split('.')[0]
            elif 'elb.amazonaws' in target: target='ALB: '+target.split('.')[0]
            print(f'| {name} | {rtype} | {target} |')
" 2>/dev/null
done
echo ""

# 3. ALB 라우팅
update_status "running" "alb"
echo "## ALB 라우팅 규칙"
echo ""

for lb_arn in $(aws elbv2 describe-load-balancers --region $REGION --output text --query 'LoadBalancers[].LoadBalancerArn' 2>/dev/null); do
  lb_name=$(echo "$lb_arn" | awk -F/ '{print $(NF-1)}')
  echo "### $lb_name"
  echo ""
  echo "| 우선순위 | 조건 | 대상 |"
  echo "|---------|------|------|"

  for listener_arn in $(aws elbv2 describe-listeners --load-balancer-arn "$lb_arn" --region $REGION --output text --query 'Listeners[?Protocol==`HTTPS`].ListenerArn' 2>/dev/null); do
    aws elbv2 describe-rules --listener-arn "$listener_arn" --region $REGION --output json 2>/dev/null | \
      python3 -c "
import sys,json
data=json.load(sys.stdin)
for r in data['Rules']:
    conds=[]
    for c in r.get('Conditions',[]):
        if 'HostHeaderConfig' in c: conds.append('Host:'+','.join(c['HostHeaderConfig']['Values']))
        if 'PathPatternConfig' in c: conds.append('Path:'+','.join(c['PathPatternConfig']['Values']))
    actions=[]
    for a in r['Actions']:
        if a['Type']=='forward':
            tgs=a.get('ForwardConfig',{}).get('TargetGroups',[]) or [{'TargetGroupArn':a.get('TargetGroupArn','')}]
            for tg in tgs:
                actions.append(tg['TargetGroupArn'].split('/')[-2] if '/' in tg['TargetGroupArn'] else '?')
        else: actions.append(a['Type'])
    cond_str=' & '.join(conds) if conds else 'default'
    print(f'| {r[\"Priority\"]} | {cond_str} | {\", \".join(actions)} |')
" 2>/dev/null
  done
  echo ""
done

# 4. CloudFront 배포
update_status "running" "cloudfront"
echo "## CloudFront 배포"
echo ""
echo "| 도메인 | Origin | 주요 경로 패턴 |"
echo "|-------|--------|--------------|"

aws cloudfront list-distributions --output json 2>/dev/null | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for d in data.get('DistributionList',{}).get('Items',[]):
    aliases=d.get('Aliases',{}).get('Items',[])
    alias_str=', '.join(aliases) if aliases else d['DomainName']
    origins=[o['DomainName'].split('.')[0] for o in d['Origins']['Items']]
    paths=[cb.get('PathPattern','') for cb in d.get('CacheBehaviors',{}).get('Items',[])][:3]
    path_str=', '.join(paths) if paths else 'default only'
    print(f'| {alias_str} | {\", \".join(origins)} | {path_str} |')
" 2>/dev/null
echo ""

# 5. nginx 라우팅 (로컬 파일에서 추출)
update_status "running" "nginx"
# NGINX_CONF: 환경변수 NGINX_CONF_PATH로 설정하거나 기본값 사용
NGINX_CONF="${NGINX_CONF_PATH:-}"
if [ -f "$NGINX_CONF" ]; then
  echo "## Nginx 라우팅 (default.conf.template)"
  echo ""
  echo "| 경로 패턴 | 프록시 대상 |"
  echo "|----------|-----------|"
  grep -E "location" "$NGINX_CONF" | grep -v "#" | while read -r line; do
    pattern=$(echo "$line" | sed 's/.*location[^/]*//' | sed 's/{.*//' | xargs)
    echo "| \`$pattern\` | (다음 proxy_pass 참조) |"
  done
  echo ""
fi

# 6. CodeBuild 파이프라인
update_status "running" "codebuild"
echo "## CodeBuild 프로젝트"
echo ""
echo "| 프로젝트 | 소스 | 트리거 |"
echo "|---------|------|--------|"

for project in $(aws codebuild list-projects --region $REGION --output text --query 'projects[]' 2>/dev/null); do
  source_type=$(aws codebuild batch-get-projects --names "$project" --region $REGION --query 'projects[0].source.type' --output text 2>/dev/null)
  webhook=$(aws codebuild batch-get-projects --names "$project" --region $REGION --query 'projects[0].webhook.filterGroups[0][0].pattern' --output text 2>/dev/null || echo "None")
  echo "| $project | $source_type | $webhook |"
done
echo ""

# 7. RDS 인스턴스
update_status "running" "rds"
echo "## RDS 인스턴스"
echo ""
echo "| 인스턴스 | 엔진 | 클래스 | 스토리지 | 엔드포인트 | 상태 |"
echo "|---------|------|--------|---------|-----------|------|"

aws rds describe-db-instances --region $REGION --output json 2>/dev/null | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for db in data['DBInstances']:
    name=db['DBInstanceIdentifier']
    engine=db['Engine']+' '+db.get('EngineVersion','')
    cls=db['DBInstanceClass']
    storage=str(db.get('AllocatedStorage',''))+'GB'
    endpoint=db.get('Endpoint',{}).get('Address','')
    port=str(db.get('Endpoint',{}).get('Port',''))
    status=db['DBInstanceStatus']
    ep_short=endpoint.split('.')[0] if endpoint else '-'
    print(f'| {name} | {engine} | {cls} | {storage} | {ep_short}:{port} | {status} |')
" 2>/dev/null
echo ""

# 8. ElastiCache 클러스터
update_status "running" "elasticache"
echo "## ElastiCache 클러스터"
echo ""
echo "| 클러스터 | 엔진 | 노드 타입 | 노드 수 | 엔드포인트 | 상태 |"
echo "|---------|------|----------|---------|-----------|------|"

aws elasticache describe-cache-clusters --region $REGION --show-cache-node-info --output json 2>/dev/null | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for c in data['CacheClusters']:
    name=c['CacheClusterId']
    engine=c['Engine']+' '+c.get('EngineVersion','')
    node_type=c['CacheNodeType']
    num_nodes=str(c['NumCacheNodes'])
    status=c['CacheClusterStatus']
    ep=c.get('ConfigurationEndpoint',{})
    if not ep:
        nodes=c.get('CacheNodes',[])
        ep_str=nodes[0]['Endpoint']['Address'].split('.')[0]+':'+str(nodes[0]['Endpoint']['Port']) if nodes else '-'
    else:
        ep_str=ep.get('Address','').split('.')[0]+':'+str(ep.get('Port',''))
    print(f'| {name} | {engine} | {node_type} | {num_nodes} | {ep_str} | {status} |')
" 2>/dev/null

aws elasticache describe-replication-groups --region $REGION --output json 2>/dev/null | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for rg in data.get('ReplicationGroups',[]):
    name=rg['ReplicationGroupId']
    status=rg['Status']
    members=', '.join(rg.get('MemberClusters',[]))
    ep=rg.get('NodeGroups',[{}])[0].get('PrimaryEndpoint',{})
    ep_str=(ep.get('Address','').split('.')[0]+':'+str(ep.get('Port',''))) if ep else '-'
    print(f'| {name} (ReplicationGroup) | redis | - | {len(rg.get(\"MemberClusters\",[]))} nodes | {ep_str} | {status} |')
" 2>/dev/null
echo ""

# 9. S3 버킷
update_status "running" "s3"
echo "## S3 버킷"
echo ""
echo "| 버킷 | 생성일 |"
echo "|------|--------|"

aws s3api list-buckets --output json 2>/dev/null | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for b in data['Buckets']:
    name=b['Name']
    created=b['CreationDate'][:10]
    print(f'| {name} | {created} |')
" 2>/dev/null
echo ""

# 10. ECR 리포지토리
update_status "running" "ecr"
echo "## ECR 리포지토리"
echo ""
echo "| 리포지토리 | 이미지 수 | 최신 태그 |"
echo "|-----------|----------|----------|"

for repo in $(aws ecr describe-repositories --region $REGION --output text --query 'repositories[].repositoryName' 2>/dev/null); do
  img_count=$(aws ecr describe-images --repository-name "$repo" --region $REGION --output text --query 'length(imageDetails)' 2>/dev/null || echo "0")
  latest_tag=$(aws ecr describe-images --repository-name "$repo" --region $REGION --output json --query 'sort_by(imageDetails, &imagePushedAt)[-1].imageTags[0]' 2>/dev/null || echo "-")
  echo "| $repo | $img_count | $latest_tag |"
done
echo ""

# 11. SES 설정
update_status "running" "ses"
echo "## SES 이메일"
echo ""
echo "| Identity | 타입 | 상태 |"
echo "|----------|------|------|"

aws sesv2 list-email-identities --region $REGION --output json 2>/dev/null | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for i in data.get('EmailIdentities',[]):
    name=i['IdentityName']
    itype=i['IdentityType']
    verified='verified' if i.get('SendingEnabled') else 'not verified'
    print(f'| {name} | {itype} | {verified} |')
" 2>/dev/null
echo ""

# 12. Parameter Store / Secrets Manager
update_status "running" "params"
echo "## Parameter Store (이름만)"
echo ""
echo "| 파라미터 | 타입 |"
echo "|---------|------|"

aws ssm describe-parameters --region $REGION --output json 2>/dev/null | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for p in data.get('Parameters',[]):
    name=p['Name']
    ptype=p['Type']
    print(f'| {name} | {ptype} |')
" 2>/dev/null
echo ""

echo "## Secrets Manager (이름만)"
echo ""
echo "| 시크릿 | 설명 |"
echo "|--------|------|"

aws secretsmanager list-secrets --region $REGION --output json 2>/dev/null | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
for s in data.get('SecretList',[]):
    name=s['Name']
    desc=s.get('Description','')[:50]
    print(f'| {name} | {desc} |')
" 2>/dev/null
echo ""

} > "$OUTPUT_FILE" 2>/dev/null

update_status "idle" "done"
