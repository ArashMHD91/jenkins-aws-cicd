from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return f"Hello from Jenkins CI/CD! Version: {os.getenv('APP_VERSION', '1.0')}"

@app.route('/health')
def health():
    return {"status": "healthy"}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)