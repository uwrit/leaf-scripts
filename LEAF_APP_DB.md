# Leaf application database schema

## app.Concept
|Column|Usage|
---|---| 
|`Id`|Unique identifier for the concept|
|`ParentId`|Unique identifier for the concept parent, also in the `app.Concept` table. Concepts will appear nested under their parent in the Leaf UI, and inherit parent access permissions.|
| `RootId`|Unique identifier for the root concept, which is the top-most concept above this concept.|
|`ExternalId`|An optional identifier used by Leaf admins to identify concepts by some source system ID, such as an Epic `MEDICATION_ID` or internal clinic ID. These columns can be useful when updating concepts based on source system changes. The Leaf application does not use these columns and admins are free to populate as they like.|
|`ExternalParentId`|An optional identifier used by Leaf admins for concept parents, similar to `ExternalId`.|
|`UniversalId`|An optional identifier used when Leaf is run in federated mode. When a Leaf user executes a query, federated partner Leaf instances find their local concepts based on matching `UniversalId`s. As such, in federated mode the `UniversalId` is expected to have a matching corresponding concept with the same value at other sites. `UniversalId`s must begin with the format `urn:leaf:concept:` but otherwise have no restrictions. For more information see the [relevent Leaf JAMIA article section](https://academic.oup.com/jamia/article/27/1/109/5583724#210345476).
|`IsPatientCountAutoCalculated`|If `false` (0) then the number of persons in the clinical DB that satisfy the concept is not automatically computed; otherwise the count of persons in the clinical DB that satisfy the concept is is automatically computed (using the stored procedure `app.sp_CalculatePatientCounts`), stored in `UiDisplayPatientCount`, and then displayed in the concepts rendered by the Leaf UI.|
|`IsNumeric`|`true` if a concept's value is numeric and can use a numerical input from Leaf users; otherwise `false`.|
|`IsParent`|`false` if a concept is a Leaf in the concept hierarchy; otherwise `true`.|
|`IsRoot`|`true` if a concept is the root of a concept domain; otherwise `false`.|
|`IsSpecializable`|`true` if a concept allows dropdown in the Leaf UI to "specialize" it's semantics and SQL `WHERE` clause. Specialized concepts must have values in the `rela.ConceptSpecializationGroup` table. For more information see the [Leaf documentation on dropdowns](https://leafdocs.rit.uw.edu/administration/concept_reference/#adding-dropdowns).|
|||


## app.ConceptSqlSet
|Header1 |Header2  | Header3|
--- | --- | ---
|data1|data2|data3|
|data11|data12|data13|