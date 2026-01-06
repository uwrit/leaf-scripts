USE [master]
GO

/****** Object:  Database [ClinicalDataDB]    Script Date: ******/
CREATE DATABASE [ClinicalDataDB]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'ClinicalDataDB', FILENAME = N'/var/opt/mssql/data/ClinicalDataDB.mdf' , SIZE = 139264KB , MAXSIZE = UNLIMITED, FILEGROWTH = 65536KB )
 LOG ON 
( NAME = N'ClinicalDataDB_log', FILENAME = N'/var/opt/mssql/data/ClinicalDataDB_log.ldf' , SIZE = 729088KB , MAXSIZE = 2048GB , FILEGROWTH = 65536KB )
GO

