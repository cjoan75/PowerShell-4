/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [ComputerName]
      ,[OperatingSystem]
      ,[OperatingSystemServicePack]
      ,[serverstatus]
      ,[UTCMonitored]
      ,[DatabaseName]
      ,[DatabasePath]
      ,[DatabaseBackupPath]
      ,[DatabaseBackupInterval]
      ,[DatabaseLoggingFlag]
      ,[DatabaseRestoreFlag]
      ,[DatabaseCleanupInterval]
      ,[IsError]
      ,[ManageStatus]
      ,[Manager]
      ,[ManageScript]
      ,[ManageDate]
  FROM [ADSysMon].[dbo].[TB_dotnetsoft_co_kr_DHCPServiceAvailability]
  order by UTCMonitored desc