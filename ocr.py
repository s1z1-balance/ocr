from flask import Flask, request, jsonify
import easyocr
import numpy as np
from PIL import Image
import cv2
import io
import os
app = Flask(__name__)
reader = easyocr.Reader(['en'], gpu=True)
DEBUG_DIR = "debug_captcha"
os.makedirs(DEBUG_DIR, exist_ok=True)
counter = [0]
def preprocess(img_pil):
    counter[0] += 1
    n = counter[0]
    img = np.array(img_pil.convert('RGB'))
    img_pil.save(f"{DEBUG_DIR}/{n}_1_original.png")
    gray = cv2.cvtColor(img, cv2.COLOR_RGB2GRAY)
    cv2.imwrite(f"{DEBUG_DIR}/{n}_2_gray.png", gray)
    # агрессивное удаление шума
    denoised = cv2.fastNlMeansDenoising(gray, h=25, templateWindowSize=7, searchWindowSize=21)
    cv2.imwrite(f"{DEBUG_DIR}/{n}_3_denoised.png", denoised)
    # размытие чтобы убить пиксельный паттерн фона
    blurred = cv2.GaussianBlur(denoised, (3, 3), 0)
    cv2.imwrite(f"{DEBUG_DIR}/{n}_4_blurred.png", blurred)
    # адаптивная бинаризация — лучше работает на неравномерном фоне
    binary = cv2.adaptiveThreshold(
        blurred, 255,
        cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
        cv2.THRESH_BINARY,
        blockSize=31,
        C=10
    )
    cv2.imwrite(f"{DEBUG_DIR}/{n}_5_binary.png", binary)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (2, 2))
    closed = cv2.morphologyEx(binary, cv2.MORPH_CLOSE, kernel)
    cv2.imwrite(f"{DEBUG_DIR}/{n}_6_final.png", closed)
    return closed
@app.route('/ocr', methods=['POST'])
def ocr():
    img = Image.open(io.BytesIO(request.data))
    processed = preprocess(img)
    results = reader.readtext(
        processed,
        detail=1,
        allowlist='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    )
    print("\n--- OCR Results ---")
    for bbox, text, conf in results:
        print(f"  text='{text}' conf={conf:.2f} bbox={bbox}")
    text = "".join([t for _, t, c in results if c > 0.2]).strip()
    print(f"  final='{text}'")
    print("-------------------\n")
    return jsonify({"text": text, "detail": [{"text": t, "conf": round(c, 2)} for _, t, c in results]})
if __name__ == '__main__':
    app.run(port=8765)
