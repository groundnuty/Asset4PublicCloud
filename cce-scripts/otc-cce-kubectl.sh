#this script invokes CCE API to configure local kubectl
#please ensure you have an existing cluster in your account#
########  Add your environment variable here #########
OS_USERNAME=$2
OS_TENANT_NAME=eu-de
OS_PROJECT_NAME=eu-de
OS_AUTH_URL=https://iam.eu-de.otc.t-systems.com/v3
OS_PASSWORD=$3
OS_USER_DOMAIN_NAME=$4
LANG=en_US.UTF-8
com=`echo $OS_AUTH_URL | awk -F '//iam.' '{print $2}' | awk -F '/v' '{print $1}'`
###################################
echo "get tenant_id and token"
#########  get tenant_id  #########
tenant_id=`curl -i -k -X POST https://iam.$com/v3/auth/tokens -H "Content-Type:application/json" -d "{\"auth\":{\"identity\":{\"methods\":[\"password\"],\"password\":{\"user\":{\"name\":\"$OS_USERNAME\",\"password\":\"$OS_PASSWORD\",\"domain\":{\"name\":\"$OS_USER_DOMAIN_NAME\"}}}},\"scope\":{\"project\":{\"name\":\"$OS_PROJECT_NAME\"}}}}" | awk -F '"id":"' '{print $2}' | awk -F '","' '{print $1}' | grep .`
echo "tenant_id is: $tenant_id"
#########  get token  #########
TOKEN=`curl -i -k -X POST https://iam.$com/v3/auth/tokens -H "Content-Type:application/json" -d "{\"auth\":{\"identity\":{\"methods\":[\"password\"],\"password\":{\"user\":{\"name\":\"$OS_USERNAME\",\"password\":\"$OS_PASSWORD\",\"domain\":{\"name\":\"$OS_USER_DOMAIN_NAME\"}}}},\"scope\":{\"project\":{\"name\":\"$OS_PROJECT_NAME\"}}}}" | grep X-Subject-Token: | awk -F  ':' '{print $2}' | grep .`
echo -e "get token:"
echo $TOKEN
#########  get app id  ####### 
USER=OS_USERNAME
CLUSTER_ID=$1
echo -e "CCE user: $USER"
echo -e "CCE cluster id: $CLUSTER_ID"
### get cluster credentials ###
echo "get credentials of cluster $2"
curl -v -k https://cce.$com/api/v1/clusters/$CLUSTER_ID/certificates -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" | jq -r .clientkey > clientkey.pem
curl -v -k https://cce.$com/api/v1/clusters/$CLUSTER_ID/certificates -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" | jq -r .cacrt > cacrt.pem
curl -v -k https://cce.$com/api/v1/clusters/$CLUSTER_ID/certificates -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" | jq -r .clientcrt > clientcrt.pem

CLUSTER_NAME=`curl -v -k https://cce.$com/api/v1/clusters/$CLUSTER_ID/certificates -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" | jq -r .cluster_name`
ENDPOINT=`curl -v -k https://cce.$com/api/v1/clusters/$CLUSTER_ID -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" | jq -r .spec.endpoint`

echo "scp the all *.pem files to the machine that has access to k8s endpoint $ENDPOINT"
echo "login into the machine, install kubectl"
echo "invoke commands below to get access"

echo kubectl config set-cluster "$CLUSTER_NAME" \
      --server="$ENDPOINT" \
      --certificate-authority=clientcrt.pem \ 
      --client-key=clientkey.pem \
      --client-certificate=clientcrt.pem \
      --cluster="$CLUSTER_NAME" \
      --user=$USER \

echo kubectl config set-cluster "$CLUSTER_NAME" --insecure-skip-tls-verify=true
echo kubectl config set-credentials $USER \
      --server="$ENDPOINT" \
      --certificate-authority=clientcrt.pem \
      --client-key=clientkey.pem \
      --client-certificate=clientcrt.pem \
      --cluster="$CLUSTER_NAME" \
      --user=$USER

echo kubectl config set-context "$CLUSTER_NAME" \
      --server="$ENDPOINT" \
      --certificate-authority=clientcrt.pem \
      --client-key=clientkey.pem \
      --client-certificate=clientcrt.pem \
      --cluster="$CLUSTER_NAME" \
      --user=$USER

echo kubectl config set current-context "$CLUSTER_NAME"
echo kubectl get nodes

### create rc ###
#curl -i -k -X POST https://cce.$com/api/v1/namespaces/default/replicationcontrollers -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" -H "X-Cluster-UUID:$2" -d "{\"metadata\":{\"name\":\"rc$1\",\"labels\":{\"cce\/appgroup\":\"app$1\"}},\"apiVersion\":\"v1\",\"kind\":\"ReplicationController\",\"spec\":{\"template\":{\"metadata\":{\"name\":\"rc$1\",\"labels\":{\"cce\/appgroup\":\"app$1\"}},\"spec\":{\"containers\":[{\"image\":\"nginx\",\"imagePullPolicy\":\"IfNotPresent\",\"name\":\"nginx\",\"ports\":[{\"protocol\":\"TCP\",\"containerPort\":80}]}]}},\"replicas\":2,\"selector\":{\"cce\/appgroup\":\"app$1\"}}}"
#curl -i -k -X POST https://cce.$com/api/v1/namespaces/default/services -H "Content-Type:application/json" -H "X-Auth-Token:$TOKEN" -H "X-Cluster-UUID:$2" -d "{\"metadata\":{\"name\":\"service$1\"},\"apiVersion\":\"v1\",\"kind\":\"Service\",\"spec\":{\"selector\":{\"cce\/appgroup\":\"app$1\"},\"type\":\"NodePort\",\"ports\":[{\"protocol\":\"TCP\",\"port\":80,\"targetPort\":80,\"nodePort\":3000$1}]}}"
