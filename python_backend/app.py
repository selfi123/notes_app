import os
import boto3
import requests
from urllib.parse import quote
from flask import Flask, request, jsonify
from botocore.config import Config
from google.oauth2 import service_account
from google.auth.transport.requests import Request as GoogleAuthRequest

app = Flask(__name__)

# Configuration: You can set these in PythonAnywhere's Web tab as Environment Variables
# Or paste them directly here since PythonAnywhere files are private.
R2_ACCOUNT_ID = os.environ.get('R2_ACCOUNT_ID', 'YOUR_R2_ACCOUNT_ID_HERE')
R2_ACCESS_KEY_ID = os.environ.get('R2_ACCESS_KEY_ID', 'YOUR_ACCESS_KEY_HERE')
R2_SECRET_ACCESS_KEY = os.environ.get('R2_SECRET_ACCESS_KEY', 'YOUR_SECRET_KEY_HERE')
R2_BUCKET_NAME = os.environ.get('R2_BUCKET_NAME', 'notes')
API_SECRET_KEY = os.environ.get('API_SECRET_KEY', 'voicecard-secure-api-key-2026')
SERVICE_ACCOUNT_FILE = os.environ.get('GOOGLE_SERVICE_ACCOUNT_FILE', 'service_account.json')
PLAY_PACKAGE_NAME = os.environ.get('PLAY_PACKAGE_NAME', 'com.krpdev.voicecard')
PLAY_SUBSCRIPTION_IDS = os.environ.get('PLAY_SUBSCRIPTION_IDS', 'premium_monthly,premium_yearly').split(',')
ALLOWED_SUBSCRIPTION_IDS = {sub_id.strip() for sub_id in PLAY_SUBSCRIPTION_IDS if sub_id.strip()}

# Simple API Key protection to ensure random people can't hit your backend

# Initialize boto3 client for Cloudflare R2
s3_client = boto3.client(
    's3',
    endpoint_url=f"https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com",
    aws_access_key_id=R2_ACCESS_KEY_ID,
    aws_secret_access_key=R2_SECRET_ACCESS_KEY,
    config=Config(signature_version='s3v4'),
    region_name='auto'
)

def verify_api_key():
    client_key = request.headers.get('x-api-key')
    if client_key != API_SECRET_KEY:
        return False
    return True


def get_google_access_token():
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        raise FileNotFoundError(
            'Google service account file not found. Set GOOGLE_SERVICE_ACCOUNT_FILE or upload service_account.json.'
        )
    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=['https://www.googleapis.com/auth/androidpublisher'],
    )
    auth_request = GoogleAuthRequest()
    credentials.refresh(auth_request)
    return credentials.token


def verify_android_subscription(package_name: str, subscription_id: str, purchase_token: str):
    token = get_google_access_token()
    encoded_package = quote(package_name, safe='')
    encoded_subscription = quote(subscription_id, safe='')
    encoded_token = quote(purchase_token, safe='')
    url = (
        f'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'
        f'{encoded_package}/purchases/subscriptions/{encoded_subscription}/tokens/{encoded_token}'
    )
    headers = {
        'Authorization': f'Bearer {token}',
        'Accept': 'application/json',
    }
    response = requests.get(url, headers=headers, timeout=20)
    if response.status_code == 200:
        return response.json()
    if response.status_code == 404:
        raise ValueError('Purchase token not found or invalid.')
    raise RuntimeError(
        f'Google Play validation failed: {response.status_code} {response.text}'
    )


@app.route('/verify-subscription', methods=['POST'])
def verify_subscription():
    if not verify_api_key():
        return jsonify({'error': 'Unauthorized. Invalid API Key.'}), 401

    data = request.get_json(silent=True)
    if not data:
        return jsonify({'error': 'Request body must be valid JSON.'}), 400

    package_name = data.get('packageName') or PLAY_PACKAGE_NAME
    product_id = data.get('productId')
    purchase_token = data.get('purchaseToken')

    if not product_id or not purchase_token:
        return jsonify({'error': 'Missing productId or purchaseToken.'}), 400

    if package_name != PLAY_PACKAGE_NAME:
        return jsonify({'error': 'Invalid packageName.'}), 400

    if product_id not in ALLOWED_SUBSCRIPTION_IDS:
        return jsonify({'error': 'Invalid productId.'}), 400

    try:
        verification_response = verify_android_subscription(package_name, product_id, purchase_token)
        return jsonify({
            'valid': True,
            'verification': verification_response,
        })
    except ValueError as ve:
        return jsonify({'valid': False, 'error': str(ve)}), 400
    except Exception as e:
        return jsonify({'valid': False, 'error': str(e)}), 500


@app.route('/generate-upload-url', methods=['GET'])
def generate_upload_url():
    if not verify_api_key():
        return jsonify({'error': 'Unauthorized. Invalid API Key.'}), 401
        
    object_key = request.args.get('key')
    if not object_key:
        return jsonify({'error': 'Missing key parameter'}), 400
        
    try:
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={'Bucket': R2_BUCKET_NAME, 'Key': object_key},
            ExpiresIn=3600 # URL valid for 1 hour
        )
        return jsonify({'url': presigned_url, 'key': object_key})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/generate-download-url', methods=['GET'])
def generate_download_url():
    if not verify_api_key():
        return jsonify({'error': 'Unauthorized. Invalid API Key.'}), 401
        
    object_key = request.args.get('key')
    if not object_key:
        return jsonify({'error': 'Missing key parameter'}), 400
        
    try:
        presigned_url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': R2_BUCKET_NAME, 'Key': object_key},
            ExpiresIn=3600 # URL valid for 1 hour
        )
        return jsonify({'url': presigned_url, 'key': object_key})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/delete-audio', methods=['POST'])
def delete_audio():
    if not verify_api_key():
        return jsonify({'error': 'Unauthorized. Invalid API Key.'}), 401
        
    data = request.get_json()
    object_key = data.get('key') if data else None
    
    if not object_key:
        return jsonify({'error': 'Missing key parameter'}), 400
        
    try:
        s3_client.delete_object(Bucket=R2_BUCKET_NAME, Key=object_key)
        return jsonify({'success': True, 'message': 'Deleted successfully'})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# Required for PythonAnywhere WSGI
application = app

if __name__ == '__main__':
    app.run(debug=True, port=5000)
