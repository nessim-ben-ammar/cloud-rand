import requests
import sys


# After deployment copy the API ID of the AWS API Gateway
# The value is an output of the terraform deployment
api_id = ""
API_BASE_URL = f"https://{api_id}.execute-api.eu-central-1.amazonaws.com/v1/"

# Step 1: Request a random hex
hex_payload = {"length": 2, "count": 5}
hex_headers = {"Content-Type": "application/json"}
hex_resp = requests.post(f"{API_BASE_URL}/hex", json=hex_payload, headers=hex_headers)
print("/hex response:", hex_resp.status_code, hex_resp.text)

if not hex_resp.ok:
    print("Failed to get hex random number.")
    sys.exit(1)

try:
    data = hex_resp.json()
    record_id = data.get("record_id")
    if not record_id:
        print("No record_id in response.")
        sys.exit(1)
except Exception as e:
    print("Error parsing /hex response:", e)
    sys.exit(1)

# Step 2: Verify the record
verify_resp = requests.get(f"{API_BASE_URL}/verify", params={"record_id": record_id})
print("/verify response:", verify_resp.status_code, verify_resp.text)

# Step 3: Request a random int
int_payload = {"range_min": 1, "range_max": 10, "count": 3}
int_headers = {"Content-Type": "application/json"}
int_resp = requests.post(f"{API_BASE_URL}/int", json=int_payload, headers=int_headers)
print("/int response:", int_resp.status_code, int_resp.text)

if not int_resp.ok:
    print("Failed to get int random number.")
    sys.exit(1)

try:
    int_data = int_resp.json()
    int_record_id = int_data.get("record_id")
    if not int_record_id:
        print("No record_id in /int response.")
        sys.exit(1)
except Exception as e:
    print("Error parsing /int response:", e)
    sys.exit(1)

# Step 4: Verify the int record
verify_int_resp = requests.get(
    f"{API_BASE_URL}/verify", params={"record_id": int_record_id}
)
print("/verify (int) response:", verify_int_resp.status_code, verify_int_resp.text)
