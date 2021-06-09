/**
 * Other odds and ends
 * Notes - The purpose of this script is to populate other Leaf
 *         configuration elements besides that of Concepts. 
 *         
 *         Currently, this script INSERTs a row (in the form of
 *         a SQL query as string) into the `app.DemographicQuery` table.
 *         This query is used for extracting patient data for populating
 *         the Visualize and Patient List screens.
 */

DECLARE @user NVARCHAR(20)     = 'bootstrap_omop.sql'
DECLARE @demog_query_shape INT = 3
DECLARE @sql NVARCHAR(MAX)     = 
    'SELECT
      personId          = CONVERT(NVARCHAR(10),P.person_id)
    , addressPostalCode = L.zip
    , addressState      = L.[state]
    , birthDate         = P.birth_datetime
    , deceasedDateTime  = D.death_datetime
    , ethnicity         = c_ethnicity.concept_name
    , gender            = c_gender.concept_name
    , deceasedBoolean   = CONVERT(BIT, CASE WHEN D.person_id IS NULL THEN 1 ELSE 0 END)
    , hispanicBoolean   = CONVERT(BIT, CASE WHEN c_ethnicity.concept_name = ''Hispanic or Latino'' THEN 1 ELSE 0 END)
    , marriedBoolean    = CONVERT(BIT, 0)
    , language          = CONVERT(NVARCHAR(1),NULL) /* Not in OMOP */
    , maritalStatus     = CONVERT(NVARCHAR(1),NULL) /* Not in OMOP */
    , mrn               = CONVERT(NVARCHAR(1),NULL) /* Not in OMOP */
    , name              = CONVERT(NVARCHAR(1),NULL) /* Not in OMOP */
    , race              = c_race.concept_name
    , religion          = CONVERT(NVARCHAR(1),NULL) /* Not in OMOP */
    FROM [dbo].[person] AS P
        LEFT JOIN dbo.concept AS c_gender
            ON P.gender_concept_id = c_gender.concept_id
        LEFT JOIN dbo.concept AS c_race
            ON P.race_concept_id = c_race.concept_id
        LEFT JOIN dbo.concept AS c_ethnicity
            ON p.ethnicity_concept_id = c_ethnicity.concept_id
        LEFT JOIN dbo.[location] AS L
            ON P.location_id = L.location_id
        LEFT JOIN dbo.death AS D
            ON P.person_id = D.person_id'

INSERT INTO app.DemographicQuery ([Lock],[SqlStatement],[Shape],[LastChanged],[ChangedBy])
SELECT 'X', @sql, @demog_query_shape, GETDATE(), @user