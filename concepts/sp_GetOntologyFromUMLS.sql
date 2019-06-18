SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Nic Dobbins
-- Create date: 2015/12/30
-- Description:	Returns a heirarchical SQL table of 
--              Ontology items which can be inserted into the
--              Leaf app.Concept table. 
-- Comments:    This script assumes 
--                1) You have a valid UMLS license.
--                2) There is a UMLS database named [UMLS].
-- =============================================
CREATE PROCEDURE [dbo].[sp_GetConceptOntologyFromUMLS]
	@OntologyType NVARCHAR (20)

AS
BEGIN
	SET NOCOUNT ON;
	
	BEGIN TRY DROP TABLE #codeHeirarchy END TRY BEGIN CATCH END CATCH
	BEGIN TRY DROP TABLE #distinctCodes END TRY BEGIN CATCH END CATCH
	BEGIN TRY DROP TABLE #allParentChildCodes END TRY BEGIN CATCH END CATCH
	BEGIN TRY DROP TABLE #allCodes END TRY BEGIN CATCH END CATCH
	BEGIN TRY DROP TABLE #codeHeirarchyVertical END TRY BEGIN CATCH END CATCH
	BEGIN TRY DROP TABLE #minmax END TRY BEGIN CATCH END CATCH
	BEGIN TRY DROP TABLE #MRCONSO END TRY BEGIN CATCH END CATCH
	BEGIN TRY DROP TABLE #MRHIER END TRY BEGIN CATCH END CATCH

    -- Copy MRCONSO
	SELECT m.AUI
		 , m.SAB
		 , m.CODE
		 , m.TTY
		 , m.STR
	INTO #MRCONSO
	FROM UMLS.dbo.MRCONSO m
	WHERE SAB = @ontologyType 

    -- Copy MRHEIR
	SELECT mh.AUI
		 , mh.PTR
	INTO #MRHIER
	FROM UMLS.dbo.MRHIER mh
	WHERE mh.AUI IN (SELECT m.AUI FROM #MRCONSO m)

	SELECT SourceType = @ontologyType
		 , mh.AUI
		 , PTR = CONVERT(NVARCHAR(400), mh.PTR)
		 , PreviousPTR = CONVERT(NVARCHAR(20),'')
	INTO #codeHeirarchy
	FROM #MRHIER mh

	CREATE NONCLUSTERED INDEX IDX_CPT ON #codeHeirarchy (PTR ASC, AUI ASC) INCLUDE (SourceType, PreviousPTR)
	CREATE NONCLUSTERED INDEX IDX_M ON #MRCONSO (AUI ASC, SAB ASC)

	/*******************************************************************************************************
	* Loop through AUI codes and separate each into new row
	*******************************************************************************************************/
	BEGIN TRY DROP TABLE #Codes END TRY BEGIN CATCH END CATCH

	DECLARE @loopCount INT = 0,
			@delimeter NVARCHAR(2) = '.',
			@loopLimit INT = 20,
			@updatedRows INT = 1;

	CREATE TABLE #Codes
	(
		Code NVARCHAR(20) NULL,
		PreviousCode NVARCHAR(20) NULL,
		CodeOrder INT NULL,
		AUI NVARCHAR(20) NULL,
		CodeType NVARCHAR(20) NULL
	)

	WHILE @loopCount < @loopLimit AND @updatedRows > 0

	BEGIN

		BEGIN TRY DROP TABLE #CurrentCodes END TRY BEGIN CATCH END CATCH

		-- Get the current left-most AUI (i.e. everything up to the first period ".")
		INSERT INTO #Codes
		SELECT Code = CASE CHARINDEX(@delimeter, PTR) WHEN 0 THEN LTRIM(RTRIM(PTR))
													  ELSE LTRIM(RTRIM(LEFT(PTR, CHARINDEX(@delimeter, PTR)))) END
			  ,PreviousCode = PreviousPTR
			  ,CodeOrder = @loopCount
			  ,AUI
			  ,CodeType = SourceType
		FROM #codeHeirarchy c
		WHERE PTR IS NOT NULL

		SET @updatedRows = @@ROWCOUNT

		-- Save the previous PTR
		UPDATE #codeHeirarchy
		SET PreviousPTR = 
            CASE CHARINDEX(@delimeter, PTR) 
                WHEN 0 THEN LTRIM(RTRIM(PTR))
				ELSE LTRIM(RTRIM(LEFT(PTR, CHARINDEX(@delimeter, PTR)))) 
            END

		-- Chop off everything to the left of the first period "."
		UPDATE #codeHeirarchy
		SET PTR = NULLIF(RIGHT(PTR, LEN(PTR) - CHARINDEX(@delimeter, PTR)),'')

		DELETE FROM #codeHeirarchy
		WHERE PTR IS NULL

		-- Increment the @loopCount
		SET @loopCount += 1

	END

	UPDATE #Codes
	SET Code = REPLACE(Code,@delimeter,'')
	  , PreviousCode = REPLACE(PreviousCode,@delimeter,'')

	/*******************************************************************************************************
	* Get distinct list of each code
	*******************************************************************************************************/
	SELECT c.Code
		  ,c.PreviousCode
		  ,CodeOrder = MIN(CodeOrder) 
		  ,c.AUI
		  ,c.CodeType
	INTO #distinctCodes
	FROM #Codes c
	GROUP BY c.Code, c.PreviousCode, c.AUI, c.CodeType

	SELECT DISTINCT ParentAUI = d.PreviousCode, AUI = d.Code
	INTO #allParentChildCodes
	FROM #distinctCodes d
	WHERE d.Code != d.PreviousCode

	UNION

	SELECT ParentAUI = d.Code, d.AUI
	FROM #distinctCodes d
	WHERE d.CodeOrder = (SELECT MAX(CodeOrder)
						 FROM #distinctCodes d2
						 WHERE d.AUI = d2.AUI)

    /*******************************************************************************************************
	* Get distinct list of each code with future display name
	*******************************************************************************************************/
	SELECT DISTINCT a.AUI, m.Code, is_Parent = 0, ui_Display_Name = CONVERT(NVARCHAR(400),'')
	INTO #allCodes
	FROM #allParentChildCodes a 
         INNER JOIN #MRCONSO m
            ON a.AUI = m.AUI

	UNION

	SELECT DISTINCT ParentAUI, m.Code, is_Parent = 0, ui_Display_Name = CONVERT(NVARCHAR(400),'')
	FROM #allParentChildCodes a 
         INNER JOIN #MRCONSO m 
            ON a.ParentAUI = m.AUI

    /*******************************************************************************************************
	* Figure out of it is a parent
	*******************************************************************************************************/
	UPDATE #allCodes
	SET is_Parent = 1
	FROM #allCodes a
	WHERE a.AUI IN (SELECT DISTINCT a2.ParentAUI FROM #allParentChildCodes a2)

	UPDATE #allCodes
	SET Code = NULL
	WHERE is_Parent = 1

	/*******************************************************************************************************
	* Update display name
	* If it is a parent use shorter name, if base child use verbose descriptive name
	*******************************************************************************************************/
	UPDATE #allCodes 
	SET ui_Display_Name = LEFT(m.STR,400)
	FROM #allCodes a 
         INNER JOIN #MRCONSO m 
            ON a.CODE = m.CODE
	WHERE a.is_Parent = 0 
	      AND m.SAB = @OntologyType
	      AND m.TTY = 'PT'

	UPDATE #allCodes
	SET ui_Display_Name = LEFT(m.STR,400)
	FROM #allCodes a 
         INNER JOIN #MRCONSO m 
            ON a.AUI = m.AUI
	WHERE a.ui_Display_Name = ''

	CREATE NONCLUSTERED INDEX IDX_CPT_AC ON #allCodes (AUI ASC, Code ASC)
	CREATE NONCLUSTERED INDEX IDX_CPT_APC ON #allParentChildCodes (AUI ASC, ParentAUI ASC)

	/*******************************************************************************************************
	* Create a vertical table for storing all children of a given AUI
	*******************************************************************************************************/
	CREATE TABLE #codeHeirarchyVertical 
	(
		AUI NVARCHAR(20) NULL,
		ChildAUI NVARCHAR(20) NULL
	)

	INSERT INTO #codeHeirarchyVertical
	SELECT a.AUI
		  ,a.AUI
	FROM #allCodes a 

	SET @loopCount = 0
	SET @loopLimit = 10
	SET @updatedRows = 1

	/*******************************************************************************************************
	* Loop through 10 times, each time going one level deeper in adding descendants
	*******************************************************************************************************/
	WHILE @loopCount < @loopLimit

	BEGIN

		BEGIN TRY DROP TABLE #currentBatch END TRY BEGIN CATCH END CATCH

		SELECT a.AUI
			  ,ChildAUI = ap.AUI
		INTO #currentBatch
		FROM #codeHeirarchyVertical a 
             INNER JOIN #allParentChildCodes ap 
                ON a.ChildAUI = ap.ParentAUI

		-- Delete if row already exists
		DELETE #currentBatch
		FROM #currentBatch c 
             INNER JOIN #codeHeirarchyVertical cv 
                ON c.AUI = cv.AUI
				   AND c.ChildAUI = cv.ChildAUI

		-- Insert if it is new
		INSERT INTO #codeHeirarchyVertical
		SELECT c.AUI
			  ,c.ChildAUI
		FROM #currentBatch c 

		-- Increment the @loopCount
		SET @loopCount += 1

	END

	/*******************************************************************************************************
	* Get the highest and lowest associated codes for a given AUI
	*******************************************************************************************************/
	SELECT a.AUI
		  ,MinCode = MIN(ac.Code)
		  ,MaxCode = MAX(ac.Code)
		  ,CodeCount = COUNT(DISTINCT ac.Code)
	INTO #minmax
	FROM #codeHeirarchyVertical a 
         INNER JOIN #allCodes ac 
            ON a.ChildAUI = ac.AUI
	WHERE ac.CODE IS NOT NULL
	GROUP BY a.AUI

	SELECT a.AUI
		  ,ParentAUI = NULLIF(ap.ParentAUI,'')
		  ,a.MinCode
		  ,a.MaxCode
		  ,a.CodeCount
		  ,OntologyType = @OntologyType
		  ,SqlSetWhere = CASE a.CodeCount WHEN 1 THEN '= ''' + MinCode + ''''
                                          WHEN 2 THEN 'IN (''' + MinCode + ''',''' + MaxCode + ''')'
										  ELSE 'BETWEEN ''' + MinCode + ''' AND ''' + MaxCode + '''' END
		  ,uiDisplayName = LEFT(ac.ui_Display_Name, 400) + ' (' + 
								CASE a.CodeCount WHEN 1 THEN @OntologyType + ':' + MinCode + ')'
												 ELSE @OntologyType + ':' + MinCode + '-' + MaxCode + ')' 
								END
	FROM #minmax a 
         INNER JOIN #allCodes ac 
            ON a.AUI = ac.AUI 
         LEFT JOIN #allParentChildCodes ap 
            ON a.AUI = ap.AUI

	END
