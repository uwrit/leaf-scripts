/**
 * Labs
 * Notes: - Creates a heavily-modified, data-specific LOINC lab tree.
 *        - Assumes that the leaf-scripts LOINC table (https://github.com/uwrit/leaf-scripts/releases/tag/umls2020AB, download LOINC.sql.zip)
 *	        is included as 'dbo.LOINC' (and can be safely dropped after script has completed).
 *        - Creates a small persistent table called dbo.leaf_loinc_ontology within the OMOP database
 *          which Leaf uses to query with i2b2-style EXISTS SQL statements.
 */
BEGIN

    DECLARE @yes BIT = 1
    DECLARE @no  BIT = 0

	DECLARE @sqlset_person               INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.person')
    DECLARE @sqlset_visit_occurrence     INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.visit_occurrence')  
    DECLARE @sqlset_condition_occurrence INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.condition_occurrence')  
    DECLARE @sqlset_v_death              INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.v_death')  
    DECLARE @sqlset_device_exposure      INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.device_exposure')  
    DECLARE @sqlset_drug_exposure        INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.drug_exposure')  
    DECLARE @sqlset_measurement          INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.measurement')  
    DECLARE @sqlset_observation          INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.observation')  
    DECLARE @sqlset_procedure_occurrence INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.procedure_occurrence')  

	DECLARE @lab_root NVARCHAR(50) = 'lab'

	BEGIN TRY DROP TABLE #A END TRY BEGIN CATCH END CATCH
	SELECT * 
	INTO #A
	FROM dbo.LOINC

	CREATE NONCLUSTERED INDEX idx_temp ON #A ([ParentAUI],[AUI])

	/**
	 * Clean up names
	 */
	UPDATE #A
	SET UiDisplayName =  LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LEFT(UiDisplayName, CHARINDEX('(LNC', UiDisplayName) - 1),'&#x7C',''),'bld-ser-plas',''),';',''),')',''),'(','')))

	/**
	 * Take parent name out of child name
	 */
	UPDATE #A
	SET UiDisplayName = LTRIM(RTRIM(REPLACE(REPLACE(A.UiDisplayName, B.UiDisplayName,''),'.','')))
	FROM #A AS A
		 INNER JOIN (SELECT AUI, ParentAUI, UiDisplayName FROM #A) AS B
			ON A.ParentAUI = B.AUI

	/**
	 * Make sure name is capitalized
	 */
	UPDATE #A
	SET UiDisplayName = UPPER(LEFT(UiDisplayName,1)) + SUBSTRING(UiDisplayName,2, LEN(UiDisplayName))

	/**
	 * Remove extra spaces
	 */
	UPDATE #A
	SET UiDisplayName = LTRIM(RTRIM(REPLACE(REPLACE(REPLACE(UiDisplayName,'  ',' '),'+',' + '),'XXX','')))

	/**
	 * Remove meaningless starting and ending slashes
	 */
	UPDATE #A
	SET UiDisplayName = LTRIM(RTRIM(REPLACE(UiDisplayName,'/','')))
	WHERE UiDisplayName LIKE '/%'
		  OR UiDisplayName LIKE '%/'

	/**
	 * Find children with same name as parents
	 */
	BEGIN TRY DROP TABLE #redundant END TRY BEGIN CATCH END CATCH
	SELECT A.AUI
	INTO #redundant
	FROM #A AS A
		 INNER JOIN #A AS B
			ON A.ParentAUI = B.AUI
	WHERE A.UiDisplayName = B.UiDisplayName

	/**
	 * Remove and re-parent any labeled (why?) as 'XXX' or blank string
	 */
	INSERT INTO #redundant (AUI)
	SELECT A.AUI
	FROM #A AS A
	WHERE A.UiDisplayName = '' OR A.UiDisplayName LIKE '%XXX'

	/**
	 * Set grandparents to parents for redudantly named
	 */
	UPDATE #A
	SET ParentAUI = B.ParentAUI
	FROM #A AS A
		 INNER JOIN (SELECT AUI, ParentAUI FROM #A) AS B
			ON A.ParentAUI = B.AUI
	WHERE EXISTS (SELECT 1 FROM #redundant AS R WHERE A.ParentAUI = R.AUI)

	/**
	 * DELETE redundants
	 */
	DELETE #A
	FROM #A AS A
	WHERE EXISTS (SELECT 1 FROM #redundant AS R WHERE A.AUI = R.AUI)

	/**
	 * Create recursive tree to gather the concepts and test under the LABS LOINC concept.
	 * The [CodePath] column functions similarly to the [CONCEPT_PATH] column in i2b2.
	 */
	BEGIN TRY DROP TABLE #B END TRY BEGIN CATCH END CATCH
	; WITH A AS
	(
		SELECT 
			AUI
		  , ParentAUI
		  , MinCode
		  , MaxCode
		  , CodeCount
		  , UiDisplayName
		  , IsParent = CASE WHEN EXISTS (SELECT 1 FROM #A AS B WHERE B.ParentAUI = A.AUI) THEN 1 ELSE 0 END
		FROM #A AS A
		WHERE AUI != 'A28297684' /* Exclude 'NOTYETCATEG' */
	)
	, B AS
	(
		SELECT 
			AUI
		  , ParentAUI
		  , UiDisplayName
		  , MinCode
		  , MaxCode
		  , CodeCount
		  , IsParent
		  , CodePath = CONVERT(NVARCHAR(400),UiDisplayName)
		FROM A
		WHERE AUI = 'A28298479' /* Top parent */
		UNION ALL
		SELECT 
			A.AUI
		  , A.ParentAUI
		  , A.UiDisplayName
		  , A.MinCode
		  , A.MaxCode
		  , A.CodeCount
		  , A.IsParent
		  , CodePath = CONVERT(NVARCHAR(400), CASE A.IsParent WHEN 0 THEN B.CodePath ELSE B.CodePath + '\' + A.UiDisplayName END)
		FROM B INNER JOIN A
				ON A.ParentAUI = B.AUI
	)

	SELECT *
	INTO #B
	FROM B

	BEGIN TRY DROP TABLE #C END TRY BEGIN CATCH END CATCH
	SELECT DISTINCT
		B.AUI
	  , B.ParentAUI
	  , UiDisplayName = CASE B.IsParent WHEN 1 THEN B.UiDisplayName ELSE C.concept_name END
	  , B.IsParent
	  , CodePath      = CONVERT(VARCHAR(900), CASE B.IsParent WHEN 1 THEN B.CodePath ELSE B.CodePath + '\' + C.concept_code END)
	  , C.concept_id
	  , C.concept_code
	  , instance_count = (SELECT COUNT(DISTINCT person_id) FROM dbo.measurement AS M WHERE C.concept_id = M.measurement_concept_id)
	INTO #C
	FROM #B AS B
		 LEFT JOIN dbo.concept AS C
			ON B.IsParent = 0
			   AND B.MinCode = C.concept_code

	CREATE NONCLUSTERED INDEX IDX_CodePath ON #C (CodePath)

	/**
	 * DELETE labs with no measurement data
	 */
	DELETE FROM #C
	WHERE IsParent = 0
		  AND instance_count = 0

	/**
	 * Urinalysis
	 */
	BEGIN TRY DROP TABLE #D END TRY BEGIN CATCH END CATCH
	SELECT
		  C.AUI
		, C.ParentAUI
		, UiDisplayName = CASE C.CodePath WHEN 'Lab\UA' THEN 'Urinalysis' ELSE C.UiDisplayName END
		, C.CodePath
		, C.concept_id
		, C.concept_code
		, row_num = 
				CASE C.IsParent 
					 WHEN 1 THEN 1 
					 ELSE DENSE_RANK() OVER (PARTITION BY concept_code ORDER BY LEN(CodePath), CodePath) 
				END
		, instance_count =
			   CASE C.IsParent
					WHEN 1 THEN (SELECT SUM(ISNULL(C2.instance_count,0)) FROM #C AS C2 WHERE C2.IsParent = 0 AND C2.CodePath LIKE C.CodePath + '%')
					ELSE C.instance_count
			   END
	INTO #D
	FROM #C AS C
	WHERE C.CodePath LIKE 'Lab\UA%'
	      
	/**
	 * Chemistry
	 */
	INSERT INTO #D (AUI, ParentAUI, UiDisplayName, CodePath, concept_id, concept_code, row_num, instance_count)
	SELECT
		  C.AUI
		, C.ParentAUI
		, UiDisplayName = CASE C.CodePath WHEN 'Lab\Chemistry and Chemistry challenge\CHEM' THEN 'Chemistry' ELSE C.UiDisplayName END
		, CodePath = REPLACE(C.CodePath,'\Chemistry and Chemistry challenge','')
		, C.concept_id
		, C.concept_code
		, row_num = 
				CASE C.IsParent 
					 WHEN 1 THEN 1 
					 ELSE DENSE_RANK() OVER (PARTITION BY concept_code ORDER BY LEN(CodePath), CodePath) 
				END
		, instance_count =
			   CASE C.IsParent
					WHEN 1 THEN (SELECT SUM(ISNULL(C2.instance_count,0)) FROM #C AS C2 WHERE C2.IsParent = 0 AND C2.CodePath LIKE C.CodePath + '%')
					ELSE C.instance_count
			   END
	FROM #C AS C
	WHERE C.CodePath LIKE 'Lab\Chemistry and Chemistry challenge\CHEM%'

	/**
	 * Hematology
	 */
	INSERT INTO #D (AUI, ParentAUI, UiDisplayName, CodePath, concept_id, concept_code, row_num, instance_count)
	SELECT
		  C.AUI
		, C.ParentAUI
		, UiDisplayName = CASE C.CodePath WHEN 'Lab\HEM/BC' THEN 'Hematology' ELSE C.UiDisplayName END
		, C.CodePath
		, C.concept_id
		, C.concept_code
		, row_num = 
				CASE C.IsParent 
					 WHEN 1 THEN 1 
					 ELSE DENSE_RANK() OVER (PARTITION BY concept_code ORDER BY LEN(CodePath), CodePath) 
				END
		, instance_count =
			   CASE C.IsParent
					WHEN 1 THEN (SELECT SUM(ISNULL(C2.instance_count,0)) FROM #C AS C2 WHERE C2.IsParent = 0 AND C2.CodePath LIKE C.CodePath + '%')
					ELSE C.instance_count
			   END
	FROM #C AS C
	WHERE C.CodePath LIKE 'Lab\HEM/BC%'

	/**
	 * Antimicrobial Susceptibility
	 */
	INSERT INTO #D (AUI, ParentAUI, UiDisplayName, CodePath, concept_id, concept_code, row_num, instance_count)
	SELECT
		  C.AUI
		, C.ParentAUI
		, UiDisplayName = CASE C.CodePath WHEN 'Lab\Microbiology and Antimicrobial susceptibility\ABXBACT' THEN 'Antimicrobial Susceptibility' ELSE C.UiDisplayName END
		, C.CodePath
		, C.concept_id
		, C.concept_code
		, row_num = 
				CASE C.IsParent 
					 WHEN 1 THEN 1 
					 ELSE DENSE_RANK() OVER (PARTITION BY concept_code ORDER BY LEN(CodePath), CodePath) 
				END
		, instance_count =
			   CASE C.IsParent
					WHEN 1 THEN (SELECT SUM(ISNULL(C2.instance_count,0)) FROM #C AS C2 WHERE C2.IsParent = 0 AND C2.CodePath LIKE C.CodePath + '%')
					ELSE C.instance_count
			   END
	FROM #C AS C
	WHERE C.CodePath LIKE 'Lab\Microbiology and Antimicrobial susceptibility\ABXBACT%'

	/**
	 * Molecular Pathology
	 */
	INSERT INTO #D (AUI, ParentAUI, UiDisplayName, CodePath, concept_id, concept_code, row_num, instance_count)
	SELECT
		  C.AUI
		, C.ParentAUI
		, UiDisplayName = CASE C.CodePath WHEN 'Lab\MOLPATH' THEN 'Molecular Pathology' ELSE C.UiDisplayName END
		, C.CodePath
		, C.concept_id
		, C.concept_code
		, row_num = 
				CASE C.IsParent 
					 WHEN 1 THEN 1 
					 ELSE DENSE_RANK() OVER (PARTITION BY concept_code ORDER BY LEN(CodePath), CodePath) 
				END
		, instance_count =
			   CASE C.IsParent
					WHEN 1 THEN (SELECT SUM(ISNULL(C2.instance_count,0)) FROM #C AS C2 WHERE C2.IsParent = 0 AND C2.CodePath LIKE C.CodePath + '%')
					ELSE C.instance_count
			   END
	FROM #C AS C
	WHERE C.CodePath LIKE 'Lab\MOLPATH%'

	/**
	 * Serology
	 */
	INSERT INTO #D (AUI, ParentAUI, UiDisplayName, CodePath, concept_id, concept_code, row_num, instance_count)
	SELECT
		  C.AUI
		, C.ParentAUI
		, UiDisplayName = CASE C.CodePath WHEN 'Lab\SERO' THEN 'Serology' ELSE C.UiDisplayName END
		, C.CodePath
		, C.concept_id
		, C.concept_code
		, row_num = 
				CASE C.IsParent 
					 WHEN 1 THEN 1 
					 ELSE DENSE_RANK() OVER (PARTITION BY concept_code ORDER BY LEN(CodePath), CodePath) 
				END
		, instance_count =
			   CASE C.IsParent
					WHEN 1 THEN (SELECT SUM(ISNULL(C2.instance_count,0)) FROM #C AS C2 WHERE C2.IsParent = 0 AND C2.CodePath LIKE C.CodePath + '%')
					ELSE C.instance_count
			   END
	FROM #C AS C
	WHERE C.CodePath LIKE 'Lab\SERO%'

	/**
	 * Microbiology
	 */
	INSERT INTO #D (AUI, ParentAUI, UiDisplayName, CodePath, concept_id, concept_code, row_num, instance_count)
	SELECT
		  C.AUI
		, C.ParentAUI
		, UiDisplayName = CASE C.CodePath WHEN 'Lab\Microbiology and Antimicrobial susceptibility\MICRO' THEN 'Microbiology' ELSE C.UiDisplayName END
		, C.CodePath
		, C.concept_id
		, C.concept_code
		, row_num = 
				CASE C.IsParent 
					 WHEN 1 THEN 1 
					 ELSE DENSE_RANK() OVER (PARTITION BY concept_code ORDER BY LEN(CodePath), CodePath) 
				END
		, instance_count =
			   CASE C.IsParent
					WHEN 1 THEN (SELECT SUM(ISNULL(C2.instance_count,0)) FROM #C AS C2 WHERE C2.IsParent = 0 AND C2.CodePath LIKE C.CodePath + '%')
					ELSE C.instance_count
			   END
	FROM #C AS C
	WHERE C.CodePath LIKE 'Lab\Microbiology and Antimicrobial susceptibility\MICRO%'

	/**
	 * Coagulation
	 */
	INSERT INTO #D (AUI, ParentAUI, UiDisplayName, CodePath, concept_id, concept_code, row_num, instance_count)
	SELECT
		  C.AUI
		, C.ParentAUI
		, UiDisplayName = CASE C.CodePath WHEN 'Lab\COAG' THEN 'Coagulation' ELSE C.UiDisplayName END
		, C.CodePath
		, C.concept_id
		, C.concept_code
		, row_num = 
				CASE C.IsParent 
					 WHEN 1 THEN 1 
					 ELSE DENSE_RANK() OVER (PARTITION BY concept_code ORDER BY LEN(CodePath), CodePath) 
				END
		, instance_count =
			   CASE C.IsParent
					WHEN 1 THEN (SELECT SUM(ISNULL(C2.instance_count,0)) FROM #C AS C2 WHERE C2.IsParent = 0 AND C2.CodePath LIKE C.CodePath + '%')
					ELSE C.instance_count
			   END
	FROM #C AS C
	WHERE C.CodePath LIKE 'Lab\COAG%'

	/**
	 * Prune any branches that have no actual tests under them
	 */
	BEGIN TRY DROP TABLE #E END TRY BEGIN CATCH END CATCH
	SELECT
		 AUI
	   , ParentAUI
	   , UiDisplayName
	   , CodePath
	   , concept_id
	   , concept_code
	   , row_num
	   , instance_count
	INTO #E
	FROM #D AS D
	WHERE D.ROW_NUM = 1
		  AND ISNULL(D.INSTANCE_COUNT,0) > 0

	/**
	 * Remove any duplicate rows and reparent
	 */
	BEGIN TRY DROP TABLE #dupes END TRY BEGIN CATCH END CATCH
	; WITH E AS
	(
		SELECT 
			 AUI
		   , ParentAUI
		   , UiDisplayName
		   , CodePath
		   , concept_id
		   , concept_code
		   , row_num = DENSE_RANK() OVER (PARTITION BY CodePath ORDER BY AUI) 
		FROM #E
		WHERE INSTANCE_COUNT > 0
	)

	/**
	 * CodePath duplicates
	 */
	SELECT 
		OldParentAUI     = E2.AUI
	  , NewParentAUI     = E1.AUI
	  , E1.UiDisplayName
	  , E1.CodePath
	  , OldUiDisplayName = E2.UiDisplayName
	  , OldCodePath		 = E2.CodePath
	INTO #dupes
	FROM E AS E2
		 INNER JOIN E AS E1
			ON E1.CodePath = E2.CodePath
	WHERE E2.ROW_NUM > 1 
		  AND E1.ROW_NUM = 1

	UPDATE #E
	SET ParentAUI = D.NewParentAUI
	FROM #E AS E
		 INNER JOIN #dupes AS D
			ON E.ParentAUI = D.OldParentAUI

	DELETE #E
	FROM #E AS E
	WHERE EXISTS (SELECT 1 FROM #dupes AS D WHERE E.AUI = D.OldParentAUI)

    /**
	 * Load value_as_concepts
	 */
	BEGIN TRY DROP TABLE #posneg END TRY BEGIN CATCH END CATCH
	SELECT 
	    F.CodePath
	  , F.concept_code
	  , F.UiDisplayName
	  , M.measurement_concept_id
	  , M.value_as_concept_id
	  , C.concept_name
	  , instance_count = COUNT(DISTINCT M.person_id)
	INTO #posneg
	FROM #F AS F
		 INNER JOIN dbo.measurement AS M
			ON F.concept_id = M.measurement_concept_id
		 INNER JOIN dbo.concept AS C
			ON M.value_as_concept_id = C.concept_id
	GROUP BY F.CodePath, F.concept_code, F.UiDisplayName, M.measurement_concept_id, M.value_as_concept_id, C.concept_name

	/**
	 * Final INSERT
	 */
	BEGIN TRY DROP TABLE #F END TRY BEGIN CATCH END CATCH
	; WITH F AS
	(
		SELECT 
			 AUI
		   , ParentAUI
		   , UiDisplayName
		   , CodePath
		   , ParentCodePath = (SELECT TOP 1 P.CodePath FROM #E AS P WHERE P.concept_code IS NULL AND E.CodePath LIKE P.CodePath + '%' AND E.CodePath != P.CodePath ORDER BY CodePath DESC)
		   , concept_id
		   , concept_code
		   , instance_count
		FROM #E AS E
		WHERE E.AUI != 'A28298479' /* Exclude "LABS" root */
	)
	SELECT *
	INTO #F
	FROM F
	WHERE instance_count > 0

    /* INSERT */
	INSERT INTO LeafDB.app.Concept (ExternalId, ExternalParentId, IsPatientCountAutoCalculated, IsNumeric, IsParent, IsRoot, IsSpecializable,
	                                SqlSetId, SqlSetWhere, UiDisplayName, UiDisplayText, UiDisplayTooltip, UiDisplayPatientCount,
	                                AddDateTime, ContentLastUpdateDateTime)

    /* Root */
    SELECT
		ExternalId					 = @lab_root
	  , ExternalParentId			 = NULL
	  , IsPatientCountAutoCalculated = @yes
	  , IsNumeric					 = @no
	  , IsParent					 = @yes
	  , IsRoot					     = @yes
	  , IsSpecializable			     = @no
	  , SqlSetId					 = @sqlset_measurement
	  , SqlSetWhere					 = 'EXISTS (SELECT 1 FROM dbo.leaf_loinc_ontology AS @O WHERE @.measurement_concept_id = @O.concept_id)'
	  , UiDisplayName				 = 'Labs'
	  , UiDisplayText				 = 'Had a laboratory test performed'
	  , UiDisplayTooltip			 = NULL
	  , UiDisplayPatientCount        = (SELECT COUNT(DISTINCT M.person_id) FROM dbo.measurement AS M WHERE M.measurement_concept_id IN (SELECT F.concept_id FROM #F AS F))
	  , AddDateTime				     = GETDATE()
	  , ContentLastUpdateDateTime	 = GETDATE()
    UNION ALL

    /* Labs */ 
	SELECT
		ExternalId					 = @lab_root + ':' + F.CodePath
	  , ExternalParentId			 = @lab_root + ':' + F.ParentCodePath
	  , IsPatientCountAutoCalculated = @yes
	  , IsNumeric					 = @no
	  , IsParent					 = CASE WHEN F.ParentCodePath IS NULL THEN @yes
									        WHEN EXISTS (SELECT 1 FROM #posneg AS PS WHERE F.CodePath = PS.CodePath) THEN @yes 
											ELSE @no 
									   END
	  , IsRoot					     = @no
	  , IsSpecializable			     = @no
	  , SqlSetId					 = @sqlset_measurement
	  , SqlSetWhere					 = 
			CASE 
				WHEN F.concept_code IS NOT NULL THEN '/* LOINC:' + F.concept_code  +' */ @.measurement_concept_id = ''' + CONVERT(NVARCHAR(20),F.concept_id) + '''' 
				ELSE 'EXISTS (SELECT 1 FROM dbo.leaf_loinc_ontology AS @O WHERE @O.CodePath LIKE ''' + F.CodePath + '%'' AND @.measurement_concept_id = @O.concept_id)' 
			END
	  , UiDisplayName				 = F.UiDisplayName
	  , UiDisplayText				 = 
			CASE 
				WHEN F.concept_code IS NOT NULL THEN 'Had a lab test for ' + F.UiDisplayName + ' performed'
				ELSE 'Had a laboratory test related to ' + F.UiDisplayName + ' performed'
			END
	  , UiDisplayTooltip			 = NULL
	  , UiDisplayPatientCount        = CASE WHEN F.concept_code IS NOT NULL THEN F.instance_count ELSE NULL END
	  , AddDateTime				     = GETDATE()
	  , ContentLastUpdateDateTime	 = GETDATE()
	FROM #F AS F
    UNION ALL

	/* Lab results (pos, neg, etc.) */ 
	SELECT
		ExternalId					 = @lab_root + ':' + F.CodePath + ':' + F.concept_name
	  , ExternalParentId			 = @lab_root + ':' + F.CodePath
	  , IsPatientCountAutoCalculated = @yes
	  , IsNumeric					 = @no
	  , IsParent					 = @no
	  , IsRoot					     = @no
	  , IsSpecializable			     = @no
	  , SqlSetId					 = @sqlset_measurement
	  , SqlSetWhere					 = '/* LOINC:' + F.concept_code  +' */ @.measurement_concept_id = ' + CONVERT(NVARCHAR(20),F.measurement_concept_id) + ' AND @.value_as_concept_id = ' + CONVERT(NVARCHAR(20),F.value_as_concept_id)
	  , UiDisplayName				 = F.concept_name
	  , UiDisplayText				 = 'Had a laboratory test for ' + F.UiDisplayName + ' performed that was ' + F.concept_name
	  , UiDisplayTooltip			 = NULL
	  , UiDisplayPatientCount        = F.instance_count
	  , AddDateTime				     = GETDATE()
	  , ContentLastUpdateDateTime	 = GETDATE()
	FROM #posneg AS F

	/*
	 * Set numeric concepts
	 */
	; WITH X AS
	(
		SELECT ExternalId   = @lab_root + ':' + F.CodePath
		FROM #F AS F
		WHERE EXISTS (SELECT 1 FROM dbo.measurement AS M WHERE M.value_as_number IS NOT NULL AND F.concept_id = M.measurement_concept_id)
	)
	UPDATE LeafDB.app.Concept
	SET [IsNumeric]          = @yes
	  , UiNumericDefaultText = 'of any result'
	  , SqlFieldNumeric      = '@.value_as_number'
	FROM LeafDB.app.Concept AS C
		 INNER JOIN X 
			ON C.ExternalId = X.ExternalId

	/**
	 * Create leaf_loinc_ontology table
	 */
	SELECT
		CodePath = CONVERT(VARCHAR(900), CodePath)
	  , ParentCodePath
	  , AUI
	  , ParentAUI
	  , concept_id
	  , concept_code
	  , instance_count
	INTO dbo.leaf_loinc_ontology
	FROM #F

    CREATE NONCLUSTERED INDEX idx_CodePath ON dbo.leaf_loinc_ontology (CodePath) INCLUDE (concept_id)

    /**
     * Set RootIds
     */
    ; WITH roots AS
    (
        SELECT 
              RootId           = C.Id
            , RootUiDisplayName = C.UiDisplayName
            , C.IsRoot
            , C.Id
            , C.ParentId
            , C.UiDisplayName
        FROM LeafDB.app.Concept AS C
        WHERE C.IsRoot = 1

        UNION ALL

        SELECT 
              roots.RootId
            , roots.RootUiDisplayName
            , C2.IsRoot
            , C2.Id
            , C2.ParentId
            , C2.UiDisplayName
        FROM roots
            INNER JOIN LeafDB.app.Concept AS C2
                ON C2.ParentId = roots.Id
    )

    UPDATE LeafDB.app.Concept
    SET RootId = roots.RootId
    FROM LeafDB.app.Concept AS C
        INNER JOIN roots
            ON C.Id = roots.Id
    WHERE C.RootId IS NULL

END