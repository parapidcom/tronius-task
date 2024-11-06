from fastapi import FastAPI, Response
import json
from typing import Dict
import uvicorn
import ssl

app = FastAPI()

vault_secret = None

def load_config() -> Dict:
    config_path = '/vault/secrets/mounted.json'
    try:
        with open(config_path, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading config: {e}")
        return {}

@app.on_event("startup")
async def startup_event():
    global vault_secret
    vault_secret = load_config()
    if not vault_secret:
        print("failed to load secret")

@app.get("/")
async def root():
    if not vault_secret:
        html_content = """
        <html>
            <body>
                <h1>This is myservice root, for some reason it was unable to pull secrets from vault</h1>
            </body>
        </html>
        """
        return Response(content=html_content, media_type="text/html")

    secret_foo = vault_secret.get('foo')
    secret_rand = vault_secret.get('rand')

    html_content = f"""
        <html>
            <body>
                <h1>Secrets from Vault ( btw you can access it <a href=http://127.0.0.1:30820/ui>here</a> use tronius for token)</h1>
                <p>This secret <b><i>'{secret_foo}'</i></b> was pulled from Vault.</p>
                <p>So was this <b><i>'{secret_rand}'</i></b>.</p>
            </body>
        </html>
        """
    return Response(content=html_content, media_type="text/html")

@app.get("/ping")
async def health_check():
    return {
        "status": "pong",
        "is_vault_secret_loaded": bool(vault_secret)
    }


if __name__ == "__main__":


    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8443,
        ssl_keyfile="/app/certs/server.key",
        ssl_certfile="/app/certs/server.crt",
        reload=False
    )
