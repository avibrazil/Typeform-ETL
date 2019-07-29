-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema braseg
-- -----------------------------------------------------

-- -----------------------------------------------------
-- Table `forms`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `forms` ;

CREATE TABLE IF NOT EXISTS `forms` (
  `id` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Typeform form ID',
  `workspace` TINYTEXT NULL DEFAULT NULL COMMENT 'Typeform workspace ID',
  `updated` TIMESTAMP NULL DEFAULT NULL COMMENT 'When form was last updated, UTC time',
  `url` VARCHAR(1000) NULL DEFAULT NULL COMMENT 'Typeform URL that capture answers from humans',
  `title` TEXT NULL DEFAULT NULL COMMENT 'Title of the form',
  `description` MEDIUMTEXT NULL DEFAULT NULL,
  PRIMARY KEY (`id`(12)))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8
COMMENT = 'A Typeform form';

CREATE UNIQUE INDEX `id_UNIQUE` ON `forms` (`id`(12) ASC);


-- -----------------------------------------------------
-- Table `responses`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `responses` ;

CREATE TABLE IF NOT EXISTS `responses` (
  `id` TINYTEXT CHARACTER SET 'utf8mb4' NOT NULL COMMENT 'Typeform response ID',
  `form` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Form ID that this response refers to',
  `landed` TIMESTAMP NULL COMMENT 'When user landed in form, UTC time',
  `submitted` TIMESTAMP NULL COMMENT 'When user submitted the form, UTC time. If this is year 1970, means used didn’t submit.',
  `agent` TEXT NULL DEFAULT NULL COMMENT 'user agent, a.k.a. browser',
  `referer` TEXT NULL DEFAULT NULL COMMENT 'referer URL',
  PRIMARY KEY (`id`(35)))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8
COMMENT = 'A Typeform user response without the response fields';

CREATE UNIQUE INDEX `id_UNIQUE` ON `responses` (`id`(35) ASC);

CREATE INDEX `fk_response_forms_idx` ON `responses` (`form`(12) ASC);

CREATE INDEX `submitted_idx` ON `responses` (`submitted`(4) ASC);


-- -----------------------------------------------------
-- Table `form_items`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `form_items` ;

CREATE TABLE IF NOT EXISTS `form_items` (
  `id` TINYTEXT CHARACTER SET 'utf8mb4' NOT NULL COMMENT 'Typeform form field ID',
  `form` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Form ID that owns this field',
  `name` TINYTEXT NULL DEFAULT NULL COMMENT 'Field slug',
  `type` TINYTEXT NULL DEFAULT NULL COMMENT 'Semantic data type',
  `title` TEXT NULL DEFAULT NULL COMMENT 'field title',
  PRIMARY KEY (`id`(12)))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8
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
  `id` TINYTEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_general_ci' NOT NULL COMMENT 'Computed unique and deterministic field answer ID',
  `form` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Form ID that this answer refers to',
  `response` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Response ID that this answer refers to',
  `field` TINYTEXT NULL DEFAULT NULL COMMENT 'Field ID that this answer refers to',
  `data_type_hint` TINYTEXT NULL COMMENT 'Basic data type of answer',
  `answer` LONGTEXT CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_bin' NULL DEFAULT NULL COMMENT 'Actual user answer for the [hidden] field',
  PRIMARY KEY (`id`(14)))
ENGINE = InnoDB
DEFAULT CHARACTER SET = utf8
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
-- View `super_answers`
-- -----------------------------------------------------
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
DROP VIEW IF EXISTS `nps_daily` ;
CREATE OR REPLACE VIEW nps_daily AS
SELECT tot.form_id,
       tot.field_name,
       tot.date_tag AS date,
       tot.type,
       tot.form_title,
       tot.field_title,
       (prom.count / tot.count) - (det.count / tot.count) AS NPS,
       det.count AS detratores,
       neut.count AS neutros,
       prom.count AS promotores,
       tot.count
FROM
  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          COUNT(answer) AS count
   FROM super_answers
   WHERE answer <= 6
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS det,

  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          COUNT(answer) AS count
   FROM super_answers
   WHERE answer >= 7
     AND answer <= 8
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS neut,

  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          COUNT(answer) AS count
   FROM super_answers
   WHERE answer >= 9
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS prom,

  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          max(submitted) AS latest,
          form_title,
          field_title,
          TYPE,
          COUNT(answer) AS count
   FROM super_answers
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS tot

WHERE det.form_id = neut.form_id
  AND neut.form_id = prom.form_id
  AND prom.form_id = tot.form_id
  AND det.field_name = neut.field_name
  AND neut.field_name = prom.field_name
  AND prom.field_name = tot.field_name
  AND det.date_tag = neut.date_tag
  AND neut.date_tag = prom.date_tag
  AND prom.date_tag = tot.date_tag;

-- -----------------------------------------------------
-- View `nps`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `nps` ;
CREATE OR REPLACE VIEW nps AS
SELECT tot.form_id,
       tot.field_name,
       tot.type,
       tot.form_title,
       tot.field_title,
       tot.first,
       tot.latest,
       (prom.count / tot.count) - (det.count / tot.count) AS NPS,
       det.count AS detratores,
       neut.count AS neutros,
       prom.count AS promotores,
       tot.count,
       tot.average,
       tot.std_deviation
FROM
  (SELECT form_id,
          field_name,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE answer <= 6
   GROUP BY form_id,
            field_name) AS det,

  (SELECT form_id,
          field_name,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE answer >= 7
     AND answer <= 8
   GROUP BY form_id,
            field_name) AS neut,

  (SELECT form_id,
          field_name,
          COUNT(answer) AS COUNT
   FROM super_answers
   WHERE answer >= 9
   GROUP BY form_id,
            field_name) AS prom,

  (SELECT form_id,
          field_name,
          min(submitted) AS FIRST,
          max(submitted) AS latest,
          form_title,
          field_title,
          TYPE,
          avg(answer) AS average,
          stddev(answer) AS std_deviation,
          COUNT(answer) AS COUNT
   FROM super_answers
   GROUP BY form_id,
            field_name) AS tot
WHERE det.form_id = neut.form_id
  AND neut.form_id = prom.form_id
  AND prom.form_id = tot.form_id
  AND det.field_name = neut.field_name
  AND neut.field_name = prom.field_name
  AND prom.field_name = tot.field_name;

-- -----------------------------------------------------
-- View `nps_cumulative`
-- -----------------------------------------------------
DROP VIEW IF EXISTS `nps_cumulative` ;
CREATE OR REPLACE VIEW nps_cumulative AS
SELECT tot.form_id,
       tot.field_name,
       tot.date_tag AS date,
       tot.type,
       tot.form_title,
       tot.field_title,
       (prom.count / tot.count) - (det.count / tot.count) AS NPS,
       det.count AS detratores,
       neut.count AS neutros,
       prom.count AS promotores,
       tot.count
FROM
  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          COUNT(answer) AS count
   FROM super_answers
   WHERE answer <= 6
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS det,

  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          COUNT(answer) AS count
   FROM super_answers
   WHERE answer >= 7
     AND answer <= 8
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS neut,

  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          COUNT(answer) AS count
   FROM super_answers
   WHERE answer >= 9
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS prom,

  (SELECT form_id,
          field_name,
          DATE(submitted) AS date_tag,
          max(submitted) AS latest,
          form_title,
          field_title,
          TYPE,
          COUNT(answer) AS count
   FROM super_answers
   GROUP BY form_id,
            field_name,
            DATE(submitted)) AS tot

WHERE det.form_id = neut.form_id
  AND neut.form_id = prom.form_id
  AND prom.form_id = tot.form_id
  AND det.field_name = neut.field_name
  AND neut.field_name = prom.field_name
  AND prom.field_name = tot.field_name
  AND det.date_tag = neut.date_tag
  AND neut.date_tag = prom.date_tag
  AND prom.date_tag = tot.date_tag;

SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- -----------------------------------------------------
-- Data for table `options`
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO `options` (`id`, `name`, `value`, `comment`) VALUES (DEFAULT, 'typeform_last', NULL, 'hora da última resposta gravada, em UTC');

COMMIT;

