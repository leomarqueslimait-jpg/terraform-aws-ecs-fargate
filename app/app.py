from flask import Flask, jsonify
import psycopg2
import os

app = Flask(__name__)

@app.route("/")
def home():
    return jsonify({"message": "Hello from ECS!"})

@app.route("/health")
def health():
    return jsonify({"status": "healthy"}), 200

@app.route("/db")
def db():
    try:
        conn = psycopg2.connect(os.environ["DATABASE_URL"])
        conn.close()
        return jsonify({"status": "database connected"})
    except Exception as e:
        return jsonify({"status": "database error", "error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)