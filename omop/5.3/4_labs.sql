/**
 * Labs
 * Notes - This script creates Leaf concepts representing laboratory
 *         tests based on a modified LOINC hierarchy. It does so by 
 *         'pruning' the LOINC tree to show only tests present in the
 *         dbo.measurement table and simplifies their display names and
 *         so on along the way.
 *
 *         Importantly, the script build Leaf concepts' SQL by leveraging 
 *         the OMOP `dbo.concept_ancestor` table. As this table contains *many* 
 *         but not *all* necessary ancestor-descendent relationships needed, 
 *         the script begins by recursively back-filling any missing relationships 
 *         present in the `dbo.concept_relationship` (of 'Is a' type) and inserting 
 *         them in the `dbo.concept_ancestor` table.  
 *         
 *         Because of this (and other processes downstream, including patient count 
 *         calculation) the script may take time to run, depending on the specifics 
 *         of database size, hardware, etc. Where possible, the script  
 *         manages its own temporary indices and cleans up after itself.
 */
BEGIN

    /**
     * Use a top-down recursive CTE, to LOINC parents to children
     */
    ; WITH X AS
    (
        SELECT
              parent_concept_id   = CONVERT(INT, NULL)
            , parent_concept_name = CONVERT(VARCHAR(255), NULL)
            , depth               = 1
            , concept_id
            , concept_code
            , concept_name
        FROM dbo.concept AS C
        WHERE C.vocabulary_id = 'LOINC'
              AND C.concept_id = 36206173 /* Root = 'Laboratory' */
        UNION ALL
        SELECT
              parent_concept_id   = X.concept_id
            , parent_concept_name = X.concept_name
            , depth               = X.depth + 1
            , C.concept_id
            , C.concept_code
            , C.concept_name
        FROM X INNER JOIN dbo.concept_relationship AS CR
                ON X.concept_id = CR.concept_id_2
            INNER JOIN dbo.concept AS C
                ON CR.concept_id_1 = C.concept_id
        WHERE C.vocabulary_id = 'LOINC'
            AND CR.relationship_id = 'Is a'
            AND C.concept_id != X.concept_id
    )
    SELECT parent_concept_id, parent_concept_name, depth = MIN(depth), concept_id, concept_code, concept_name
    INTO #L
    FROM X
    GROUP BY parent_concept_id, parent_concept_name, concept_id, concept_code, concept_name

    CREATE NONCLUSTERED INDEX IDX_TEMP ON #L ([parent_concept_id],[depth])

    /**
     * Find all unique parent LOINC concept_ids
     */
    ; WITH P AS
    (
        SELECT DISTINCT parent_concept_id
        FROM #L
    )
    SELECT parent_concept_id, row_id = ROW_NUMBER() OVER (ORDER BY (SELECT 1))
    INTO #P
    FROM P

    /**
     * Loop through each parent, find descendants, and back-fill 
     * any missing relationships in dbo.concept_ancestor
     */
    DECLARE @row_id INT     = 1
    DECLARE @max_row_id INT = (SELECT MAX(row_id) FROM #P)
    DECLARE @concept_id INT = (SELECT TOP 1 parent_concept_id FROM #P WHERE row_id = @row_id)

    WHILE @row_id <= @max_row_id
    BEGIN
        SET @concept_id = (SELECT TOP 1 parent_concept_id FROM #P WHERE row_id = @row_id)
        
        /**
         * Recurse to find all descendant concepts
         */
        ; WITH X AS
        (
                SELECT
                        root_concept_id     = L.parent_concept_id
                        , root_concept_name   = L.parent_concept_name
                        , root_depth          = L.depth - 1
                        , parent_concept_id
                        , parent_concept_name
                        , depth            
                        , concept_id
                        , concept_code
                        , concept_name
                FROM #L AS L
                WHERE L.parent_concept_id = @concept_id
                UNION ALL
                SELECT
                        X.root_concept_id
                        , X.root_concept_name
                        , X.root_depth
                        , parent_concept_id   = X.concept_id
                        , parent_concept_name = X.concept_name
                        , depth               = X.depth + 1                  
                        , L.concept_id
                        , L.concept_code
                        , L.concept_name
                FROM X INNER JOIN #L AS L
                        ON X.concept_id = L.parent_concept_id
        )
        , X2 AS
        (
                SELECT root_concept_id, concept_id, min_levels_of_separation = MIN(depth - root_depth), max_levels_of_separation = MAX(depth - root_depth)
                FROM X
                GROUP BY root_concept_id, concept_id
        )
        /**
         * Insert descendants into concept_ancestor table
         */
        INSERT INTO dbo.concept_ancestor (ancestor_concept_id, descendant_concept_id, min_levels_of_separation, max_levels_of_separation)
        SELECT root_concept_id, concept_id, min_levels_of_separation, max_levels_of_separation
        FROM X2
        WHERE NOT EXISTS (SELECT 1 FROM dbo.concept_ancestor AS L
                            WHERE L.ancestor_concept_id = root_concept_id
                                AND L.descendant_concept_id = concept_id)

        SET @row_id += 1
    END
    
    
    /**
     * Initialize Leaf-related params
     */
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
    
    SELECT DISTINCT
      RootId                        = NULL
    , ParentId                      = NULL
    , ExternalId                    = @lab_root + ':' + CONVERT(NVARCHAR(20), X.concept_id)
    , ExternalParentId              = @lab_root + ':' + CONVERT(NVARCHAR(20), X.parent_concept_id)
    , IsPatientCountAutoCalculated  = @yes
    , IsNumeric                     = @no
    , IsParent                      = CASE WHEN EXISTS (SELECT 1 FROM #L AS X2 WHERE X2.parent_concept_id = X.concept_id) THEN 1 ELSE 0 END
    , IsRoot                        = CASE WHEN X.parent_concept_id IS NULL THEN 1 ELSE 0 END
    , IsSpecializable               = @no
    , SqlSetId                      = @sqlset_measurement
    , SqlSetWhere                   = '/* ' + REPLACE(REPLACE(X.concept_name, 'WITH',''),'SET','') + ' */ ' +
                                            CASE WHEN EXISTS (SELECT 1 FROM #L AS X2 WHERE X2.parent_concept_id = X.concept_id)
                                                    THEN 'EXISTS (SELECT 1 ' +
                                                        '         FROM dbo.concept_ancestor AS @CA ' +
                                                        '         WHERE @CA.descendant_concept_id = @.measurement_concept_id ' + 
                                                        '               AND @CA.ancestor_concept_id = ' + CONVERT(NVARCHAR(20), X.concept_id) + ')'
                                                    ELSE '@.measurement_concept_id = ' + CONVERT(NVARCHAR(20), X.concept_id)
                                            END
    , SqlFieldNumeric               = CONVERT(NVARCHAR(50), NULL)
    , UiDisplayName                 = X.concept_name
    , UiDisplayText                 = 'Had laboratory test for ' + X.concept_name
    , UiDisplayTooltip              = NULL
    , UiDisplayPatientCount         = 0
    , UiNumericDefaultText          = CONVERT(NVARCHAR(50), NULL)
    , AddDateTime                   = GETDATE()
    , ContentLastUpdateDateTime     = GETDATE()
    
    , concept_id
    , concept_name
    , concept_code
    , parent_concept_id
    , parent_concept_name
    
    , row_id = 0
    INTO #X
    FROM #L AS X

    /**
     * Add temporary index on measurement_concept_id
     */
    CREATE NONCLUSTERED INDEX IDX_TEMP_measurement_concept_id ON [dbo].[measurement] ([measurement_concept_id]) INCLUDE ([person_id])
    CREATE NONCLUSTERED INDEX IDX_X_0 ON #X ([IsParent]) INCLUDE ([concept_id])
    CREATE NONCLUSTERED INDEX IDX_X_1 ON #X ([row_id])
    CREATE NONCLUSTERED INDEX IDX_X_2 ON #X ([concept_id])
    
    /**
     * DELETE non-parents with no data
     */
    DELETE #X
    FROM #X AS X
    WHERE X.IsParent = @no
        AND NOT EXISTS (SELECT 1 FROM dbo.measurement AS M WHERE M.measurement_concept_id = X.concept_id)

    /**
     * DELETE parents with no data
     */
    DELETE #X
    FROM #X AS X
    WHERE X.IsParent = @yes
        AND NOT EXISTS (SELECT 1
                        FROM dbo.measurement AS M
                        WHERE EXISTS (SELECT 1 
                                        FROM dbo.concept_ancestor AS CA 
                                        WHERE CA.descendant_concept_id = M.measurement_concept_id 
                                              AND CA.ancestor_concept_id = X.concept_id))

    /**
     * DELETE non-parents with no children
     */
    DELETE #X
    FROM #X AS X
    WHERE X.IsParent = @yes
        AND NOT EXISTS (SELECT 1 FROM #X AS X2 WHERE X2.parent_concept_id = X.concept_id)

    /**
     * Set row_ids
     */
    ; WITH Y AS
    (
        SELECT concept_id, row_id = ROW_NUMBER() OVER (ORDER BY (SELECT 1))
        FROM #X
    )

    UPDATE #X
    SET row_id = Y.row_id
    FROM #X AS X 
        INNER JOIN Y 
            ON X.concept_id = Y.concept_id

    /**
     * Loop through each concept
     */
    SET @row_id     = 1
    SET @concept_id = 0
    SET @max_row_id = (SELECT MAX(row_id) FROM #X)
    DECLARE @is_parent BIT = @no
    
    /**
     * Calculate UiDisplayCount and IsNumeric serially
     */
    WHILE @row_id <= @max_row_id
    BEGIN
        SET @concept_id = (SELECT TOP 1 concept_id FROM #X WHERE row_id = @row_id)
        SET @is_parent  = (SELECT TOP 1 IsParent FROM #X WHERE row_id = @row_id)
        
        /* If non-parent */
        IF @is_parent = 0
            UPDATE #X
            SET UiDisplayPatientCount = (SELECT COUNT(DISTINCT person_id)
                                        FROM dbo.measurement AS M
                                        WHERE M.measurement_concept_id = @concept_id)
              , IsNumeric             = CASE WHEN EXISTS (SELECT 1 
                                                        FROM dbo.measurement AS M
                                                        WHERE M.measurement_concept_id = @concept_id
                                                                AND M.value_as_number IS NOT NULL)
                                            THEN 1 ELSE 0
                                        END
            FROM #X AS X
            WHERE X.concept_id = @concept_id
        
        /* Else if parent */
        ELSE
            UPDATE #X
            SET UiDisplayPatientCount = (SELECT COUNT(DISTINCT person_id)
                                        FROM dbo.measurement AS M
                                        WHERE EXISTS (SELECT 1 FROM dbo.concept_ancestor AS CA WHERE CA.descendant_concept_id = M.measurement_concept_id AND CA.ancestor_concept_id = @concept_id))
            FROM #X AS X
            WHERE X.concept_id = @concept_id
        
        SET @row_id += 1
    END
    
    DROP INDEX IDX_TEMP_measurement_concept_id ON [dbo].[measurement]

    /**
     * For concepts with multiple parents, set ancestry
     * to that with the highest patient count (yes, a somewhat arbitrary solution)
     */
    ; WITH A AS
    (
        SELECT UiDisplayName, concept_id
        FROM #X
        GROUP BY UiDisplayName, concept_id
        HAVING COUNT(*) > 1
    ), B AS
    (
        SELECT A.UiDisplayName, A.concept_id, X.parent_concept_id, X.UiDisplayPatientCount
        FROM A INNER JOIN #X AS X
                ON A.concept_id = X.concept_id
    )
    , C AS
    (
        SELECT UiDisplayName, concept_id, parent_concept_id, max_parent_id = (SELECT TOP 1 parent_concept_id FROM B AS B2 WHERE B2.concept_id = B.concept_id ORDER BY UiDisplayPatientCount DESC)
        FROM B
    )
    , D AS
    (
        SELECT DISTINCT UiDisplayName, concept_id, max_parent_id 
        FROM C
    )
    
    DELETE #X
    FROM #X AS X
        INNER JOIN D
            ON X.concept_id = D.concept_id
            AND D.max_parent_id != X.parent_concept_id

    /**
     * Set numeric lab test-specific column values
     */
    UPDATE #X
    SET UiNumericDefaultText = 'of any result' 
    , SqlFieldNumeric      = '@.value_as_number'
    WHERE IsNumeric = 1

    /**
     * Set root Concept text
     */
    UPDATE #X
    SET UiDisplayName = 'Labs'
    , UiDisplayText = 'Had a laboratory test performed'
    WHERE IsRoot = 1

    /**
     * Remove parent's name from child Concept name
     * to improve readability
     */
    UPDATE #X
    SET UiDisplayName = LTRIM(RTRIM(REPLACE(C.UiDisplayName, P.UiDisplayName, '')))
    FROM #X AS C
        INNER JOIN (SELECT * FROM #X) AS P
            ON C.ExternalParentId = P.ExternalId

    /**
     * More name cleanup
     */
    UPDATE #X
    SET UiDisplayName = LTRIM(RTRIM(RIGHT(UiDisplayName, LEN(UiDisplayName)-2)))
    WHERE LEFT(UiDisplayName, 2) = '| '

    UPDATE #X
    SET UiDisplayName = LTRIM(RTRIM(RIGHT(UiDisplayName, LEN(UiDisplayName)-1)))
    WHERE LEFT(UiDisplayName, 1) = '.'
        OR LEFT(UiDisplayName, 1) = '/'

    UPDATE #X
    SET UiDisplayName = UPPER(LEFT(UiDisplayName, 1)) + RIGHT(UiDisplayName, LEN(UiDisplayName)-1)

    UPDATE #X
    SET UiDisplayName = LTRIM(RTRIM(REPLACE(UiDisplayName, 'XXX |', '')))
    WHERE UiDisplayName LIKE '%XXX%'

    /**
     * Find value_as_concept lab tests
     * (e.g., tests with 'Positive' or 'Negative' results)
     */
    SELECT 
          concept_id					 = X.concept_id
        , concept_name				     = X.concept_name
        , measurement_concept_id         = M.value_as_concept_id
        , measurement_value_concept_name = C.concept_name
        , cnt                            = COUNT(DISTINCT m.person_id)
    INTO #Y
    FROM #X AS X
         INNER JOIN dbo.measurement AS M
            ON X.concept_id = M.measurement_concept_id
         INNER JOIN dbo.concept AS C
            ON C.concept_id = M.value_as_concept_id
    WHERE X.IsParent = @no
          AND M.value_as_concept_id IS NOT NULL
    GROUP BY  X.concept_id, X.concept_name, M.value_as_concept_id, C.concept_name

    /** 
     * Update IsParent flag for Concepts with child `value_as_concept_id` Concepts
     */
    UPDATE #X
    SET IsParent = 1
    FROM #X AS X
    WHERE EXISTS (SELECT 1 FROM #Y AS Y WHERE X.concept_id = Y.concept_id)

    /**
     * Final INSERT
     */
    INSERT INTO LeafDB.app.Concept (ExternalId, ExternalParentId, IsPatientCountAutoCalculated, IsNumeric, IsParent, IsRoot, IsSpecializable,
                                    SqlSetId, SqlSetWhere, UiDisplayName, UiDisplayText, UiDisplayTooltip, UiDisplayPatientCount, UiNumericDefaultText, SqlFieldNumeric,
                                    AddDateTime, ContentLastUpdateDateTime)
    SELECT
      ExternalId
    , ExternalParentId
    , IsPatientCountAutoCalculated
    , IsNumeric
    , IsParent
    , IsRoot
    , IsSpecializable
    , SqlSetId
    , SqlSetWhere
    , UiDisplayName
    , UiDisplayText
    , UiDisplayTooltip
    , UiDisplayPatientCount
    , UiNumericDefaultText
    , SqlFieldNumeric
    , AddDateTime
    , ContentLastUpdateDateTime
    FROM #X AS X

    UNION ALL

    SELECT
      ExternalId					 = X.ExternalId + ':' + CONVERT(NVARCHAR(50), Y.measurement_concept_id)
    , ExternalParentId               = X.ExternalId
    , X.IsPatientCountAutoCalculated
    , X.IsNumeric						
    , IsParent                       = @no
    , X.IsRoot
    , X.IsSpecializable
    , X.SqlSetId
    , SqlSetWhere                    = X.SqlSetWhere + ' AND @.value_as_concept_id = ' + CONVERT(NVARCHAR(50), Y.measurement_concept_id)
    , UiDisplayName                  = Y.measurement_value_concept_name
    , UiDisplayText                  = X.UiDisplayText + ' that was ' + Y.measurement_value_concept_name
    , X.UiDisplayTooltip
    , UiDisplayPatientCount          = Y.cnt
    , X.UiNumericDefaultText
    , X.SqlFieldNumeric
    , X.AddDateTime
    , X.ContentLastUpdateDateTime
    FROM #Y AS Y
        INNER JOIN #X AS X
            ON Y.concept_id = X.concept_id

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