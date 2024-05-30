#!/usr/bin/env python3
"""
Module Docstring
"""

__author__ = "Cyberkryption"
__version__ = "0.1.0"
__license__ = "MIT"

import os
import re
import logging
from graypy import GELFUDPHandler
import argparse

def main(args):
    """ Main entry point of the app """
    # Configure the logger
    logger = logging.getLogger('corbiere')
    logger.setLevel(logging.INFO)

    # Create a GELFUDPHandler object for the Graylog server
    handler = GELFUDPHandler('172.16.5.101', 12215)
    logger.addHandler(handler)

    # Regex pattern to ignore lines starting with #
    pattern = re.compile(r'^[^#]')

    # Directory containing log files
    log_directory = args.directory

    # Iterate through each file in the directory
    for filename in os.listdir(log_directory):
        if filename.endswith(".log"):
            filepath = os.path.join(log_directory, filename)
            print(f"Processing file: {filepath}")
            with open(filepath, 'r',encoding='utf-8') as file:
                for line in file:
                    # Ignore lines starting with #
                    if pattern.match(line):
                        logger.info(line.strip())

if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description='Send log files to Graylog server')
    parser.add_argument('directory', metavar='directory', type=str, help='Path to the directory containing log files')
    args = parser.parse_args()
    
    main(args)