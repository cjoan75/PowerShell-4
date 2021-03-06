/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [ComputerName]
      ,[OperatingSystem]
      ,[OperatingSystemServicePack]
      ,[CAName]
      ,[DNSName]
      ,[CAType]
      ,[CertEnrollPolicyTemplates]
      ,[CATemplates]
      ,[UTCMonitored]
      ,[IsError]
      ,[ManageStatus]
      ,[Manager]
      ,[ManageScript]
      ,[ManageDate]
  FROM [ADSysMon].[dbo].[TB_dotnetsoft_co_kr_ADCSEnrollmentPolicy]
  order by UTCMonitored desc

--  SELECT LEN('DNPROD01.dotnetsoft.co.kr')