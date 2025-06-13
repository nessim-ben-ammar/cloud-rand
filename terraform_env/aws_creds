#!/bin/sh
set -e

AWS_DIR="$HOME/.aws"
AWS_CRED_FILE="$AWS_DIR/credentials"

if [ ! -f "$AWS_CRED_FILE" ]; then
    mkdir -p "$AWS_DIR"
    echo "AWS credentials not found. Please enter your credentials:"
    echo -n "AWS Access Key ID: "
    read AWS_ACCESS_KEY_ID
    echo -n "AWS Secret Access Key: "
    read -s AWS_SECRET_ACCESS_KEY
    echo
    echo -n "Default region name [us-east-1]: "
    read AWS_DEFAULT_REGION
    AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION:-us-east-1}
    cat > "$AWS_CRED_FILE" <<EOF
[default]
aws_access_key_id = $AWS_ACCESS_KEY_ID
aws_secret_access_key = $AWS_SECRET_ACCESS_KEY
region = $AWS_DEFAULT_REGION
EOF
    chmod 600 "$AWS_CRED_FILE"
    echo "Credentials saved to $AWS_CRED_FILE."
else
    echo "AWS credentials found."
fi

exec "$@"
