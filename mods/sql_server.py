import pyodbc
import pandas as pd

def connect_sql_server(conn_str: str):
    conn = pyodbc.connect(conn_str)
    return conn

def run_query(conn, query: str):
    df = pd.read_sql(query, conn)
    return df
