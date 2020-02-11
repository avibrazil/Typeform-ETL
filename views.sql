CREATE OR REPLACE VIEW tf_super_answers AS
SELECT answers.id,
       responses.submitted,
       forms.id AS form_id,
       forms.title AS form_title,
       form_items.name AS field_name,
       form_items.type,
       form_items.title AS field_title,
       answers.data_type_hint,
       answers.answer
FROM tf_answers,
     tf_responses,
     tf_form_items,
     tf_forms
WHERE tf_forms.id=tf_form_items.form
  AND tf_answers.form=tf_forms.id
  AND tf_answers.field=tf_form_items.id
  AND tf_answers.response=tf_responses.id

-----------------

CREATE OR REPLACE VIEW tf_nps_daily AS
select * from (
SELECT tot.form_id,
       tot.field_name,
       tot.date_tag,
       tot.type,
       tot.form_title,
       tot.field_title,
       tot.total,
       det.total AS detratores,
       neut.total AS neutros,
       prom.total AS promotores,
       CONCAT(100 * ((prom.total / tot.total) - (det.total / tot.total)), '%') AS NPS,
       acumtot.total AS acumulado_total
FROM
  (SELECT tf_form_id,
          tf_field_name,
          CONCAT(YEAR(submitted), '-', MONTH(submitted), '-', DAY(submitted)) AS date_tag,
          COUNT(answer) AS total
   FROM tf_super_answers
   WHERE answer <= 6
   GROUP BY form_id,
            field_name,
            YEAR(submitted),
            MONTH(submitted),
            DAY(submitted)) AS det,

  (SELECT form_id,
          field_name,
          CONCAT(YEAR(submitted), '-', MONTH(submitted), '-', DAY(submitted)) AS date_tag,
          COUNT(answer) AS total
   FROM tf_super_answers
   WHERE answer >= 7
     AND answer <= 8
   GROUP BY form_id,
            field_name,
            YEAR(submitted),
            MONTH(submitted),
            DAY(submitted)) AS neut,

  (SELECT form_id,
          field_name,
          CONCAT(YEAR(submitted), '-', MONTH(submitted), '-', DAY(submitted)) AS date_tag,
          COUNT(answer) AS total
   FROM tf_super_answers
   WHERE answer >= 9
   GROUP BY form_id,
            field_name,
            YEAR(submitted),
            MONTH(submitted),
            DAY(submitted)) AS prom,

  (SELECT form_id,
          field_name,
          CONCAT(YEAR(submitted), '-', MONTH(submitted), '-', DAY(submitted)) AS date_tag,
          max(submitted) AS latest,
          form_title,
          field_title,
          TYPE,
          COUNT(answer) AS total
   FROM tf_super_answers
   GROUP BY form_id,
            field_name,
            YEAR(submitted),
            MONTH(submitted),
            DAY(submitted)) AS tot,

WHERE det.form_id = neut.form_id
  AND neut.form_id = prom.form_id
  AND prom.form_id = tot.form_id
  AND det.field_name = neut.field_name
  AND neut.field_name = prom.field_name
  AND prom.field_name = tot.field_name
  AND det.date_tag = neut.date_tag
  AND neut.date_tag = prom.date_tag
  AND prom.date_tag = tot.date_tag

) as nps1,
  (SELECT form_id,
          field_name,
          CONCAT(max(YEAR(submitted)), '-', max(MONTH(submitted)), '-', max(DAY(submitted))) AS date_tag,
          submitted,
          form_title,
          field_title,
          TYPE,
          COUNT(answer) AS total
   FROM tf_super_answers
  where nps1.form_id=form_id
  AND nps1.field_name=field_name
   GROUP BY form_id,
            field_name) AS acumtot
where acumtot.submitted <= nps1.latest


-----------------
SELECT answers.id,
       responses.submitted,
       forms.id AS form_id,
       forms.title,
       form_items.name AS field_name,
       form_items.type,
       form_items.title AS field_title,
       answers.data_type_hint,
       answers.answer
FROM tf_answers AS answers,
     tf_responses AS responses,
     tf_form_items AS form_items,
     tf_forms AS forms
WHERE forms.id=form_items.form
  AND answers.form=forms.id
  AND answers.field=form_items.id
  AND answers.response=responses.id
  AND forms.id='APiACy'
  AND form_items.name='4772be8bd4f21ea2'
LIMIT 10


create view tf_super_answers
SELECT tf_answers.id,
       tf_responses.submitted,
       tf_forms.id AS form_id,
       tf_forms.title,
       tf_form_items.name AS field_name,
       tf_form_items.type,
       tf_form_items.title AS field_title,
       tf_answers.data_type_hint,
       tf_answers.answer
FROM tf_answers,
     tf_responses,
     tf_form_items,
     tf_forms
WHERE tf_forms.id=tf_form_items.form
  AND tf_answers.form=tf_forms.id
  AND tf_answers.field=tf_form_items.id
  AND tf_answers.response=tf_responses.id
         
         
         
  AND tf_forms.id='APiACy'
  AND tf_form_items.name='4772be8bd4f21ea2'






SELECT answers.id,
       responses.submitted,
       year(responses.submitted) AS YEAR,
       month(responses.submitted) AS MONTH,
       week(responses.submitted) AS WEEK,
       forms.id AS form_id,
       forms.title,
       form_items.name AS field_name,
       form_items.type,
       form_items.title AS field_title,
       answers.data_type_hint,
       count(answers.answer)
FROM tf_answers AS answers,
     tf_responses AS responses,
     tf_form_items AS form_items,
     tf_forms AS forms
WHERE forms.id=form_items.form
  AND answers.form=forms.id
  AND answers.field=form_items.id
  AND answers.response=responses.id
  AND forms.id='APiACy'
  AND form_items.name='4772be8bd4f21ea2'
GROUP BY year(responses.submitted),
         month(responses.submitted),
         day(responses.submitted)
