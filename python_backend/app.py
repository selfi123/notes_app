import os
from datetime import datetime, timezone
from typing import Optional

import boto3
import requests
from botocore.config import Config
from flask import Flask, jsonify, request
from google.auth.transport.requests import Request as GoogleAuthRequest
from google.oauth2 import service_account
from urllib.parse import quote

app = Flask(__name__)

# ─── Configuration (set in PythonAnywhere Web tab → Environment variables) ───
R2_ACCOUNT_ID = os.environ.get('R2_ACCOUNT_ID', '')
R2_ACCESS_KEY_ID = os.environ.get('R2_ACCESS_KEY_ID', '')
R2_SECRET_ACCESS_KEY = os.environ.get('R2_SECRET_ACCESS_KEY', '')
R2_BUCKET_NAME = os.environ.get('R2_BUCKET_NAME', 'notes')
API_SECRET_KEY = os.environ.get('API_SECRET_KEY', 'voicecard-secure-api-key-2026')
SERVICE_ACCOUNT_FILE = os.environ.get(
    'GOOGLE_SERVICE_ACCOUNT_FILE',
    'notesdrop-501016-eb935592f1ad.json',
)
PLAY_PACKAGE_NAME = os.environ.get('PLAY_PACKAGE_NAME', 'com.krpdev.voicecard')
PLAY_SUBSCRIPTION_IDS = os.environ.get(
    'PLAY_SUBSCRIPTION_IDS',
    'premium_monthly,premium_yearly',
).split(',')
ALLOWED_SUBSCRIPTION_IDS = {
    sub_id.strip() for sub_id in PLAY_SUBSCRIPTION_IDS if sub_id.strip()
}

# Subscription states where the user still has access until expiryTime.
PREMIUM_SUBSCRIPTION_STATES = {
    'SUBSCRIPTION_STATE_ACTIVE',
    'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
    'SUBSCRIPTION_STATE_CANCELED',
    'SUBSCRIPTION_STATE_PENDING_PURCHASE_CANCELED',
}

s3_client = boto3.client(
    's3',
    endpoint_url=f'https://{R2_ACCOUNT_ID}.r2.cloudflarestorage.com',
    aws_access_key_id=R2_ACCESS_KEY_ID,
    aws_secret_access_key=R2_SECRET_ACCESS_KEY,
    config=Config(signature_version='s3v4'),
    region_name='auto',
)


def verify_api_key():
    client_key = request.headers.get('x-api-key')
    return client_key == API_SECRET_KEY


def get_google_access_token():
    if not os.path.exists(SERVICE_ACCOUNT_FILE):
        raise FileNotFoundError(
            f'Google service account file not found: {SERVICE_ACCOUNT_FILE}. '
            'Upload the JSON key next to app.py or set GOOGLE_SERVICE_ACCOUNT_FILE.'
        )
    credentials = service_account.Credentials.from_service_account_file(
        SERVICE_ACCOUNT_FILE,
        scopes=['https://www.googleapis.com/auth/androidpublisher'],
    )
    auth_request = GoogleAuthRequest()
    credentials.refresh(auth_request)
    return credentials.token


def _google_play_get(path: str):
    token = get_google_access_token()
    url = f'https://androidpublisher.googleapis.com/androidpublisher/v3/{path}'
    response = requests.get(
        url,
        headers={
            'Authorization': f'Bearer {token}',
            'Accept': 'application/json',
        },
        timeout=20,
    )
    return response


def fetch_subscription_v2(package_name: str, purchase_token: str) -> dict:
    encoded_package = quote(package_name, safe='')
    encoded_token = quote(purchase_token, safe='')
    response = _google_play_get(
        f'applications/{encoded_package}/purchases/subscriptionsv2/tokens/{encoded_token}'
    )
    if response.status_code == 200:
        return response.json()
    if response.status_code == 404:
        raise ValueError('Purchase token not found or invalid.')
    raise RuntimeError(
        f'Google Play subscriptionsv2 failed: {response.status_code} {response.text}'
    )


def fetch_subscription_v1(
    package_name: str,
    subscription_id: str,
    purchase_token: str,
) -> dict:
    encoded_package = quote(package_name, safe='')
    encoded_subscription = quote(subscription_id, safe='')
    encoded_token = quote(purchase_token, safe='')
    response = _google_play_get(
        f'applications/{encoded_package}/purchases/subscriptions/'
        f'{encoded_subscription}/tokens/{encoded_token}'
    )
    if response.status_code == 200:
        return response.json()
    if response.status_code == 404:
        raise ValueError('Purchase token not found or invalid.')
    raise RuntimeError(
        f'Google Play subscription v1 failed: {response.status_code} {response.text}'
    )


def _parse_rfc3339(value: str) -> datetime:
    return datetime.fromisoformat(value.replace('Z', '+00:00'))


def evaluate_subscription_v2(data: dict, expected_product_id: Optional[str] = None) -> dict:
    state = data.get('subscriptionState', '')
    now = datetime.now(timezone.utc)
    best_expiry = None
    matched_product = None
    auto_renewing = False

    for item in data.get('lineItems', []):
        product_id = item.get('productId')
        expiry_raw = item.get('expiryTime')
        if not product_id or not expiry_raw:
            continue
        if expected_product_id and product_id != expected_product_id:
            continue
        if product_id not in ALLOWED_SUBSCRIPTION_IDS:
            continue

        expiry = _parse_rfc3339(expiry_raw)
        if best_expiry is None or expiry > best_expiry:
            best_expiry = expiry
            matched_product = product_id
            auto_renewing = item.get('autoRenewingPlan') is not None

    is_premium = (
        state in PREMIUM_SUBSCRIPTION_STATES
        and best_expiry is not None
        and best_expiry > now
    )

    return {
        'valid': is_premium,
        'isPremium': is_premium,
        'productId': matched_product,
        'expiresAt': best_expiry.isoformat() if best_expiry else None,
        'expiresAtMillis': int(best_expiry.timestamp() * 1000) if best_expiry else None,
        'subscriptionState': state,
        'autoRenewing': auto_renewing,
        'source': 'subscriptionsv2',
    }


def evaluate_subscription_v1(data: dict, expected_product_id: str) -> dict:
    now_ms = int(datetime.now(timezone.utc).timestamp() * 1000)
    expiry_ms = int(data.get('expiryTimeMillis', 0))
    payment_state = data.get('paymentState')
    cancel_reason = data.get('cancelReason')

    # paymentState: 0=pending, 1=received, 2=free trial, 3=pending deferred upgrade/downgrade
    payment_ok = payment_state in (1, 2, 3)
    is_premium = payment_ok and expiry_ms > now_ms

    return {
        'valid': is_premium,
        'isPremium': is_premium,
        'productId': expected_product_id,
        'expiresAt': datetime.fromtimestamp(
            expiry_ms / 1000, tz=timezone.utc
        ).isoformat(),
        'expiresAtMillis': expiry_ms,
        'subscriptionState': 'ACTIVE' if is_premium else 'EXPIRED',
        'autoRenewing': bool(data.get('autoRenewing')),
        'cancelReason': cancel_reason,
        'source': 'subscriptionsv1',
    }


def verify_android_subscription(
    package_name: str,
    product_id: str,
    purchase_token: str,
) -> dict:
    try:
        v2_data = fetch_subscription_v2(package_name, purchase_token)
        result = evaluate_subscription_v2(v2_data, expected_product_id=product_id)
        if result['isPremium']:
            return result
        # Fall through to v1 if v2 didn't confirm premium (some legacy setups).
    except ValueError:
        raise
    except Exception:
        pass

    v1_data = fetch_subscription_v1(package_name, product_id, purchase_token)
    return evaluate_subscription_v1(v1_data, product_id)


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
        result = verify_android_subscription(package_name, product_id, purchase_token)
        status_code = 200 if result['valid'] else 400
        return jsonify(result), status_code
    except ValueError as exc:
        return jsonify({'valid': False, 'isPremium': False, 'error': str(exc)}), 400
    except FileNotFoundError as exc:
        return jsonify({'valid': False, 'isPremium': False, 'error': str(exc)}), 500
    except Exception as exc:
        return jsonify({'valid': False, 'isPremium': False, 'error': str(exc)}), 500


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
            Params={
                'Bucket': R2_BUCKET_NAME,
                'Key': object_key,
                'ContentType': 'audio/mp4',
            },
            ExpiresIn=3600,
        )
        return jsonify({'url': presigned_url, 'key': object_key})
    except Exception as exc:
        return jsonify({'error': str(exc)}), 500


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
            ExpiresIn=3600,
        )
        return jsonify({'url': presigned_url, 'key': object_key})
    except Exception as exc:
        return jsonify({'error': str(exc)}), 500


@app.route('/delete-audio', methods=['POST'])
def delete_audio():
    if not verify_api_key():
        return jsonify({'error': 'Unauthorized. Invalid API Key.'}), 401

    data = request.get_json(silent=True)
    object_key = data.get('key') if data else None

    if not object_key:
        return jsonify({'error': 'Missing key parameter'}), 400

    try:
        s3_client.delete_object(Bucket=R2_BUCKET_NAME, Key=object_key)
        return jsonify({'success': True, 'message': 'Deleted successfully'})
    except Exception as exc:
        return jsonify({'error': str(exc)}), 500


application = app

if __name__ == '__main__':
    app.run(debug=True, port=5000)
