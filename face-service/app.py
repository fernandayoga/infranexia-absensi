from flask import Flask, request, jsonify
from flask_cors import CORS
from deepface import DeepFace
import os
import base64
import numpy as np
from PIL import Image
import io
import tempfile

app = Flask(__name__)
CORS(app)

# ===== HEALTH CHECK =====
@app.route('/', methods=['GET'])
def index():
    return jsonify({'message': 'Face Recognition Service is running 🚀'})

# ===== COMPARE FACE =====
@app.route('/compare', methods=['POST'])
def compare_face():
    try:
        data = request.get_json()

        live_image_base64 = data.get('live_image')
        stored_image_path = data.get('stored_image_path')

        if not live_image_base64 or not stored_image_path:
            return jsonify({
                'match': False,
                'message': 'Data tidak lengkap'
            }), 400

        if not os.path.exists(stored_image_path):
            return jsonify({
                'match': False,
                'message': 'Foto referensi tidak ditemukan'
            }), 404

        # Decode base64 → simpan sebagai file temporary
        live_image_bytes = base64.b64decode(live_image_base64)
        live_image = Image.open(io.BytesIO(live_image_bytes)).convert('RGB')

        # Simpan ke temp file
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp:
            live_image.save(tmp.name)
            tmp_path = tmp.name

        try:
            # Bandingkan wajah menggunakan DeepFace
            result = DeepFace.verify(
                img1_path=tmp_path,
                img2_path=stored_image_path,
                model_name='VGG-Face',  # bisa diganti: Facenet, ArcFace
                enforce_detection=True,
                distance_metric='cosine'
            )

            is_match = result['verified']
            distance = result['distance']
            threshold = result['threshold']
            confidence = round((1 - distance) * 100, 2)

            return jsonify({
                'match': is_match,
                'confidence': confidence,
                'distance': float(distance),
                'threshold': float(threshold),
                'message': 'Wajah cocok!' if is_match else 'Wajah tidak cocok'
            })

        finally:
            # Hapus temp file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)

    except Exception as e:
        print(f'Error: {e}')
        # Kalau tidak ada wajah terdeteksi
        if 'Face could not be detected' in str(e):
            return jsonify({
                'match': False,
                'message': 'Wajah tidak terdeteksi, pastikan pencahayaan cukup'
            }), 400

        return jsonify({
            'match': False,
            'message': f'Server error: {str(e)}'
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)