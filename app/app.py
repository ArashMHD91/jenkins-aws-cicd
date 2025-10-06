from flask import Flask
import os

app = Flask(__name__)

@app.route('/')
def hello():
    return f"Hello from Jenkins CI/CD! Version: 5.0"  # Changed from 4.0 to 5.0

@app.route('/health')
def health():
    return {"status": "healthy"}, 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
