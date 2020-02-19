# Typeform ETL

A python class and main function to extract and continuously sync data from a Typeform.com account.

## Installation

### Requirements

You should prefer Python 3 packages from your operating system.

So under Fedora Linux:

```shell
dnf install python3-requests python3-sqlalchemy python3-pandas python3-configobj python3-mysql
```
Under Red Hat Enterprise Linux 8:

```shell
dnf install python3-requests python3-sqlalchemy python3-configobj mariadb-connector-c-devel mariadb-connector-c gcc
pip3 install mysqlclient --user
```
This MariaDB connector is the one that works with SQLAlchemy (used by the module). Other connectors as PyMySQL failed our tests.

Installing `mysqlclient` with `pip` requires compilers and MariaDB development framework pre-installed in the system, as shown in the Red Hat Enterprise Linux section.

### Install the module

```shell
pip3 install TypeformETL --user
```

All unsatisfied dependencies (such as Pandas on RHEL) will be installed along.

## Usage

### With plain command line

```shell
python3 -m TypeformETL --typeform "6w___API_KEY___nPZ" --database 'mysql://user:password@host/dbname'
```

Add `--restart` to get and sync all data from Typeform, not just last updates.

Add `--updatedb` to do everything but update database.

Add `--debug` to be more verbose.

### Config file

If you want to not pass arguments through command line, you can also use a config file.
Use `--config` to pass a config file name. By default, the main module will look for a file name called `syncFromTypeform.conf` in the current directory.
Arguments from config file and command line will be combined giving priority to the ones passed in command line.
So if a database URL is passed both in command line and config file, the command line will be used.

### With CRON

I have these 2 entries at the same time on my crontab:

```shell
@hourly python3 -m TypeformETL --typeform "6w___API_KEY___nPZ" --database 'mysql://user:password@host/dbname'
30 3 * * 0 python3 -m TypeformETL --typeform "6w___API_KEY___nPZ" --database 'mysql://user:password@host/dbname' --restart
```

Which will run a sync every hour. And once a week will reset data tables and bring all data from scratch.

### Into a Python program

```python
from TypeformETL import TypeformETL

tf = TypeformETL(
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

Having “`tf_`” as a table prefix, these are the objects (tables and views) that will be created and updated:

| Table/View        | Name             | Contents                                                                                                                                  |
|-------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| table             | `tf_forms`         | Contains metadata about forms                                                                                                             |
| table             | `tf_form_items`    | Contains metadata about form items (text fields, checkboxes) related to their parent forms                                                |
| table             | `tf_answers`       | Contains all answers to all fields of all forms; each complete form response has an entry in the `tf_responses` table.                                                                                           |
| table             | `tf_responses`     | Contains all responses and metadata to all forms; each form **response** has an entry here, each form field **answer** has an entry in the `tf_answers` table. |
| table             | `tf_options`       | Operational table used by the syncer                                                                                                      |
| table             | `tf_synclog`       | Operational table that logs every sync with some simple statistics                                                                        |
| view              | `tf_super_answers` | A convenient view that joins together table `tf_answers`, `tf_responses`, `tf_form_items`, `tf_forms`                                     |
| view              | `tf_nps`           | The calculated current [NPS (Net Promoter Score)](https://en.wikipedia.org/wiki/Net_Promoter) of all numerical fields (only a few fields might have a real NPS semantic)                |
| materialized view | `tf_nps_daily_mv`  | Since `tf_nps_daily` takes a long time to be calculated, this table has a pre-calculated copy of its data. Use it instead of `tf_nps_daily`    |
| view              | `tf_nps_daily`     | The NPS of all numerical fields per day; can be used to see evolution of some NPS along time.                                             |
| view              | `tf__nps_daily`    | Auxiliary view used to calculate cumulative NPS                                                                                           |

The module makes `INSERT`, `UPDATE`, `CREATE TABLE`, `DROP TABLE`, `TRUNCATE` operations. Make sure the database connection user has granted permission to all these operations.