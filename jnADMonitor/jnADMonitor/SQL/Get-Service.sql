/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 100 [ServiceStatus]
      ,[Name]
      ,[DisplayName]
      ,[ComputerName]
      ,[UTCMonitored]
      ,[ServiceFlag]
      ,[IsError]
      ,[ManageStatus]
      ,[Manager]
      ,[ManageScript]
      ,[ManageDate]
  FROM [ADSysMon].[dbo].[TB_corp_lgcns_com_SERVICE]
    order by UTCMonitored desc