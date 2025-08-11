import logging
import os

def setup_logger(log_file='output/app.log'):
    os.makedirs(os.path.dirname(log_file), exist_ok=True)

    logging.basicConfig(
        filename=log_file,
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )

    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter('%(asctime)s [%(levelname)s] - %(message)s'))

    logging.getLogger('').addHandler(console)

def get_logger():
    return logging.getLogger()
