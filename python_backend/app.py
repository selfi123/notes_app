import os
import boto3
from flask import Flask, request, jsonify
from botocore.config import Config

app = Flask(__name__)

# Configuration: You can set these in PythonAnywhere's Web tab as Environment Variables
# Or paste them directly here since PythonAnywhere files are private.
R2_ACCOUNT_ID = os.environ.get('R2_ACCOUNT_ID', 'YOUR_R2_ACCOUNT_ID_HERE')
R2_ACCESS_KEY_ID = os.environ.get('R2_ACCESS_KEY_ID', 'YOUR_ACCESS_KEY_HERE')
R2_SECRET_ACCESS_KEY = os.environ.get('R2_SECRET_ACCESS_KEY', 'YOUR_SECRET_KEY_HERE')
R2_BUCKET_NAME = os.environ.get('R2_BUCKET_NAME', 'notes')

# Simple API Key protection to ensure random people can't hit your backend
API_SECRET_KEY = os.environ.get('API_SECRET_KEY', 'voicecard-secure-api-key-2026')

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
