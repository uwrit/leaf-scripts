# Configuring Leaf with OMOP
Leaf is a flexible tool able to work with nearly any clinical data model.
This section of `leaf-scripts` deals specifically with the [OMOP Common Data Model](https://www.ohdsi.org/omop/).

Configuring Leaf to work with a particular database and Concept tree is
often the most time-consuming aspect of Leaf installation. Using OMOP - which presents
a consistent, widely-used data model - therefore offers an opportunity to create 
a generalizable starting point in Leaf configuration, saving time and energy in setup.
(while also providing examples of how to configure Leaf programmatically!)

The scripts in this repo assume:
1 - You're working using SQL Server as your RDBMS.
2 - You have a 'vanilla' OMOP database with no renamed columns or tables.
3 - Your Leaf application database exists on the same server and is named `LeafDB`.

While (1) and (2) should not be surprising, (3) is not the case for everyone, so before
running the setup scripts **be sure to first rename `LeafDB` -> `YourDatabaseName` in any scripts you run**.

The scripts are designed to build a basic Concept tree shaped like the following:
 - **Demographics** [2_demographics.sql](./5.3/2_demographics.sql)
 - **Encounters** [3_visits.sql](./5.3/3_visits.sql)
 - **Labs** [4_labs.sql](./5.3/4_labs.sql)
 - **Vitals** [5_vitals.sql](./5.3/5_vitals.sql)

Scripts are designed to be run sequentially in the order they are numbered, but this is strictly
only necessary for the [0_views.sql](./5.3/0_views.sql) and [1_sqlsets.sql](./5.3/1_sqlsets.sql) scripts, 
which should be run first.

Note that we are also currently working on scripts for `Conditions` and `Procedures`.
