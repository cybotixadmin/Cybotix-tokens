#!/bin/sh
## Requires openssl, nodejs, jq, pem-jwk
## mkdir keys
## cd keys
## npm init
## npm install pem-jwk
## npm install jq
## FIXES for jwt.io compliance
# use base64Url encoding
# use echo -n in pack function

## create the data access request token for sending the users browser and be picked up the Cybotix plugin
# 1. create the header
# 2. create the payload
# 3. create the signature
# 4. create the JWT
# 5. create the JWK
# 6. export the JWT
# 7. export the JWK
##


header='{
  "alg": "HS256",
  "typ": "JWT"
}'

payload='{
  "sub": "https://www.vendor.com/",
  "aud": "cybotix-personal-data-commander",
  "requestdetails":{"messagetext":"Can we see your click history for the past hour?","clickhistory":{"filter":".*top.*"}},
  "exp": 1735689600,
  "nbf": 1563980400,
  "iat": 1563980400
}'

echo $payload

function pack() {
  # Remove line breaks and spaces
  echo $1 | sed -e "s/[\r\n]\+//g" | sed -e "s/ //g"
}

function base64url_encode {
  (if [ -z "$1" ]; then cat -; else echo -n "$1"; fi) |
    openssl base64 -e -A |
      sed s/\\+/-/g |
      sed s/\\//_/g |
      sed -E s/=+$//
}

# just for debugging
function base64url_decode {
  INPUT=$(if [ -z "$1" ]; then echo -n $(cat -); else echo -n "$1"; fi)
  MOD=$(($(echo -n "$INPUT" | wc -c) % 4))
  PADDING=$(if [ $MOD -eq 2 ]; then echo -n '=='; elif [ $MOD -eq 3 ]; then echo -n '=' ; fi)
  echo -n "$INPUT$PADDING" |
    sed s/-/+/g |
    sed s/_/\\//g |
    openssl base64 -d -A
}


# Base64 Encoding
b64_header=$(pack "$header" | base64url_encode)
b64_payload=$(pack "$payload" | base64url_encode)
signature=$(echo -n $b64_header.$b64_payload | openssl dgst -sha256 -sign client.privatekey.pem | base64url_encode)


# Export JWT
echo $b64_header.$b64_payload.$signature > data.access.request.jwt.txt
# Create JWK from public key
if [ ! -d ./node_modules/pem-jwk ]; then
  # A tool to convert PEM to JWK
  npm install pem-jwk
fi

jwk=$(./node_modules/.bin/pem-jwk public-key.pem)
# Add additional fields
jwk=$(echo '{"use":"sig"}' $jwk $header | jq -cs add)
# Export JWK
echo '{"keys":['$jwk']}'| jq . > jwks.json

echo "--- JWT ---"
cat jwt.txt
echo -e "\n--- JWK ---"
jq . jwks.json

