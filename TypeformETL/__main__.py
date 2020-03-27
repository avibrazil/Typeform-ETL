from . import TypeformETL
import logging.handlers
import logging
from configobj import ConfigObj    # dnf install python3-configobj
import argparse

        
def prepareLogging(level=logging.INFO):
    # Switch between INFO/DEBUG while running in production/developping:
    logging.getLogger('TypeformETL').setLevel(level)
    logging.getLogger('TypeformETL.TypeformETL').setLevel(level)
    logging.getLogger('requests.packages.urllib3').setLevel(logging.WARNING)
    logging.getLogger('requests.packages.urllib3').propagate=True
    logging.captureWarnings(True)
    
    if level == logging.DEBUG:
        # Show messages on screen too:
        logging.getLogger().addHandler(logging.StreamHandler())

    # Send messages to Syslog:
    #logging.getLogger().addHandler(logging.handlers.SysLogHandler(address='/dev/log'))
    logging.getLogger().addHandler(logging.handlers.SysLogHandler())
    
    
def prepareArgs():
    parser = argparse.ArgumentParser(description='EXTRACT Typeform recent responses, TRANSFORM them into table and LOAD results into a database')
    
    parser.add_argument('--typeform', '-t', dest='typeform_token', required=True,
                        help='Typeform API key')

    parser.add_argument('--database', '--db', dest='database', required=True,
                        help='Destination database URL as «mysql://user:pass@host.com/dbname?charset=utf8mb4»')
    
    parser.add_argument('--tableprefix', '--prefix', dest='tableprefix',
                        help='A string to prefix every table name with, such as "tf_"')
    
    parser.add_argument('--updatedb', '-u', dest='dbupdate', default=True, action='store_false',
                        help='Get updates from Typeform but do not update database')    

    parser.add_argument('--restart', '-r', dest='restart', default=False, action='store_true',
                        help='Ignore last sync info stored on DB and get all responses from Typeform')

    parser.add_argument('--debug', '-d', dest='debug', default=False, action='store_true',
                        help='Be more verbose and output messages to console in addition to (the default) syslog')

    parser.add_argument('--config', '-c', dest='config', default='syncFromTypeform.conf',
                        help='Config file with Typeform API key and destination database URL')

    return parser.parse_args()



def main():
    args=prepareArgs()

    # Read config file
    context=ConfigObj(args.config)
    
    # Remove empty args
    if args.database is None:
        args.database=context['database']

    if args.typeform_token is None:
        args.typeform_token=context['typeform_token']
    
    # Merge configuration file parameters with command line arguments
    context.update(vars(args))
    
    # print(context)
    
    
    if context['debug']:
        prepareLogging(logging.DEBUG)
    else:
        prepareLogging()
    

    # Prepare syncing machine
    tf = TypeformETL(
        token=context['typeform_token'],
        dburl=context['database'],
        restart=context['restart'],
        dbupdate=context['dbupdate'],
        tableprefix=context['tableprefix']
    )
    
    
    # Read Typeform updates and write to DB
    tf.sync()
    
    

if __name__ == "__main__":
    main()
