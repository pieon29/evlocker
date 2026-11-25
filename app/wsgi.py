import logging
import sys

from evlocker import create_app

logging.basicConfig(stream=sys.stdout, level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
app = create_app()
