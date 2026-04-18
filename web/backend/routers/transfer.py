from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel
from database import get_conn
from jose import jwt # type: ignore
import os

router = APIRouter()

class TransferRequest(BaseModel):
    from_account_id: int
    to_account_id: int
    amount: float
    note: str = ""

def get_user_from_token(authorization: str):
    token = authorization.replace("Bearer ", "")
    return jwt.decode(token, os.getenv("JWT_SECRET"), algorithms=["HS256"])

@router.post("/")
def transfer(req: TransferRequest, authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("SELECT balance, user_id FROM accounts WHERE id = %s", (req.from_account_id,))
    src = cur.fetchone()
    if not src:
        raise HTTPException(status_code=404, detail="Source account not found")

    if str(src[1]) != str(user.get("sub")):
        raise HTTPException(status_code=403, detail="Unauthorized to transfer from this account")

    if src[0] < req.amount:
        raise HTTPException(status_code=400, detail="Insufficient funds")

    cur.execute("UPDATE accounts SET balance = balance - %s WHERE id = %s", (req.amount, req.from_account_id))
    cur.execute("UPDATE accounts SET balance = balance + %s WHERE id = %s", (req.amount, req.to_account_id))
    cur.execute("""
        INSERT INTO transactions (from_account_id, to_account_id, amount, note)
        VALUES (%s, %s, %s, %s)
    """, (req.from_account_id, req.to_account_id, req.amount, req.note))

    conn.commit()
    cur.close()
    conn.close()
    return {"message": "Transfer complete"}