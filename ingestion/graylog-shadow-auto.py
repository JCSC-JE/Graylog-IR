#!/usr/bin/env python3

import os
import csv
import json
import logging
import argparse
import graypy
import datetime
from pathlib import Path

def main():
    # set up the command line arguments
    parser = argparse.ArgumentParser(description='Convert CSV files to JSONL and send to a GELF receiver over TCP or UDP')
    parser.add_argument('directory', help='the directory containing the CSV files')
    parser.add_argument('--host', default='localhost', help='the hostname of the GELF receiver (default: localhost)')
    parser.add_argument('--port', type=int, default=12201, help='the port number of the GELF receiver (default: 12201)')
    parser.add_argument('--proto', choices=['tcp', 'udp'], default='udp', help='the protocol used to send the GELF messages (default: udp)')
    args = parser.parse_args()

    filecount=0

    # get today's date
    today = (datetime.datetime.now() - datetime.timedelta(days=1)).strftime('%Y-%m-%d')
    today = today.replace('-', '/')

    # combine command line directory and datepath
    reports_path = Path(args.directory + today) 
       
    # get a listing of all the files in the directory
    file_list = os.listdir(reports_path)

    # filter the file list to only include CSV files
    csv_files = [file for file in file_list if file.endswith('.csv')]
    
    # configure logging to use the GELFTCPHandler
    logger = logging.getLogger('shadowserver')
    logger.setLevel(logging.INFO)

    if args.proto == 'tcp':
        handler = graypy.GELFTCPHandler(host=args.host, port=args.port, debugging_fields=False)
    else:
        handler = graypy.GELFUDPHandler(host=args.host, port=args.port, debugging_fields=False)
    logger.addHandler(handler)
  
    # iterate over each CSV file
    for file in csv_files:
        # construct the full file path
        file_path = os.path.join(reports_path, file)

        # open the CSV file for reading
        with open(file_path, 'r') as csv_file:
            # read the header row of the CSV file
            header = next(csv.reader(csv_file))
            records=0
            filecount=filecount+1
            logstr = "{\"status\": \"starting\",\"file\":\""
            logstr =logstr + str(file)
            logstr = logstr  + "\"}"
            logger.info(logstr)

            # iterate over each row of the CSV file
            for row in csv.reader(csv_file):
                # create a dictionary representing the row
                row_dict = dict(zip(header, row))
                row_dict['filename'] = str(file)

                if 'timestamp' in row_dict:
                    timestamp = row_dict['timestamp']
                    dt = datetime.datetime.strptime(timestamp, '%Y-%m-%d %H:%M:%S')
                    iso8601_str = dt.isoformat(sep=' ',timespec='milliseconds')
                    row_dict['timestamp'] = iso8601_str
                
                # convert the dictionary to a JSON string
                row_json = json.dumps(row_dict)

                # send the JSON string as a GELF message over TCP
                logger.info(row_json)

            logstr = "{\"status\": \"processed\",\"records\":\""
            logstr = logstr + str(records)
            logstr = logstr + "\",\"file\":\""
            logstr = logstr + str(file)
            logstr = logstr  + "\"}"
            logger.info(logstr)
    
    logstr = "{\"status\": \"finshed\",\"files\":\""
    logstr =logstr + str(filecount)
    logstr = logstr  + "\"}"
    logger.info(logstr)

if __name__ == '__main__':
    main()
