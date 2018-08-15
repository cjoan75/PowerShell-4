/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [IDX]
      ,[TYPE]
      ,[EVENT_NAME]
      ,[MESSAGE]
      ,[CREATE_DATE]
      ,[CREATER_ID]
  FROM [ADSysMon].[dbo].[TB_SYSTEM_LOG]
  order by [CREATE_DATE] desc