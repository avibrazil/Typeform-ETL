#!/usr/bin/env python3

#############################################
##
## Incremental ETL implementation for Typeform.
## Brings all your Typeform data into tables on a regular SQL database.
## Designed to be executed everyday to bring incremental data from Typeform.
## Tested with MySQL 5, but should run with any SQL database with little or no effort.
## 
## USAGE
## - Create a database with a schema as on schema.sql
## - Get a Typeform API key
## - Create a config file from syncFromTypeform.conf.example and put API and DB URL
## - Run ./Typeform.py for a first (might be big) sync
## - For an incremental ETL, schedule your system (cron) to run it like this several times per day
##
## Notebook and module written by Avi Alkalay <avi at unix.sh>
## São Paulo, July 2019
##


import logging
import logging.handlers
import math
import hashlib
from datetime import datetime
from dateutil import parser as dateparser
import json
import requests
from sqlalchemy.types import BLOB
import pandas as pd
from configobj import ConfigObj    # dnf install python3-configobj
import sqlalchemy
import argparse

module_logger = logging.getLogger(__name__)

class TypeformSync:
    
    # API paremeters
    workspaceListURL='https://api.typeform.com/workspaces'
    formListURL='https://api.typeform.com/forms?page_size=200&page={page}'
    formItemsURL='https://api.typeform.com/forms/{id}'
    respListURL='https://api.typeform.com/forms/{id}/responses?since={since}&page_size={psize}&page={page}&completed={completed}'
    typeformHeader=None

    
    # DB parameters
    db=None
    lastSync=None
    dbWriteChunckSize=3000 # records
    tablePrefix=''
    
    # DataFrames for updated tables of entities to be synced
    forms=None
    formItems=None
    responses=None
    answers=None
    
    # Logging
    response=None
    logger=None

    
    def __init__(self,token=None,dburl=None,restart=False,dbupdate=True,tableprefix=None):
        self.token=token
        self.dbURL=dburl

        if tableprefix:
            self.tablePrefix=tableprefix
        
        if __name__ == '__main__':
            self.logger=logging.getLogger('Typeform.TypeformSync')
        else:
            self.logger=logging.getLogger(__name__ + '.TypeformSync')

        self.typeformHeader={'Authorization': f'Bearer {self.token}'}
        
        self.restart=restart
        self.dbUpdate=dbupdate
        
        

    def __connectDB(self):
        try:
            self.db=sqlalchemy.create_engine(self.dbURL, encoding='utf8')
        except sqlalchemy.exc.SQLAlchemyError as error:
            self.logger.error('Can’t connect to DB.', exc_info=True)
            raise error

            
            
            
            
    def __getLastSync(self):
        if self.restart:
            self.lastSync = None
        else:
            options=pd.read_sql(f"SELECT * FROM {self.tablePrefix}options;", self.db)
            self.lastSync = options[options.name=='typeform_last']['value'].values[0]

        if self.lastSync != None:
            self.lastSync = dateparser.parse(self.lastSync)
        else:
            self.lastSync = datetime(1970,1,1)


        
    def __setLastSync(self):
        lastData=self.responses['landed'].sort_values(ascending=False).head(1)[0]

        # Set last sync date
        self.db.execute("UPDATE {pref}options SET value='{last}' WHERE name='typeform_last'".format(last=lastData,pref=self.tablePrefix))

        # Update the sync log
        self.db.execute("INSERT INTO {}synclog (timestamp,forms,form_items,responses,answers) VALUES (UTC_TIMESTAMP(),{},{},{},{})".format(
            self.tablePrefix,
            self.forms.shape[0],
            self.formItems.shape[0],
            self.responses.shape[0],
            self.answers.shape[0]
        ))
        
        # Update the daily NPS materialized view
        if self.answers.shape[0] > 0:
            # This is a heavy task, so only if we have new answers
            
            self.logger.debug('Update nps_daily_mv materialized view…')

            self.db.execute(f"DROP TABLE IF EXISTS {self.tablePrefix}nps_daily_mv2;")
            self.db.execute(f"CREATE TABLE {self.tablePrefix}nps_daily_mv2 AS SELECT * FROM {self.tablePrefix}nps_daily;")
                            
            self.db.execute(f"DROP TABLE IF EXISTS {self.tablePrefix}nps_daily_mv;")
            self.db.execute(f"RENAME TABLE {self.tablePrefix}nps_daily_mv2 TO {self.tablePrefix}nps_daily_mv;")

        
                
    def getWorkspaces(self):
        # Still unimplemented
        workspaceColumns=['id', 'url', 'title']


    
    def getForms(self):
        forms=[]

        # This column order (and names) must match the respective table in the database
        formColumns=['id', 'workspace', 'updated', 'url', 'title','description']
        
        self.logger.debug('Requesting forms…')

        try:
            self.response=requests.get(self.formListURL.format(page=1),
                                  headers=self.typeformHeader).json()
        except:
            self.logger.error('Error trying to get forms.', exc_info=True)
            raise

        for f in self.response['items']:
            form={}
            form['id']        =f['id']
            #form['workspace'] =f['workspace']['href'][:-6]
            form['url']       =f['_links']['display']
            form['title']     =f['title']
#             form['ref']       =f['ref']
            form['updated']   =dateparser.parse(f['last_updated_at']).replace(tzinfo=None)

            forms.append(form)

        self.forms=pd.DataFrame(columns=formColumns)
        self.forms=self.forms.append(forms)
        self.forms.set_index('id',inplace=True)

        del forms

        
        
    def getFormItems(self):
        field  = {}
        fields = []

        # This column order (and names) must match the respective table in the database
        formItemsColumns=['id','form','name','type','title']

        self.logger.debug('Requesting form items…')

        for form in self.forms.index:
            self.response=None
            try:
                self.response=requests.get(self.formItemsURL.format(id=form),
                       headers=self.typeformHeader).json()
            except requests.exceptions.RequestException as error:
                self.logger.error('Error trying to get form items', exc_info=True)
                raise error

            # Get form's workspace ID from last 6 chars on workspace URL
            self.forms.at[form,'workspace'] = self.response['workspace']['href'][-6:]
            
            if 'fields' in self.response:
                for f in self.response['fields']:
                    field = {}
                    field['form']               = form
                    field['id']                 = f['id']
                    field['title']              = f['title']
                    field['name']               = f['ref']
                    field['type']               = f['type']
                    
                    if 'description' in f:
                        field['description']    = f['description']

                    fields.append(field)

            if 'hidden' in self.response:
                for f in self.response['hidden']:
                    idCalc=hashlib.new('shake_256')

                    field = {}
                    field['form']      = form
                    field['title']     = f
                    field['name']      = f
                    field['type']      = 'hidden'

                    idCalc.update('{}hidden{}'.format(form,f).encode('utf-8'))
                    field['id']        = idCalc.hexdigest(5)

                    fields.append(field)

        self.formItems=pd.DataFrame(columns=formItemsColumns)
        self.formItems=self.formItems.append(fields)
        self.formItems.set_index('id',inplace=True)

        del fields
        

        
    def getResponses(self):
        meta     = {}
        metas    = []
        answer   = {}
        answers  = []

        # This column order (and names) must match the respective table in the database
        metaColumns=['id', 'form', 'landed', 'submitted', 'agent', 'referer']
        answerColumns=['id', 'form', 'response', 'field', 'data_type_hint', 'answer']
        

#         debugIndex=['KPbhd6'] #,'APiACy','YRyBYh']
#         for form in debugIndex:
        for form in self.forms.index:
            for completed in [True,False]:
                completed=str(completed).lower()
                self.response=None
                try:
                    self.logger.debug('Requesting response statistics for form «{}», submitted={}…'.format(form,completed))

                    self.response=requests.get(self.respListURL.format(id=form, psize=1, page=1,
                                                                       completed=completed,
                                                                       since=self.lastSync.isoformat()),
                                           headers=self.typeformHeader).json()
                    
                    
                    #self.logger.debug('Form «{}», submitted={}, looks like: {}'.format(form,completed,str(self.response)[:150]))

                except requests.exceptions.RequestException as error:
                    self.logger.error('Error trying to get response statistics for form «{}».'.format(form), exc_info=True)
                    raise error

                if 'total_items' in self.response.keys():
                    number_of_pages_of_1000_responses = math.ceil(self.response['total_items']/1000)
                else:
                    number_of_pages_of_1000_responses = 0

                for page in range(1,number_of_pages_of_1000_responses+1):
                    try:
                        self.logger.debug('Requesting responses for form «{}», submitted={}…'.format(form,completed))

                        responseSet=requests.get(self.respListURL.format(id=form, psize=1000, page=page, completed=completed,
                                                                        since=self.lastSync.isoformat()),
                                                headers=self.typeformHeader).json()
                    except requests.exceptions.RequestException as error:
                        self.logger.error('Error trying to get response details for form «{}»'.format(form), exc_info=True)
                        raise error



                    for i in responseSet['items']:
                        meta = {}
                        meta['id']          = i['response_id']
                        meta['form']        = form
                        meta['landed']      = dateparser.parse(i['landed_at']).replace(tzinfo=None)
                        meta['submitted']   = dateparser.parse(i['submitted_at']).replace(tzinfo=None)
                        meta['agent']       = i['metadata']['user_agent']
                        meta['referer']     = i['metadata']['referer']

                        metas.append(meta)

                        # Handle all hidden fields of response
                        if 'hidden' in i.keys():
                            for field in i['hidden'].keys():
                                idCalc=hashlib.new('shake_256')
                                idCalc.update('{}{}{}'.format(form,meta['id'],field).encode('UTF-8'))

                                answer = {}
                                answer['id']          =  idCalc.hexdigest(5)
                                answer['response']    =  meta['id']
                                answer['form']        =  form
                                answer['answer']      =  i['hidden'][field]

                                idCalc=hashlib.new('shake_256')
                                idCalc.update('{}hidden{}'.format(form,field).encode('UTF-8'))
                                answer['field']       =  idCalc.hexdigest(5)

                                answer['data_type_hint'] = 'hidden'

                                answers.append(answer)


                        # Handle all regular fields of response
                        if 'answers' in i.keys():
                            for field in i['answers']:
            #                     print(f'\t{field}')
                                idCalc=hashlib.new('shake_256')
                                idCalc.update('{}{}{}'.format(form,meta['id'],field['field']['id']).encode('UTF-8'))

                                answer = {}
                                answer['id']       =  idCalc.hexdigest(5)
                                answer['response'] =  meta['id']
                                answer['form']     =  form
                                answer['field']    =  field['field']['id']
                                answer['data_type_hint'] = field['type']


                                # Handle multichoice fields
                                if field['type'] == 'choices':
                                    # Handle multi-choice fields: concatenate with `|` as separator
                                    answer['answer'] = []
                                    for k in field[field['type']].keys():
                                        for a in field[field['type']][k]:
                                            answer['answer'].append(a)
                                    answer['answer'] = '|'.join(answer['answer'])
                                elif field['type'] == 'choice':
                                    # Handle single-choice fields
                                    for k in field[field['type']].keys():
                                        answer['answer']=field[field['type']][k]
                                else:
                                    # Default: just get the content, always as a string
                                    answer['answer'] = str(field[field['type']])

                                answers.append(answer)


        self.responses=pd.DataFrame(columns=metaColumns)
        if len(metas)>0:
            self.responses=self.responses.append(metas)
        
        # Sort reponses by «landed» time
        self.responses.sort_values(by='landed', inplace=True)
        self.responses.set_index('id',inplace=True)
        del metas

        self.answers=pd.DataFrame(columns=answerColumns)
        if len(answers)>0:
            self.answers=self.answers.append(answers)
        self.answers.set_index('id',inplace=True)
        
        # Sort answers by reponses’ «landed» time
        self.answers['response']=pd.Categorical(self.answers['response'],self.responses.sort_values(by='landed').index)
        self.answers.sort_values(by='response', inplace=True)
        del answers    
    

    
    def statistics(self):
        self.logger.info('Number of forms: {}'.format(self.forms.shape[0]))
        self.logger.info('Number of form fields: {}'.format(self.formItems.shape[0]))
        self.logger.info('Number of responses: {}'.format(self.responses.shape[0]))
        self.logger.info('Number of fields answered: {}'.format(self.answers.shape[0]))

        
    
    def getUpdates(self):
        self.logger.debug('Requesting form updates since {}…'.format(self.lastSync))

        self.getForms()
        self.getFormItems()
        self.getResponses()
        
        
        
    def syncUpdates(self):
        self.logger.debug('Writting updates to DB…')

        comb = [
            {'df': 'forms',     'temp': 'forms_temp',      'table': 'forms'},
            {'df': 'formItems', 'temp': 'form_items_temp', 'table': 'form_items'},
            {'df': 'responses', 'temp': 'responses_temp',  'table': 'responses'},
            {'df': 'answers',   'temp': 'answers_temp',    'table': 'answers'}
        ]
        
        for e in comb:
            self.logger.debug('Writting «{df}» dataframe updates to «{table}» table in DB'.format(df=e['df'],table=e['table']))

            try:
                
                # Pandas plain to_sql() doesn't take care of correct column data type,
                # so we have to inherit from target table like this:
                self.db.execute('DROP TABLE IF EXISTS {prefix}{temp};'.format(temp=e['temp'],target=e['table'],prefix=self.tablePrefix))
                self.db.execute('CREATE TABLE {prefix}{temp} AS SELECT * FROM {prefix}{target} LIMIT 1;'.format(temp=e['temp'],target=e['table'],prefix=self.tablePrefix))
                self.db.execute('TRUNCATE TABLE {prefix}{temp};'.format(temp=e['temp'],target=e['table'],prefix=self.tablePrefix))

                if self.__dict__[e['df']].shape[0] > 1.25*self.dbWriteChunckSize:
                    for chunk in range(0,math.ceil(self.__dict__[e['df']].shape[0]/self.dbWriteChunckSize)):
                        self.logger.debug('Writting «{df}» to DB: [{start}:{end})'.format(
                            df=e['df'],
                            start=chunk*self.dbWriteChunckSize,
                            end=(chunk+1)*self.dbWriteChunckSize
                        ))
                        self.__dict__[e['df']][chunk*self.dbWriteChunckSize:(chunk+1)*self.dbWriteChunckSize].reset_index().to_sql(
                            name=self.tablePrefix + e['temp'],
                            index=False,
    #                         dtype=blobs,
    #                         method=None,
                            if_exists='append',
                            con=self.db
                        )
                else:
                    self.__dict__[e['df']].reset_index().to_sql(
                        name=self.tablePrefix + e['temp'],
                        index=False,
    #                     dtype=blobs,
    #                     method=None,
                        if_exists='replace',
                        con=self.db
                    )
            except BaseException as e:
                self.logger.error('Error writting temporary table to database.', exc_info=True)
                raise e



            self.db.execute('REPLACE INTO {prefix}{target} (SELECT * FROM {prefix}{temp}); DROP TABLE {prefix}{temp};'.format(temp=e['temp'],target=e['table'],prefix=self.tablePrefix))
        

    def sync(self):
        self.__connectDB()
        self.__getLastSync()

        self.getUpdates()
        
        if self.dbUpdate:
            self.syncUpdates()
            self.__setLastSync()
        
        self.statistics()




        
def prepareLogging(level=logging.INFO):
    # Switch between INFO/DEBUG while running in production/developping:
    logging.getLogger('Typeform').setLevel(level)
    logging.getLogger('Typeform.TypeformSync').setLevel(level)
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
    
    parser.add_argument('--database', '--db', dest='database', nargs=1,
                        help='Destination database URL as «mysql://user:pass@host.com/dbname?charset=utf8mb4»')
    
    parser.add_argument('--tableprefix', '--prefix', dest='tableprefix', nargs=1,
                        help='A string to prefix every table name with, such as "tf_"')
    
    parser.add_argument('--updatedb', '-u', dest='dbupdate', default=True, action='store_false',
                        help='Get updates from Typeform but do not update database')    

    parser.add_argument('--typeform', '-t', dest='typeform_token', nargs=1,
                        help='Typeform API key')

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
    
    # Setup logging
    if context['debug']:
        prepareLogging(logging.DEBUG)
    else:
        prepareLogging()
    


    # Prepare syncing machine
    tf = TypeformSync(
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
