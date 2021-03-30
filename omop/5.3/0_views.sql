/**
 * Leaf OMOP 5.3 bootstrap script.
 * Create Views
 * Notes - The `dbo.v_death` view is needed because Leaf 
 *         assumes that any longitudinal SQL set (concretely,
 *         a set which has any sort of associated dates) *also* 
 *         contains an associated `visit_occurrence_id` column. 
 *
 *         As this is not the case with the OMOP `dbo.death` table,
 *         we add a view with a NULL'd out `visit_occurrence_id` to
 *         ensure SQL statement validity.
 */
CREATE OR ALTER VIEW dbo.v_death
AS
SELECT [person_id]
      ,[death_date]
      ,[death_datetime]
      ,[visit_occurrence_id] = NULL
      ,[death_type_concept_id]
      ,[cause_concept_id]
      ,[cause_source_value]
      ,[cause_source_concept_id]
FROM [dbo].[death]
GO