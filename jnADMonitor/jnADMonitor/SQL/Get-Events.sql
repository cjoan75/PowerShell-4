SELECT TOP 100 [LogName] ,[TimeCreated] ,[Id] ,[ProviderName] ,[LevelDisplayName] ,[Message] ,[ComputerName] ,[UTCMonitored] ,[ServiceFlag] ,[ManageStatus] ,[Manager] ,[ManageScript] ,[ManageDate]
FROM [dbo].[TB_CORP_LGCNS_COM_EVENT]
ORDER BY [UTCMonitored] DESC

SELECT TOP 10 [LogName]
      ,[TimeCreated]
      ,[Id]
      ,[ProviderName]
      ,[LevelDisplayName]
      ,[Message]
      ,[ComputerName]
      ,[UTCMonitored]
      ,[ServiceFlag]
      ,[ManageStatus]
      ,[Manager]
      ,[ManageScript]
      ,[ManageDate]
  FROM [ADSysMon].[dbo].[TB_dotnetsoft_co_kr_EVENT]
  order by UTCMonitored desc
