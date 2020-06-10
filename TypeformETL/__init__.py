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
import math
import hashlib
import base64
from datetime import datetime
from dateutil import parser as dateparser
import json
import requests
import pandas as pd
import sqlalchemy
from sqlalchemy.types import BLOB

__version__ = '0.6.1'

module_logger = logging.getLogger(__name__)

class TypeformETL:
    
    # API paremeters
    workspaceListURL='https://api.typeform.com/workspaces'
    formListURL='https://api.typeform.com/forms?page_size=200&page={page}'
    formItemsURL='https://api.typeform.com/forms/{id}'
    respListURL='https://api.typeform.com/forms/{id}/responses?since={since}&page_size={psize}&page={page}&completed={completed}'
    typeformHeader=None

    
    # DB parameters
    db=None
    lastLanded=None
    lastSubmitted=None
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

    # Debug stuff
    debugForms=['ARqhAx', 'KPbhd6'] #,'APiACy','YRyBYh']
    
    def __init__(self,token=None,dburl=None,restart=False,dbupdate=True,tableprefix=None):
        self.token=token
        self.dbURL=dburl

        if tableprefix:
            self.tablePrefix=tableprefix
        
        if __name__ == '__main__':
            self.logger=logging.getLogger('TypeformETL.TypeformETL')
        else:
            self.logger=logging.getLogger(__name__ + '.TypeformETL')

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
            self.lastLanded = None
            self.lastSubmitted = None
        else:
            lasts=pd.read_sql(f"select max(landed) as landed, max(submitted) as submitted from {self.tablePrefix}responses;", self.db)
            self.lastLanded = lasts['landed'].values[0]
            self.lastSubmitted = lasts['submitted'].values[0]

        if self.lastLanded != None:
            self.lastLanded = datetime.utcfromtimestamp(self.lastLanded.astype(int) * 1e-9)
        else:
            self.lastLanded = datetime(1970,1,1)

        if self.lastSubmitted != None:
            self.lastSubmitted = datetime.utcfromtimestamp(self.lastSubmitted.astype(int) * 1e-9)
        else:
            self.lastSubmitted = datetime(1970,1,1)




        
    def __setLastSync(self):
        lastData=self.responses['landed'].sort_values(ascending=False).head(1)[0]

        # Set last sync date
        self.db.execute("UPDATE {pref}options SET value='{last}' WHERE name='typeform_last'".format(last=lastData,pref=self.tablePrefix))

        # Update the sync log
        self.db.execute("INSERT INTO {}synclog (timestamp,version,forms,form_items,responses,answers) VALUES (UTC_TIMESTAMP(),'{}',{},{},{},{})".format(
            self.tablePrefix,
            __version__,
            self.forms.shape[0],
            self.formItems.shape[0],
            self.responses.shape[0],
            self.answers.shape[0]
        ))
        
#        # Update the daily NPS materialized view
#        if self.answers.shape[0] > 0:
#            # This is a heavy task, so only if we have new answers
#            
#            self.logger.debug('Update nps_daily_mv materialized view…')
#
##             DROP TABLE IF EXISTS tf_nps_daily_mv2;
##             CREATE TABLE tf_nps_daily_mv2 AS SELECT * FROM tf_nps_daily;
##             DROP TABLE IF EXISTS tf_nps_daily_mv;
##             RENAME TABLE tf_nps_daily_mv2 TO tf_nps_daily_mv;
#            
#            self.db.execute(f"DROP TABLE IF EXISTS {self.tablePrefix}nps_daily_mv2;")
#            self.db.execute(f"CREATE TABLE {self.tablePrefix}nps_daily_mv2 AS SELECT * FROM {self.tablePrefix}nps_daily;")
#                            
#            self.db.execute(f"DROP TABLE IF EXISTS {self.tablePrefix}nps_daily_mv;")
#            self.db.execute(f"RENAME TABLE {self.tablePrefix}nps_daily_mv2 TO {self.tablePrefix}nps_daily_mv;")

        
                
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
#             if f['id'] not in self.debugForms:
#                 continue

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
        formItemsColumns=['id','parent_id','form','position','name','parent_name','type','title','description']

        self.logger.debug('Requesting form items…')

#         for form in self.debugForms:
        for form in self.forms.index.sort_values():
            self.response=None
            field_index=0
            try:
                self.response=requests.get(self.formItemsURL.format(id=form),
                       headers=self.typeformHeader).json()
                self.logger.debug('Requested: ' + self.formItemsURL.format(id=form))
            except requests.exceptions.RequestException as error:
                self.logger.error('Error trying to get form items', exc_info=True)
                raise error

            # Get form's workspace ID from last 6 chars on workspace URL
            self.forms.at[form,'workspace'] = self.response['workspace']['href'][-6:]

            if 'hidden' in self.response:
                for f in self.response['hidden']:
                    field = {}
                    field['form']      = form
                    field['title']     = f
                    field['name']      = f
                    field['type']      = 'hidden'
                    field['position']  = field_index

                    field['id']        = self.makeID('{}hidden{}'.format(form,f))

                    fields.append(field)
                    field_index += 1
                    del field

            if 'fields' in self.response:
                for f in self.response['fields']:                
                    field = {}
                    field['form']               = form
                    field['id']                 = f['id']
                    field['title']              = f['title']
                    field['name']               = f['ref']
                    field['type']               = f['type']
                    field['position']           = field_index
                    
                    if 'properties' in f and 'description' in f['properties']:
                        field['description']    = f['properties']['description']

                    fields.append(field)
                    field_index += 1
                    del field
                
                    # Handle sub fields (under group fields)
                    if 'properties' in f and 'fields' in f['properties']:
                        for subf in f['properties']['fields']:
                            field = {}
                            field['form']               = form
                            field['parent_id']          = f['id']
                            field['id']                 = subf['id']
                            field['title']              = subf['title']
                            field['name']               = subf['ref']
                            field['parent_name']        = f['ref']
                            field['type']               = subf['type']
                            field['position']           = field_index

                            if 'properties' in subf and 'description' in subf['properties']:
                                field['description']    = subf['properties']['description']

                            fields.append(field)
                            field_index += 1
                            del field
        
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
        metaColumns=['id', 'form', 'ip_address', 'landed', 'submitted', 'agent', 'referer']
        answerColumns=['id', 'form', 'response', 'sequence', 'field', 'data_type_hint', 'answer']
        

#         for form in self.debugForms:
        for form in self.forms.index.sort_values():
            for completed in [True,False]:
            
                if completed:
                    since=self.lastSubmitted.isoformat()
                else:
                    since=self.lastLanded.isoformat()
            
                self.response=None
                try:
                    self.logger.debug('Requesting response statistics for form «{}», submitted={}…'.format(form,completed))

                    self.response=requests.get(
                            self.respListURL.format(id=form, psize=1, page=1,
                                       completed=str(completed).lower(),
                                       since=since
                            ),
                            headers=self.typeformHeader
                    ).json()


                    #self.logger.debug('Form «{}», submitted={}, looks like: {}'.format(form,completed,str(self.response)[:150]))

                except requests.exceptions.RequestException as error:
                    self.logger.error('Error trying to get response statistics for form «{}».'.format(form), exc_info=True)
                    raise error

                if 'total_items' in self.response.keys():
                    number_of_pages_of_1000_responses = math.ceil(self.response['total_items']/1000)
                else:
                    number_of_pages_of_1000_responses = 0

                lastToken=None
                for page in range(1,number_of_pages_of_1000_responses+1):
                    try:                    
                        url=self.respListURL.format(
                            id=form, psize=1000,
                            page=page, completed=str(completed).lower(),
                            since=since
                        )

                        if lastToken:
                            # Append last token we have for this page
                            url += f'&before={lastToken}'

                        
                        responseSet=requests.get(url,headers=self.typeformHeader).json()
                        
#                         self.logger.debug(responseSet)

                        self.logger.debug('Requesting responses for form «{}»: {} answers'.format(form,responseSet['total_items']))
                        self.logger.debug(f'Requesting from: {url}')

                    except requests.exceptions.RequestException as error:
                        self.logger.error('Error trying to get response details for form «{}»'.format(form), exc_info=True)
                        raise error



                    for i in responseSet['items']:
    #                         self.logger.debug(f"working on: {i}")

                        meta = {}
                        meta['id']          = i['response_id']
                        meta['form']        = form
                        meta['landed']      = dateparser.parse(i['landed_at']).replace(tzinfo=None)
                        meta['agent']       = i['metadata']['user_agent']
                        meta['referer']     = i['metadata']['referer']

                        if 'network_id' in i['metadata']:
                            meta['ip_address'] = i['metadata']['network_id']

                        if 'submitted_at' in i:
                            # apparently became an optional parameter in 2020-03-02
                            meta['submitted'] = dateparser.parse(i['submitted_at']).replace(tzinfo=None)

                        lastToken=i['token'] # generally same as i['response_id'], but just to follow docs
                        metas.append(meta)

                        seq=0

                        # Handle all hidden fields of response
                        for t in ['hidden']: #,'calculated']:
                            if t in i.keys():
                                for field in i[t].keys():
                                    answer = {}
                                    answer['id']          =  self.makeID('{}{}{}'.format(form,meta['id'],field))
                                    answer['response']    =  meta['id']
                                    answer['form']        =  form
                                    answer['sequence']    =  seq
                                    answer['answer']      =  i[t][field]
                                    answer['field']       =  self.makeID('{}{}{}'.format(form,t,field))

                                    answer['data_type_hint'] = t

                                    answers.append(answer)
                                    seq+=1


                        # Handle all regular fields of response
                        if 'answers' in i.keys():
                            # apparently content into 'ansewrs' became optional in 2020-03-02
                            if i['answers'] is None:
                                # Flag submitted as Null if there are no answers
                                meta['submitted'] = None
                            else:
                                for field in i['answers']:
                                    answer = {}
                                    answer['id']       =  self.makeID('{}{}{}'.format(form,meta['id'],field['field']['id']))
                                    answer['response'] =  meta['id']
                                    answer['form']     =  form
                                    answer['sequence'] =  seq
                                    answer['field']    =  field['field']['id']
                                    answer['data_type_hint'] = field['type']


                                    # Handle multichoice fields
                                    if field['type'] == 'choices' or field['type'] == 'choice':
                                        answer['answer'] = {}
                                        
                                        if 'labels' in field[field['type']] or 'label' in field[field['type']]:
                                            if field['type'] == 'choices':
                                                # Multi-choice
                                                answer['answer'] = dict(zip(
                                                    field[field['type']]['ids'],
                                                    field[field['type']]['labels']
                                                ))
                                            else:
                                                # Single choice
                                                answer['answer'][field[field['type']]['id']] = str(field[field['type']]['label'])
                                                
                                        if 'other' in field[field['type']]:
                                            answer['answer']['other'] = field[field['type']]['other']

                                        # convert to compressed Unicode JSON to store in DB
                                        answer['answer']=json.dumps(
                                            answer['answer'],
                                            ensure_ascii=False,
                                            separators=(',', ':')
                                        )
                                    else:
                                        # Default: just get the content, always as a string
                                        answer['answer'] = str(field[field['type']])

                                    answers.append(answer)
                                    seq+=1


        self.responses=pd.DataFrame(columns=metaColumns)
        if len(metas)>0:
            self.responses=self.responses.append(metas)
        
        # Sort reponses by «landed» time
        self.responses.sort_values(by='landed', inplace=True)
        self.responses.set_index('id',inplace=True)
#         self.logger.debug(self.responses)
        del metas

        self.answers=pd.DataFrame(columns=answerColumns)
        if len(answers)>0:
            self.answers=self.answers.append(answers)
        self.answers.set_index('id',inplace=True)
        
        # Sort answers by reponses’ «landed» time
#         self.answers['response']=pd.Categorical(self.answers['response'],self.responses.sort_values(by='landed').index)
        self.answers.sort_values(by='response', inplace=True)
        del answers    
    

    def makeID(self,content,contentEncoding='UTF-8',digester=base64.b85encode,algo='shake_256',size=20):
        machine=hashlib.new(algo)
        machine.update(content.encode(contentEncoding))
        return digester(machine.digest(size)).decode('ascii')
        
    
    def statistics(self):
        self.logger.info('Number of forms: {}'.format(self.forms.shape[0]))
        self.logger.info('Number of form fields: {}'.format(self.formItems.shape[0]))
        self.logger.info('Number of responses: {}'.format(self.responses.shape[0]))
        self.logger.info('Number of fields answered: {}'.format(self.answers.shape[0]))

        
    
    def getUpdates(self):
        self.logger.debug('Requesting form updates since {}…'.format(self.lastSubmitted))

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
                self.db.execute('CREATE TABLE {prefix}{temp} LIKE {prefix}{target};'.format(temp=e['temp'],target=e['table'],prefix=self.tablePrefix))
#                 self.db.execute('TRUNCATE TABLE {prefix}{temp};'.format(temp=e['temp'],target=e['table'],prefix=self.tablePrefix))

                if self.__dict__[e['df']].shape[0] > 1.25*self.dbWriteChunckSize:
                    chunkIndex=0
                    for chunk in range(0,math.ceil(self.__dict__[e['df']].shape[0]/self.dbWriteChunckSize)):
                        self.logger.debug('Writting «{df}» to DB: [{start}:{end})'.format(
                            df=e['df'],
                            start=chunk*self.dbWriteChunckSize,
                            end=(chunk+1)*self.dbWriteChunckSize
                        ))
#                         self.__dict__[e['df']][chunk*self.dbWriteChunckSize:(chunk+1)*self.dbWriteChunckSize].reset_index().to_csv(
#                             f"{e['temp']}.{chunkIndex}.tsv",
#                             sep='\t',
#                             index=False
#                         )
                        
                        self.__dict__[e['df']][chunk*self.dbWriteChunckSize:(chunk+1)*self.dbWriteChunckSize].reset_index().to_sql(
                            name=self.tablePrefix + e['temp'],
                            index=False,
    #                         dtype=blobs,
    #                         method=None,
                            if_exists='append',
                            con=self.db
                        )
                        chunkIndex+=1
                        
                        
                else:
#                     self.__dict__[e['df']].reset_index().to_csv(
#                         f"{e['temp']}.tsv",
#                         sep='\t',
#                         index=False
#                     )
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



            self.db.execute('INSERT INTO {prefix}{target} (SELECT * FROM {prefix}{temp}) ON DUPLICATE KEY UPDATE id=VALUES(id); DROP TABLE {prefix}{temp}'.format(temp=e['temp'],target=e['table'],prefix=self.tablePrefix))
        

    def sync(self):
        self.__connectDB()
        self.__getLastSync()

        self.getUpdates()
        
        if self.dbUpdate:
            self.syncUpdates()
            self.__setLastSync()
        
        self.statistics()

