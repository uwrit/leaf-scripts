/**
 *
 * Authors: Nic Dobbins, Ross Naheedy, Cherise Woods
 *
 * The script auto-populates the Leaf concept tree with PCORNet-specific fields and tables.
 * PCORNET uses the fields `PATID` and `ENCOUNTERID` to track patient and encounter identifiers.
 * This script thus assumes Leaf appsettings.json Compiler.FieldPersonId and Compiler.FieldEncounterId
 * have been configured to these in the API (else the concepts here won't work).
 *
 * The general approach of this script is *not* data-driven (ie, dynamically finding values within data
 * and building concepts from that), but rather hard-coded. This is done to ensure the concept tree at every site
 * looks the same.
 *
 * Appsettings file: https://github.com/uwrit/leaf/blob/master/src/server/API/appsettings.json#L65
 * Config instructions: https://leafdocs.rit.uw.edu/installation/installation_steps/6_appsettings/#compiler
 *
 *
 **/

 /* Cheatsheet code to clear the current concept tree:

     TRUNCATE TABLE app.ConceptTokenizedIndex
     TRUNCATE TABLE app.ConceptForwardIndex
     DELETE app.ConceptInvertedIndex
     DELETE rela.QueryConceptDependency
     DELETE app.PanelFilter
     DELETE app.ConceptEvent
     DELETE app.Concept
     DELETE app.ConceptSqlSet

 */

DECLARE @user NVARCHAR(20) = 'pcornet_leaf_script'
DECLARE @yes BIT = 1
DECLARE @no  BIT = 0

/**
 * Add PCORNet SQL tables to be queried in Leaf
 */
INSERT INTO app.ConceptSqlSet (SqlSetFrom, IsEncounterBased, IsEventBased, SqlFieldDate, Created, CreatedBy, Updated, UpdatedBy)
SELECT *
FROM (VALUES ('dbo.DEMOGRAPHIC',          @no,  @no,  NULL,             GETDATE(), @user, GETDATE(), @user),                          
             ('dbo.ENCOUNTER',            @yes, @no, '@.ADMIT_DATE',	GETDATE(), @user, GETDATE(), @user),
             ('dbo.DIAGNOSIS',            @yes, @no, '@.DX_DATE',	    GETDATE(), @user, GETDATE(), @user),
             ('dbo.PROCEDURES',           @yes, @no, '@.PX_DATE',       GETDATE(), @user, GETDATE(), @user),          
             ('dbo.VITAL',                @yes, @no, '@.MEASURE_DATE',  GETDATE(), @user, GETDATE(), @user),  
             ('dbo.LAB_RESULT_CM',        @yes, @no, '@.SPECIMEN_DATE', GETDATE(), @user, GETDATE(), @user),
             ('dbo.DEATH',                @yes, @no, '@.DEATH_DATE',    GETDATE(), @user, GETDATE(), @user), 
             ('dbo.IMMUNIZATION',         @yes, @no, '@.VX_ADMIN_DATE', GETDATE(), @user, GETDATE(), @user)
     ) AS X(col1,col2,col3,col4,col5,col6,col7,col8)

/**
 * For concepts, start by creating a single temporary table. We'll insert all of our generated concepts in this,
 * then use the temp table to final insert into the Leaf app.Concept table
 */
BEGIN TRY DROP TABLE #concepts END TRY BEGIN CATCH END CATCH
CREATE TABLE #concepts (
	[ExternalId] [nvarchar](200) NULL,
	[ExternalParentId] [nvarchar](200) NULL,
	[UniversalId] [nvarchar](200) NULL,
	[IsPatientCountAutoCalculated] [bit] NULL,
	[IsNumeric] [bit] NULL,
	[IsParent] [bit] NULL,
	[IsRoot] [bit] NULL,
	[IsSpecializable] [bit] NULL,
	[SqlSetId] [int] NULL,
	[SqlSetWhere] [nvarchar](1000) NULL,
	[SqlFieldNumeric] [nvarchar](1000) NULL,
	[UiDisplayName] [nvarchar](400) NULL,
	[UiDisplayText] [nvarchar](1000) NULL,
	[UiDisplayUnits] [nvarchar](50) NULL,
	[UiNumericDefaultText] [nvarchar](50) NULL,
) 

/** 
 * Demographics
 */
DECLARE @sqlset_demographic INT = (SELECT TOP 1 Id FROM app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.DEMOGRAPHIC')
DECLARE @sqlset_death INT       = (SELECT TOP 1 Id FROM app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.DEATH')

DECLARE @uid_demog_root   NVARCHAR(50) = 'urn:leaf:concept:demographic'
DECLARE @uid_demog_sex    NVARCHAR(50) = 'urn:leaf:concept:demographic:sex'
DECLARE @uid_demog_ethnic NVARCHAR(50) = 'urn:leaf:concept:demographic:ethnicity'
DECLARE @uid_demog_race   NVARCHAR(50) = 'urn:leaf:concept:demographic:race'
DECLARE @uid_demog_age    NVARCHAR(50) = 'urn:leaf:concept:demographic:age'
DECLARE @uid_demog_vital  NVARCHAR(50) = 'urn:leaf:concept:demographic:vital'

; WITH sex AS
(
    SELECT *
    FROM (VALUES 
                ('Female', 'Were female at birth', '@.SEX = ''F''', @uid_demog_sex + ':F'),
                ('Male',   'Were male at birth',   '@.SEX = ''M''', @uid_demog_sex + ':M')
         ) AS X(UiDisplayName, UiDisplayText, SqlSetWhere, UniversalId)
), vital AS
(
    SELECT *
    FROM (VALUES 
                ('Living',  'Patients are living',   'NOT EXISTS (SELECT 1 FROM dbo.DEATH AS @D WHERE @.PATID = @D.PATID)', @uid_demog_vital + ':L'),
                ('Deceased','Patients are deceased', 'EXISTS (SELECT 1 FROM dbo.DEATH AS @D WHERE @.PATID = @D.PATID)',     @uid_demog_vital + ':D')
         ) AS X(UiDisplayName, UiDisplayText, SqlSetWhere, UniversalId)
), ethnicity AS
(
    SELECT *
    FROM (VALUES 
                ('Hispanic',     'Identify as Hispanic',             '@.HISPANIC = ''Y''', @uid_demog_ethnic + ':Y'),
                ('Not Hispanic', 'Identify as non-Hispanic',         '@.HISPANIC = ''N''', @uid_demog_ethnic + ':N'),
                ('Unknown',      'Hispanic idenfication is Unknown', '@.HISPANIC = ''U''', @uid_demog_ethnic + ':U')
         ) AS X(UiDisplayName, UiDisplayText, SqlSetWhere, UniversalId)
), race AS
(
    SELECT *
    FROM (VALUES 
                ('American Indian or Alaska Native',    'Identify as American Indian or Alaska Native',    '@.RACE = ''01''', @uid_demog_race + ':01'),
                ('Asian',                               'Identify as Asian',                               '@.RACE = ''02''', @uid_demog_race + ':02'),
                ('Black or African American',           'Identify as Black or African American',           '@.RACE = ''03''', @uid_demog_race + ':03'),
                ('Native Hawaiian or Pacific Islander', 'Identify as Native Hawaiian or Pacific Islander', '@.RACE = ''04''', @uid_demog_race + ':04'),
                ('White',                               'Identify as White',                               '@.RACE = ''05''', @uid_demog_race + ':05'),
                ('Multiple races',                      'Identify as multiple races',                      '@.RACE = ''06''', @uid_demog_race + ':06')
         ) AS X(UiDisplayName, UiDisplayText, SqlSetWhere, UniversalId)
)

INSERT INTO #concepts (ExternalId, ExternalParentId, UniversalId, [IsNumeric], IsParent, IsRoot, SqlSetId, SqlSetWhere, 
                       SqlFieldNumeric, UiDisplayName, UiDisplayText, UiDisplayUnits, UiNumericDefaultText)

/* Demographics root */
SELECT ExternalId            = @uid_demog_root
     , ExternalParentId      = NULL
     , UniversalId           = @uid_demog_root
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @yes
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'Demographics'
     , UiDisplayText         = 'Have demographics'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
     
UNION ALL 

/* Sex parent */ 
SELECT ExternalId            = @uid_demog_sex
     , ExternalParentId      = @uid_demog_root
     , UniversalId           = @uid_demog_sex
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @no
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'Sex'
     , UiDisplayText         = 'Identify with a sex'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL

UNION ALL 

/* Sexes */ 
SELECT ExternalId            = X.UniversalId
     , ExternalParentId      = @uid_demog_sex
     , UniversalId           = X.UniversalId
     , [IsNumeric]           = @no
     , IsParent              = @no
     , IsRoot                = @no
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = X.SqlSetWhere
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = X.UiDisplayName
     , UiDisplayText         = X.UiDisplayText
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
FROM sex AS X    

UNION ALL     
 
/* Ethnicity parent */     
SELECT ExternalId            = @uid_demog_ethnic
     , ExternalParentId      = @uid_demog_root
     , UniversalId           = @uid_demog_ethnic
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @no
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'Ethnicity'
     , UiDisplayText         = 'Have ethnicity data'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL

UNION ALL 

/* Ethnicities */     
SELECT ExternalId            = X.UniversalId
     , ExternalParentId      = @uid_demog_ethnic
     , UniversalId           = X.UniversalId
     , [IsNumeric]           = @no
     , IsParent              = @no
     , IsRoot                = @no
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = X.SqlSetWhere
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = X.UiDisplayName
     , UiDisplayText         = X.UiDisplayText
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
FROM ethnicity AS X    

UNION ALL     
 
/* Race parent */     
SELECT ExternalId            = @uid_demog_race
     , ExternalParentId      = @uid_demog_root
     , UniversalId           = @uid_demog_race
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @no
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'Race'
     , UiDisplayText         = 'Identify as one or more races'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL

UNION ALL 

/* Races */     
SELECT ExternalId            = X.UniversalId
     , ExternalParentId      = @uid_demog_race
     , UniversalId           = X.UniversalId
     , [IsNumeric]           = @no
     , IsParent              = @no
     , IsRoot                = @no
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = X.SqlSetWhere
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = X.UiDisplayName
     , UiDisplayText         = X.UiDisplayText
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
FROM race AS X    

UNION ALL     
 
/* Age */     
SELECT ExternalId            = @uid_demog_age
     , ExternalParentId      = @uid_demog_root
     , UniversalId           = @uid_demog_age
     , [IsNumeric]           = @yes
     , IsParent              = @no
     , IsRoot                = @no
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = '/* Current Age */ (DATEDIFF(DAY, @.BIRTH_DATE, GETDATE()) / 365.25)'
     , UiDisplayName         = 'Age'
     , UiDisplayText         = 'Are'
     , UiDisplayUnits        = 'years old'
     , UiNumericDefaultText  = 'any current age'

UNION ALL     
 
/* Vital status parent */     
SELECT ExternalId            = @uid_demog_vital
     , ExternalParentId      = @uid_demog_root
     , UniversalId           = @uid_demog_vital
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @no
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'Vital Status'
     , UiDisplayText         = 'Have a vital status'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL

UNION ALL 

/* Vital status */     
SELECT ExternalId            = X.UniversalId
     , ExternalParentId      = @uid_demog_vital
     , UniversalId           = X.UniversalId
     , [IsNumeric]           = @no
     , IsParent              = @no
     , IsRoot                = @no
     , SqlSetId              = @sqlset_demographic
     , SqlSetWhere           = X.SqlSetWhere
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = X.UiDisplayName
     , UiDisplayText         = X.UiDisplayText
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
FROM vital AS X    

/** 
 * Encounters
 */
DECLARE @sqlset_encounter INT = (SELECT TOP 1 Id FROM app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.ENCOUNTER')

DECLARE @uid_enc_root NVARCHAR(50) = 'urn:leaf:concept:encounter'

; WITH encounters AS
(
    SELECT *
    FROM (VALUES 
                ('Outpatient',          'Had an Outpatient visit',                                    '@.ENC_TYPE = ''AV''', @uid_enc_root + ':AV'),
                ('Emergency',           'Visited the Emergency department',                           '@.ENC_TYPE = ''ED''', @uid_enc_root + ':ED'),
                ('Emergency/Inpatient', 'Visited the Emergency department and admitted as Inpatient', '@.ENC_TYPE = ''EI''', @uid_enc_root + ':EI'),
                ('Inpatient',           'Admitted as an Inpatient',                                   '@.ENC_TYPE = ''IP''', @uid_enc_root + ':IP')
         ) AS X(UiDisplayName, UiDisplayText, SqlSetWhere, UniversalId)
)


INSERT INTO #concepts (ExternalId, ExternalParentId, UniversalId, [IsNumeric], IsParent, IsRoot, SqlSetId, SqlSetWhere, 
                       SqlFieldNumeric, UiDisplayName, UiDisplayText, UiDisplayUnits, UiNumericDefaultText)

/* Encounter root */
SELECT ExternalId            = @uid_enc_root
     , ExternalParentId      = NULL
     , UniversalId           = @uid_enc_root
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @yes
     , SqlSetId              = @sqlset_encounter
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'Encounters'
     , UiDisplayText         = 'Have had an encounter'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
     
UNION ALL 

/* Encounters */ 
SELECT ExternalId            = X.UniversalId
     , ExternalParentId      = @uid_enc_root
     , UniversalId           = X.UniversalId
     , [IsNumeric]           = @no
     , IsParent              = @no
     , IsRoot                = @no
     , SqlSetId              = @sqlset_encounter
     , SqlSetWhere           = X.SqlSetWhere
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = X.UiDisplayName
     , UiDisplayText         = X.UiDisplayText
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
FROM encounters AS X    

/** 
 * Diagnoses
 * Note: here we depend on an external table derived from the UMLS
 *       to build the ICD-10 tree. The table is called `UMLS_ICD10`
 *       and can be downloaded at https://drive.google.com/drive/u/0/folders/1GRtL04PHBz8OAHRZB455mc1qAiCfU1pL. 
 */
DECLARE @sqlset_dx INT = (SELECT TOP 1 Id FROM app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.DIAGNOSIS')

DECLARE @uid_dx_root  NVARCHAR(50) = 'urn:leaf:concept:dx'

/** 
 * Create a temporary table for transforming ICD-10
 */
BEGIN TRY DROP TABLE #icd10 END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE #icd10_2 END TRY BEGIN CATCH END CATCH
SELECT  
     AUI
    ,ParentAUI
    ,[ParentUniversalId] = 'urn:leaf:concept:dx:icd10:' + (SELECT TOP 1 CASE WHEN CodeCount = 1 THEN MinCode ELSE MinCode + '_' + MaxCode END 
                                                          FROM dbo.[UMLS_ICD10] AS X2
                                                          WHERE X.ParentAUI = X2.AUI)
    ,[UniversalId]      = 'urn:leaf:concept:dx:icd10:' + CASE WHEN CodeCount = 1 THEN MinCode ELSE MinCode + '_' + MaxCode END
    ,[IsParent]         = CASE WHEN CodeCount = 1 THEN 0 ELSE 1 END
    ,[SqlSetWhere]      = '@.DX_TYPE = ''10'' AND @.DX ' + [SqlSetWhere]
    ,[UiDisplayName]
    ,[UiDisplayText]    = 'Had diagnosis of ' + [UiDisplayName]
INTO #icd10    
FROM dbo.[UMLS_ICD10] AS X

/** 
 * Using this UniversalId naming convention, occassionally ICD-10 code ranges can be duplicated.
 * Use a CTE with ROW_NUMBER() to identify cases of dupes. We'll add a count to the end of each 
 * duplicated UniversalId to de-dupe them
 */
; WITH icd10 AS
(
     SELECT 
          AUI, ParentAUI, UniversalId, SqlSetWhere, UiDisplayName, UiDisplayText, IsParent, 
          RowNum = ROW_NUMBER() OVER (PARTITION BY UniversalId ORDER BY UniversalId)
     FROM #ICD10
), icd10_2 AS
(
     SELECT 
          AUI
        , ParentAUI
        , UniversalId = CASE WHEN RowNum > 1 THEN UniversalId + '_' + CONVERT(NVARCHAR(2), RowNum) ELSE UniversalId END
        , SqlSetWhere
        , UiDisplayName
        , UiDisplayText
        , IsParent
     FROM icd10
)
SELECT * 
INTO #icd10_2 
FROM icd10_2

INSERT INTO #concepts (ExternalId, ExternalParentId, UniversalId, [IsNumeric], IsParent, IsRoot, SqlSetId, SqlSetWhere, 
                       SqlFieldNumeric, UiDisplayName, UiDisplayText, UiDisplayUnits, UiNumericDefaultText)

/* Diagnoses root */
SELECT ExternalId            = @uid_dx_root
     , ExternalParentId      = NULL
     , UniversalId           = @uid_dx_root
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @yes
     , SqlSetId              = @sqlset_dx
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'Diagnoses'
     , UiDisplayText         = 'Have had a diagnosis'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
     
UNION ALL 

/* Diagnoses - ICD10 root */ 
SELECT ExternalId            = (SELECT TOP 1 UniversalId FROM #icd10_2 WHERE ParentAUI IS NULL)
     , ExternalParentId      = @uid_dx_root
     , UniversalId           = (SELECT TOP 1 UniversalId FROM #icd10_2 WHERE ParentAUI IS NULL)
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @no
     , SqlSetId              = @sqlset_dx
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'ICD-10'
     , UiDisplayText         = 'Have had a diagnosis coded in ICD-10'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
     
UNION ALL 

/* Diagnoses - ICD10 codes */ 
SELECT ExternalId            = X.UniversalId
     , ExternalParentId      = (SELECT TOP 1 UniversalId FROM #icd10_2 AS X2 WHERE X.ParentAUI = X2.AUI)
     , UniversalId           = X.UniversalId
     , [IsNumeric]           = @no
     , IsParent              = X.IsParent
     , IsRoot                = @no
     , SqlSetId              = @sqlset_dx
     , SqlSetWhere           = X.SqlSetWhere
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = X.UiDisplayName
     , UiDisplayText         = X.UiDisplayText
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
FROM #icd10_2 AS X    
WHERE ParentAUI IS NOT NULL

/** 
 * Procedures - CPT
 * Note: driven from cpt.sql available at https://drive.google.com/drive/u/0/folders/1GRtL04PHBz8OAHRZB455mc1qAiCfU1pL. 
 */
DECLARE @sqlset_pxcpt INT = (SELECT TOP 1 Id FROM app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.PROCEDURES')

DECLARE @uid_pxcpt_root  NVARCHAR(50) = 'urn:leaf:concept:px'

/** 
 * Create a temporary table for transforming CPT
 */
BEGIN TRY DROP TABLE #cpt END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE #cpt_2 END TRY BEGIN CATCH END CATCH
SELECT  
     AUI
    ,ParentAUI
    ,[ParentUniversalId] = 'urn:leaf:concept:px:cpt:' + (SELECT TOP 1 CASE WHEN CodeCount = 1 THEN MinCode ELSE MinCode + '_' + MaxCode END 
                                                          FROM dbo.[UMLS_CPT] AS X2
                                                          WHERE X.ParentAUI = X2.AUI)
    ,[UniversalId]      = 'urn:leaf:concept:px:cpt:' + CASE WHEN CodeCount = 1 THEN MinCode ELSE MinCode + '_' + MaxCode END
    ,[IsParent]         = CASE WHEN CodeCount = 1 THEN 0 ELSE 1 END
    ,[SqlSetWhere]      = '@.PX_TYPE = ''CH'' AND @.PX ' + [SqlSetWhere]
    ,[UiDisplayName]
    ,[UiDisplayText]    = 'Had the procedure ' + [UiDisplayName]
INTO #cpt    
FROM dbo.[UMLS_CPT] AS X

/** 
 * Using this UniversalId naming convention, occassionally CPT code ranges can be duplicated.
 * Use a CTE with ROW_NUMBER() to identify cases of dupes. We'll add a count to the end of each 
 * duplicated UniversalId to de-dupe them
 */
; WITH cpt AS
(
     SELECT 
          AUI, ParentAUI, UniversalId, SqlSetWhere, UiDisplayName, UiDisplayText, IsParent, 
          RowNum = ROW_NUMBER() OVER (PARTITION BY UniversalId ORDER BY UniversalId)
     FROM #cpt
), cpt_2 AS
(
     SELECT 
          AUI
        , ParentAUI
        , UniversalId = CASE WHEN RowNum > 1 THEN UniversalId + '_' + CONVERT(NVARCHAR(2), RowNum) ELSE UniversalId END
        , SqlSetWhere
        , UiDisplayName
        , UiDisplayText
        , IsParent
     FROM cpt
)
SELECT * 
INTO #cpt_2 
FROM cpt_2

INSERT INTO #concepts (ExternalId, ExternalParentId, UniversalId, [IsNumeric], IsParent, IsRoot, SqlSetId, SqlSetWhere, 
                       SqlFieldNumeric, UiDisplayName, UiDisplayText, UiDisplayUnits, UiNumericDefaultText)

/* Procedures root */
SELECT ExternalId            = @uid_pxcpt_root
     , ExternalParentId      = NULL
     , UniversalId           = @uid_pxcpt_root
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @yes
     , SqlSetId              = @sqlset_pxcpt
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'Procedures'
     , UiDisplayText         = 'Have had a procedure'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
     
UNION ALL 

/* Procedures - CPT root */ 
SELECT ExternalId            = (SELECT TOP 1 UniversalId FROM #cpt_2 WHERE ParentAUI IS NULL)
     , ExternalParentId      = @uid_pxcpt_root
     , UniversalId           = (SELECT TOP 1 UniversalId FROM #cpt_2 WHERE ParentAUI IS NULL)
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @no
     , SqlSetId              = @sqlset_pxcpt
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'CPT'
     , UiDisplayText         = 'Have had a procedure coded in CPT'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
     
UNION ALL 

/* Procedures - CPT codes */ 
SELECT ExternalId            = X.UniversalId
     , ExternalParentId      = (SELECT TOP 1 UniversalId FROM #cpt_2 AS X2 WHERE X.ParentAUI = X2.AUI)
     , UniversalId           = X.UniversalId
     , [IsNumeric]           = @no
     , IsParent              = X.IsParent
     , IsRoot                = @no
     , SqlSetId              = @sqlset_pxcpt
     , SqlSetWhere           = X.SqlSetWhere
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = Left(X.UiDisplayName,400)
     , UiDisplayText         = X.UiDisplayText
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
FROM #cpt_2 AS X    
WHERE ParentAUI IS NOT NULL

/** 
 * Procedures - ICD10PCS
 * Note: driven from icd10pcs.sql available at https://drive.google.com/drive/u/0/folders/1GRtL04PHBz8OAHRZB455mc1qAiCfU1pL. 
 */
DECLARE @sqlset_pxicd INT = (SELECT TOP 1 Id FROM app.ConceptSqlSet WHERE SqlSetFrom = 'dbo.PROCEDURES')

DECLARE @uid_pxicd_root  NVARCHAR(50) = 'urn:leaf:concept:px'

/** 
 * Create a temporary table for transforming ICD10PCS
 */
BEGIN TRY DROP TABLE #icd10pcs END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE #icd10pcs_2 END TRY BEGIN CATCH END CATCH
SELECT  
     AUI
    ,ParentAUI
    ,[ParentUniversalId] = 'urn:leaf:concept:px:icd10pcs:' + (SELECT TOP 1 CASE WHEN CodeCount = 1 THEN MinCode ELSE MinCode + '_' + MaxCode END 
                                                          FROM dbo.[UMLS_ICD10PCS] AS X2
                                                          WHERE X.ParentAUI = X2.AUI)
    ,[UniversalId]      = 'urn:leaf:concept:px:icd10pcs:' + CASE WHEN CodeCount = 1 THEN MinCode ELSE MinCode + '_' + MaxCode END
    ,[IsParent]         = CASE WHEN CodeCount = 1 THEN 0 ELSE 1 END
    ,[SqlSetWhere]      = '@.PX_TYPE = ''10'' AND @.PX ' + [SqlSetWhere]
    ,[UiDisplayName]
    ,[UiDisplayText]    = 'Had the procedure ' + [UiDisplayName]
INTO #icd10pcs    
FROM dbo.[UMLS_ICD10PCS] AS X

/** 
 * Using this UniversalId naming convention, occassionally ICD10PCS code ranges can be duplicated.
 * Use a CTE with ROW_NUMBER() to identify cases of dupes. We'll add a count to the end of each 
 * duplicated UniversalId to de-dupe them
 */
; WITH icd10pcs AS
(
     SELECT 
          AUI, ParentAUI, UniversalId, SqlSetWhere, UiDisplayName, UiDisplayText, IsParent, 
          RowNum = ROW_NUMBER() OVER (PARTITION BY UniversalId ORDER BY UniversalId)
     FROM #icd10pcs
), icd10pcs_2 AS
(
     SELECT 
          AUI
        , ParentAUI
        , UniversalId = CASE WHEN RowNum > 1 THEN UniversalId + '_' + CONVERT(NVARCHAR(2), RowNum) ELSE UniversalId END
        , SqlSetWhere
        , UiDisplayName
        , UiDisplayText
        , IsParent
     FROM icd10pcs
)
SELECT * 
INTO #icd10pcs_2 
FROM icd10pcs_2

INSERT INTO #concepts (ExternalId, ExternalParentId, UniversalId, [IsNumeric], IsParent, IsRoot, SqlSetId, SqlSetWhere, 
                       SqlFieldNumeric, UiDisplayName, UiDisplayText, UiDisplayUnits, UiNumericDefaultText)

/* Procedures - ICD10PCS root */ 
SELECT ExternalId            = 'urn:leaf:concept:px:icd10pcs'
     , ExternalParentId      = @uid_pxicd_root
     , UniversalId           = 'urn:leaf:concept:px:icd10pcs'
     , [IsNumeric]           = @no
     , IsParent              = @yes
     , IsRoot                = @no
     , SqlSetId              = @sqlset_pxicd
     , SqlSetWhere           = NULL
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = 'ICD10PCS'
     , UiDisplayText         = 'Have had a procedure coded in ICD10PCS'
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
     
UNION ALL 

/* Procedures - ICD10PCS codes */ 
SELECT ExternalId            = X.UniversalId
     , ExternalParentId      = 'urn:leaf:concept:px:icd10pcs' -- (SELECT UniversalId FROM #icd10pcs_2 AS X2 WHERE X2.ParentAUI is null)
     , UniversalId           = X.UniversalId
     , [IsNumeric]           = @no
     , IsParent              = X.IsParent
     , IsRoot                = @no
     , SqlSetId              = @sqlset_pxicd
     , SqlSetWhere           = X.SqlSetWhere
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = Left(X.UiDisplayName,400)
     , UiDisplayText         = X.UiDisplayText
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
FROM #icd10pcs_2 AS X    
WHERE ParentAUI = 'A16077350'

UNION ALL

/* Procedures - ICD10PCS codes */ 
SELECT ExternalId            = X.UniversalId
     , ExternalParentId      = (SELECT TOP 1 UniversalId FROM #icd10pcs_2 AS X2 WHERE X.ParentAUI = X2.AUI)
     , UniversalId           = X.UniversalId
     , [IsNumeric]           = @no
     , IsParent              = X.IsParent
     , IsRoot                = @no
     , SqlSetId              = @sqlset_pxicd
     , SqlSetWhere           = X.SqlSetWhere
     , SqlFieldNumeric       = NULL
     , UiDisplayName         = Left(X.UiDisplayName,400)
     , UiDisplayText         = X.UiDisplayText
     , UiDisplayUnits        = NULL
     , UiNumericDefaultText  = NULL
FROM #icd10pcs_2 AS X    
WHERE ParentAUI != 'A16077350'

/** 
 * Final steps: Add to Leaf
 */
INSERT INTO app.Concept ([ExternalId],[ExternalParentId],[UniversalId],[IsPatientCountAutoCalculated],[IsNumeric],[IsParent],[IsRoot],
                         [SqlSetId],[SqlSetWhere],[SqlFieldNumeric],[UiDisplayName],[UiDisplayText],[UiDisplayUnits],[UiNumericDefaultText],
                         [AddDateTime],[ContentLastUpdateDateTime])
SELECT [ExternalId]
      ,[ExternalParentId]
      ,[UniversalId]
      ,[IsPatientCountAutoCalculated]
      ,[IsNumeric]
      ,[IsParent]
      ,[IsRoot]
      ,[SqlSetId]
      ,[SqlSetWhere]
      ,[SqlFieldNumeric]
      ,[UiDisplayName]
      ,[UiDisplayText]
      ,[UiDisplayUnits]
      ,[UiNumericDefaultText]
      ,[AddDateTime]               = GETDATE()
      ,[ContentLastUpdateDateTime] = GETDATE()
FROM #concepts AS C
WHERE NOT EXISTS (SELECT 1
                  FROM app.Concept AS C2
                  WHERE C.UniversalId = C2.UniversalId) /* Don't insert (duplicate) existing concepts */

/**
 * Set ParentIds
 */
UPDATE app.Concept
SET ParentId = P.Id
FROM app.Concept AS C
     INNER JOIN (SELECT P.Id, P.ParentId, P.ExternalId
                 FROM app.Concept AS P) AS P ON C.ExternalParentID = P.ExternalID
WHERE C.ParentId IS NULL

/**
 * Set RootIds
 */
; WITH roots AS
(
    SELECT RootId           = C.Id
        , RootUiDisplayName = C.UiDisplayName
        , C.IsRoot
        , C.Id
        , C.ParentId
        , C.UiDisplayName
    FROM app.Concept AS C
    WHERE C.IsRoot = 1
    UNION ALL
    SELECT roots.RootId
        , roots.RootUiDisplayName
        , C2.IsRoot
        , C2.Id
        , C2.ParentId
        , C2.UiDisplayName
    FROM roots
         INNER JOIN app.Concept AS C2 ON C2.ParentId = roots.Id
)

UPDATE app.Concept
SET RootId = roots.RootId
FROM app.Concept AS C
     INNER JOIN roots ON C.Id = roots.Id
WHERE C.RootId IS NULL

/**
 * Set Basic Demographics query (for Visualize and Patient List tabs)
 */
DELETE app.DemographicQuery

INSERT INTO app.DemographicQuery (Lock, Shape, LastChanged, ChangedBy, SqlStatement)
SELECT Lock         = 'X'
     , Shape        = 3
     , LastChanged  = GETDATE()
     , ChangedBy    = @user
     , SqlStatement = 
     'SELECT
        d.PATID AS personId,
        '' AS addressPostalCode,
        '' AS addressState,
        d.BIRTH_DATE AS birthDate,
        (SELECT TOP 1 d2.DEATH_DATE FROM DEATH d2 WHERE d2.PATID = d.PATID) AS deceasedDateTime,
        CASE d.HISPANIC WHEN ''Y'' then ''Hispanic or Latino'' ELSE ''Not Hispanic or Latino'' END AS ethnicity,
        CASE d.sex WHEN ''F'' THEN ''Female'' WHEN ''M'' THEN ''Male'' ELSE ''Other'' END AS gender,
        ''Unknown'' AS [language],
        ''Unknown'' AS maritalStatus,
        CAST(0 AS BIT) AS marriedBoolean,
        CAST(CASE WHEN d.hispanic = ''Y'' THEN 1 ELSE 0 END AS BIT) AS hispanicBoolean,
        CAST(CASE WHEN EXISTS (SELECT d2.DEATH_DATE FROM DEATH d2 WHERE d2.PATID = d.PATID) THEN 1 ELSE 0 END AS BIT) AS deceasedBoolean,
        ''Unknown Unknown'' AS [name],
        ''Unknown'' AS mrn,
        CASE d.race
                WHEN ''05'' THEN ''White''
                WHEN ''03'' THEN ''Black or African American''
                WHEN ''02'' THEN ''Asian''
                WHEN ''04'' THEN ''Native Hawaiian or Other Pacific Islander''
                WHEN ''01'' THEN ''American Indian or Alaska Native''
                WHEN ''06'' THEN ''Multi-racial''
                WHEN ''NI'' THEN ''Unknown''
                WHEN ''UN'' THEN ''Unknown''
                WHEN ''OT'' THEN ''Other''
                ELSE ''Other''
                END AS race,
        ''Unknown'' AS religion
     FROM DEMOGRAPHIC d'
