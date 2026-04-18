from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel
from jose import jwt # type: ignore
import urllib.request
import os

router = APIRouter()

class LinkAccountRequest(BaseModel):
    bank_url: str

def get_user_from_token(authorization: str):
    token = authorization.replace("Bearer ", "")
    return jwt.decode(token, os.getenv("JWT_SECRET"), algorithms=["HS256"])

@router.post("/link")
def link_external_account(req: LinkAccountRequest, authorization: str = Header(...)):
    user = get_user_from_token(authorization)

    try:
        with urllib.request.urlopen(req.bank_url, timeout=5) as resp:
            content = resp.read().decode(errors="replace")
            return {"status": "fetched", "content": content}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))
