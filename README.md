# leaf-scripts
Creating Leaf Concepts manually can be done quickly using the Leaf Admin Panel, but certain types of Concepts are best created by SQL script. Here are a few examples of how to do so.

## ICD10 diagnoses using UMLS
This example assumes that you have an active [UMLS license](https://uts.nlm.nih.gov/license.html) and a database named `UMLS` on the same server as your Leaf application database. Note that ICD10 diagnosese are used just as an example, and you can apply this pattern ICD9 and other coding systems just as easily.

You can find the full example script used here wrapped as a stored procedure at https://github.com/uwrit/leaf-scripts/concepts/sp_InsertConceptsFromUMLS.sql.

1) Use the example [sp_GetOntologyFromUMLS stored procedure](https://github.com/uwrit/leaf-scripts/concepts/sp_GetOntologyFromUMLS.sql) to populate a temporary table that looks like this:

| AUI       | ParentAUI | MinCode | MaxCode | CodeCount | OntologyType | SqlSetWhere                  | UiDisplayName                                                          |
| --------- | --------- | ------- | ------- | --------- | ------------ | ---------------------------- | ---------------------------------------------------------------------- |
| A20098492 | NULL      | A00.0   | Z99.89  | 69823     | ICD10CM      | BETWEEN 'A00.0' AND 'Z99.89' | ICD-10-CM TABULAR LIST of DISEASES and INJURIES (ICD10CM:A00.0-Z99.89) |
| A17824693 | A17773405 | A02.29  | A02.29  | 1         | ICD10CM      | = 'A02.29'                   | Salmonella with other localized infection (ICD10CM:A02.29)             |
| A17773458 | A17773456 | A41.81  | A41.89  | 2         | ICD10CM      | IN ('A41.81','A41.89')       | Other specified sepsis (ICD10CM:A41.81-A41.89)                         |


Each row contains a reference to its parent row via `ParentAUI`, and a SQL expression in `SqlSetWhere` which we can plug into our datamodel by prepending our column names.

```sql
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
EXEC dbo.sp_GetConceptOntologyFromUMLS 'ICD10CM'
```

2) Find the diagnosis `SQL Set` ID and insert the hierarchical UMLS rows into the `app.Concept` table:

```sql
DECLARE @SqlSetId INT = (SELECT TOP (1) S.Id FROM app.ConceptSqlSet S WHERE S.SqlSetFrom = 'dbo.diagnosis')

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
   ,[ExternalParentId]			           = 'UMLS_AUI:' + O.ParentAUI
   ,[IsPatientCountAutoCalculated]                 = 1
   ,[IsNumeric]					   = 0		
   ,[IsParent]					   = CASE WHEN EXISTS (SELECT 1 FROM #Output O2 WHERE O.AUI = O2.ParentAUI) THEN 1 ELSE 0 END
   ,[IsRoot]					   = CASE WHEN ParentAUI IS NULL THEN 1 ELSE 0 END
   ,[IsSpecializable]			           = 0
   ,[SqlSetId]					   = @SqlSetId
   ,[SqlSetWhere]				   = '@.CodingSystem = ''ICD10'' AND @.Code ' + O.SqlSetWhere
   ,[UiDisplayName]				   = O.uiDisplayName
   ,[UiDisplayText]				   = 'Had diagnosis of ' + O.UiDisplayName
   ,[AddDateTime]				   = GETDATE()
   ,[ContentLastUpdateDateTime]                    = GETDATE()
FROM #Output O
WHERE NOT EXISTS (SELECT 1
		  FROM app.Concept c
		  WHERE 'UMLS_AUI:' + o.AUI = c.ExternalID)
```

Note that above in 

```
,[SqlSetWhere] = '@.CodingSystem = ''ICD10'' AND @.Code ' + O.SqlSetWhere
```

The example assumes a hypothetical diagnosis table structure in your clinical database like:

 | PatientId | CodingSystem | Code  | ... |
 | --------- | ------------ | ----- | --- |
 | A         | ICD10        | E11.2 |     |
 | B         | ICD10        | T34.5 |     |
 | C         | ICD10        | S09.1 |     |

Your clinical database columns will likely differ, so tailor this section appropriately for your data.

3) Update the `app.Concept.ParentId` values using the `ExternalId` and `ExternalParentIds`:

```sql
UPDATE app.Concept
SET ParentId = p.Id
FROM app.Concept c
	 INNER JOIN (SELECT p.Id, p.ParentId, p.ExternalId
				 FROM app.Concept p) p 
		ON c.ExternalParentID = p.ExternalID
WHERE EXISTS (SELECT 1 FROM #Output o WHERE 'UMLS_AUI:' + o.AUI = c.ExternalId)
```

And that's it! You'll likely want to have the Leaf Admin Panel open and inspect/tweak these after running the script to make sure everything looks as expected.

You can use this general pattern to insert diagnosis, procedure, LOINC, or other codes.
