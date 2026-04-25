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

@app.route("/stress")                                    # ← add here
def stress():
    result = sum(i * i for i in range(1000000))
    return jsonify({"result": result, "status": "done"})

@app.route("/db")
def db():
    try:
        conn = psycopg2.connect(
            host=os.environ["DB_HOST"],
            dbname=os.environ["DB_NAME"],
            user=os.environ["DB_USER"],
            port=os.environ["DB_PORT"],
            password=os.environ["DB_PASSWORD"]
        )
        conn.close()
        return jsonify({"status": "database connected"})
    except Exception as e:
        return jsonify({"status": "database error", "error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)