--
-- Database structure for TypeformETL
-- 
-- Designed by Avi Alkalay <avi at unix dot sh>
--


-- If recreating the database from scratch, to avoid foreign key constrains, 
-- delete all tables first in this order:

DROP TABLE IF EXISTS tf_answers;
DROP TABLE IF EXISTS tf_responses;
DROP TABLE IF EXISTS tf_form_items;
DROP TABLE IF EXISTS tf_forms;




--
-- Table structure for table tf_forms
--

DROP TABLE IF EXISTS tf_forms;
CREATE TABLE tf_forms (
  id varchar(8) CHARACTER SET ascii NOT NULL COMMENT 'Typeform form ID',
  workspace varchar(8) DEFAULT NULL COMMENT 'Typeform workspace ID',
  updated timestamp NULL DEFAULT NULL COMMENT 'When form was last updated, UTC time',
  url text DEFAULT NULL COMMENT 'Typeform URL that capture answers from humans',
  title text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Title of the form',
  description text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (id)
) DEFAULT CHARSET=utf8 COMMENT='A Typeform form';




--
-- Table structure for table tf_form_items
--

DROP TABLE IF EXISTS tf_form_items;
CREATE TABLE tf_form_items (
  id varchar(30) CHARACTER SET ascii NOT NULL COMMENT 'Typeform form field ID',
  parent_id varchar(30) CHARACTER SET ascii DEFAULT NULL COMMENT 'Typeform form field parent ID',
  form varchar(8) CHARACTER SET ascii NOT NULL COMMENT 'Form ID that owns this field',
  position int unsigned NOT NULL COMMENT 'Field position or order in form',
  name varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Field slug',
  parent_name varchar(45) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Slug of parent field',
  type varchar(20) CHARACTER SET ascii DEFAULT NULL COMMENT 'Semantic data type',
  title text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'field title',
  description text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'field description',
  PRIMARY KEY (id),
  FOREIGN KEY fk_form_items_form (form) REFERENCES tf_forms(id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY fk_form_items_parent_id (parent_id) REFERENCES tf_form_items(id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY fk_form_items_parent_name (parent_name) REFERENCES tf_form_items(name) ON UPDATE CASCADE ON DELETE CASCADE,
  INDEX (name),
  INDEX (parent_id),
  INDEX (parent_name),
  INDEX (type)
) DEFAULT CHARSET=utf8 COMMENT='A Typeform form field';




--
-- Table structure for table tf_responses
--

DROP TABLE IF EXISTS tf_responses;
CREATE TABLE tf_responses (
  id varchar(45) CHARACTER SET ascii NOT NULL COMMENT 'Typeform response ID',
  form varchar(8) CHARACTER SET ascii NOT NULL COMMENT 'Form ID that this response refers to',
  ip_address varchar(40) CHARACTER SET ascii COMMENT 'From network_id',
  landed timestamp NULL DEFAULT NULL COMMENT 'When user landed in form, UTC time',
  submitted timestamp NULL DEFAULT NULL COMMENT 'When user submitted the form, UTC time. If this is NULL, means used didn’t submit.',
  agent text DEFAULT NULL COMMENT 'user agent, a.k.a. browser',
  referer text DEFAULT NULL COMMENT 'referer URL',
   KEY (id),
  FOREIGN KEY fk_responses_form (form) REFERENCES tf_forms(id) ON UPDATE CASCADE ON DELETE CASCADE,
  INDEX (landed),
  INDEX (submitted)
) DEFAULT CHARSET=utf8 COMMENT='A Typeform user response without the answered fields';







--
-- Table structure for table tf_answers
--

DROP TABLE IF EXISTS tf_answers;
CREATE TABLE tf_answers (
  id varchar(30) NOT NULL COMMENT 'Computed unique and deterministic field answer ID',
  form varchar(8) CHARACTER SET ascii NOT NULL COMMENT 'Form ID that this answer refers to',
  response varchar(45) CHARACTER SET ascii NOT NULL COMMENT 'Response ID that this answer refers to',
  sequence int unsigned NOT NULL COMMENT 'Sequence of answer inside the response',
  field varchar(30) CHARACTER SET ascii NOT NULL COMMENT 'Field ID that this answer refers to',
  data_type_hint varchar(20) DEFAULT NULL COMMENT 'Basic data type of answer',
  answer longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Actual user answer for the [hidden] field',
   KEY (id),
  FOREIGN KEY fk_answers_form (form) REFERENCES tf_forms(id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY fk_answers_response (response) REFERENCES tf_responses(id) ON UPDATE CASCADE ON DELETE CASCADE,
  FOREIGN KEY fk_answers_field (field) REFERENCES tf_form_items(id) ON UPDATE CASCADE ON DELETE CASCADE,
  INDEX (data_type_hint)
) DEFAULT CHARSET=utf8 COMMENT='A Typeform user response for each [hidden] field';









--
-- Table structure for table tf_options
--

DROP TABLE IF EXISTS tf_options;
CREATE TABLE tf_options (
  id int unsigned NOT NULL AUTO_INCREMENT,
  name varchar(30) NOT NULL,
  value varchar(200) DEFAULT NULL,
  comment varchar(255) DEFAULT NULL,
  PRIMARY KEY (id),
  INDEX (name)
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
		answers.id as id,
		answers.response as response,
		answers.sequence as sequence,
		form_items.id as field_id,
		form_items.parent_id as field_parent_id,
		form_items.parent_name as field_parent_name,
		form_items.position as position,
		form_items.name as field_name,
		form_items.type as type,
		form_items.title as field_title,
		form_items.description as field_description,
		answers.data_type_hint as data_type_hint,
		answers.answer as answer
	from tf_form_items as form_items
	left outer join tf_answers as answers
		on answers.field = form_items.id
)
select
	answer.id as id,
	responses.id as response_id,
	responses.ip_address as ip_address,
	responses.landed as landed,
	responses.submitted as submitted,
	forms.id as form_id,
	forms.title as form_title,
	answer.sequence as sequence,
	answer.field_id as field_id,
	answer.field_name,
	answer.field_parent_id as field_parent_id,
	answer.field_parent_name as field_parent_name,
	answer.position as position,
	answer.type,
	answer.field_title,
	answer.field_description,
	answer.data_type_hint,
	answer.answer
from
	tf_responses as responses
	join tf_forms as forms on forms.id = responses.form
	left outer join answer on answer.response = responses.id;







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
	a.form, a.field, r.submitted asc;







START TRANSACTION;
INSERT INTO tf_options (id, name, value, comment) VALUES (DEFAULT, 'typeform_last', NULL, 'UTC time of last recorded answer');
COMMIT;

