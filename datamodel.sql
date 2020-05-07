-- MySQL dump 10.17  Distrib 10.3.17-MariaDB, for Linux (x86_64)
-- ------------------------------------------------------
-- Server version	10.3.17-MariaDB

--
-- Table structure for table `tf_answers`
--

DROP TABLE IF EXISTS `tf_answers`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tf_answers` (
  `id` tinytext NOT NULL COMMENT 'Computed unique and deterministic field answer ID',
  `form` tinytext CHARACTER SET ascii NOT NULL COMMENT 'Form ID that this answer refers to',
  `response` tinytext CHARACTER SET ascii NOT NULL COMMENT 'Response ID that this answer refers to',
  `field` tinytext DEFAULT NULL COMMENT 'Field ID that this answer refers to',
  `data_type_hint` tinytext DEFAULT NULL COMMENT 'Basic data type of answer',
  `answer` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Actual user answer for the [hidden] field',
  PRIMARY KEY (`id`(14)),
  UNIQUE KEY `id_UNIQUE` (`id`(14)),
  KEY `fk_answer_forms_idx` (`form`(12)),
  KEY `fk_answer_responses_idx` (`response`(35)),
  KEY `fk_answer_form_items_idx` (`field`(14)),
  KEY `data_type_idx` (`data_type_hint`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='A Typeform user response for each [hidden] field';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tf_form_items`
--

DROP TABLE IF EXISTS `tf_form_items`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tf_form_items` (
  `id` tinytext NOT NULL COMMENT 'Typeform form field ID',
  `form` tinytext CHARACTER SET ascii NOT NULL COMMENT 'Form ID that owns this field',
  `name` tinytext DEFAULT NULL COMMENT 'Field slug',
  `type` tinytext DEFAULT NULL COMMENT 'Semantic data type',
  `title` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'field title',
  PRIMARY KEY (`id`(12)),
  UNIQUE KEY `id_UNIQUE` (`id`(12)),
  KEY `fk_form_items_forms_idx` (`form`(12)),
  KEY `name_idx` (`name`(45)),
  KEY `type_idx` (`type`(15))
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='A Typeform form field';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tf_forms`
--

DROP TABLE IF EXISTS `tf_forms`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tf_forms` (
  `id` tinytext CHARACTER SET ascii NOT NULL COMMENT 'Typeform form ID',
  `workspace` tinytext DEFAULT NULL COMMENT 'Typeform workspace ID',
  `updated` timestamp NULL DEFAULT NULL COMMENT 'When form was last updated, UTC time',
  `url` varchar(1000) DEFAULT NULL COMMENT 'Typeform URL that capture answers from humans',
  `title` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Title of the form',
  `description` mediumtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  PRIMARY KEY (`id`(12)),
  UNIQUE KEY `id_UNIQUE` (`id`(12))
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='A Typeform form';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary table structure for view `tf_nps`
--

DROP TABLE IF EXISTS `tf_nps`;
/*!50001 DROP VIEW IF EXISTS `tf_nps`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `tf_nps` (
  `form_id` tinyint NOT NULL,
  `field_name` tinyint NOT NULL,
  `type` tinyint NOT NULL,
  `form_title` tinyint NOT NULL,
  `field_title` tinyint NOT NULL,
  `first` tinyint NOT NULL,
  `last` tinyint NOT NULL,
  `NPS` tinyint NOT NULL,
  `detractors` tinyint NOT NULL,
  `passives` tinyint NOT NULL,
  `promoters` tinyint NOT NULL,
  `total` tinyint NOT NULL,
  `average` tinyint NOT NULL,
  `std_deviation` tinyint NOT NULL
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Temporary table structure for view `tf_nps_daily`
--

DROP TABLE IF EXISTS `tf_nps_daily`;
/*!50001 DROP VIEW IF EXISTS `tf_nps_daily`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `tf_nps_daily` (
  `form_id` tinyint NOT NULL,
  `field_name` tinyint NOT NULL,
  `date` tinyint NOT NULL,
  `type` tinyint NOT NULL,
  `form_title` tinyint NOT NULL,
  `field_title` tinyint NOT NULL,
  `NPS_ofdate` tinyint NOT NULL,
  `detractors` tinyint NOT NULL,
  `passives` tinyint NOT NULL,
  `promoters` tinyint NOT NULL,
  `total` tinyint NOT NULL,
  `NPS_cumulative` tinyint NOT NULL,
  `detr_cumulative` tinyint NOT NULL,
  `pass_cumulative` tinyint NOT NULL,
  `prom_cumulative` tinyint NOT NULL,
  `totl_cumulative` tinyint NOT NULL
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `tf_options`
--

DROP TABLE IF EXISTS `tf_options`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tf_options` (
  `id` int(10) unsigned NOT NULL AUTO_INCREMENT,
  `name` text NOT NULL,
  `value` text DEFAULT NULL,
  `comment` text DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `id_UNIQUE` (`id`),
  KEY `optname` (`name`(45))
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8 COMMENT='Holds random app options';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tf_responses`
--

DROP TABLE IF EXISTS `tf_responses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tf_responses` (
  `id` tinytext NOT NULL COMMENT 'Typeform response ID',
  `form` tinytext CHARACTER SET ascii NOT NULL COMMENT 'Form ID that this response refers to',
  `landed` timestamp NULL DEFAULT NULL COMMENT 'When user landed in form, UTC time',
  `submitted` timestamp NULL DEFAULT NULL COMMENT 'When user submitted the form, UTC time. If this is year 1970, means used didn’t submit.',
  `agent` text DEFAULT NULL COMMENT 'user agent, a.k.a. browser',
  `referer` text DEFAULT NULL COMMENT 'referer URL',
  PRIMARY KEY (`id`(35)),
  UNIQUE KEY `id_UNIQUE` (`id`(35)),
  KEY `fk_response_forms_idx` (`form`(12)),
  KEY `submitted_idx` (`submitted`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='A Typeform user response without the response fields';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Temporary table structure for view `tf_super_answers`
--

DROP TABLE IF EXISTS `tf_super_answers`;
/*!50001 DROP VIEW IF EXISTS `tf_super_answers`*/;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
/*!50001 CREATE TABLE `tf_super_answers` (
  `id` tinyint NOT NULL,
  `submitted` tinyint NOT NULL,
  `form_id` tinyint NOT NULL,
  `form_title` tinyint NOT NULL,
  `field_name` tinyint NOT NULL,
  `type` tinyint NOT NULL,
  `field_title` tinyint NOT NULL,
  `data_type_hint` tinyint NOT NULL,
  `answer` tinyint NOT NULL
) ENGINE=MyISAM */;
SET character_set_client = @saved_cs_client;

--
-- Table structure for table `tf_synclog`
--

DROP TABLE IF EXISTS `tf_synclog`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tf_synclog` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `timestamp` timestamp NULL DEFAULT NULL COMMENT 'UTC time of last sync',
  `forms` int(10) unsigned DEFAULT 0 COMMENT 'Number of forms read in this sync',
  `form_items` int(10) unsigned DEFAULT 0 COMMENT 'Number of form fields read in this sync',
  `responses` int(10) unsigned DEFAULT 0 COMMENT 'Number of responses written in this sync',
  `answers` int(10) unsigned DEFAULT 0 COMMENT 'Number of answers written in this sync',
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=4604 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

-- Dump completed on 2020-05-07 19:35:07



CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW tf_nps_daily AS 
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



CREATE OR REPLACE
ALGORITHM = UNDEFINED VIEW `tf_nps` AS
select
    `f`.`form` AS `form_id`,
    `f`.`name` AS `field_name`,
    `f`.`type` AS `type`,
    `totl`.`form_title` AS `form_title`,
    `f`.`title` AS `field_title`,
    `totl`.`first` AS `first`,
    `totl`.`last` AS `last`,
    `prom`.`count` / `totl`.`count` - `detr`.`count` / `totl`.`count` AS `NPS`,
    coalesce(`detr`.`count`,
    0) AS `detractors`,
    coalesce(`pass`.`count`,
    0) AS `passives`,
    coalesce(`prom`.`count`,
    0) AS `promoters`,
    coalesce(`totl`.`count`,
    0) AS `total`,
    coalesce(`totl`.`average`,
    0) AS `average`,
    coalesce(`totl`.`std_deviation`,
    0) AS `std_deviation`
from
    ((((`braseg`.`tf_form_items` `f`
join (
    select
        `super_answers`.`form_id` AS `form_id`,
        `super_answers`.`field_name` AS `field_name`,
        min(`super_answers`.`submitted`) AS `first`,
        max(`super_answers`.`submitted`) AS `last`,
        `super_answers`.`form_title` AS `form_title`,
        `super_answers`.`field_title` AS `field_title`,
        `super_answers`.`type` AS `TYPE`,
        avg(`super_answers`.`answer`) AS `average`,
        std(`super_answers`.`answer`) AS `std_deviation`,
        count(`super_answers`.`answer`) AS `count`
    from
        `braseg`.`tf_super_answers` `super_answers`
    where
        `super_answers`.`data_type_hint` = 'number'
    group by
        `super_answers`.`form_id`,
        `super_answers`.`field_name`) `totl` on
    (`f`.`form` = `totl`.`form_id`
    and `f`.`name` = `totl`.`field_name`))
join (
    select
        `super_answers`.`form_id` AS `form_id`,
        `super_answers`.`field_name` AS `field_name`,
        count(`super_answers`.`answer`) AS `count`
    from
        `braseg`.`tf_super_answers` `super_answers`
    where
        `super_answers`.`answer` <= 6
        and `super_answers`.`data_type_hint` = 'number'
    group by
        `super_answers`.`form_id`,
        `super_answers`.`field_name`) `detr` on
    (`totl`.`form_id` = `detr`.`form_id`
    and `totl`.`field_name` = `detr`.`field_name`))
join (
    select
        `super_answers`.`form_id` AS `form_id`,
        `super_answers`.`field_name` AS `field_name`,
        count(`super_answers`.`answer`) AS `count`
    from
        `braseg`.`tf_super_answers` `super_answers`
    where
        `super_answers`.`answer` >= 7
        and `super_answers`.`answer` <= 8
        and `super_answers`.`data_type_hint` = 'number'
    group by
        `super_answers`.`form_id`,
        `super_answers`.`field_name`) `pass` on
    (`totl`.`form_id` = `pass`.`form_id`
    and `totl`.`field_name` = `pass`.`field_name`))
join (
    select
        `super_answers`.`form_id` AS `form_id`,
        `super_answers`.`field_name` AS `field_name`,
        count(`super_answers`.`answer`) AS `count`
    from
        `braseg`.`tf_super_answers` `super_answers`
    where
        `super_answers`.`answer` >= 9
        and `super_answers`.`data_type_hint` = 'number'
    group by
        `super_answers`.`form_id`,
        `super_answers`.`field_name`) `prom` on
    (`totl`.`form_id` = `prom`.`form_id`
    and `totl`.`field_name` = `prom`.`field_name`))



