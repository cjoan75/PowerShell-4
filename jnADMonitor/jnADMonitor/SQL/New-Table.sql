USE ADSysMon
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP TABLE [dbo].[TB_SERVERS]
GO

CREATE TABLE [dbo].[TB_SERVERS](
	[Domain] [nvarchar](30) NOT NULL,
	[ServiceFlag] [nvarchar](10) NOT NULL,
	[ComputerName] [nvarchar](50) NOT NULL,
	[IPAddress] [nvarchar](15) NULL,
	[UTCMonitored] [datetime] NOT NULL,
	PRIMARY KEY CLUSTERED ([Domain] ASC, [ServiceFlag] ASC, [ComputerName] ASC)
)

EXEC('
CREATE PROCEDURE [dbo].[SP_SERVERS]
		@Domain nvarchar(30)
		,@ServiceFlag nvarchar(10)
		,@ComputerName nvarchar(50)
		,@IPAddress nvarchar(15)
		,@UTCMonitored datetime
AS
BEGIN

INSERT INTO [dbo].[$($TableName)]
		( [Domain]
		,[ServiceFlag]
		,[ComputerName]
		,[IPAddress]
		,[UTCMonitored]
		)
		VALUES
		( @Domain 
		,@ServiceFlag
		,@ComputerName
		,@IPAddress
		,@UTCMonitored
		)

END
')

GO

DROP TABLE [dbo].[TB_MonitoringTaskLogs]

GO

CREATE TABLE [dbo].[TB_MonitoringTaskLogs](
	[TaskDate] [smalldatetime] NOT NULL,
	[TaskType] [nvarchar](10) NOT NULL,
	[Company] [nvarchar](50) NOT NULL,
	[ADService] [nvarchar](10) NULL,
	[Serviceitem] [nvarchar](50) NULL,
	[ComputerName] [nvarchar](50) NULL,
	[TaskScript] [nvarchar](max) NULL,
	[CreateDate] [smalldatetime] DEFAULT GETUTCDATE()
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

DROP TABLE [dbo].[TB_ProblemManagement]
GO

CREATE TABLE [dbo].[TB_ProblemManagement](
	[IDX] [int] IDENTITY(1,1) NOT NULL,
	[MonitoredTime] [datetime] NOT NULL,
	[Company] [nvarchar](20) NOT NULL,
	[ADService] [nvarchar](10) NOT NULL,
	[Serviceitem] [nvarchar](50) NOT NULL,
	[ComputerName] [nvarchar](50) NOT NULL,
	[ProblemScript] [nvarchar](max) NULL,
	[ManageStatus] [nvarchar](20) NULL,
	[Manager] [nvarchar](50) NULL,
	[ManageScript] [nvarchar](max) NULL,
	[ManageDate] [datetime] NULL,
	[ManageIDX] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[IDX] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

CREATE TABLE [dbo].[TB_SYSTEM_LOG](
	[IDX] [int] NOT NULL,
	[TYPE] [nvarchar](5) NOT NULL,
	[EVENT_NAME] [nvarchar](30) NOT NULL,
	[MESSAGE] [nvarchar](max) NULL,
	[CREATE_DATE] [datetime] NOT NULL,
	[CREATER_ID] [varchar](10) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO

CREATE PROCEDURE [dbo].[USP_INSERT_SYSTEM_LOG]
	 @TYPE			nvarchar(5)
	,@EVENT_NAME	nvarchar(30)
	,@MESSAGE		nvarchar(MAX)
	,@CREATE_DATE	datetime
	,@CREATER_ID	varchar(10)
AS
BEGIN

	SET NOCOUNT ON;

	INSERT INTO TB_SYSTEM_LOG 
			( [TYPE]
			, EVENT_NAME
			, [MESSAGE]
			, CREATE_DATE
			, CREATER_ID 
			)
	VALUES	( @TYPE			
			,@EVENT_NAME	
 			,@MESSAGE		
			,@CREATE_DATE	
			,@CREATER_ID	
			)

END

GO


CREATE TABLE [dbo].[TB_TestOnDemand](
	[IDX] [int] IDENTITY(1,1) NOT NULL,
	[DemandDate] [datetime] NOT NULL DEFAULT (getUTCdate()),
	[Company] [nvarchar](20) NOT NULL,
	[TOD_Code] [nvarchar](5) NOT NULL,
	[TOD_Demander] [nvarchar](50) NOT NULL,
	[TOD_Result] [nvarchar](1) NULL DEFAULT ('N'),
	[TOD_ResultScript] [nvarchar](max) NULL,
	[CompleteDate] [datetime] NULL,
 CONSTRAINT [PK_TB_TestOnDemand] PRIMARY KEY CLUSTERED 
(
	[IDX] DESC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO


insert into [ADSysMon].[dbo].[TB_TestOnDemand](
	[DemandDate]
    ,[Company]
    ,[TOD_Code]
    ,[TOD_Demander]) 
values (
	GETUTCDATE()
	,'DOTNETSOFT_CO_KR'
	,'TEST'
	,'TESTER'
)
GO

