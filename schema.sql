-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema braseg
-- -----------------------------------------------------
-- utf8mb4_bin is the most compatible and emoji-ready charset I could find.

-- -----------------------------------------------------
-- Table `forms`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `forms` ;

CREATE TABLE IF NOT EXISTS `forms` (
  `id` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Typeform form ID',
  `workspace` TINYTEXT NULL DEFAULT NULL COMMENT 'Typeform workspace ID',
  `updated` TIMESTAMP NULL DEFAULT NULL COMMENT 'When form was last updated, UTC time',
  `url` VARCHAR(1000) NULL DEFAULT NULL COMMENT 'Typeform URL that capture answers from humans',
  `title` TEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_bin' NULL DEFAULT NULL COMMENT 'Title of the form',
  `description` MEDIUMTEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_bin' NULL DEFAULT NULL,
  PRIMARY KEY (`id`(12)))
ENGINE = InnoDB
COMMENT = 'A Typeform form';

CREATE UNIQUE INDEX `id_UNIQUE` ON `forms` (`id`(12) ASC);


-- -----------------------------------------------------
-- Table `responses`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `responses` ;

CREATE TABLE IF NOT EXISTS `responses` (
  `id` TINYTEXT NOT NULL COMMENT 'Typeform response ID',
  `form` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Form ID that this response refers to',
  `landed` TIMESTAMP NULL COMMENT 'When user landed in form, UTC time',
  `submitted` TIMESTAMP NULL COMMENT 'When user submitted the form, UTC time. If this is year 1970, means used didn’t submit.',
  `agent` TEXT NULL DEFAULT NULL COMMENT 'user agent, a.k.a. browser',
  `referer` TEXT NULL DEFAULT NULL COMMENT 'referer URL',
  PRIMARY KEY (`id`(35)))
ENGINE = InnoDB
COMMENT = 'A Typeform user response without the response fields';

CREATE UNIQUE INDEX `id_UNIQUE` ON `responses` (`id`(35) ASC);

CREATE INDEX `fk_response_forms_idx` ON `responses` (`form`(12) ASC);

CREATE INDEX `submitted_idx` ON `responses` (`submitted`(4) ASC);


-- -----------------------------------------------------
-- Table `form_items`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `form_items` ;

CREATE TABLE IF NOT EXISTS `form_items` (
  `id` TINYTEXT NOT NULL COMMENT 'Typeform form field ID',
  `form` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Form ID that owns this field',
  `name` TINYTEXT NULL DEFAULT NULL COMMENT 'Field slug',
  `type` TINYTEXT NULL DEFAULT NULL COMMENT 'Semantic data type',
  `title` TEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_bin' NULL DEFAULT NULL COMMENT 'field title',
  PRIMARY KEY (`id`(12)))
ENGINE = InnoDB
COMMENT = 'A Typeform form field';

CREATE UNIQUE INDEX `id_UNIQUE` ON `form_items` (`id`(12) ASC);

CREATE INDEX `fk_form_items_forms_idx` ON `form_items` (`form`(12) ASC);

CREATE INDEX `name_idx` ON `form_items` (`name`(45) ASC);

CREATE INDEX `type_idx` ON `form_items` (`type`(15) ASC);


-- -----------------------------------------------------
-- Table `answers`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `answers` ;

CREATE TABLE IF NOT EXISTS `answers` (
  `id` TINYTEXT NOT NULL COMMENT 'Computed unique and deterministic field answer ID',
  `form` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Form ID that this answer refers to',
  `response` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Response ID that this answer refers to',
  `field` TINYTEXT NULL DEFAULT NULL COMMENT 'Field ID that this answer refers to',
  `data_type_hint` TINYTEXT NULL COMMENT 'Basic data type of answer',
  `answer` LONGTEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_bin' NULL DEFAULT NULL COMMENT 'Actual user answer for the [hidden] field',
  PRIMARY KEY (`id`(14)))
ENGINE = InnoDB
COMMENT = 'A Typeform user response for each [hidden] field';

CREATE UNIQUE INDEX `id_UNIQUE` ON `answers` (`id`(14) ASC);

CREATE INDEX `fk_answer_forms_idx` ON `answers` (`form`(12) ASC);

CREATE INDEX `fk_answer_responses_idx` ON `answers` (`response`(35) ASC);

CREATE INDEX `fk_answer_form_items_idx` ON `answers` (`field`(14) ASC);

CREATE INDEX `data_type_idx` ON `answers` (`data_type_hint`(15) ASC);


-- -----------------------------------------------------
-- Table `options`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `options` ;

CREATE TABLE IF NOT EXISTS `options` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name` TEXT NOT NULL,
  `value` TEXT NULL,
  `comment` TEXT NULL DEFAULT NULL,
  PRIMARY KEY (`id`))
ENGINE = InnoDB
COMMENT = 'Holds random app options';

CREATE UNIQUE INDEX `id_UNIQUE` ON `options` (`id` ASC);

CREATE INDEX `optname` ON `options` (`name`(45) ASC);


-- -----------------------------------------------------
-- Table `synclog`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `synclog` ;

CREATE TABLE IF NOT EXISTS `synclog` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `timestamp` TIMESTAMP NULL COMMENT 'UTC time of last sync',
  `forms` INT UNSIGNED NULL DEFAULT 0 COMMENT 'Number of forms read in this sync',
  `form_items` INT UNSIGNED NULL DEFAULT 0 COMMENT 'Number of form fields read in this sync',
  `responses` INT UNSIGNED NULL DEFAULT 0 COMMENT 'Number of responses written in this sync',
  `answers` INT UNSIGNED NULL DEFAULT 0 COMMENT 'Number of answers written in this sync',
  PRIMARY KEY (`id`))
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Placeholder table for view `super_answers`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `super_answers` (`id` INT, `submitted` INT, `form_id` INT, `form_title` INT, `field_name` INT, `type` INT, `field_title` INT, `data_type_hint` INT, `answer` INT);

-- -----------------------------------------------------
-- Placeholder table for view `nps_daily`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `nps_daily` (`form_id` INT, `field_name` INT, `date` INT, `type` INT, `form_title` INT, `field_title` INT, `NPS_ofdate` INT, `detractors` INT, `passives` INT, `promoters` INT, `total` INT, `detr_cumulative` INT, `pass_cumulative` INT, `prom_cumulative` INT, `totl_cumulative` INT, `NPS_cumulative` INT);

-- -----------------------------------------------------
-- Placeholder table for view `nps`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `nps` (`form_id` INT, `field_name` INT, `type` INT, `form_title` INT, `field_title` INT, `first` INT, `last` INT, `NPS` INT, `detractors` INT, `passives` INT, `promoters` INT, `total` INT, `average` INT, `std_deviation` INT);

-- -----------------------------------------------------
-- Placeholder table for view `_nps_daily`
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `_nps_daily` (`form_id` INT, `field_name` INT, `DATE` INT, `type` INT, `form_title` INT, `field_title` INT, `NPS_ofdate` INT, `detractors` INT, `passives` INT, `promoters` INT, `total` INT, `detr_cumulative_count` INT, `pass_cumulative_count` INT, `prom_cumulative_count` INT, `totl_cumulative_count` INT);

-- -----------------------------------------------------
-- procedure refresh_nps_daily_mv
-- -----------------------------------------------------
DROP procedure IF EXISTS `refresh_nps_daily_mv`;

DELIMITER $$
CREATE PROCEDURE refresh_nps_daily_mv (OUT rc INT)
    BEGIN
        DROP TABLE nps_daily_mv;

        CREATE TABLE nps_daily_mv AS
        SELECT * FROM nps_daily;

        SET rc = 0;
    END;$$

DELIMITER ;

-- -----------------------------------------------------
-- View `super_answers`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `super_answers`;
DROP VIEW IF EXISTS `super_answers` ;
CREATE OR REPLACE VIEW super_answers AS
SELECT answers.id,
       responses.submitted,
       forms.id AS form_id,
       forms.title AS form_title,
       form_items.name AS field_name,
       form_items.type,
       form_items.title AS field_title,
       answers.data_type_hint,
       answers.answer
FROM answers,
     responses,
     form_items,
     forms
WHERE forms.id=form_items.form
  AND answers.form=forms.id
  AND answers.field=form_items.id
  AND answers.response=responses.id;

-- -----------------------------------------------------
-- View `nps_daily`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `nps_daily`;
DROP VIEW IF EXISTS `nps_daily` ;
CREATE  OR REPLACE VIEW nps_daily AS
SELECT form_id,
       field_name,
       date,
       type,
       form_title,
       field_title,
       NPS_ofdate,
       detractors,
       passives,
       promoters,
       total,
       detr_cumulative_count AS detr_cumulative,
       pass_cumulative_count AS pass_cumulative,
       prom_cumulative_count AS prom_cumulative,
       totl_cumulative_count AS totl_cumulative,
       (prom_cumulative_count / totl_cumulative_count) - (detr_cumulative_count / totl_cumulative_count) AS NPS_cumulative
FROM _nps_daily;

-- -----------------------------------------------------
-- View `nps`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `nps`;
DROP VIEW IF EXISTS `nps` ;
CREATE OR REPLACE VIEW nps AS
SELECT totl.form_id,
       totl.field_name,
       totl.type,
       totl.form_title,
       totl.field_title,
       totl.first,
       totl.last,
       (prom.count / totl.count) - (detr.count / totl.count) AS NPS,
       detr.count AS detractors,
       pass.count AS passives,
       prom.count AS promoters,
       totl.count AS total,
       totl.average,
       totl.std_deviation
FROM
  (SELECT form_id,
          field_name,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE answer <= 6
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name) AS detr,

  (SELECT form_id,
          field_name,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE answer >= 7
     AND answer <= 8
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name) AS pass,

  (SELECT form_id,
          field_name,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE answer >= 9
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name) AS prom,

  (SELECT form_id,
          field_name,
          min(submitted) AS FIRST,
          max(submitted) AS LAST,
          form_title,
          field_title,
          TYPE,
          avg(answer) AS average,
          stddev(answer) AS std_deviation,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE data_type_hint='number'
   GROUP BY form_id,
            field_name) AS totl
WHERE detr.form_id = pass.form_id
  AND pass.form_id = prom.form_id
  AND prom.form_id = totl.form_id
  AND detr.field_name = pass.field_name
  AND pass.field_name = prom.field_name
  AND prom.field_name = totl.field_name;

-- -----------------------------------------------------
-- View `_nps_daily`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `_nps_daily`;
DROP VIEW IF EXISTS `_nps_daily` ;
CREATE OR REPLACE VIEW _nps_daily AS
SELECT totl.form_id,
       totl.field_name,
       totl.date_tag AS DATE,
       totl.type,
       totl.form_title,
       totl.field_title,
       (prom.count / totl.count)-(detr.count / totl.count) AS NPS_ofdate,
       detr.count AS detractors,
       pass.count AS passives,
       prom.count AS promoters,
       totl.count AS total,

  (SELECT COUNT(answer)
   FROM super_answers a
   WHERE answer <= 6
     AND form_id = totl.form_id
     AND field_name = totl.field_name
     AND DATE(submitted) <= DATE
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name) AS detr_cumulative_count,

  (SELECT COUNT(answer)
   FROM super_answers a
   WHERE answer >= 7
     AND answer <= 8
     AND form_id = totl.form_id
     AND field_name = totl.field_name
     AND DATE(submitted) <= DATE
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name) AS pass_cumulative_count,

  (SELECT COUNT(answer)
   FROM super_answers a
   WHERE answer >= 9
     AND form_id = totl.form_id
     AND field_name = totl.field_name
     AND DATE(submitted) <= DATE
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name) AS prom_cumulative_count,

  (SELECT COUNT(answer)
   FROM super_answers a
   WHERE form_id = totl.form_id
     AND field_name = totl.field_name
     AND DATE(a.submitted) <= DATE
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name) AS totl_cumulative_count
FROM
  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE answer <= 6
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS detr,

  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE answer >= 7
     AND answer <= 8
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS pass,

  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE answer >= 9
     AND data_type_hint='number'
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS prom,

  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          MAX(submitted) AS latest,
          form_title,
          field_title,
          TYPE,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE data_type_hint='number'
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS totl
WHERE detr.form_id = pass.form_id
  AND pass.form_id = prom.form_id
  AND prom.form_id = totl.form_id
  AND detr.field_name = pass.field_name
  AND pass.field_name = prom.field_name
  AND prom.field_name = totl.field_name
  AND detr.date_tag = pass.date_tag
  AND pass.date_tag = prom.date_tag
  AND prom.date_tag = totl.date_tag
ORDER BY date;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- -----------------------------------------------------
-- Data for table `options`
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO `options` (`id`, `name`, `value`, `comment`) VALUES (DEFAULT, 'typeform_last', NULL, 'hora da última resposta gravada, em UTC');

COMMIT;

