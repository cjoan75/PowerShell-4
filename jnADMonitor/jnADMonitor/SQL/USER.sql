/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 [USERID]
      ,[USERNAME]
      ,[PASSWORD]
      ,[MAILADDRESS]
      ,[MOBILEPHONE]
      ,[USEYN]
      ,[CREATE_DATE]
  FROM [ADSysMon].[dbo].[TB_USER]