/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [ComputerName]
      ,[OperatingSystem]
      ,[OperatingSystemServicePack]
      ,[dnsstatus]
      ,[UTCMonitored]
      ,[IsError]
      ,[ManageStatus]
      ,[Manager]
      ,[ManageScript]
      ,[ManageDate]
  FROM [ADSysMon].[dbo].[TB_dotnetsoft_co_kr_DNSServiceAvailability]
  order by UTCMonitored desc