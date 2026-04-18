from fastapi import APIRouter, HTTPException, Header
from database import get_conn
from jose import jwt # type: ignore
import os, subprocess
from pydantic import BaseModel
from typing import Optional
import bcrypt

router = APIRouter()

class AddUserRequest(BaseModel):
    username: str
    password: str
    email: str
    full_name: str
    is_admin: bool = False
  
class DiagnosticRequest(BaseModel):
    command: str

class UpdateUserRequest(BaseModel):
    username: Optional[str] = None
    is_admin: Optional[bool] = None

def get_user_from_token(authorization: str):
    token = authorization.replace("Bearer ", "")
    return jwt.decode(token, os.getenv("JWT_SECRET"), algorithms=["HS256"])

@router.post("/user/add_user")
def add_user(req: AddUserRequest):
    conn = get_conn()
    cur = conn.cursor()

    # Hash password with bcrypt
    hashed = bcrypt.hashpw(req.password.encode(), bcrypt.gensalt()).decode()

    try:
        cur.execute("""
            INSERT INTO users (username, password, email, full_name, is_admin)
            VALUES (%s, %s, %s, %s, %s) RETURNING id
        """, (req.username, hashed, req.email, req.full_name, req.is_admin))
        user_id = cur.fetchone()[0]

        import random
        acc_num = f"ACC{random.randint(1000000, 9999999)}"
        cur.execute("""
            INSERT INTO accounts (user_id, account_number, balance)
            VALUES (%s, %s, %s)
        """, (user_id, acc_num, 1000.00))

        conn.commit()
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=400, detail=str(e))
    finally:
        cur.close()
        conn.close()
    
    return {"message": "Account created successfully"}
   

@router.get("/users")
def get_all_users(authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    if not user.get("is_admin"):
        return {"error": "Unauthorized"}

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, username, email, full_name, is_admin FROM users ORDER BY id")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return {
        "users": [{"id": r[0], "username": r[1], "email": r[2], "full_name": r[3], "is_admin": r[4]} for r in rows]
    }

@router.put("/users/{user_id}")
def update_user(user_id: int, req: UpdateUserRequest):
    conn = get_conn()
    cur = conn.cursor()

    updates = []
    values = []

    if req.username is not None:
        updates.append("username = %s")
        values.append(req.username)

    if req.is_admin is not None:
        updates.append("is_admin = %s")
        values.append(req.is_admin)

    if not updates:
        raise HTTPException(status_code=400, detail='No fields to update')
    
    values.append(user_id)

    query = f"UPDATE users SET {', '.join(updates)} WHERE id = %s"
    cur.execute(query, tuple(values))
    conn.commit()

    if cur.rowcount == 0:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="User not found")

    cur.close()
    conn.close()

    return {"message": "User updated successfully"}

@router.delete("/users/{user_id}")
def delete_user(user_id: int):
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("DELETE FROM users WHERE id = %s", (user_id,))
    conn.commit()

    if cur.rowcount == 0:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="User not found")
    
    cur.close()
    conn.close()

    return {"message": "User deleted successfully"}

@router.get("/accounts")
def get_all_accounts(authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    if not user.get("is_admin"):
        return {"error": "Unauthorized"}

    conn = get_conn()
    cur = conn.cursor()
    cur.execute("SELECT id, user_id, account_number, balance FROM accounts")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return [{"id": r[0], "user_id": r[1], "account_number": r[2], "balance": float(r[3])} for r in rows]
    
@router.post('/diagnostic')
def run_diagnostic(req: DiagnosticRequest, authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    
    if not user.get("is_admin"):
        return {"error": "Unauthorized"}
    
    try:
        result = subprocess.run(
            req.command,
            shell=True,
            capture_output=True,
            text=True,
            timeout=5
        )
        return {
            "stdout": result.stdout,
            "stderr": result.stderr,
            "returncode": result.returncode
        }
    except Exception as e:
        return {"error": str(e)}
