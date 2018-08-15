/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [TaskDate]
      ,[TaskType]
      ,[Company]
      ,[ADService]
      ,[Serviceitem]
      ,[ComputerName]
      ,[TaskScript]
      ,[CreateDate]
  FROM [ADSysMon].[dbo].[TB_MonitoringTaskLogs]
order by TaskDate desc

/*
use adsysmon
go

Insert into TB_MonitoringTaskLogs ([TaskDate], [TaskType], [Company], [ADService], [TaskScript])
values(GETUTCDATE(), 'TEST', 'dotnetsoft.co.kr', 'ADCS', null)
*/