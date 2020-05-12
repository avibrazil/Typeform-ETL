--
-- Database structure for TypeformETL
-- 
-- Designed by Avi Alkalay <avi at unix dot sh>
--


--
-- Table structure for table tf_forms
--

DROP TABLE IF EXISTS tf_forms;
CREATE TABLE tf_forms (
  id tinytext CHARACTER SET ascii NOT NULL COMMENT 'Typeform form ID',
  workspace tinytext DEFAULT NULL COMMENT 'Typeform workspace ID',
  updated timestamp NULL DEFAULT NULL COMMENT 'When form was last updated, UTC time',
  url varchar(1000) DEFAULT NULL COMMENT 'Typeform URL that capture answers from humans',
  title text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Title of the form',
  description mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (id(12)),
  UNIQUE KEY id_UNIQUE (id(12))
) DEFAULT CHARSET=utf8 COMMENT='A Typeform form';




--
-- Table structure for table tf_form_items
--

DROP TABLE IF EXISTS tf_form_items;
CREATE TABLE tf_form_items (
  id tinytext NOT NULL COMMENT 'Typeform form field ID',
  form tinytext CHARACTER SET ascii NOT NULL COMMENT 'Form ID that owns this field',
  name tinytext DEFAULT NULL COMMENT 'Field slug',
  type tinytext DEFAULT NULL COMMENT 'Semantic data type',
  title text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'field title',
  PRIMARY KEY (id(12)),
  UNIQUE KEY id_UNIQUE (id(12)),
  KEY fk_form_items_forms_idx (form(12)),
  KEY name_idx (name(45)),
  KEY type_idx (type(15))
) DEFAULT CHARSET=utf8 COMMENT='A Typeform form field';




--
-- Table structure for table tf_responses
--

DROP TABLE IF EXISTS tf_responses;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE tf_responses (
  id tinytext NOT NULL COMMENT 'Typeform response ID',
  form tinytext CHARACTER SET ascii NOT NULL COMMENT 'Form ID that this response refers to',
  landed timestamp NULL DEFAULT NULL COMMENT 'When user landed in form, UTC time',
  submitted timestamp NULL DEFAULT NULL COMMENT 'When user submitted the form, UTC time. If this is NULL, means used didn’t submit.',
  agent text DEFAULT NULL COMMENT 'user agent, a.k.a. browser',
  referer text DEFAULT NULL COMMENT 'referer URL',
  PRIMARY KEY (id(35)),
  UNIQUE KEY id_UNIQUE (id(35)),
  KEY fk_response_forms_idx (form(12)),
  KEY submitted_idx (submitted)
) DEFAULT CHARSET=utf8 COMMENT='A Typeform user response without the response fields';







--
-- Table structure for table tf_answers
--

DROP TABLE IF EXISTS tf_answers;
CREATE TABLE tf_answers (
  id tinytext NOT NULL COMMENT 'Computed unique and deterministic field answer ID',
  form tinytext CHARACTER SET ascii NOT NULL COMMENT 'Form ID that this answer refers to',
  response tinytext CHARACTER SET ascii NOT NULL COMMENT 'Response ID that this answer refers to',
  field tinytext DEFAULT NULL COMMENT 'Field ID that this answer refers to',
  data_type_hint tinytext DEFAULT NULL COMMENT 'Basic data type of answer',
  answer longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Actual user answer for the [hidden] field',
  PRIMARY KEY (id(14)),
  UNIQUE KEY id_UNIQUE (id(14)),
  KEY fk_answer_forms_idx (form(12)),
  KEY fk_answer_responses_idx (response(35)),
  KEY fk_answer_form_items_idx (field(14)),
  KEY data_type_idx (data_type_hint(15))
) DEFAULT CHARSET=utf8 COMMENT='A Typeform user response for each [hidden] field';









--
-- Table structure for table tf_options
--

DROP TABLE IF EXISTS tf_options;
CREATE TABLE tf_options (
  id int(10) unsigned NOT NULL AUTO_INCREMENT,
  name text NOT NULL,
  value text DEFAULT NULL,
  comment text DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY id_UNIQUE (id),
  KEY optname (name(45))
) DEFAULT CHARSET=utf8 COMMENT='Holds random app options';








--
-- Table structure for table tf_synclog
--

DROP TABLE IF EXISTS tf_synclog;
CREATE TABLE tf_synclog (
  id int(11) NOT NULL AUTO_INCREMENT,
  timestamp timestamp NULL DEFAULT NULL COMMENT 'UTC time of last sync',
  forms int(10) unsigned DEFAULT 0 COMMENT 'Number of forms read in this sync',
  form_items int(10) unsigned DEFAULT 0 COMMENT 'Number of form fields read in this sync',
  responses int(10) unsigned DEFAULT 0 COMMENT 'Number of responses written in this sync',
  answers int(10) unsigned DEFAULT 0 COMMENT 'Number of answers written in this sync',
  PRIMARY KEY (id)
) DEFAULT CHARSET=utf8;






--
-- View definition for tf_suser_answers
--

DROP VIEW IF EXISTS tf_super_answers;
CREATE OR REPLACE VIEW tf_super_answers AS
with answer as (
	select
		answers.id AS id,
		answers.response as response,
		form_items.name AS field_name,
		form_items.type AS type,
		form_items.title AS field_title,
		answers.data_type_hint AS data_type_hint,
		answers.answer AS answer
	from
		tf_answers as answers,
		tf_form_items as form_items
	where
		form_items.id = answers.field
)
select
	answer.id AS id,
	responses.id AS response_id,
	responses.landed as landed,
	responses.submitted AS submitted,
	forms.id as form_id,
	forms.title as form_title,
	answer.field_name,
	answer.type,
	answer.field_title,
	answer.data_type_hint,
	answer.answer
from
	tf_responses as responses
	join tf_forms as forms on forms.id = responses.form
	left outer join answer on answer.response = responses.id







--
-- View definition for tf_nps_daily
--

DROP VIEW IF EXISTS tf_nps_daily ;
CREATE OR REPLACE VIEW tf_nps_daily AS 
select
	a.form as form_id,
	fi.name as field_name,
	r.submitted as date,
	fi.type as type,
	f.title as form_title,
	fi.title as field_title,
	
 	((count(case when a.answer>=9 then 1 else NULL end) over day)-(count(case when a.answer<7 then 1 else NULL end) over day))/(count(a.answer) over day) as NPS_ofdate,
	count(case when a.answer<7 then 1 else NULL end) over day as detractors,
	count(case when a.answer between 7 and 8 then 1 else NULL end) over day as passives,
	count(case when a.answer>=9 then 1 else NULL end) over day as promoters,
	count(a.answer) over day as total,
	
    ((count(case when a.answer>=9 then 1 else NULL end) over untilday)-(count(case when a.answer<7 then 1 else NULL end) over untilday))/(count(a.answer) over untilday) as NPS_cumulative,
	count(case when a.answer<7 then 1 else NULL end) over untilday as detr_cumulative,
	count(case when a.answer between 7 and 8 then 1 else NULL end) over untilday as pass_cumulative,
	count(case when a.answer>=9 then 1 else NULL end) over untilday as prom_cumulative,
	count(a.answer) over untilday as totl_cumulative
from
	tf_answers a,
	tf_responses r,
	tf_form_items fi,
	tf_forms f
where
	a.data_type_hint in ('number')
	and r.submitted is not NULL
	and r.id = a.response
	and fi.id = a.field
	and fi.form = a.form
	and f.id = a.form
window
	day as (partition by date(r.submitted), a.form, a.field),
	untilday as (partition by a.form, a.field order by r.submitted asc rows unbounded preceding)
order by
	a.form, a.field, r.submitted asc;





--
-- View definition for tf_nps
--

DROP VIEW IF EXISTS tf_nps;
CREATE OR REPLACE VIEW tf_nps AS
select
	a.form as form_id,
	fi.name as field_name,
	min(r.submitted) as first,
	max(r.submitted) as last,
	fi.type as type,
	f.title as form_title,
	fi.title as field_title,
 	((count(case when a.answer>=9 then 1 else NULL end))-(count(case when a.answer<7 then 1 else NULL end)))/(count(a.answer)) as NPS,
	count(case when a.answer<7 then 1 else NULL end) as detractors,
	count(case when a.answer between 7 and 8 then 1 else NULL end) as passives,
	count(case when a.answer>=9 then 1 else NULL end) as promoters,
	count(a.answer) as total,
	avg(a.answer) as average,
	std(a.answer) as std_deviation
from
	tf_answers a,
	tf_responses r,
	tf_form_items fi,
	tf_forms f
where
	a.data_type_hint in ('number')
	and r.submitted is not NULL
	and r.id = a.response
	and fi.id = a.field
	and fi.form = a.form
	and f.id = a.form
group by
	form_id, field_name
order by
	a.form, a.field, r.submitted asc







START TRANSACTION;
INSERT INTO tf_options (id, name, value, comment) VALUES (DEFAULT, 'typeform_last', NULL, 'UTC time of last recorded answer');
COMMIT;

