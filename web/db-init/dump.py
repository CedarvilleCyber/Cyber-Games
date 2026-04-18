import psycopg2
import sys
import datetime

HOST = "172.16.0.25"
USER = "snb-admin"
DB = "national_bank"
PASSWORD = "snb-password"

def dump_db():
    print(f"-- PostgreSQL database dump generated at {datetime.datetime.now()}")
    print("SET statement_timeout = 0;")
    print("SET lock_timeout = 0;")
    print("SET idle_in_transaction_session_timeout = 0;")
    print("SET client_encoding = 'UTF8';")
    print("SET standard_conforming_strings = on;")
    print("SET check_function_bodies = false;")
    print("SET xmloption = content;")
    print("SET client_min_messages = warning;")
    print("SET row_security = off;")
    print("")

    try:
        conn = psycopg2.connect(host=HOST, user=USER, dbname=DB, password=PASSWORD)
        cur = conn.cursor()

        cur.execute("""
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
        """)
        tables = [row[0] for row in cur.fetchall()]

        for table in tables:
            print(f"-- Data for Name: {table}; Type: TABLE DATA; Schema: public;")
            cur.execute(f"SELECT * FROM {table}")
            rows = cur.fetchall()
            if not rows: continue
            
            colnames = [desc.name for desc in cur.description]
            print(f"COPY public.{table} ({', '.join(colnames)}) FROM stdin;")
            for row in rows:
                formatted_row = []
                for val in row:
                    if val is None:
                        formatted_row.append('\\N')
                    elif isinstance(val, str):
                        formatted_row.append(val.replace('\t', '\t').replace('\n', '\n').replace('\r', '\r'))
                    else:
                        formatted_row.append(str(val))
                print('\t'.join(formatted_row))
            print("\.")
            print("")

        cur.close()
        conn.close()

    except Exception as e:
        print(f"-- Error: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    dump_db()
