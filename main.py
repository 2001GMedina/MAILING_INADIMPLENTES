import os
from dotenv import load_dotenv
from mods.sql_server import connect_sql_server, run_query
from mods.google_sheets import auth_google_sheets, clear_worksheet, insert_dataframe_to_worksheet
from mods.logger import setup_logger, get_logger

# Define a pasta base (onde o main.py está localizado)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))

def load_query(file_path: str) -> str:
    with open(file_path, 'r', encoding='utf-8') as file:
        query = file.read()
    return query

def main():
    # Inicializa o sistema de log
    setup_logger()
    logger = get_logger()

    try:
        logger.info('Iniciando o processo de atualização de dados.')

        # Carrega variáveis de ambiente
        load_dotenv()

        # Variáveis
        GOOGLE_URL = os.getenv('URL')
        GOOGLE_CREDS = os.path.join(BASE_DIR, 'config', 'g_creds.json')
        CONN_STRING = os.getenv('CONN_STRING')
        WORKSHEET_NAME = 'MAILING_INADIMPLENTES'
        QUERY_PATH = os.path.join(BASE_DIR, 'queries', 'inadimplentes.sql')

        logger.info('Carregando query SQL.')
        SQL_QUERY = load_query(QUERY_PATH)

        logger.info('Conectando ao SQL Server.')
        conn = connect_sql_server(CONN_STRING)

        logger.info('Executando a consulta.')
        df = run_query(conn, SQL_QUERY)

        logger.info('Conectando ao Google Sheets.')
        client = auth_google_sheets(GOOGLE_CREDS)

        logger.info('Formatando datas.')
        for col in df.select_dtypes(include=["datetime64[ns]"]).columns:
            df[col] = df[col].dt.strftime("%d/%m/%Y")

        logger.info('Tratando valores ausentes (NaN).')
        df = df.fillna("")

        logger.info('Limpando a worksheet.')
        clear_worksheet(client, GOOGLE_URL, WORKSHEET_NAME)

        logger.info('Inserindo novos dados na worksheet.')
        insert_dataframe_to_worksheet(client, GOOGLE_URL, WORKSHEET_NAME, df)

        logger.info('Processo finalizado com sucesso.')

    except Exception as e:
        logger.error(f'Erro durante o processo: {e}', exc_info=True)
        raise  # <- Broker for Jenkins

if __name__ == '__main__':
    main()