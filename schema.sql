-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema «omitted»
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
  `id` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Typeform response ID',
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

CREATE INDEX `submitted` ON `responses` (`submitted`(15) ASC);


-- -----------------------------------------------------
-- Table `form_items`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `form_items` ;

CREATE TABLE IF NOT EXISTS `form_items` (
  `id` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Typeform form field ID',
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

CREATE INDEX `name` ON `form_items` (`name`(45) ASC);


-- -----------------------------------------------------
-- Table `answers`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `answers` ;

CREATE TABLE IF NOT EXISTS `answers` (
  `id` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Computed unique and deterministic field answer ID',
  `form` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Form ID that this answer refers to',
  `response` TINYTEXT CHARACTER SET 'ascii' NOT NULL COMMENT 'Response ID that this answer refers to',
  `field` TINYTEXT NULL DEFAULT NULL COMMENT 'Field ID that this answer refers to',
  `data_type_hint` TINYTEXT NULL COMMENT 'Basic data type of answer',
  `answer` TEXT NULL DEFAULT NULL COMMENT 'Actual user answer for the [hidden] field',
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


SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;

-- -----------------------------------------------------
-- Data for table `options`
-- -----------------------------------------------------
START TRANSACTION;
INSERT INTO `options` (`id`, `name`, `value`, `comment`) VALUES (DEFAULT, 'typeform_last', NULL, 'hora da última resposta gravada, em UTC');

COMMIT;

