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
from datetime import datetime
from dateutil import parser as dateparser
import json
import requests
import pandas as pd
from configobj import ConfigObj    # dnf install python3-configobj
import sqlalchemy

config='syncFromTypeform.conf'

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
    dbWriteChunckSize=750 # records

    
    # DataFrames for updated tables of entities to be synced
    forms=None
    formItems=None
    responses=None
    answers=None
    
    # Logging
    response=None
    logger=None

    
    def __init__(self,token=None,dburl=None):
        self.token=token
        self.dbURL=dburl
        
        self.logger=logging.getLogger(__name__ + '.TypeformSync')

        self.typeformHeader={'Authorization': f'Bearer {self.token}'}
        
        

    def __connectDB(self):
        try:
            self.db=sqlalchemy.create_engine(self.dbURL)
        except sqlalchemy.exc.SQLAlchemyError as error:
            self.logger.error('Can’t connect to DB.', exc_info=True)
            raise error

            
            
            
            
    def __getLastSync(self):
        options=pd.read_sql("SELECT * FROM options;", self.db)

        self.lastSync = options[options.name=='typeform_last']['value'].values[0]
        if self.lastSync != None:
            self.lastSync = dateparser.parse(self.lastSync)
        else:
            self.lastSync = datetime(1970,1,1)


        
    def __setLastSync(self):
        lastData=self.responses['landed'].sort_values(ascending=False).head(1)[0]
        self.db.execute("UPDATE options SET value='{}' WHERE name='typeform_last'".format(lastData))
        
        
    def getWorkspaces(self):
        # Still unused
        workspaceColumns=['id', 'url', 'title']


    
    def getForms(self):
        forms=[]

        # This column order (and names) must match the respective table in the database
        formColumns=['id', 'workspace', 'updated', 'url', 'title','description']
        
        self.logger.debug('Requesting forms…')

        try:
            self.response=requests.get(self.formListURL.format(page=1),
                                  headers=self.typeformHeader).json()
        except requests.exceptions.RequestException as error:
            self.logger.error('Error trying to get forms.', exc_info=True)
            raise error

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

        self.logger.info('Number of forms: {}'.format(self.forms.shape[0]))

        del forms

        
        
    def getFormItems(self):
        field  = {}
        fields = []

        # This column order (and names) must match the respective table in the database
        formItemsColumns=['id','form','ref','type','title']

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
                    field['ref']                = f['ref']
                    field['type']               = f['type']
                    
                    if 'description' in f:
                        field['description']    = f['description']

                    fields.append(field)

            if 'hidden' in self.response:
                    idCalc=hashlib.new('shake_256')

                    field = {}
                    field['form']      = form
                    field['title']     = 'f'
                    field['ref']       = 'f'
                    field['type']      = 'hidden'

                    idCalc.update('{}hidden{}'.format(form,f).encode('utf-8'))
                    field['id']        = idCalc.hexdigest(5)

                    fields.append(field)

        self.formItems=pd.DataFrame(columns=formItemsColumns)
        self.formItems=self.formItems.append(fields)
        self.formItems.set_index('id',inplace=True)

        self.logger.info('Number of form items: {}'.format(self.formItems.shape[0]))

        del fields
        
        
        
    def getResponses(self):
        meta     = {}
        metas    = []
        answer   = {}
        answers  = []

        # This column order (and names) must match the respective table in the database
        metaColumns=['id', 'form', 'landed', 'submitted', 'agent', 'referer']
        answerColumns=['id', 'form', 'response', 'field', 'data_type_hint', 'answer']
        

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
                    
                    
                    self.logger.debug('Form «{}», submitted={}, looks like: {}'.format(form,completed,str(self.response)[:150]))

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
            
            if self.__dict__[e['df']].shape[0] > 1.25*self.dbWriteChunckSize:
                for chunk in range(0,math.ceil(self.__dict__[e['df']].shape[0]/self.dbWriteChunckSize)):
                    self.logger.debug('Writting «{df}» to DB: [{start}:{end}]'.format(
                        df=e['df'],
                        start=chunk*self.dbWriteChunckSize,
                        end=(chunk+1)*self.dbWriteChunckSize-1
                    ))
                    self.__dict__[e['df']][chunk*self.dbWriteChunckSize:(chunk+1)*self.dbWriteChunckSize-1].reset_index().to_sql(
                        name=e['temp'],
                        index=False,
                        if_exists='append',
                        con=self.db
                    )
            else:
                self.__dict__[e['df']].reset_index().to_sql(
                    name=e['temp'],
                    index=False,
                    if_exists='replace',
                    con=self.db
                )

            self.db.execute('REPLACE INTO {target} (SELECT * FROM {temp}); DROP TABLE {temp};'.format(temp=e['temp'],target=e['table']))
        

    def sync(self):
        self.__connectDB()
        self.__getLastSync()

        self.getUpdates()
        self.syncUpdates()
        
        self.__setLastSync()


        
        

def main():
    # Switch between INFO/DEBUG while running in production/developping:
    logging.getLogger().setLevel(logging.DEBUG)
    logging.getLogger('Typeform').setLevel(logging.DEBUG)
    logging.getLogger('urllib3.connectionpool').setLevel(logging.WARNING)

    context=ConfigObj(config)

    tf = TypeformSync(context['typeform_token'],context['database'])
    
    tf.sync()
    
    

if __name__ == "__main__":
    main()