#!/bin/bash

CA_CERT=/usr/share/elasticsearch/config/certs/ca/ca.crt

if [ x${ELASTIC_PASSWORD} == x ]; then
   echo "Set the ELASTIC_PASSWORD environment variable in the .env file";
   exit 1;
elif [ x${KIBANA_PASSWORD} == x ]; then
   echo "Set the KIBANA_PASSWORD environment variable in the .env file";
   exit 1;
fi;
if [ ! -f config/certs/ca.zip ]; then
   echo "Creating CA";
   bin/elasticsearch-certutil ca --silent --pem -out config/certs/ca.zip;
   unzip config/certs/ca.zip -d config/certs;
fi;
if [ ! -f config/certs/certs.zip ]; then
   echo "Creating certs";
   bin/elasticsearch-certutil cert --silent --pem -out config/certs/certs.zip --in /usr/share/elasticsearch/instances.yml --ca-cert config/certs/ca/ca.crt --ca-key config/certs/ca/ca.key;
   unzip config/certs/certs.zip -d config/certs;
fi;
echo "Setting file permissions"
chown -R root:root config/certs;
find . -type d -exec chmod 750 \{\} \;;
find . -type f -exec chmod 640 \{\} \;;

echo "Waiting for Elasticsearch availability";
until curl -s --cacert config/certs/ca/ca.crt -u "elastic:${ELASTIC_PASSWORD}" https://elasticsearch:9200/_cat/health | grep -i "green"; do sleep 10; done;

echo "Setting kibana_system password";
until curl -s -X POST --cacert $CA_CERT -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" https://elasticsearch:9200/_security/user/kibana_system/_password -d "{\"password\":\"${KIBANA_PASSWORD}\"}" | grep -q "^{}"; do sleep 10; done;

# echo "Creating test.user user"
# res=`curl -s -X PUT --cacert $CA_CERT -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" https://elasticsearch:9200/_security/user/test.user -d '{"full_name": "Test User", "roles": ["superuser"], "password": "abcd1234"}'`
# if [[ $res != *'"created":true'* ]]; then
#     echo "test.user user creation failed -" $res
# fi

# sleep 30
# echo "Loading Kibana sample ecommerce data"
# res=`curl -s -X POST --cacert $CA_CERT -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" -H "kbn-xsrf: reporting" https://kibana:5601/api/sample_data/ecommerce`
# echo $res

# echo "Creating super-role";
# res=`curl -s -X PUT --cacert $CA_CERT -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" https://elasticsearch:9200/_security/role/superrole -d '{"cluster": ["all"],"indices": [{"names": ["*.*"],"privileges": ["all"],"allow_restricted_indices": true}],"applications": [{"application": "kibana-.kibana","privileges": ["all"],"resources": ["*"]}]}'`
# if [[ $res != *'"created":true'* ]]; then
#     echo "Super-role creation failed -" $res
# fi

# echo "Creating super-role-user";
# res=`curl -s -X PUT --cacert $CA_CERT -u "elastic:${ELASTIC_PASSWORD}" -H "Content-Type: application/json" https://elasticsearch:9200/_security/user/superuser -d '{"full_name": "Super User", "roles": ["superrole"], "password": "abcd1234"}'`
# if [[ $res != *'"created":true'* ]]; then
#     echo "Super-user creation failed -" $res
# fi

# sleep 30;
# echo "Setting Kibana dark mode"
# curl -s -X PUT --cacert $CA_CERT -u "superuser:abcd1234" -H "Content-Type: application/json" https://elasticsearch:9200/.kibana/_doc/config:${STACK_VERSION} -d '{"config": {"theme:darkMode": true}}'

# sleep 30;
# echo "Creating example agent policy"
# curl -s -X POST --cacert $CA_CERT -u "elastic:${ELASTIC_PASSWORD}" --header 'Content-Type: application/json' --header 'kbn-xsrf: xxx' 'https://kibana:5601/api/fleet/agent_policies?sys_monitoring=true' -d '{"name":"Example agent policy","description":"","id":"example-agent-policy","namespace":"default","monitoring_enabled":["logs","metrics"]}'

# echo "Getting enrollment token for agent"
# curl -s -X GET --cacert $CA_CERT -u "elastic:${ELASTIC_PASSWORD}" --header 'Content-Type: application/json' --header 'kbn-xsrf: xxx' 'https://kibana:5601/api/fleet/enrollment_api_keys' | sed 's/",/\n/g' | grep example-agent-policy -B2 -m1 | grep api_key | cut -d ":" -f2 | sed 's/"//g' > config/certs/elastic-agent.yml
# echo -n 'fleet.access_api_key: ' | cat - config/certs/elastic-agent.yml > temp && mv temp config/certs/elastic-agent.yml
# cat config/certs/elastic-agent.yml
# curl -s -X GET --cacert $CA_CERT -u "elastic:${ELASTIC_PASSWORD}" --header 'Content-Type: application/json' --header 'kbn-xsrf: xxx' 'https://kibana:5601/api/fleet/enrollment_api_keys' | sed 's/",/\n/g' | grep example-agent-policy -B2 -m1 | grep api_key | cut -d ":" -f2 | sed 's/"//g'