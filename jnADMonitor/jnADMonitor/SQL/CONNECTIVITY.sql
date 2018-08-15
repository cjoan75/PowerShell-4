/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [ComputerName]
      ,[CanPing]
      ,[CanPort135]
      ,[UTCMonitored]
  FROM [ADSysMon].[dbo].[TB_dotnetsoft_co_kr_CONNECTIVITY]
    order by UTCMonitored desc