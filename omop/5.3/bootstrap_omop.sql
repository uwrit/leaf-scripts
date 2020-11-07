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

DECLARE @yes INT = 1
DECLARE @no  INT = 0

DECLARE @sqlset_person               INT
DECLARE @sqlset_visit_occurrence     INT
DECLARE @sqlset_condition_occurrence INT
DECLARE @sqlset_v_death              INT
DECLARE @sqlset_device_exposure      INT
DECLARE @sqlset_drug_exposure        INT
DECLARE @sqlset_measurement          INT
DECLARE @sqlset_observation          INT
DECLARE @sqlset_procedure_occurrence INT

DECLARE @user NVARCHAR(20) = 'bootstrap_omop.sql'

/**
 * Create metadata temp table of all OMOP 
 * SQL Sets to be queried in Leaf.
 */
BEGIN TRY DROP TABLE #SqlSets END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE #SqlSetsInput END TRY BEGIN CATCH END CATCH

CREATE TABLE #SqlSets      (Id INT, SqlSetName NVARCHAR(50), IsEncounterBased BIT)
CREATE TABLE #SqlSetsInput (SqlSetName NVARCHAR(50), IsEncounterBased BIT, SqlFieldDate NVARCHAR(50), TempId INT)

INSERT INTO  #SqlSetsInput (SqlSetName, IsEncounterBased, SqlFieldDate, TempId)
SELECT col1, col2, col3, ROW_NUMBER() OVER(ORDER BY (SELECT 1))
FROM (VALUES ('dbo.person',               @no,  NULL),                          
             ('dbo.visit_occurrence',     @yes, '@.visit_start_datetime'),
             ('dbo.condition_occurrence', @yes, '@.condition_start_datetime'),
             ('dbo.v_death',              @yes, '@.death_datetime'),          
             ('dbo.device_exposure',      @yes, '@.device_exposure_start_datetime'),  
             ('dbo.drug_exposure',        @yes, '@.drug_exposure_start_datetime'),
             ('dbo.measurement',          @yes, '@.measurement_datetime'), 
             ('dbo.observation',          @yes, '@.observation_datetime'),      
             ('dbo.procedure_occurrence', @yes, '@.procedure_datetime')
     ) AS X(col1,col2,col3)

/**
 * For each OMOP table of interest, INSERT into
 * the ConceptSqlSet table and track the output ID.
 */
DECLARE @row_id    INT = 1
DECLARE @row_count INT = (SELECT COUNT(*) FROM #SqlSetsInput)
DECLARE @set_name NVARCHAR(50)
DECLARE @is_encounter_based BIT
DECLARE @set_field_date NVARCHAR(50)

WHILE @row_id <= @row_count
BEGIN
    SELECT @set_name = X.SqlSetName, @is_encounter_based = X.IsEncounterBased, @set_field_date = X.SqlFieldDate
    FROM #SqlSetsInput AS X
    WHERE TempId = @row_id

    INSERT INTO LeafDB.app.ConceptSqlSet (IsEncounterBased, IsEventBased, SqlSetFrom, SqlFieldDate, Created, CreatedBy, Updated, UpdatedBy)
    OUTPUT INSERTED.Id, @set_name, @is_encounter_based INTO #SqlSets (Id, SqlSetName, IsEncounterBased)
    SELECT @is_encounter_based, 0, @set_name, @set_field_date, GETDATE(), @user, GETDATE(), @user

    SET @row_id += 1
END

SET @sqlset_person               = (SELECT TOP 1 Id FROM #SqlSets WHERE SqlSetName = 'dbo.person')
SET @sqlset_visit_occurrence     = (SELECT TOP 1 Id FROM #SqlSets WHERE SqlSetName = 'dbo.visit_occurrence')  
SET @sqlset_condition_occurrence = (SELECT TOP 1 Id FROM #SqlSets WHERE SqlSetName = 'dbo.condition_occurrence')  
SET @sqlset_v_death              = (SELECT TOP 1 Id FROM #SqlSets WHERE SqlSetName = 'dbo.v_death')  
SET @sqlset_device_exposure      = (SELECT TOP 1 Id FROM #SqlSets WHERE SqlSetName = 'dbo.device_exposure')  
SET @sqlset_drug_exposure        = (SELECT TOP 1 Id FROM #SqlSets WHERE SqlSetName = 'dbo.drug_exposure')  
SET @sqlset_measurement          = (SELECT TOP 1 Id FROM #SqlSets WHERE SqlSetName = 'dbo.measurement')  
SET @sqlset_observation          = (SELECT TOP 1 Id FROM #SqlSets WHERE SqlSetName = 'dbo.observation')  
SET @sqlset_procedure_occurrence = (SELECT TOP 1 Id FROM #SqlSets WHERE SqlSetName = 'dbo.procedure_occurrence')  

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
    SELECT 1
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