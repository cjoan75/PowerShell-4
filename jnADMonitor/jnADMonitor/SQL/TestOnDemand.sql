/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [IDX]
      ,[DemandDate]
      ,[Company]
      ,[TOD_Code]
      ,[TOD_Demander]
      ,[TOD_Result]
      ,[TOD_ResultScript]
      ,[CompleteDate]
  FROM [ADSysMon].[dbo].[TB_TestOnDemand]
  order by [DemandDate] desc

