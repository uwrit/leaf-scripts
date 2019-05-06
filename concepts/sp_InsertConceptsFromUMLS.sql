
-- =============================================
-- Author:		Nic Dobbins
-- Create date: 2019/05/06
-- Description:	Inserts Concepts by ontologies created 
--              dynamically by pulling from the sp_GetOntologyFromUMLS.
-- Comments:    Adapt this example sproc to populate 
--              Ontology-based concepts.
-- =============================================
CREATE PROCEDURE [dbo].[sp_Leaf_InsertConceptsFromUMLS]
	@OntologyType NVARCHAR(50),
	@DisplayTextPrefix NVARCHAR(100),
	@SqlSetId INT
AS
BEGIN
  
	CREATE TABLE #Output
	(
		AUI NVARCHAR(20) NULL,
		ParentAUI NVARCHAR(20) NULL,
		MinCode NVARCHAR(20) NULL,
		MaxCode NVARCHAR(20) NULL,
		CodeCount INT NULL,
		OntologyType NVARCHAR(20) NULL,
		SqlSetWhere NVARCHAR(1000) NULL,
		UiDisplayName NVARCHAR(400) NULL
	)

	INSERT INTO #Output
	EXEC dbo.sp_GetConceptOntologyFromUMLS @OntologyType
	
	INSERT INTO app.Concept
	(
       [ExternalId]
      ,[ExternalParentId]
      ,[IsPatientCountAutoCalculated]
      ,[IsNumeric]
      ,[IsParent]
      ,[IsRoot]
      ,[IsSpecializable]
      ,[SqlSetId]
      ,[SqlSetWhere]
      ,[UiDisplayName]
      ,[UiDisplayText]
      ,[AddDateTime]
      ,[ContentLastUpdateDateTime]
	)
	SELECT 
		[ExternalId]				   = 'UMLS_AUI:' + O.AUI
       ,[ExternalParentId]			   = 'UMLS_AUI:' + O.ParentAUI
       ,[IsPatientCountAutoCalculated] = 1
       ,[IsNumeric]					   = 0		
       ,[IsParent]					   = CASE WHEN EXISTS (SELECT 1 FROM #Output O2 WHERE O.AUI = O2.ParentAUI) THEN 1 ELSE 0 END
       ,[IsRoot]					   = CASE WHEN ParentAUI IS NULL THEN 1 ELSE 0 END
       ,[IsSpecializable]			   = 0
       ,[SqlSetId]					   = @SqlSetId
       ,[SqlSetWhere]				   = O.SqlSetWhere
       ,[UiDisplayName]				   = O.uiDisplayName
       ,[UiDisplayText]				   = @DisplayTextPrefix + ' ' + O.uiDisplayName
       ,[AddDateTime]				   = GETDATE()
       ,[ContentLastUpdateDateTime]    = GETDATE()
	FROM #Output O
	WHERE NOT EXISTS (SELECT 1
					  FROM app.Concept c
					  WHERE 'UMLS_AUI:' + o.AUI = c.ExternalID)

	-- Update Parent Linkage
	UPDATE app.Concept
	SET ParentId = p.Id
	FROM app.Concept c
		 INNER JOIN (SELECT p.Id, p.ParentId, p.ExternalId
					 FROM app.Concept p) p 
			ON c.ExternalParentID = p.ExternalID
	WHERE EXISTS (SELECT 1 FROM #Output o WHERE 'UMLS_AUI:' + o.AUI = c.ExternalId)

END
