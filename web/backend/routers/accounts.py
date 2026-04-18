from fastapi import APIRouter, Header, HTTPException
from database import get_conn
from jose import jwt # type: ignore
import os

router = APIRouter()

def get_user_from_token(authorization: str):
    token = authorization.replace("Bearer ", "")
    payload = jwt.decode(token, os.getenv("JWT_SECRET"), algorithms=["HS256"])
    return payload

@router.get("/{account_id}")
def get_account(account_id: int, authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    conn = get_conn()
    cur = conn.cursor()

    # cur.execute("SELECT id, account_number, balance, user_id FROM accounts WHERE id = %s", (account_id,))
    query = """
    SELECT 
        a.id, 
        a.account_number,
        a.balance,
        a.user_id,
        u.username
    FROM accounts a 
    JOIN users u on a.user_id = u.id
    WHERE a.id = %s;
    """
    cur.execute(query, (account_id,))
    account = cur.fetchone()
    cur.close()
    conn.close()

    if not account:
        raise HTTPException(status_code=404, detail="Account not found")

    return {
        "id": account[0],
        "username": account[4],
        "account_number": account[1],
        "balance": float(account[2]),
        "user_id": account[3],
    }

@router.get("/me/summary")
def get_my_accounts(authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, account_number, balance FROM accounts WHERE user_id = %s", (user["sub"],))
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [{"id": r[0], "account_number": r[1], "balance": float(r[2])} for r in rows]