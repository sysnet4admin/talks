# 인공지능 에이전트로 관리하는 쿠버네티스 신세계

## 발표 정보
- **행사명**: Cloud Native Korea Community Day 2025
- **발표 제목**: 인공지능 에이전트로 관리하는 쿠버네티스 신세계
- **발표 형식**: AI 에이전트 기반 Kubernetes 라이브 데모
- **핵심 컨셉**: 아이언맨의 자비스와 같은 AI 어시스턴트로 Kubernetes 관리

## 발표 배경 및 목적
쿠버네티스를 사용하고 관리하기 위해서는 다양한 명령어를 필수적으로 알아야 합니다. 예를 들면 kubectl같은 것을 말이죠.

물론 이것에 대한 이해가 없이 사용하기는 어렵지만 때때로는:
- 자세한 명령이 기억이 안 날 수도 있고
- 이미 알지만 다소 번거로운 반복적인 작업들을 AI가 도와줬으면 하는 때가 있습니다
- 아이언맨의 자비스와 같은 존재가 말이죠

현재의 AI 기술로 이와 같은 기능을 구현하고 사용하는 것은 매우 쉬워졌습니다.

**특별한 세션 진행 방식**: 초반 간단한 설명 외에 모든 것을 청중의 요청을 받아 라이브로 진행!

## 환경 설정

### 필수 도구
```bash
# AWS CLI 설치 및 설정
aws --version
aws configure

# kubectl 설치
kubectl version --client

# eksctl 설치
eksctl version

# Helm 설치 (필요시)
helm version
```

### 일반적인 EKS 명령어

#### 클러스터 관리
```bash
# 클러스터 생성
eksctl create cluster --name demo-cluster --region ap-northeast-2 --nodegroup-name workers --node-type t3.medium --nodes 2

# 클러스터 목록 조회
eksctl get cluster

# kubectl 컨텍스트 설정
aws eks update-kubeconfig --region ap-northeast-2 --name demo-cluster

# 클러스터 삭제
eksctl delete cluster --name demo-cluster --region ap-northeast-2
```

#### 노드 그룹 관리
```bash
# 노드 그룹 생성
eksctl create nodegroup --cluster=demo-cluster --name=new-workers --node-type=t3.large --nodes=3

# 노드 그룹 조회
eksctl get nodegroup --cluster=demo-cluster

# 노드 그룹 스케일링
eksctl scale nodegroup --cluster=demo-cluster --name=workers --nodes=5
```

#### 기본 kubectl 명령어
```bash
# 노드 상태 확인
kubectl get nodes

# 파드 조회
kubectl get pods --all-namespaces

# 서비스 조회
kubectl get svc --all-namespaces

# 네임스페이스 조회
kubectl get namespaces
```

## AI 에이전트가 도움을 줄 수 있는 시나리오

### 1. 기억이 안 나는 명령어들
- "특정 네임스페이스의 파드만 보고 싶은데 명령어가 뭐였지?"
- "파드 로그를 실시간으로 보려면?"
- "서비스 계정 생성하는 YAML 형식이 어떻게 되지?"
- "Ingress에서 SSL 설정은 어떻게 하지?"

### 2. 반복적이고 번거로운 작업들
- 여러 네임스페이스에 동일한 리소스 배포
- 복잡한 YAML 파일 생성 및 검증
- 트러블슈팅을 위한 다양한 리소스 상태 확인
- 모니터링 설정 및 대시보드 구성

### 3. 복잡한 설정 및 관리
- 클러스터 설정 및 네트워킹
- 보안 정책 및 RBAC 설정
- 오토스케일링 구성
- 백업 및 복구 전략

### 4. 트러블슈팅 및 디버깅
- 파드가 시작되지 않을 때 원인 분석
- 네트워크 연결 문제 해결
- 리소스 부족 문제 해결
- 성능 최적화

### 5. 베스트 프랙티스 적용
- 보안 강화 방안
- 효율적인 리소스 사용
- CI/CD 파이프라인 구성
- 모니터링 및 알람 설정

## 데모 시나리오 예제

### 기본 앱 배포
```yaml
# sample-app.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sample-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sample-app
  template:
    metadata:
      labels:
        app: sample-app
    spec:
      containers:
      - name: app
        image: nginx:latest
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: sample-app-service
spec:
  selector:
    app: sample-app
  ports:
  - port: 80
    targetPort: 80
  type: LoadBalancer
```

### 배포 명령어
```bash
kubectl apply -f sample-app.yaml
kubectl get pods
kubectl get svc
```

## 트러블슈팅 명령어

### 일반적인 디버깅
```bash
# 파드 로그 확인
kubectl logs <pod-name>

# 파드 상세 정보
kubectl describe pod <pod-name>

# 이벤트 확인
kubectl get events --sort-by='.lastTimestamp'

# 클러스터 상태 확인
kubectl cluster-info

# 리소스 사용량 확인
kubectl top nodes
kubectl top pods
```

## AI 에이전트 활용 시 주요 장점

### 1. 학습 곡선 단축
- 복잡한 명령어를 외우지 않아도 자연어로 요청 가능
- 실수를 줄이고 더 안전한 작업 수행
- 단계별 가이드와 설명 제공

### 2. 효율성 향상
- 반복 작업 자동화
- 여러 명령어를 조합한 복잡한 워크플로우 처리
- 실시간 문제 해결 지원

### 3. 베스트 프랙티스 적용
- 보안 및 성능 최적화 권장사항 제공
- 업계 표준에 맞는 설정 가이드
- 지속적인 개선 제안

## 라이브 데모 진행 방식

1. **청중 질문 접수**: 실시간으로 Kubernetes 관련 질문 받기
2. **AI 에이전트 활용**: 자연어 요청을 통한 문제 해결
3. **실제 실행**: 제안된 솔루션을 라이브로 실행
4. **결과 확인**: 작업 결과를 함께 확인하며 학습

### 예상 라이브 시나리오 예시
- "개발 환경용 MySQL을 배포하고 외부에서 접근할 수 있게 해주세요"
- "파드가 계속 재시작되는 문제를 해결해주세요"
- "특정 애플리케이션의 CPU 사용량이 높을 때 자동으로 스케일링되게 하려면?"
- "보안을 강화하기 위한 네트워크 정책을 만들어주세요"

## 세션 후 기대효과
- Kubernetes 명령어에 대한 부담감 해소
- AI 도구를 활용한 효율적인 클러스터 관리 방법 습득
- 실무에서 바로 활용할 수 있는 실전 경험 획득
- 아이언맨의 자비스처럼 똑똑한 AI 어시스턴트 활용법 체득

## 주의사항
- 데모용 리소스는 비용 절약을 위해 세션 후 정리
- 실제 운영 환경과 다른 설정일 수 있음을 명시
- 질문에 따라 실시간으로 리소스 생성/삭제 가능
- AI 도구는 보조 역할이며, Kubernetes에 대한 기본 이해는 여전히 중요

## 참고 링크
- [AWS EKS 공식 문서](https://docs.aws.amazon.com/eks/)
- [eksctl 공식 문서](https://eksctl.io/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [Claude Code 공식 문서](https://docs.anthropic.com/claude-code)