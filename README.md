# terraform-prototype-k8s-graylog
Graylog with Elasticsearch & MongoDB, on docker-desktop kubernetes (tested on Mac M1)

## Setup Ingress Controller

Kubernetes on Docker desktop does not come pre-installed with an ingress controller.
Follow the steps below to set it up.

Apply the controller configs
```bash
kubectl config use-context docker-desktop
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.6.4/deploy/static/provider/cloud/deploy.yaml
```

Wait for the ingress controller pod to be running
```bash
kubectl -n ingress-nginx get pod

deepak@Deepaks-MBP-2 terraform-prototype-k8s-mongo % kubectl -n ingress-nginx get pod
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-56l8s        0/1     Completed   0          37s
ingress-nginx-admission-patch-ptsns         0/1     Completed   0          37s
ingress-nginx-controller-6f79748cff-hcwhq   1/1     Running     0          37s
```

Ingress is now ready.


## Install

```
terraform init
terraform plan
terraform apply
```

Graylog can be accessed through the ingress at http://graylog.local, by adding the host entry
```
127.0.0.1   graylog.local
```

