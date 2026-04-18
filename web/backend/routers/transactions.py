from fastapi import APIRouter, Header, Query
from database import get_conn
from pydantic import BaseModel
import subprocess
from jose import jwt # type: ignore
import os

router = APIRouter()

class ExportRequest(BaseModel):
    filename: str

def get_user_from_token(authorization: str):
    token = authorization.replace("Bearer ", "")
    return jwt.decode(token, os.getenv("JWT_SECRET"), algorithms=["HS256"])

@router.get("/search")
def search_transactions(q: str = Query(""), authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    conn = get_conn()
    cur = conn.cursor()

    query = f"SELECT id::text, from_account_id::text, to_account_id::text, amount::text, note, created_at::text FROM transactions WHERE note LIKE '%{q}%'"
    cur.execute(query)
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return [
        {
            "id": str(r[0]),
            "from": str(r[1]),
            "to": str(r[2]),
            "amount": str(r[3]),
            "note": r[4],
            "date": str(r[5])
        }
    for r in rows
]

@router.post("/export")
def export_transactions(req: ExportRequest, authorization: str = Header(...)):
    user = get_user_from_token(authorization)

    result = subprocess.run(
        f"echo 'id,amount,note' > /tmp/{req.filename}.csv",
        shell=True, capture_output=True, text=True, timeout=5
    )
    return {"message": f"Exported to {req.filename}.csv"}


@router.get("/history/{account_id}")
def get_history(account_id: int, authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("""
        SELECT id, from_account_id, to_account_id, amount, note, created_at
        FROM transactions
        WHERE from_account_id = %s OR to_account_id = %s
        ORDER BY created_at DESC
    """, (account_id, account_id))
    rows = cur.fetchall()
    cur.close()
    conn.close()

    return [
        {"id": r[0], "from": r[1], "to": r[2], "amount": float(r[3]), "note": r[4], "date": str(r[5])}
        for r in rows
    ]

