# GATEWAY with jwt key offloading

## Prepare jwt keys

Note: public key for lua lib must be in PEM format.

    bash scripts/keygen.sh develop/jwt_keys

## Docker Compose

    JWT_SECRET_KEY=$(cat develop/jwt_keys/public.pem) docker-compose up -d --build

## Test JWT token and cookies

    token=$(python ../echo_devops/scripts/jwt_token.py -k develop/jwt_keys/private.pem -u sensoradmin -r sensoradmin_role -o sensoradmin_org -t $((3600*24)) 2>/dev/null)
    curl -H "Authorization: Bearer ${token}" http://127.0.0.1:8080//something-without-blacklist/
    curl --cookie "jwt=${token}" http://127.0.0.1:8080//something-without-blacklist/

## Test JWT expired token

    token=$(python ../echo_devops/scripts/jwt_token.py -k develop/jwt_keys/private.pem -u sensoradmin -r sensoradmin_role -o sensoradmin_org -t 1 2>/dev/null)
    sleep 20
    curl -H "Authorization: Bearer ${token}" http://127.0.0.1:8080//something-without-blacklist/
    curl --cookie "jwt=${token}" http://127.0.0.1:8080//something-without-blacklist/
