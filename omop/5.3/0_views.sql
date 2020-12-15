/**
 * Create Views
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