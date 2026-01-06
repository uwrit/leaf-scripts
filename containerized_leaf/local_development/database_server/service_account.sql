/* If using a service account - Optional but Recommended! */
/* If creating a clinical database will need to also provide select permission on that database as well */

CREATE LOGIN leaf_svc WITH PASSWORD = '<your_pass>'

USE LeafDB
GO

CREATE USER leaf_svc FOR LOGIN leaf_svc

GRANT SELECT,UPDATE,INSERT,DELETE,EXEC ON SCHEMA :: app TO leaf_svc;
GRANT SELECT,UPDATE,INSERT,DELETE,EXEC ON SCHEMA :: network TO leaf_svc;
GRANT SELECT,UPDATE,INSERT,DELETE,EXEC ON SCHEMA :: adm TO leaf_svc;
GRANT SELECT,UPDATE,INSERT,DELETE,EXEC ON SCHEMA :: auth TO leaf_svc;
GRANT SELECT,UPDATE,INSERT,DELETE,EXEC ON SCHEMA :: ref TO leaf_svc;
GRANT SELECT,UPDATE,INSERT,DELETE,EXEC ON SCHEMA :: rela TO leaf_svc;

/* Else if on Linux */
ALTER SERVER ROLE [sysadmin] ADD MEMBER leaf_svc;