from fastapi import APIRouter, Header, HTTPException
from pydantic import BaseModel
from database import get_conn
from jinja2 import Environment 
from jose import jwt # type: ignore
import os

router = APIRouter()

jinja_env = Environment()

class ProfileUpdate(BaseModel):
    email: str = None
    full_name: str = None
    bio: str = None
    balance: float = None
    is_admin: bool = None

def get_user_from_token(authorization: str):
    token = authorization.replace("Bearer ", "")
    return jwt.decode(token, os.getenv("JWT_SECRET"), algorithms=["HS256"])

@router.get("/me")
def get_profile(authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    conn = get_conn()
    cur = conn.cursor()

    cur.execute("SELECT id, username, email, full_name, bio, is_admin FROM users WHERE id = %s", (int(user["sub"]),))
    row = cur.fetchone()
    cur.close()
    conn.close()

    if not row:
        raise HTTPException(status_code=404, detail="User not found")

    return {
        "id": row[0], 
        "username": row[1], 
        "email": row[2], 
        "full_name": row[3], 
        "bio": row[4], 
        "is_admin": row[5]
    }

@router.put("/me")
def update_profile(req: ProfileUpdate, authorization: str = Header(...)):
    user = get_user_from_token(authorization)
    conn = get_conn()
    cur = conn.cursor()

    rendered_bio = jinja_env.from_string(req.bio or "").render()

    updates = {}
    if req.email: updates["email"] = req.email
    if req.full_name: updates["full_name"] = req.full_name
    if rendered_bio: updates["bio"] = rendered_bio
    if req.balance is not None: updates["balance"] = req.balance
    if req.is_admin is not None: updates["is_admin"] = req.is_admin

    if updates:
        set_clause = ", ".join([f"{k} = %s" for k in updates])
        values = list(updates.values()) + [user["sub"]]
        cur.execute(f"UPDATE users SET {set_clause} WHERE id = %s", values)
        conn.commit()

    cur.close()
    conn.close()
    return {"message": "Profile updated"}