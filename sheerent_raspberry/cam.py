from flask import Flask, send_file, jsonify, request
from picamera2 import Picamera2
from time import sleep
import io
import cv2
import RPi.GPIO as GPIO

app = Flask(__name__)

# ===== GPIO 설정 =====
SERVO_PIN = 18       # 서보 모터 핀
RED_LED_PIN = 23     # 닫힘 상태 LED
GREEN_LED_PIN = 24   # 열림 상태 LED

GPIO.setmode(GPIO.BCM)
GPIO.setup(SERVO_PIN, GPIO.OUT)
GPIO.setup(RED_LED_PIN, GPIO.OUT)
GPIO.setup(GREEN_LED_PIN, GPIO.OUT)

servo = GPIO.PWM(SERVO_PIN, 50)  # 50Hz PWM
servo.start(0)

def open_door():
    print("문 열기")
    servo.ChangeDutyCycle(7.5)  # 열린 위치
    GPIO.output(RED_LED_PIN, GPIO.LOW)
    GPIO.output(GREEN_LED_PIN, GPIO.HIGH)
    sleep(1)
    servo.ChangeDutyCycle(0)  # 서보 안정화

def close_door():
    print("문 닫기")
    servo.ChangeDutyCycle(2.5)  # 닫힌 위치
    GPIO.output(GREEN_LED_PIN, GPIO.LOW)
    GPIO.output(RED_LED_PIN, GPIO.HIGH)
    sleep(1)
    servo.ChangeDutyCycle(0)

# ===== 카메라 설정 =====
picam = Picamera2()
picam.configure(picam.create_still_configuration())

@app.route('/shoot', methods=['GET'])
def shoot():
    try:
        picam.start()
        sleep(2)
        frame = picam.capture_array()
        picam.stop()

        is_success, buffer = cv2.imencode(".jpg", frame)
        if not is_success:
            return jsonify({"error": "Image encoding failed"}), 500

        io_buf = io.BytesIO(buffer.tobytes())
        return send_file(io_buf, mimetype='image/jpeg')

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# ===== 문 제어 API =====
@app.route('/open', methods=['POST'])
def open_route():
    open_door()
    return jsonify({"status": "opened"})

@app.route('/close', methods=['POST'])
def close_route():
    close_door()
    return jsonify({"status": "closed"})

if __name__ == "__main__":
    try:
        # 서버 시작 시 기본 상태: 문 닫힘, 빨간 LED ON, 초록 LED OFF
        print("초기 상태: 문 닫힘")
        servo.ChangeDutyCycle(2.5)  # 닫힌 위치
        GPIO.output(GREEN_LED_PIN, GPIO.LOW)
        GPIO.output(RED_LED_PIN, GPIO.HIGH)
        sleep(1)
        servo.ChangeDutyCycle(0)  # 서보 안정화

        app.run(host='0.0.0.0', port=8000)
    finally:
        GPIO.cleanup()
