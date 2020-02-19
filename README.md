# Typeform ETL

A python class and main function to extract and continuously sync data from a Typeform.com account.

## Installation

```shell
pip3 install TypeformETL --user
```

## Usage

### With CRON

I have these 2 entries at the same time on my crontab:

```shell
@hourly cd /home/aviram/src/Typeform-ETL && ./Typeform.py
30 3 * * 0 cd /home/aviram/src/Typeform-ETL && ./Typeform.py --restart
```

Which will run a sync every hour. And once a week will reset data tables and bring all data from scratch.

### With plain command line

```shell

```

### Into a Python program

```python
from TypeformETL import TypeformETL

tf = TypeformSync(
	token=context['typeform_token'],
	dburl=context['database'],
	restart=context['restart'],
	dbupdate=context['dbupdate'],
	tableprefix=context['tableprefix']
)


# Read Typeform updates and write to DB
tf.sync()
```

## Database
A SQL database must exist. MySQL and MariaDB tested.

Having “tf_” as a table prefix, these are the objects (tables and views) that will be created and updated:

| Table/View        | Name             | Contents                                                                                                                                  |
|-------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| table             | tf_forms         | Contains metadata about forms                                                                                                             |
| table             | tf_form_items    | Contains metadata about form items (text fields, checkboxes) related to their parent forms                                                |
| table             | tf_answers       | Contains all answers to all fields of all forms                                                                                           |
| table             | tf_responses     | Contains all responses to all forms; each form response has an entry here, each form field answer has an entry in the `tf_answers` table. |
| table             | tf_options       | Operational table used by the syncer                                                                                                      |
| table             | tf_synclog       | Operational table that logs every sync with some simple statistics                                                                        |
| view              | tf_super_answers | A convenient view that joins together table `tf_answers`, `tf_responses`, `tf_form_items`, `tf_forms`                                     |
| view              | tf_nps           | The calculated current NPS (Net Promoter Score) of all numerical fields (only a few fields might have a real NPS semantic)                |
| materialized view | tf_nps_daily_mv  | Since `tf_nps_daily` takes a long time to be calculated, this table has a pre-calculated copy of its data. Use it instead of `tf_nps_daily`    |
| view              | tf_nps_daily     | The NPS of all numerical fields per day; can be used to see evolution of some NPS along time.                                             |
| view              | tf__nps_daily    | Auxiliary view used to calculate cumulative NPS                                                                                           |

The module makes `INSERT`, `UPDATE`, `CREATE TABLE`, `DROP TABLE`, `TRUNCATE` operations. Make sure its user has granted permission to all these operations.