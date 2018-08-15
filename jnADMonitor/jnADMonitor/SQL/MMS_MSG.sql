USE [ADSysMon]
GO

/****** Object:  Table [dbo].[MMS_MSG]    Script Date: 1/27/2015 12:08:37 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

SET ANSI_PADDING ON
GO

CREATE TABLE [dbo].[MMS_MSG](
	[MSGKEY] [int] IDENTITY(1,1) NOT NULL,
	[SUBJECT] [varchar](120) NULL,
	[PHONE] [varchar](15) NULL,
	[CALLBACK] [varchar](15) NULL,
	[STATUS] [varchar](2) NULL DEFAULT ('0'),
	[REQDATE] [datetime] NULL,
	[MSG] [varchar](4000) NULL,
	[FILE_CNT] [int] NULL DEFAULT ((0)),
	[FILE_CNT_REAL] [int] NULL DEFAULT ((0)),
	[FILE_PATH1] [varchar](128) NULL,
	[FILE_PATH1_SIZE] [int] NULL,
	[FILE_PATH2] [varchar](128) NULL,
	[FILE_PATH2_SIZE] [int] NULL,
	[FILE_PATH3] [varchar](128) NULL,
	[FILE_PATH3_SIZE] [int] NULL,
	[FILE_PATH4] [varchar](128) NULL,
	[FILE_PATH4_SIZE] [int] NULL,
	[FILE_PATH5] [varchar](128) NULL,
	[FILE_PATH5_SIZE] [int] NULL,
	[EXPIRETIME] [varchar](10) NULL DEFAULT ('43200'),
	[SENTDATE] [datetime] NULL,
	[RSLTDATE] [datetime] NULL,
	[REPORTDATE] [datetime] NULL,
	[TERMINATEDDATE] [datetime] NULL,
	[RSLT] [varchar](10) NULL,
	[REPCNT] [int] NULL DEFAULT ((0)),
	[TYPE] [varchar](2) NOT NULL DEFAULT ('0'),
	[TELCOINFO] [varchar](10) NULL,
	[ROUTE_ID] [varchar](20) NULL,
	[ID] [varchar](20) NULL,
	[POST] [varchar](20) NULL,
	[ETC1] [varchar](64) NULL,
	[ETC2] [varchar](32) NULL,
	[ETC3] [varchar](32) NULL,
	[ETC4] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[MSGKEY] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO

SET ANSI_PADDING OFF
GO


