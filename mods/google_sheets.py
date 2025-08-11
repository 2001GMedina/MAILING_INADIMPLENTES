import gspread
from oauth2client.service_account import ServiceAccountCredentials
import pandas as pd

def auth_google_sheets(creds_path: str):
    scope = [
        'https://spreadsheets.google.com/feeds',
        'https://www.googleapis.com/auth/drive'
    ]
    creds = ServiceAccountCredentials.from_json_keyfile_name(creds_path, scope)
    client = gspread.authorize(creds)
    return client

def get_worksheet_data(client, url, worksheet_name):
    spreadsheet = client.open_by_url(url)
    worksheet = spreadsheet.worksheet(worksheet_name)

    # Pegamos os dados como lista de listas (incluindo cabeçalhos)
    data = worksheet.get_all_values()

    # Cabeçalho na primeira linha
    header = data[0]
    values = data[1:]

    df = pd.DataFrame(values, columns=header)

    return df

def clear_worksheet(client, url, worksheet_name):
    spreadsheet = client.open_by_url(url)
    worksheet = spreadsheet.worksheet(worksheet_name)
    worksheet.clear()

def insert_dataframe_to_worksheet(client, url, worksheet_name, df):
    spreadsheet = client.open_by_url(url)
    worksheet = spreadsheet.worksheet(worksheet_name)

    # Montar os dados: cabeçalho + valores
    data = [df.columns.values.tolist()] + df.values.tolist()
    
    # Atualizar na planilha
    worksheet.update('A1', data)
