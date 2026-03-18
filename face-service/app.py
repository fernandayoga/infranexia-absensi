from turtle import distance

from flask import Flask, request, jsonify
from flask_cors import CORS
from deepface import DeepFace
import os
import base64
import numpy as np
from PIL import Image
import io
import tempfile
import cv2

app = Flask(__name__)
CORS(app)

# ===== HEALTH CHECK =====
@app.route('/', methods=['GET'])
def index():
    return jsonify({'message': 'Face Recognition Service is running 🚀'})

# ← Tambahkan fungsi helper ini di atas route
def load_image_as_numpy(image_path):
    img = cv2.imread(image_path)
    if img is None:
        img = np.array(Image.open(image_path).convert('RGB'))
        img = cv2.cvtColor(img, cv2.COLOR_RGB2BGR)
    else:
        img = np.array(img)
    return img


# ===== COMPARE FACE =====
@app.route('/compare', methods=['POST'])
def compare_face():
    try:
        data = request.get_json()

        live_image_base64 = data.get('live_image')
        stored_image_path = data.get('stored_image_path')

        if not live_image_base64 or not stored_image_path:
            return jsonify({'match': False, 'message': 'Data tidak lengkap'}), 400

        if not os.path.exists(stored_image_path):
            return jsonify({'match': False, 'message': 'Foto referensi tidak ditemukan'}), 404

        # Decode base64 → simpan sebagai file temporary
        live_image_bytes = base64.b64decode(live_image_base64)
        live_image = Image.open(io.BytesIO(live_image_bytes)).convert('RGB')

        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp:
            live_image.save(tmp.name, 'JPEG', quality=85)
            tmp_path = tmp.name

        # ← Preprocess foto dari DB juga
        stored_image = Image.open(stored_image_path).convert('RGB')
        with tempfile.NamedTemporaryFile(suffix='.jpg', delete=False) as tmp2:
            stored_image.save(tmp2.name, 'JPEG', quality=85)
            tmp2_path = tmp2.name

        # Preprocess kedua gambar ke numpy dulu
        img1 = load_image_as_numpy(tmp_path)
        img2 = load_image_as_numpy(tmp2_path)

        cv2.imwrite(tmp_path, img1)
        cv2.imwrite(tmp2_path, img2)

        try:
            result = DeepFace.verify(
                img1_path=tmp_path,
                img2_path=tmp2_path,  # ← pakai tmp2_path bukan stored_image_path
                model_name='Facenet',
                enforce_detection=False,
                distance_metric='cosine',
                detector_backend='opencv'
            )

            is_match = result['verified']
            distance = result['distance']
            threshold = result['threshold']

            # Threshold ketat
            STRICT_THRESHOLD = 0.20
            if distance > STRICT_THRESHOLD:
                is_match = False

            confidence = round((1 - distance) * 100, 2)

            print(f'=== COMPARE RESULT ===')
            print(f'Match: {is_match}')
            print(f'Distance: {distance:.4f}')
            print(f'Threshold: {threshold:.4f}')
            print(f'Confidence: {confidence}%')

            return jsonify({
                'match': is_match,
                'confidence': confidence,
                'distance': float(distance),
                'threshold': float(threshold),
                'message': 'Wajah cocok!' if is_match else 'Wajah tidak cocok'
            })

        finally:
            # Hapus kedua temp file
            if os.path.exists(tmp_path):
                os.unlink(tmp_path)
            if os.path.exists(tmp2_path):
                os.unlink(tmp2_path)
            # Bersihkan memori
            import gc
            gc.collect()

    except Exception as e:
        print(f'Full error: {str(e)}')
        import traceback
        traceback.print_exc()

        if 'Face could not be detected' in str(e):
            return jsonify({
                'match': False,
                'message': 'Wajah tidak terdeteksi'
            }), 400

        return jsonify({
            'match': False,
            'message': f'Server error: {str(e)}'
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)