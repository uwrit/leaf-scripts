/**
 * Leaf OMOP 5.3 bootstrap script.
 * Assumptions: TODO
 * License: TODO
 */

DECLARE @add_dx_icd10     BIT = 1
DECLARE @add_dx_icd9      BIT = 1
DECLARE @add_proc_icd10   BIT = 1
DECLARE @add_proc_icd9    BIT = 1
DECLARE @add_proc_cpt     BIT = 1
DECLARE @add_proc_hcpcs   BIT = 1
DECLARE @add_demographics BIT = 1
DECLARE @add_visits       BIT = 1
DECLARE @add_labs         BIT = 1
DECLARE @add_meds         BIT = 1
DECLARE @add_vitals       BIT = 1

DECLARE @yes BIT = 1
DECLARE @no  BIT = 0

DECLARE @user NVARCHAR(20) = 'bootstrap_omop.sql'

/**
 * Add OMOP SQL Sets to be queried in Leaf.
 */
INSERT INTO LeafDB.app.ConceptSqlSet (SqlSetFrom, IsEncounterBased, IsEventBased, SqlFieldDate, Created, CreatedBy, Updated, UpdatedBy)
SELECT *
FROM (VALUES ('dbo.person',               @no,  @no,  NULL,                              GETDATE(), @user, GETDATE(), @user),                          
             ('dbo.visit_occurrence',     @yes, @no, '@.visit_start_datetime',           GETDATE(), @user, GETDATE(), @user),
             ('dbo.condition_occurrence', @yes, @no, '@.condition_start_datetime',       GETDATE(), @user, GETDATE(), @user),
             ('dbo.v_death',              @yes, @no, '@.death_datetime',                 GETDATE(), @user, GETDATE(), @user),          
             ('dbo.device_exposure',      @yes, @no, '@.device_exposure_start_datetime', GETDATE(), @user, GETDATE(), @user),  
             ('dbo.drug_exposure',        @yes, @no, '@.drug_exposure_start_datetime',   GETDATE(), @user, GETDATE(), @user),
             ('dbo.measurement',          @yes, @no, '@.measurement_datetime',           GETDATE(), @user, GETDATE(), @user), 
             ('dbo.observation',          @yes, @no, '@.observation_datetime',           GETDATE(), @user, GETDATE(), @user),      
             ('dbo.procedure_occurrence', @yes, @no, '@.procedure_datetime',             GETDATE(), @user, GETDATE(), @user)
     ) AS X(col1,col2,col3,col4,col5,col6,col7,col8)

DECLARE @sqlset_person               INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.person')
DECLARE @sqlset_visit_occurrence     INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.visit_occurrence')  
DECLARE @sqlset_condition_occurrence INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.condition_occurrence')  
DECLARE @sqlset_v_death              INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.v_death')  
DECLARE @sqlset_device_exposure      INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.device_exposure')  
DECLARE @sqlset_drug_exposure        INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.drug_exposure')  
DECLARE @sqlset_measurement          INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.measurement')  
DECLARE @sqlset_observation          INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.observation')  
DECLARE @sqlset_procedure_occurrence INT = (SELECT TOP 1 Id FROM LeafDB.app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.procedure_occurrence')  

/**
 * Demographics
 */
IF @add_demographics = 1
BEGIN

    DECLARE @demog_root   NVARCHAR(50) = 'demographics'
    DECLARE @demog_gender NVARCHAR(50) = 'demographics:gender'
    DECLARE @demog_ethnic NVARCHAR(50) = 'demographics:ethnicity'
    DECLARE @demog_race   NVARCHAR(50) = 'demographics:race'
    DECLARE @demog_age    NVARCHAR(50) = 'demographics:age'
    DECLARE @demog_vital  NVARCHAR(50) = 'demographics:vital'

    ; WITH gender AS
    (
        SELECT C.concept_name, C.concept_id, cnt = COUNT(*), concept_id_string = CONVERT(NVARCHAR(50), C.concept_id)
        FROM dbo.person AS X INNER JOIN dbo.concept AS C
             ON X.gender_concept_id = C.concept_id
        WHERE X.gender_concept_id != 0
        GROUP BY C.concept_name, C.concept_id
    ), ethnicity AS
    (
        SELECT C.concept_name, C.concept_id, cnt = COUNT(*), concept_id_string = CONVERT(NVARCHAR(50), C.concept_id)
        FROM dbo.person AS X INNER JOIN dbo.concept AS C
             ON X.ethnicity_concept_id = C.concept_id
        WHERE X.ethnicity_concept_id != 0
        GROUP BY C.concept_name, C.concept_id
    ), race AS
    (
        SELECT C.concept_name, C.concept_id, cnt = COUNT(*), concept_id_string = CONVERT(NVARCHAR(50), C.concept_id)
        FROM dbo.person AS X INNER JOIN dbo.concept AS C
             ON X.race_concept_id = C.concept_id
        WHERE X.race_concept_id != 0
        GROUP BY C.concept_name, C.concept_id
    )

    /* INSERT */
    INSERT INTO LeafDB.app.Concept (ExternalId, ExternalParentId, [IsNumeric], IsParent, IsRoot, SqlSetId, SqlSetWhere, 
                                    SqlFieldNumeric, UiDisplayName, UiDisplayText, UiDisplayUnits, UiNumericDefaultText)
    
    /* Root */
    SELECT ExternalId           = @demog_root
         , ExternalParentId     = NULL
         , [IsNumeric]          = @no
         , IsParent             = @yes
         , IsRoot               = @yes
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = NULL
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = 'Demographics'
         , UiDisplayText        = 'Have demographics'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    UNION ALL

    /* Gender */
    SELECT ExternalId           = @demog_gender
         , ExternalParentId     = @demog_root
         , [IsNumeric]          = @no
         , IsParent             = @yes
         , IsRoot               = @no
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = NULL
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = 'Gender'
         , UiDisplayText        = 'Have gender data'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    UNION ALL
    SELECT ExternalId           = @demog_gender + ':' + X.concept_id_string
         , ExternalParentId     = @demog_gender
         , [IsNumeric]          = @no
         , IsParent             = @no
         , IsRoot               = @no
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = '/* ' + X.concept_name + ' */ @.gender_concept_id = ' + X.concept_id_string
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = X.concept_name
         , UiDisplayText        = 'Identify as ' + X.concept_name
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    FROM gender AS X    
    UNION ALL    
    
    /* Ethnicity */    
    SELECT ExternalId           = @demog_ethnic
         , ExternalParentId     = @demog_root
         , [IsNumeric]          = @no
         , IsParent             = @yes
         , IsRoot               = @no
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = NULL
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = 'Ethncity'
         , UiDisplayText        = 'Have ethnicity data'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    UNION ALL    
    SELECT ExternalId           = @demog_ethnic + ':' + X.concept_id_string
         , ExternalParentId     = @demog_ethnic
         , [IsNumeric]          = @no
         , IsParent             = @no
         , IsRoot               = @no
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = '/* ' + X.concept_name + ' */ @.ethnicity_concept_id = ' + X.concept_id_string
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = X.concept_name
         , UiDisplayText        = 'Identify as ' + X.concept_name
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    FROM ethnicity AS X    
    UNION ALL    
    
    /* Race */    
    SELECT ExternalId           = @demog_race
         , ExternalParentId     = @demog_root
         , [IsNumeric]          = @no
         , IsParent             = @yes
         , IsRoot               = @no
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = NULL
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = 'Race'
         , UiDisplayText        = 'Have race data'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    UNION ALL    
    SELECT ExternalId           = @demog_race + ':' + X.concept_id_string
         , ExternalParentId     = @demog_race
         , [IsNumeric]          = @no
         , IsParent             = @no
         , IsRoot               = @no
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = '/* ' + X.concept_name + ' */ @.race_concept_id = ' + X.concept_id_string
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = X.concept_name
         , UiDisplayText        = 'Identify as ' + X.concept_name
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    FROM race AS X    
    UNION ALL    
    
    /* Age */    
    SELECT ExternalId           = @demog_age
         , ExternalParentId     = @demog_root
         , [IsNumeric]          = @yes
         , IsParent             = @no
         , IsRoot               = @no
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = '/* Not deceased */ NOT EXISTS (SELECT 1 FROM dbo.death AS @D WHERE @.person_id = @D.person_id)'
         , SqlFieldNumeric      = '/* Current Age */ (DATEDIFF(DAY, @.birth_datetime, GETDATE()) / 365.25)'
         , UiDisplayName        = 'Age'
         , UiDisplayText        = 'Are'
         , UiDisplayUnits       = 'years old'
         , UiNumericDefaultText = 'any current age'
    UNION ALL

    /* Vital status */    
    SELECT ExternalId           = @demog_vital
         , ExternalParentId     = @demog_root
         , [IsNumeric]          = @no
         , IsParent             = @yes
         , IsRoot               = @no
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = NULL
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = 'Vital Status'
         , UiDisplayText        = 'Are living or deceased'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    UNION ALL

    /* Living */    
    SELECT ExternalId           = @demog_vital + ':living'
         , ExternalParentId     = @demog_vital
         , [IsNumeric]          = @no
         , IsParent             = @no
         , IsRoot               = @no
         , SqlSetId             = @sqlset_person
         , SqlSetWhere          = '/* Not deceased */ NOT EXISTS (SELECT 1 FROM dbo.death AS @D WHERE @.person_id = @D.person_id)'
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = 'Living'
         , UiDisplayText        = 'Are living or not known to be deceased'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    UNION ALL

    /* Deceased */    
    SELECT ExternalId           = @demog_vital + ':deceased'
         , ExternalParentId     = @demog_vital
         , [IsNumeric]          = @no
         , IsParent             = @no
         , IsRoot               = @no
         , SqlSetId             = @sqlset_v_death
         , SqlSetWhere          = NULL
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = 'Deceased'
         , UiDisplayText        = 'Are known to be deceased'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL

END

/**
 * Visits
 */
IF @add_visits = 1
BEGIN
    
    DECLARE @visit_root NVARCHAR(50) = 'visit'

    ; WITH visit_types AS
    (
        SELECT C.concept_name, C.concept_id, cnt = COUNT(*), concept_id_string = CONVERT(NVARCHAR(50), C.concept_id)
        FROM dbo.visit_occurrence AS X INNER JOIN dbo.concept AS C
             ON X.visit_concept_id = C.concept_id
        WHERE X.visit_concept_id != 0
        GROUP BY C.concept_name, C.concept_id
    )

    /* INSERT */
    INSERT INTO LeafDB.app.Concept (ExternalId, ExternalParentId, [IsNumeric], IsParent, IsRoot, SqlSetId, SqlSetWhere, 
                                    SqlFieldNumeric, UiDisplayName, UiDisplayText, UiDisplayUnits, UiNumericDefaultText)
    
    /* Root */
    SELECT ExternalId           = @visit_root
         , ExternalParentId     = NULL
         , [IsNumeric]          = @no
         , IsParent             = @yes
         , IsRoot               = @yes
         , SqlSetId             = @sqlset_visit_occurrence
         , SqlSetWhere          = NULL
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = 'Encounters'
         , UiDisplayText        = 'Have had an encounter'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    UNION ALL

    /* Visit types */
    SELECT ExternalId           = @visit_root + ':' + X.concept_id_string
         , ExternalParentId     = @visit_root
         , [IsNumeric]          = @no
         , IsParent             = @yes
         , IsRoot               = @no
         , SqlSetId             = @sqlset_visit_occurrence
         , SqlSetWhere          = '/* ' + X.concept_name + ' */ @.visit_concept_id = ' + X.concept_id_string
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = X.concept_name
         , UiDisplayText        = 'Had an ' + X.concept_name
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL
    FROM visit_types AS X   

END

/**
 * Conditions - TODO
 */
IF @add_dx_icd9 = 1 OR @add_dx_icd10 = 1
BEGIN
    SELECT 1
END

/**
 * Labs - TODO
 */
IF @add_labs = 1
BEGIN

    BEGIN TRY DROP TABLE #L END TRY BEGIN CATCH END CATCH

	DECLARE @loinc_root INT = 36206173

	; WITH roots AS
	(
		SELECT root_concept_id = C.concept_id
			 , root_concept_name = C.concept_name
			 , is_root = 1
			 , parent_concept_id = @loinc_root
			 , C.concept_id
			 , C.concept_name
			 , C.concept_code
			 , C.vocabulary_id
			 , C.concept_class_id
		FROM dbo.concept AS C
		WHERE vocabulary_id = 'LOINC'
			  AND concept_class_id = 'LOINC Hierarchy'
			  AND EXISTS (SELECT 1 FROM dbo.concept_relationship AS CR 
						  WHERE C.concept_id = CR.concept_id_1 
							    AND CR.concept_id_2 = @loinc_root 
								AND CR.relationship_id = 'Is a')

		UNION ALL

		SELECT P.root_concept_id
			 , P.root_concept_name
			 , is_root = 0
			 , P.concept_id
			 , C.concept_id
			 , C.concept_name
			 , C.concept_code
			 , C.vocabulary_id
			 , C.concept_class_id
		FROM roots AS P
			 INNER JOIN dbo.concept_relationship AS CR
				ON P.concept_id = CR.concept_id_2 AND CR.relationship_id = 'Is A'
			 INNER JOIN dbo.concept AS C
				ON CR.concept_id_1 = C.concept_id
		WHERE C.vocabulary_id = 'LOINC'
	)
	
	SELECT *
		 , concept_id_string = CONVERT(NVARCHAR(20), concept_id)
		 , is_component = 0
		 , is_parent	= 0
		 , is_numeric   = 0
	INTO #L 
	FROM roots

	UPDATE #L
	SET is_parent    = 1
	FROM #L AS C
	WHERE EXISTS (SELECT 1
				  FROM dbo.concept_ancestor AS CS
					     INNER JOIN dbo.measurement AS M
					  		ON CS.descendant_concept_id = M.measurement_concept_id
				  WHERE C.concept_id = CS.ancestor_concept_id)

	UPDATE #L
	SET is_component = 1
	  , is_parent    = 0
	WHERE EXISTS (SELECT 1 FROM dbo.measurement AS M WHERE concept_id = M.measurement_concept_id)

	UPDATE #L
	SET is_numeric = 1
	WHERE is_component = 1
		  AND EXISTS (SELECT 1 FROM dbo.measurement AS M WHERE concept_id = M.measurement_concept_id AND M.value_as_number IS NOT NULL)

	DELETE #L
	WHERE is_parent = 0
		  AND is_component = 0

	DECLARE @labs_root NVARCHAR(50) = 'labs'

	/* INSERT */
    INSERT INTO uwDM_Leaf.app.Concept (ExternalId, ExternalParentId, [IsNumeric], IsParent, IsRoot, SqlSetId, SqlSetWhere, 
                                       SqlFieldNumeric, UiDisplayName, UiDisplayText, UiDisplayUnits, UiNumericDefaultText)
    
    /* Root */
    SELECT ExternalId           = @labs_root
         , ExternalParentId     = NULL
         , [IsNumeric]          = @no
         , IsParent             = @yes
         , IsRoot               = @yes
         , SqlSetId             = @sqlset_measurement
         , SqlSetWhere          = NULL
         , SqlFieldNumeric      = NULL
         , UiDisplayName        = 'Labs'
         , UiDisplayText        = 'Had a laboratory test ordered'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = NULL

    UNION ALL

	/* Hierarchy and components */
	SELECT ExternalId           = @labs_root + ':' + X.concept_id_string
         , ExternalParentId     = @labs_root + ':' + CONVERT(NVARCHAR(20),X.parent_concept_id)
         , [IsNumeric]          = X.is_numeric
         , IsParent             = is_parent
         , IsRoot               = @no
         , SqlSetId             = @sqlset_measurement
         , SqlSetWhere          = CASE is_parent WHEN 1 THEN 'EXISTS (SELECT 1 ' +
																	 'FROM dbo.concept_ancestor AS @CS ' +
																	 'WHERE @.measurement_concept_id = @CS.descendant_concept_id ' +
																		  ' @.ancestor_concept_id = ' + X.concept_id_string
												 WHEN 0 THEN '@.measurement_concept_id = ' + X.concept_id_string
								  END
         , SqlFieldNumeric      = CASE WHEN X.is_numeric = 1 THEN '@.value_as_number' END
         , UiDisplayName        = X.concept_name
         , UiDisplayText        = 'Had a laboratory test for ' + X.concept_name + ' ordered'
         , UiDisplayUnits       = NULL
         , UiNumericDefaultText = CASE WHEN X.is_numeric = 1 THEN 'of any result' END
	FROM #L AS X

END

/**
 * Meds - TODO
 */
IF @add_meds = 1
BEGIN
    SELECT 1
END

/**
 * Procedures - TODO
 */
IF @add_proc_icd9 = 1 OR @add_proc_icd10 = 1 OR @add_proc_cpt = 1 OR @add_proc_hcpcs = 1
BEGIN
    SELECT 1
END

/**
 * Vitals - TODO
 */
IF @add_vitals = 1
BEGIN
    SELECT 1
END


/**
 * Set ParentId based on ExternalIds
 */
UPDATE LeafDB.app.Concept
SET ParentId = p.Id
FROM LeafDB.app.Concept c
     INNER JOIN (SELECT p.Id, p.ParentId, p.ExternalId
                 FROM LeafDB.app.Concept p) p 
                      ON c.ExternalParentID = p.ExternalID
WHERE c.ParentId IS NULL

/**
 * Set RootIds
 */
; WITH roots AS
(
	SELECT RootId = c.Id
		 , RootUiDisplayName = c.UiDisplayName
		 , c.IsRoot
		 , c.Id
		 , c.ParentId
		 , c.UiDisplayName
	FROM LeafDB.app.Concept AS c
	WHERE c.IsRoot = 1

	UNION ALL

	SELECT roots.RootId
		 , roots.RootUiDisplayName
		 , c2.IsRoot
		 , c2.Id
		 , c2.ParentId
		 , c2.UiDisplayName
	FROM roots
		 INNER JOIN LeafDB.app.Concept c2
			ON c2.ParentId = roots.Id
)

UPDATE LeafDB.app.Concept
SET RootId = roots.RootId
FROM LeafDB.app.Concept AS C
	 INNER JOIN roots
		ON C.Id = roots.Id
WHERE C.RootId IS NULL


-- SELECT * FROM LeafDB.app.Concept