/**
 * Leaf OMOP 5.3 bootstrap script.
 * Demographics
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

    DECLARE @demog_root   NVARCHAR(50) = 'demographics'
    DECLARE @demog_gender NVARCHAR(50) = 'demographics:gender'
    DECLARE @demog_ethnic NVARCHAR(50) = 'demographics:ethnicity'
    DECLARE @demog_race   NVARCHAR(50) = 'demographics:race'
    DECLARE @demog_age    NVARCHAR(50) = 'demographics:age'
    DECLARE @demog_vital  NVARCHAR(50) = 'demographics:vital'

    ; WITH gender AS
    (
        SELECT C.concept_name, C.concept_id, cnt = COUNT(DISTINCT person_id), concept_id_string = CONVERT(NVARCHAR(50), C.concept_id)
        FROM dbo.person AS X INNER JOIN dbo.concept AS C
             ON X.gender_concept_id = C.concept_id
        WHERE X.gender_concept_id != 0
        GROUP BY C.concept_name, C.concept_id
    ), ethnicity AS
    (
        SELECT C.concept_name, C.concept_id, cnt = COUNT(DISTINCT person_id), concept_id_string = CONVERT(NVARCHAR(50), C.concept_id)
        FROM dbo.person AS X INNER JOIN dbo.concept AS C
             ON X.ethnicity_concept_id = C.concept_id
        WHERE X.ethnicity_concept_id != 0
        GROUP BY C.concept_name, C.concept_id
    ), race AS
    (
        SELECT C.concept_name, C.concept_id, cnt = COUNT(DISTINCT person_id), concept_id_string = CONVERT(NVARCHAR(50), C.concept_id)
        FROM dbo.person AS X INNER JOIN dbo.concept AS C
             ON X.race_concept_id = C.concept_id
        WHERE X.race_concept_id != 0
        GROUP BY C.concept_name, C.concept_id
    )

    /* INSERT */
    INSERT INTO LeafDB.app.Concept (ExternalId, ExternalParentId, [IsNumeric], IsParent, IsRoot, SqlSetId, SqlSetWhere, 
                                    SqlFieldNumeric, UiDisplayName, UiDisplayText, UiDisplayUnits, UiNumericDefaultText, UiDisplayPatientCount)
    
    /* Root */
    SELECT ExternalId            = @demog_root
         , ExternalParentId      = NULL
         , [IsNumeric]           = @no
         , IsParent              = @yes
         , IsRoot                = @yes
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = NULL
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = 'Demographics'
         , UiDisplayText         = 'Have demographics'
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = (SELECT COUNT(*) FROM dbo.person)
    UNION ALL 
 
    /* Gender */ 
    SELECT ExternalId            = @demog_gender
         , ExternalParentId      = @demog_root
         , [IsNumeric]           = @no
         , IsParent              = @yes
         , IsRoot                = @no
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = NULL
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = 'Gender'
         , UiDisplayText         = 'Have gender data'
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = (SELECT SUM(cnt) FROM gender)
    UNION ALL 
    SELECT ExternalId            = @demog_gender + ':' + X.concept_id_string
         , ExternalParentId      = @demog_gender
         , [IsNumeric]           = @no
         , IsParent              = @no
         , IsRoot                = @no
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = '/* ' + X.concept_name + ' */ @.gender_concept_id = ' + X.concept_id_string
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = X.concept_name
         , UiDisplayText         = 'Identify as ' + X.concept_name
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = X.cnt
    FROM gender AS X     
    UNION ALL     
     
    /* Ethnicity */     
    SELECT ExternalId            = @demog_ethnic
         , ExternalParentId      = @demog_root
         , [IsNumeric]           = @no
         , IsParent              = @yes
         , IsRoot                = @no
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = NULL
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = 'Ethnicity'
         , UiDisplayText         = 'Have ethnicity data'
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = (SELECT SUM(cnt) FROM ethnicity)
    UNION ALL     
    SELECT ExternalId            = @demog_ethnic + ':' + X.concept_id_string
         , ExternalParentId      = @demog_ethnic
         , [IsNumeric]           = @no
         , IsParent              = @no
         , IsRoot                = @no
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = '/* ' + X.concept_name + ' */ @.ethnicity_concept_id = ' + X.concept_id_string
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = X.concept_name
         , UiDisplayText         = 'Identify as ' + X.concept_name
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = X.cnt
    FROM ethnicity AS X     
    UNION ALL     
     
    /* Race */     
    SELECT ExternalId            = @demog_race
         , ExternalParentId      = @demog_root
         , [IsNumeric]           = @no
         , IsParent              = @yes
         , IsRoot                = @no
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = NULL
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = 'Race'
         , UiDisplayText         = 'Have race data'
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = (SELECT SUM(cnt) FROM race)
    UNION ALL     
    SELECT ExternalId            = @demog_race + ':' + X.concept_id_string
         , ExternalParentId      = @demog_race
         , [IsNumeric]           = @no
         , IsParent              = @no
         , IsRoot                = @no
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = '/* ' + X.concept_name + ' */ @.race_concept_id = ' + X.concept_id_string
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = X.concept_name
         , UiDisplayText         = 'Identify as ' + X.concept_name
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = X.cnt
    FROM race AS X     
    UNION ALL     
     
    /* Age */     
    SELECT ExternalId            = @demog_age
         , ExternalParentId      = @demog_root
         , [IsNumeric]           = @yes
         , IsParent              = @no
         , IsRoot                = @no
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = NULL
         , SqlFieldNumeric       = '/* Current Age */ (DATEDIFF(DAY, @.birth_datetime, GETDATE()) / 365.25)'
         , UiDisplayName         = 'Age'
         , UiDisplayText         = 'Are'
         , UiDisplayUnits        = 'years old'
         , UiNumericDefaultText  = 'any current age'
         , UiDisplayPatientCount = (SELECT COUNT(*) FROM dbo.person)
    UNION ALL 
 
    /* Vital status */     
    SELECT ExternalId            = @demog_vital
         , ExternalParentId      = @demog_root
         , [IsNumeric]           = @no
         , IsParent              = @yes
         , IsRoot                = @no
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = NULL
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = 'Vital Status'
         , UiDisplayText         = 'Are living or deceased'
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = (SELECT COUNT(*) FROM dbo.person)
    UNION ALL 
 
    /* Living */     
    SELECT ExternalId            = @demog_vital + ':living'
         , ExternalParentId      = @demog_vital
         , [IsNumeric]           = @no
         , IsParent              = @no
         , IsRoot                = @no
         , SqlSetId              = @sqlset_person
         , SqlSetWhere           = '/* Not deceased */ NOT EXISTS (SELECT 1 FROM dbo.death AS @D WHERE @.person_id = @D.person_id)'
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = 'Living'
         , UiDisplayText         = 'Are living or not known to be deceased'
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = (SELECT COUNT(*) FROM dbo.person AS P WHERE NOT EXISTS (SELECT 1 FROM dbo.death AS D WHERE P.person_id = D.person_id))
    UNION ALL 
 
    /* Deceased */     
    SELECT ExternalId            = @demog_vital + ':deceased'
         , ExternalParentId      = @demog_vital
         , [IsNumeric]           = @no
         , IsParent              = @no
         , IsRoot                = @no
         , SqlSetId              = @sqlset_v_death
         , SqlSetWhere           = NULL
         , SqlFieldNumeric       = NULL
         , UiDisplayName         = 'Deceased'
         , UiDisplayText         = 'Are known to be deceased'
         , UiDisplayUnits        = NULL
         , UiNumericDefaultText  = NULL
         , UiDisplayPatientCount = (SELECT COUNT(*) FROM dbo.person AS P WHERE EXISTS (SELECT 1 FROM dbo.death AS D WHERE P.person_id = D.person_id))

    /**
    * Set ParentId based on ExternalIds
    */
    UPDATE LeafDB.app.Concept
    SET ParentId = P.Id
    FROM LeafDB.app.Concept AS C
        INNER JOIN (SELECT P.Id, P.ParentId, P.ExternalId
                    FROM LeafDB.app.Concept AS P) AS P
                        ON C.ExternalParentID = P.ExternalID
    WHERE C.ParentId IS NULL

    /**
    * Set RootIds
    */
    ; WITH roots AS
    (
        SELECT RootId            = C.Id
            , RootUiDisplayName = C.UiDisplayName
            , C.IsRoot
            , C.Id
            , C.ParentId
            , C.UiDisplayName
        FROM LeafDB.app.Concept AS C
        WHERE C.IsRoot = 1

        UNION ALL

        SELECT roots.RootId
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