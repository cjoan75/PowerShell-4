USE [ADSysMon]
GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_TEST_ON_DEMAND_COMPLETED]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_UPDATE_TEST_ON_DEMAND_COMPLETED]
GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST_TEST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST_TEST]
GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_MANAGE_COMPANY_USER]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_UPDATE_MANAGE_COMPANY_USER]
GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_CHANGE_PASSWORD]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_UPDATE_CHANGE_PASSWORD]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_W32TIMESYNC_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_W32TIMESYNC_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_USER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_USER_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_USER_INFO]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_USER_INFO]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TOPOLOGY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_TOPOLOGY_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TEST_ON_DEMAND_RUN]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_TEST_ON_DEMAND_RUN]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TEST_ON_DEMAND_PROCESSING_ITEM]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_TEST_ON_DEMAND_PROCESSING_ITEM]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TEST_ON_DEMAND_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_TEST_ON_DEMAND_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TEST_ON_DEMAND_DATA]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_TEST_ON_DEMAND_DATA]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SYSVOL_SHARES_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_SYSVOL_SHARES_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVICE_STATUS]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_SERVICE_STATUS]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVICE_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_SERVICE_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVICE_AVAILABILITY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_SERVICE_AVAILABILITY_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_SERVER_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVER_CHART_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_SERVER_CHART_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_REPOSITORY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_REPOSITORY_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_REPLICATION_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_REPLICATION_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_PROBLEM_MANAGEMENT_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_PROBLEM_MANAGEMENT_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_PERFORMANCE_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_PERFORMANCE_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_MONITORING_TASK_LOG_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_MONITORING_TASK_LOG_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_MONITORING_TASK_LOG_DASHBOARD]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_MONITORING_TASK_LOG_DASHBOARD]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_MANAGE_COMPANY_USER]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_MANAGE_COMPANY_USER]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_EVENT_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_EVENT_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_ENROLLMENT_POLICY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_ENROLLMENT_POLICY_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_SVC_DIV]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_DASHBOARD_SVC_DIV]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_SVC]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_DASHBOARD_SVC]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_CONNECTIVITY]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_DASHBOARD_CONNECTIVITY]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_COM_DIV]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_DASHBOARD_COM_DIV]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_COM]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_DASHBOARD_COM]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_CONNECTIVITY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_CONNECTIVITY_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_CODE_SUB]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_CODE_SUB]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_ANY_TABLE]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_ANY_TABLE]
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_ADVERTISEMENT_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_SELECT_ADVERTISEMENT_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_MERGE_USER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_MERGE_USER_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_MERGE_TEST_ON_DEMAND]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_MERGE_TEST_ON_DEMAND]
GO
/****** Object:  StoredProcedure [dbo].[USP_MERGE_SERVER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_MERGE_SERVER_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_MERGE_MANAGE_COMPANY_USER]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_MERGE_MANAGE_COMPANY_USER]
GO
/****** Object:  StoredProcedure [dbo].[USP_INSERT_SYSTEM_LOG]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_INSERT_SYSTEM_LOG]
GO
/****** Object:  StoredProcedure [dbo].[USP_INSERT_MANAGE_COMPANY_USER]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_INSERT_MANAGE_COMPANY_USER]
GO
/****** Object:  StoredProcedure [dbo].[USP_DELETE_USER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_DELETE_USER_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_DELETE_SERVER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_DELETE_SERVER_LIST]
GO
/****** Object:  StoredProcedure [dbo].[USP_CREATE_TABLE_PARAMETER]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_CREATE_TABLE_PARAMETER]
GO
/****** Object:  StoredProcedure [dbo].[USP_CREATE_PROC_PARAMETER]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_CREATE_PROC_PARAMETER]
GO
/****** Object:  StoredProcedure [dbo].[USP_CREATE_DTO_CODE]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[USP_CREATE_DTO_CODE]
GO
/****** Object:  StoredProcedure [dbo].[IF_SERVERS]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_SERVERS]
GO
/****** Object:  StoredProcedure [dbo].[IF_ProblemManagement]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_ProblemManagement]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_SERVICE]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_SERVICE]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_PERFORMANCE]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_PERFORMANCE]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_EVENT]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_EVENT]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_DNSServiceAvailability]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_DNSServiceAvailability]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_DHCPServiceAvailability]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_DHCPServiceAvailability]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_CONNECTIVITY]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_CONNECTIVITY]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSW32TimeSync]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_ADDSW32TimeSync]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSTopology]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_ADDSTopology]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSSysvolShares]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_ADDSSysvolShares]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSRepository]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_ADDSRepository]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSReplication]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_ADDSReplication]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSAdvertisement]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_ADDSAdvertisement]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADCSServiceAvailability]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_ADCSServiceAvailability]
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADCSEnrollmentPolicy]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP PROCEDURE [dbo].[IF_LGE_NET_ADCSEnrollmentPolicy]
GO
/****** Object:  UserDefinedFunction [dbo].[UFN_GET_TABLE_COLUMNS_STR]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP FUNCTION [dbo].[UFN_GET_TABLE_COLUMNS_STR]
GO
/****** Object:  UserDefinedFunction [dbo].[UFN_GET_SPLIT_BigSize]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP FUNCTION [dbo].[UFN_GET_SPLIT_BigSize]
GO
/****** Object:  UserDefinedFunction [dbo].[UFN_GET_MONITOR_DATE]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP FUNCTION [dbo].[UFN_GET_MONITOR_DATE]
GO
/****** Object:  UserDefinedFunction [dbo].[UFN_GET_DOMAIN_NAME]    Script Date: 2015-01-13 오후 6:58:45 ******/
DROP FUNCTION [dbo].[UFN_GET_DOMAIN_NAME]
GO
/****** Object:  UserDefinedFunction [dbo].[UFN_GET_DOMAIN_NAME]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 임윤철
-- 작성일 : 2014.12.10  
-- 수정일 : 
-- 설  명 : 회사 도메인 또는 코드 입력시 회사 도메인을 반환함.
-- 실  행 : SELECT [dbo].[UFN_GET_MONITOR_DATE]('LGE', 'ADCS')

-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  
CREATE FUNCTION [dbo].[UFN_GET_DOMAIN_NAME]
(
	@COMPANY_NAME	NVARCHAR(50)
)
RETURNS nvarchar(16)
AS
BEGIN 
	
	--DECLARE @COMPANY_NAME	NVARCHAR(50)
	DECLARE @TEMP_NAME	 nvarchar(50)
	
	SET @COMPANY_NAME = 'LGE'


	SET @TEMP_NAME  = (SELECT VALUE2 FROM [dbo].[TB_COMMON_CODE_SUB] WHERE CLASS_CODE = '0001' AND SUB_CODE = @COMPANY_NAME)

	IF (@TEMP_NAME IS NULL) 
	BEGIN
		SET @TEMP_NAME  = (SELECT VALUE2 FROM [dbo].[TB_COMMON_CODE_SUB] WHERE CLASS_CODE = '0001' AND VALUE2 = @COMPANY_NAME)
	END

	--SELECT @TEMP_NAME
	

	RETURN @TEMP_NAME
 
 END


 
GO
/****** Object:  UserDefinedFunction [dbo].[UFN_GET_MONITOR_DATE]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 임윤철
-- 작성일 : 2014.12.10  
-- 수정일 : 
-- 설  명 : TB_MonitoringTaskLogs 에서 최근 모니터링한 시간을 가져온다.
-- 실  행 : SELECT [dbo].[UFN_GET_MONITOR_DATE]('LGE', 'ADCS')

-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  
CREATE FUNCTION [dbo].[UFN_GET_MONITOR_DATE]
(
	@COMPANY_NAME	NVARCHAR(50),
	@ADSERVICE      NVARCHAR(10)
)
RETURNS nvarchar(16)
AS
BEGIN 

	DECLARE @END_DATE    datetime
	DECLARE @LAST_DATE	 nvarchar(16)
	

	--SET @LAST_DATE = '2014-12-16 02:00' --'2014-12-09 09:16'
	SET @COMPANY_NAME = (SELECT [dbo].[UFN_GET_DOMAIN_NAME](@COMPANY_NAME))

	SET @END_DATE = (
						SELECT MAX(TaskDate)
						  FROM [ADSysMon].[dbo].[TB_MonitoringTaskLogs] 
 						 WHERE Company = @COMPANY_NAME
						   AND ADService = @ADSERVICE
						   AND TaskType = 'END' 
						 GROUP BY Company, ADService, TaskType
	 )

	SET @LAST_DATE = (
					 SELECT CONVERT(nvarchar(16),MAX(TaskDate),120)
					   FROM [ADSysMon].[dbo].[TB_MonitoringTaskLogs] 
					  WHERE Company = @COMPANY_NAME
						AND ADService = @ADSERVICE
						AND TaskType = 'START' 
						AND TaskDate <= @END_DATE
					  GROUP BY Company, ADService, TaskType
					)

	RETURN @LAST_DATE
 
 END
GO
/****** Object:  UserDefinedFunction [dbo].[UFN_GET_SPLIT_BigSize]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		(주)닷넷소프트 임윤철 
-- Create date: 2013.11.25
-- Description:	문자열을 SplitChar기준으로 테이블로 반환한다. BigSize SPLIT용 
-- SELECT * FROM [dbo].[UFN_GET_SPLIT_BigSize] ('Event^Service^PerLog^Replication', '^')
-- =============================================
CREATE FUNCTION [dbo].[UFN_GET_SPLIT_BigSize] 
(
	@String varchar(max), 
	@Delimiter char(1))

   RETURNS @temptable TABLE (items varchar(max)
)   
AS
   BEGIN
       DECLARE @idx INT        
        DECLARE @slice VARCHAR(8000)        

        SELECT @idx = 1        
            IF len(@String)<1 or @String is null  RETURN        

       WHILE @idx!= 0        
       BEGIN        
           SET @idx = charindex(@Delimiter,@String)        
           IF @idx!=0        
               SET @slice = left(@String,@idx - 1)        
           ELSE        
              SET @slice = @String        

           IF(len(@slice)>0)   
               INSERT INTO @temptable(Items) values(@slice)        

           SET @String = right(@String,len(@String) - @idx)        
           IF len(@String) = 0 BREAK        
       END    
   RETURN  
   END   

GO
/****** Object:  UserDefinedFunction [dbo].[UFN_GET_TABLE_COLUMNS_STR]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 박항록
-- 작성일 : 2014.11.06  
-- 수정일 : 2014.11.06  
-- 설   명 : 
-- 실   행 :  SELECT [dbo].[UFN_GET_TABLE_COLUMNS_STR]('TB_LGE_NET_ADDSSysvolShares')

-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  
CREATE FUNCTION [dbo].[UFN_GET_TABLE_COLUMNS_STR]
(
	@TABLE_NAME	NVARCHAR(50)
)
RETURNS nvarchar(2000)
AS
BEGIN 

	DECLARE @COLUMN_NAME varchar(50)
	DECLARE @DATA_TYPE	 varchar(50)
	DECLARE @IS_NULLABLE varchar(3)
	
	DECLARE @DTO_CODE	 varchar(8000)
	SET @DTO_CODE = ''

	DECLARE @TMP_CODE	 varchar(1000)

	DECLARE CUR_COLUMNS CURSOR FOR	
		SELECT COLUMN_NAME 
		  FROM INFORMATION_SCHEMA.COLUMNS
		 WHERE TABLE_NAME = @TABLE_NAME
		 ORDER BY ORDINAL_POSITION
	OPEN CUR_COLUMNS
	FETCH NEXT FROM CUR_COLUMNS
	INTO @COLUMN_NAME 
	WHILE @@FETCH_STATUS = 0 
	BEGIN
 	
		IF ( LEN(@DTO_CODE) = 0 )
		BEGIN 
			SET @DTO_CODE =   '['+ @COLUMN_NAME+ ']'
		END
		ELSE
		BEGIN
			SET @DTO_CODE = @DTO_CODE +', ' +  '['+ @COLUMN_NAME+ ']'
		END

		FETCH NEXT FROM CUR_COLUMNS INTO @COLUMN_NAME 
	END
	CLOSE CUR_COLUMNS
	DEALLOCATE CUR_COLUMNS

	RETURN @DTO_CODE
 
 END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADCSEnrollmentPolicy]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_ADCSEnrollmentPolicy]
 @ComputerName nvarchar(50)
,@OperatingSystem nvarchar(100)
,@OperatingSystemServicePack nvarchar(100)
,@CAName nvarchar(30)
,@DNSName nvarchar(30) 
,@CAType nvarchar(200)
,@CertEnrollPolicyTemplates nvarchar(max)
,@CATemplates nvarchar(max)
,@UTCMonitored datetime
,@IsError nvarchar(10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_ADCSEnrollmentPolicy]
   (  [ComputerName],
  [OperatingSystem],
  [OperatingSystemServicePack],
  [CAName],
  [DNSName],
  [CAType],
  [CertEnrollPolicyTemplates],
  [CATemplates],
  [UTCMonitored],
  [IsError]
   )
 VALUES
   (  @ComputerName,
  @OperatingSystem,
  @OperatingSystemServicePack,
  @CAName,
  @DNSName,
  @CAType,
  @CertEnrollPolicyTemplates,
  @CATemplates,
  @UTCMonitored,
  @IsError
   )

END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADCSServiceAvailability]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_ADCSServiceAvailability]
 @ComputerName nvarchar(50)
,@OperatingSystem nvarchar(100)
,@OperatingSystemServicePack nvarchar(100)
,@CAName nvarchar(30)
,@DNSName nvarchar(30) 
,@CAType nvarchar(200)
,@PingAdmin nvarchar(200)
,@Ping nvarchar(200)
,@UTCMonitored datetime
,@CrlPublishStatus nvarchar(MAX)
,@DeltaCrlPublishStatus nvarchar(MAX)
,@IsError nvarchar(10)        
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_ADCSServiceAvailability]
   (  [ComputerName],
  [OperatingSystem],
  [OperatingSystemServicePack],
  [CAName],
  [DNSName],
  [CAType],
  [PingAdmin],
  [Ping],
  [UTCMonitored],
  [CrlPublishStatus],
  [DeltaCrlPublishStatus],
  [IsError]
   )
 VALUES
   (  @ComputerName,
  @OperatingSystem,
  @OperatingSystemServicePack,
  @CAName,
  @DNSName,
  @CAType,
  @PingAdmin,
  @Ping,
  @UTCMonitored,
  @CrlPublishStatus,
  @DeltaCrlPublishStatus,
  @IsError
   )

END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSAdvertisement]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_ADDSAdvertisement]
 @ComputerName nvarchar(50)
    ,@IsGlobalCatalog nvarchar(10)
,@IsRODC nvarchar(10)
,@OperationMasterRoles nvarchar(max)
,@OperatingSystemServicePack nvarchar(30)
,@UTCMonitored datetime
,@OperatingSystem nvarchar(50)
    ,@dcdiag_advertising nvarchar(max)
,@IsError nvarchar(10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_ADDSAdvertisement]
   ( [ComputerName] 
    ,[IsGlobalCatalog] 
,[IsRODC]
,[OperationMasterRoles]
,[OperatingSystemServicePack]
,[UTCMonitored]
,[OperatingSystem]
    ,[dcdiag_advertising]
,[IsError]
)
 VALUES
   ( @ComputerName 
    ,@IsGlobalCatalog 
,@IsRODC
,@OperationMasterRoles
,@OperatingSystemServicePack
,@UTCMonitored
,@OperatingSystem
    ,@dcdiag_advertising
,@IsError
   )

END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSReplication]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[IF_LGE_NET_ADDSReplication]
 @ComputerName nvarchar(50)
,@repadmin nvarchar(100)
,@OperatingSystem nvarchar(100)
,@OperatingSystemServicePack nvarchar(100)
,@IsGlobalCatalog nvarchar(10)
,@IsRODC nvarchar(10)
,@OperationMasterRoles nvarchar(max)
,@UTCMonitored datetime
,@IsError nvarchar(10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_ADDSReplication]
   ( [ComputerName]
	,[repadmin]
	,[OperatingSystem]
	,[OperatingSystemServicePack]
	,[IsGlobalCatalog]
	,[IsRODC]
	,[OperationMasterRoles]
	,[UTCMonitored]
	,[IsError]
   )
 VALUES
   ( @ComputerName
	,@repadmin
	,@OperatingSystem
	,@OperatingSystemServicePack
	,@IsGlobalCatalog
	,@IsRODC
	,@OperationMasterRoles
	,@UTCMonitored
	,@IsError
   )

END

GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSRepository]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_ADDSRepository]
 @ComputerName nvarchar(50)
,@SysvolPath nvarchar(200)
,@LogFileSize nvarchar(20)
,@IsGlobalCatalog nvarchar(20)
,@DataBaseSize nvarchar(200)
,@IsRODC nvarchar(20)
,@LogFilePath nvarchar(200)
,@DataBasePath nvarchar(200)
,@DatabaseDriveFreeSpace nvarchar(50)
,@OperatingSystemServicePack nvarchar(50)
,@UTCMonitored datetime
,@OperatingSystem nvarchar(200)
,@IsError nvarchar(10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_ADDSRepository]
   (  [ComputerName]
 ,[SysvolPath]
 ,[LogFileSize]
 ,[IsGlobalCatalog]
 ,[DataBaseSize]
 ,[IsRODC]
 ,[LogFilePath]
 ,[DataBasePath]
 ,[DatabaseDriveFreeSpace]
 ,[OperatingSystemServicePack]
 ,[UTCMonitored]
 ,[OperatingSystem]
 ,[IsError]
   )
 VALUES
   ( @ComputerName
,@SysvolPath
,@LogFileSize
,@IsGlobalCatalog
,@DataBaseSize
,@IsRODC
,@LogFilePath
,@DataBasePath
,@DatabaseDriveFreeSpace
,@OperatingSystemServicePack
,@UTCMonitored
,@OperatingSystem
,@IsError
   )

END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSSysvolShares]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_ADDSSysvolShares]
 @ComputerName nvarchar(50)
,@frssysvol nvarchar(max)
,@OperatingSystem nvarchar(100)
,@OperatingSystemServicePack nvarchar(100)
,@IsGlobalCatalog nvarchar(10)
,@IsRODC nvarchar(10)
,@OperationMasterRoles nvarchar(max)
,@UTCMonitored datetime
,@IsError nvarchar(10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_ADDSSysvolShares]
   ( [ComputerName]
,[frssysvol]
,[OperatingSystem]
,[OperatingSystemServicePack]
,[IsGlobalCatalog]
,[IsRODC]
,[OperationMasterRoles]
,[UTCMonitored]
,[IsError]
   )
 VALUES
   ( @ComputerName
,@frssysvol
,@OperatingSystem
,@OperatingSystemServicePack
,@IsGlobalCatalog
,@IsRODC
,@OperationMasterRoles
,@UTCMonitored
,@IsError
   )

END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSTopology]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_ADDSTopology]
 @ComputerName nvarchar(50)
,@adtopology nvarchar(max)
,@OperatingSystem nvarchar(100)
,@OperatingSystemServicePack nvarchar(100)
,@IsGlobalCatalog nvarchar(10)
,@IsRODC nvarchar(10)
,@OperationMasterRoles nvarchar(max)
,@UTCMonitored datetime
,@IsError nvarchar(10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_ADDSTopology]
   ( [ComputerName]
        ,[adtopology]
,[OperatingSystem]
,[OperatingSystemServicePack]
,[IsGlobalCatalog]
,[IsRODC]
,[OperationMasterRoles]
,[UTCMonitored]
,[IsError]
   )
 VALUES
   ( @ComputerName
,@adtopology
,@OperatingSystem
,@OperatingSystemServicePack
,@IsGlobalCatalog
,@IsRODC
,@OperationMasterRoles
,@UTCMonitored
,@IsError
   )

END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_ADDSW32TimeSync]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[IF_LGE_NET_ADDSW32TimeSync]
 @ComputerName nvarchar(50)
,@LastSuccessfulSyncedTime nvarchar(50)
,@TimeSource nvarchar(50)
,@IsGlobalCatalog nvarchar(20)
,@IsRODC nvarchar(20)
,@OperationMasterRoles nvarchar(max)
,@OperatingSystemServicePack nvarchar(50)
,@UTCMonitored datetime
,@OperatingSystem nvarchar(200)
,@IsError [nvarchar](10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_ADDSW32TimeSync]
   (  [ComputerName],
  [LastSuccessfulSyncedTime],
  [TimeSource],
  [IsGlobalCatalog],
  [IsRODC],
  [OperationMasterRoles],
  [OperatingSystemServicePack],
  [UTCMonitored],
     [OperatingSystem],
  [IsError]
   )
 VALUES
   ( @ComputerName
,@LastSuccessfulSyncedTime
,@TimeSource
,@IsGlobalCatalog
,@IsRODC
,@OperationMasterRoles
,@OperatingSystemServicePack
,@UTCMonitored
        ,@OperatingSystem
,@IsError
   )

END

GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_CONNECTIVITY]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_CONNECTIVITY]
@ComputerName nvarchar(50)
,@CanPing nvarchar(5)
,@CanPort135 nvarchar(5)
,@UTCMonitored datetime
AS
BEGIN

INSERT INTO [dbo].[TB_LGE_NET_CONNECTIVITY]
( [ComputerName]
,[CanPing]
,[CanPort135]
,[UTCMonitored]
)
VALUES
( @ComputerName 
,@CanPing
,@CanPort135
,@UTCMonitored
)

END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_DHCPServiceAvailability]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_DHCPServiceAvailability]
    @ComputerName nvarchar(50), 
 @OperatingSystem nvarchar(100),
@OperatingSystemServicePack nvarchar(100),
@serverstatus nvarchar(300),
@UTCMonitored datetime,
@DatabaseName nvarchar(100),
@DatabasePath nvarchar(100),
@DatabaseBackupPath nvarchar(100),
@DatabaseBackupInterval nvarchar(20),
@DatabaseLoggingFlag nvarchar(20),
@DatabaseRestoreFlag nvarchar(20),
@DatabaseCleanupInterval nvarchar(20),
@IsError nvarchar(10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_DHCPServiceAvailability]
   ([ComputerName], 
[OperatingSystem],
[OperatingSystemServicePack],
[serverstatus],
[UTCMonitored],
[DatabaseName],
[DatabasePath],
[DatabaseBackupPath],
[DatabaseBackupInterval],
[DatabaseLoggingFlag],
[DatabaseRestoreFlag],
[DatabaseCleanupInterval],
[IsError])
 VALUES
   (@ComputerName, 
@OperatingSystem,
@OperatingSystemServicePack,
@serverstatus,
@UTCMonitored,
@DatabaseName,
@DatabasePath,
@DatabaseBackupPath,
@DatabaseBackupInterval,
@DatabaseLoggingFlag,
@DatabaseRestoreFlag,
@DatabaseCleanupInterval,
@IsError)
END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_DNSServiceAvailability]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_DNSServiceAvailability]
    @ComputerName nvarchar(50), 
 @OperatingSystem nvarchar(100),
@OperatingSystemServicePack nvarchar(100),
@dnsstatus nvarchar(300),
@UTCMonitored datetime,
@IsError nvarchar(10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_DNSServiceAvailability]
   ([ComputerName], 
[OperatingSystem],
[OperatingSystemServicePack],
[dnsstatus],
[UTCMonitored],
[IsError])
 VALUES
   (@ComputerName, 
@OperatingSystem,
@OperatingSystemServicePack,
@dnsstatus,
@UTCMonitored,
@IsError
   )

END
GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_EVENT]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROCEDURE [dbo].[IF_LGE_NET_EVENT]
	 @LogName nvarchar(30)
	,@TimeCreated datetime
	,@Id nvarchar(30)
	,@ProviderName nvarchar(30)
	,@LevelDisplayName nvarchar(30)
	,@Message nvarchar(max)
	,@ComputerName nvarchar(50)
	,@UTCMonitored datetime
	,@ServiceFlag nvarchar(10)
AS
BEGIN
INSERT INTO [dbo].[TB_LGE_NET_EVENT]
   ([LogName]
   ,[TimeCreated]
   ,[Id]
   ,[ProviderName]
   ,[LevelDisplayName]
   ,[Message]
   ,[ComputerName]
   ,[UTCMonitored]
   ,[ServiceFlag])
 VALUES
   (@LogName,
	@TimeCreated,
	@Id,
	@ProviderName,
	@LevelDisplayName,
    @Message,
    @ComputerName,
    @UTCMonitored,
    @ServiceFlag)
END

GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_PERFORMANCE]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[IF_LGE_NET_PERFORMANCE]
	 @TimeStamp datetime
	,@TimeStamp100NSec nvarchar(18)
	,@Value float
	,@Path nvarchar(100)
	,@InstanceName nvarchar(100)
	,@ComputerName nvarchar(50)
	,@UTCMonitored datetime
	,@ServiceFlag nvarchar(10)
AS
BEGIN
 
INSERT INTO [dbo].[TB_LGE_NET_PERFORMANCE]
   ( [TimeStamp] 
    ,[TimeStamp100NSec] 
	,[Value]
	,[Path]
	,[InstanceName]
    ,[ComputerName]
    ,[UTCMonitored]
	,[ServiceFlag]
   )
 VALUES
   ( @TimeStamp 
    ,@TimeStamp100NSec 
	,@Value
	,@Path
    ,@InstanceName
    ,@ComputerName 
	,@UTCMonitored
	,@ServiceFlag
   )

END


GO
/****** Object:  StoredProcedure [dbo].[IF_LGE_NET_SERVICE]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_LGE_NET_SERVICE]
@ServiceStatus nvarchar(30)
,@Name nvarchar(30)
,@DisplayName nvarchar(50)
,@ComputerName nvarchar(50)
,@UTCMonitored datetime
,@ServiceFlag nvarchar(10)
,@IsError nvarchar(10)
AS
BEGIN

INSERT INTO [dbo].[TB_LGE_NET_SERVICE]
( [ServiceStatus]
,[Name] 
,[DisplayName]
,[ComputerName]
,[UTCMonitored]
,[ServiceFlag]
,[IsError]
)
VALUES
( @ServiceStatus 
,@Name 
,@DisplayName
,@ComputerName
,@UTCMonitored
,@ServiceFlag
,@IsError
)

END
GO
/****** Object:  StoredProcedure [dbo].[IF_ProblemManagement]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_ProblemManagement]
 @MonitoredTime datetime
    ,@Company nvarchar(20)
,@ADService nvarchar(10)
,@ServiceItem nvarchar(50)
,@ComputerName nvarchar(50)
,@ProblemScript nvarchar(max)
    AS
BEGIN
 
INSERT INTO [dbo].[TB_ProblemManagement]
   ( [MonitoredTime] 
    ,[Company] 
,[ADService]
,[ServiceItem]
,[ComputerName]
,[ProblemScript]
    )
 VALUES
   ( @MonitoredTime 
    ,@Company 
,@ADService
,@ServiceItem
,@ComputerName 
        ,@ProblemScript
        )

END
GO
/****** Object:  StoredProcedure [dbo].[IF_SERVERS]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[IF_SERVERS]
@Domain nvarchar(30)
,@ServiceFlag nvarchar(10)
,@ComputerName nvarchar(50)
,@IPAddress nvarchar(15)
,@UTCMonitored datetime
AS
BEGIN

INSERT INTO [dbo].[TB_SERVERS]
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
GO
/****** Object:  StoredProcedure [dbo].[USP_CREATE_DTO_CODE]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[USP_CREATE_DTO_CODE]  
	 @TABLE_NAME		varchar(50)
AS  
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 
-- 작성일 : 2014.10.08  
-- 수정일 : 2014.10.08  
-- 설   명 : Dto클래스 코드생성
-- 실   행 :  EXEC [dbo].[USP_CREATE_DTO_CODE] 'TB_DOC_TRAVEL_MANAGEMENT'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  
  
SET NOCOUNT ON  

BEGIN
	
	DECLARE @COLUMN_NAME varchar(50)
	DECLARE @DATA_TYPE	 varchar(50)
	DECLARE @IS_NULLABLE varchar(3)
	
	DECLARE @DTO_CODE	 varchar(8000)
	SET @DTO_CODE = ''

	DECLARE @TMP_CODE	 varchar(1000)

	DECLARE CUR_COLUMNS CURSOR FOR	
	SELECT COLUMN_NAME, DATA_TYPE, IS_NULLABLE
	  FROM INFORMATION_SCHEMA.COLUMNS
	 WHERE TABLE_NAME = @TABLE_NAME
	 ORDER BY ORDINAL_POSITION
	OPEN CUR_COLUMNS
	FETCH NEXT FROM CUR_COLUMNS
	INTO @COLUMN_NAME, @DATA_TYPE, @IS_NULLABLE
	WHILE @@FETCH_STATUS = 0 
	BEGIN

		SET @TMP_CODE = '/// <summary>' + char(13) + char(10) + '/// ' + char(13) + char(10) + '/// </summary> ' + char(13) + char(10)
		SET @TMP_CODE = @TMP_CODE + 'public '
		IF @DATA_TYPE = 'int' 
			SET @TMP_CODE = @TMP_CODE + 'int ' + @COLUMN_NAME 
		ELSE IF (@DATA_TYPE = 'money' OR @DATA_TYPE = 'numeric')
		BEGIN
			IF @IS_NULLABLE = 'YES'
				SET @TMP_CODE = @TMP_CODE + 'decimal? ' + @COLUMN_NAME 
			ELSE 
				SET @TMP_CODE = @TMP_CODE + 'decimal ' + @COLUMN_NAME 
		END
		ELSE IF (@DATA_TYPE = 'date' OR @DATA_TYPE = 'smalldatetime')
		BEGIN
			IF @IS_NULLABLE = 'YES'
				SET @TMP_CODE = @TMP_CODE + 'DateTime? ' + @COLUMN_NAME 
			ELSE
				SET @TMP_CODE = @TMP_CODE + 'DateTime ' + @COLUMN_NAME 
		END		
		ELSE
			SET @TMP_CODE = @TMP_CODE + 'string ' + @COLUMN_NAME
			
		SET @TMP_CODE = @TMP_CODE + ' { get; set; }'
		
		--Append Dto Code		
		SET @DTO_CODE = @DTO_CODE + @TMP_CODE + char(13) + char(10) + char(13) + char(10)

		FETCH NEXT FROM CUR_COLUMNS INTO @COLUMN_NAME, @DATA_TYPE, @IS_NULLABLE
	END
	CLOSE CUR_COLUMNS
	DEALLOCATE CUR_COLUMNS

	SELECT @DTO_CODE

END  
 


GO
/****** Object:  StoredProcedure [dbo].[USP_CREATE_PROC_PARAMETER]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[USP_CREATE_PROC_PARAMETER]  
	 @PROCEDURE_NAME		varchar(50)
AS  
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 
-- 작성일 : 2014.10.08  
-- 수정일 : 2014.10.08  
-- 설   명 : Dto클래스 코드생성
-- 실   행 :  EXEC [dbo].[USP_CREATE_PROC_PARAMETER] 'USP_DELETE_SAMPLE_REQUEST_ITEMS_ALL'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  
  
SET NOCOUNT ON  

BEGIN
	
	DECLARE @PARAM_NAME varchar(50)
	
	DECLARE @PARAMETER	 varchar(8000)
	SET @PARAMETER = ''

	DECLARE CUR_PARAMS CURSOR FOR	
	SELECT PARAMETER_NAME 
	  FROM information_schema.parameters
	 WHERE specific_name= @PROCEDURE_NAME
	 ORDER BY ORDINAL_POSITION
	OPEN CUR_PARAMS
	FETCH NEXT FROM CUR_PARAMS
	INTO @PARAM_NAME
	WHILE @@FETCH_STATUS = 0 
	BEGIN

		--Append Paremeter		
		SET @PARAMETER = @PARAMETER + @PARAM_NAME + ', '

		FETCH NEXT FROM CUR_PARAMS INTO @PARAM_NAME
	END
	CLOSE CUR_PARAMS
	DEALLOCATE CUR_PARAMS

	SELECT @PARAMETER

END  
 


GO
/****** Object:  StoredProcedure [dbo].[USP_CREATE_TABLE_PARAMETER]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트   
-- 작성일 : 2014.10.08  
-- 수정일 : 2014.10.08  
-- 설   명 : Table
-- 실   행 :  EXEC [dbo].[USP_CREATE_TABLE_PARAMETER] 'TB_LGE_NET_PERFORMANCE'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  
CREATE PROCEDURE [dbo].[USP_CREATE_TABLE_PARAMETER]  
	 @TABLE_NAME		varchar(50)
AS  
  
SET NOCOUNT ON  

BEGIN
	
	DECLARE @PARAM_NAME varchar(50)
	
	DECLARE @PARAMETER	 varchar(8000)
	SET @PARAMETER = ''

	SELECT ',@' + COLUMN_NAME + char(9) + CASE WHEN CHARACTER_MAXIMUM_LENGTH IS NOT NULL THEN DATA_TYPE + '(' + CONVERT(varchar(10), CHARACTER_MAXIMUM_LENGTH) + ')' ELSE DATA_TYPE END
	  FROM INFORMATION_SCHEMA.COLUMNS
	 WHERE TABLE_NAME = @TABLE_NAME
	 ORDER BY ORDINAL_POSITION

END  
 


GO
/****** Object:  StoredProcedure [dbo].[USP_DELETE_SERVER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.22  
-- 수정일 : 2014.12.22  
-- 설   명 : 서버 리스트 삭제
-- 실   행 : EXEC [dbo].[USP_DELETE_SERVER_LIST] 'LGE.NET','ADCS','TESTTEST'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_DELETE_SERVER_LIST] 
	@DOMAIN			NVARCHAR(30),
	@SERVICEFLAG	NVARCHAR(10),
	@COMPUTERNAME	NVARCHAR(50)
AS
BEGIN
	SET NOCOUNT ON;

DELETE FROM [dbo].[TB_SERVERS]
      WHERE [Domain] = @DOMAIN
	    AND [ServiceFlag] = @SERVICEFLAG
		AND	[ComputerName] = @COMPUTERNAME
END



GO
/****** Object:  StoredProcedure [dbo].[USP_DELETE_USER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.23  
-- 수정일 : 2014.12.23  
-- 설   명 : 유저 논리 삭제
-- 실   행 : EXEC [dbo].[USP_DELETE_USER_LIST] 'test2'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_DELETE_USER_LIST] 
	@USERID			NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;

UPDATE [dbo].[TB_USER]
   SET [USEYN] = 'N'
      ,[CREATE_DATE] = GETUTCDATE()
 WHERE [USERID] = @USERID
END

GO
/****** Object:  StoredProcedure [dbo].[USP_INSERT_MANAGE_COMPANY_USER]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.19  
-- 수정일 : 2014.12.19  
-- 설   명 : 회사 담당 목록 추가
-- 실   행 : EXEC [dbo].[USP_INSERT_MANAGE_COMPANY_USER] 'admin', 'LGE', 'system'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_INSERT_MANAGE_COMPANY_USER] 
	@USERID			NVARCHAR(10),
	@COMPANYCODE	NVARCHAR(10),
	@CREATE_ID		NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;	

	INSERT INTO [dbo].[TB_MANAGE_COMPANY_USER]
           ([USERID]
           ,[COMPANYCODE]
           ,[CREATE_ID]
           ,[CREATE_DATE]
           ,[USEYN])
     VALUES
           (@USERID
           ,@COMPANYCODE
           ,@CREATE_ID
           ,GETUTCDATE()
           ,'Y')
END




GO
/****** Object:  StoredProcedure [dbo].[USP_INSERT_SYSTEM_LOG]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 
-- 작성일 : 2014.11.13  
-- 수정일 : 2014.11.13  
-- 설   명 : TB_SYSTEM_LOG 저장
-- 실   행 : 
[dbo].[USP_CREATE_DTO_CODE] 'TB_SYSTEM_LOG'
[dbo].[USP_CREATE_TABLE_PARAMETER] 'TB_SYSTEM_LOG'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
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
/****** Object:  StoredProcedure [dbo].[USP_MERGE_MANAGE_COMPANY_USER]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


 /*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.19  
-- 수정일 : 2014.12.19  
-- 설  명 :  
-- 실  행 : 

[dbo].[USP_MERGE_MANAGE_COMPANY_USER] 'test', 'HIP','system', 'Y'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  

CREATE PROCEDURE  [dbo].[USP_MERGE_MANAGE_COMPANY_USER] 
	@USERID			NVARCHAR(10),
	@COMPANYCODE	NVARCHAR(MAX),
	@CREATEID		NVARCHAR(10),
	@USEYN			VARCHAR(1)
AS
BEGIN

	SET NOCOUNT ON;
	
	DECLARE @TEMP_COMPANY table (
		USERID nvarchar(10),
		COMPANYCODE nvarchar(10)
	)
	INSERT INTO @TEMP_COMPANY

	SELECT @USERID, items FROM [dbo].[UFN_GET_SPLIT_BigSize] (@COMPANYCODE,'^')


	MERGE dbo.TB_MANAGE_COMPANY_USER AS TB1
	USING (SELECT userid , companycode  from @TEMP_COMPANY ) AS TB2
	   ON TB1.USERID = TB2.USERID AND TB1.COMPANYCODE = TB2.COMPANYCODE
	 WHEN matched THEN
	 UPDATE
	    SET USEYN = @USEYN,
			CREATE_ID = @CREATEID,
			CREATE_DATE = GETUTCDATE()
	 WHEN not matched THEN
	 INSERT (   [USERID]
			   ,[COMPANYCODE]
			   ,[CREATE_ID]
			   ,[CREATE_DATE]
			   ,[USEYN]		
			)
	 VALUES (  @USERID
			  ,@COMPANYCODE
              ,@CREATEID
              ,GETUTCDATE()
              ,'Y');	

 
END

GO
/****** Object:  StoredProcedure [dbo].[USP_MERGE_SERVER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.22  
-- 수정일 : 2014.12.22  
-- 설   명 : SERVER LIST MARGE
-- 실   행 : EXEC [dbo].[USP_MERGE_SERVER_LIST] 'LGE.NET','ADCS','TESTTEST','10.0.0.1'
-------------------------------------------------------------------------------------  
-- 수   정   일 : 
-- 수   정   자 : 
-- 수 정  내 용 : 
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_MERGE_SERVER_LIST] 
	@DOMAIN			NVARCHAR(30),
	@SERVICEFLAG	NVARCHAR(10),
	@COMPUTERNAME	NVARCHAR(50),
	@IPADDRESS		NVARCHAR(15)
AS
BEGIN
	SET NOCOUNT ON;
	
	MERGE	[dbo].[TB_SERVERS] AS TB1
	USING	(SELECT	@DOMAIN	AS [Domain],
					@SERVICEFLAG AS [ServiceFlag],
					@COMPUTERNAME AS [ComputerName])	AS TB2
	   ON	TB1.[Domain] = TB2.[Domain]
	  AND	TB1.[ServiceFlag] = TB2.[ServiceFlag]
	  AND	TB1.[ComputerName] = TB2.[ComputerName]
	 WHEN	MATCHED THEN
   UPDATE
      SET	--[Domain] = @DOMAIN,
			--[ServiceFlag] = @SERVICEFLAG,
			[ComputerName] = @COMPUTERNAME,
			[IPAddress] = @IPADDRESS,
			[UTCMonitored] = GETUTCDATE()
	 WHEN	NOT MATCHED THEN
   INSERT	(	[Domain],
				[ServiceFlag],
				[ComputerName],
				[IPAddress],
				[UTCMonitored]
			)
	VALUES	(	@DOMAIN,
				@SERVICEFLAG,
				@COMPUTERNAME,
				@IPADDRESS,
				GETUTCDATE()
			);
END
GO
/****** Object:  StoredProcedure [dbo].[USP_MERGE_TEST_ON_DEMAND]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 /*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHR
-- 작성일 : 2014.12.12  
-- 수정일 : 2014.12.12  
-- 설  명 :  
-- 실  행 : [dbo].[USP_CREATE_TABLE_PARAMETER] 'TB_TestOnDemand'
[dbo].[USP_CREATE_PROC_PARAMETER] 'USP_MERGE_TEST_ON_DEMAND'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  

CREATE PROCEDURE  [dbo].[USP_MERGE_TEST_ON_DEMAND] 
	@IDX	int
	,@DemandDate		datetime
	,@Company			nvarchar(20)
	,@TOD_Code			nvarchar(5)
	,@TOD_Demander		nvarchar(50)
	,@TOD_Result		nvarchar(1)
	,@TOD_ResultScript	nvarchar(MAX)
	,@CompleteDate		datetime
AS
BEGIN

	SET NOCOUNT ON;
	
	MERGE dbo.TB_TestOnDemand AS TB1
	USING (SELECT @IDX AS  IDX  ) AS TB2
	   ON TB1.IDX = TB2.IDX 
	 WHEN matched THEN
	 UPDATE
	    SET   
			TOD_Result = @TOD_Result, 
			TOD_ResultScript = @TOD_ResultScript, 
			CompleteDate = GETUTCDATE()
	 WHEN not matched THEN
	 INSERT (  DemandDate		
	 		  ,Company			
	 		  ,TOD_Code			
			  ,TOD_Demander		
			  ,TOD_Result		
	 		  ,TOD_ResultScript	
	 		  ,CompleteDate		
			)
	 VALUES (  @DemandDate		 
			  ,@Company			
			  ,@TOD_Code			
			  ,@TOD_Demander		
			  ,@TOD_Result		
			  ,@TOD_ResultScript	
			  ,@CompleteDate	);	

  SELECT ISNULL(CAST(SCOPE_IDENTITY() AS INT),@IDX) AS IDX 
END
GO
/****** Object:  StoredProcedure [dbo].[USP_MERGE_USER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.23  
-- 수정일 : 2014.12.23  
-- 설   명 : USER LIST MARGE
-- 실   행 : EXEC [dbo].[USP_MERGE_USER_LIST] 'twkim',N'김태원','nf3j54XWVGk=','','','Y'
-------------------------------------------------------------------------------------  
-- 수   정   일 : 
-- 수   정   자 : 
-- 수 정  내 용 : 
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_MERGE_USER_LIST] 
	@USERID			NVARCHAR(10),
	@USERNAME		NVARCHAR(50),
	@PASSWORD		NVARCHAR(1000),
	@MAILADDRESS	NVARCHAR(50),
	@MOBILEPHONE	NVARCHAR(15),
	@USEYN			CHAR(1)
AS
BEGIN
	SET NOCOUNT ON;
	
	MERGE	[dbo].[TB_USER] AS TB1
	USING	(SELECT	@USERID	AS [USERID])	AS TB2
	   ON	TB1.[USERID] = TB2.[USERID]

	 WHEN	MATCHED THEN
   UPDATE
      SET	[USERID] = @USERID,
			[USERNAME] = @USERNAME,
			[PASSWORD] = @PASSWORD,
			[MAILADDRESS] = @MAILADDRESS,
			[MOBILEPHONE] = @MOBILEPHONE,
			[USEYN] = @USEYN,
			[CREATE_DATE] = GETUTCDATE()
	 WHEN	NOT MATCHED THEN
   INSERT	(	[USERID],
				[USERNAME],
				[PASSWORD],
				[MAILADDRESS],
				[MOBILEPHONE],
				[USEYN],
				[CREATE_DATE]
			)
	VALUES	(	@USERID,
				@USERNAME,
				@PASSWORD,
				@MAILADDRESS,
				@MOBILEPHONE,
				@USEYN,
				GETUTCDATE()
			);
END
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_ADVERTISEMENT_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.11
-- 수정일 : 2014.12.11  
-- 설   명 : AD DS Advertisement List
-- 실   행 : EXEC [dbo].[USP_SELECT_ADVERTISEMENT_LIST] 'LGE','ADDS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_ADVERTISEMENT_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_' + @ADSERVICE + 'Advertisement';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime'
 
	SET @PARAM = N' @MonitorTime nvarchar(25)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_ANY_TABLE]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- [UP_SELECT_ANY_TABLE]
-- 동적쿼리, 입력받은 테이블명으로 SELECT 결과를 반환
-- EXEC USP_SELECT_ANY_TABLE 'TB_LGE_NET_DHCPServiceAvailability', '2014-12-09 16:50'
-- =============================================
CREATE PROCEDURE [dbo].[USP_SELECT_ANY_TABLE]
(
	@TABLE_NAME nvarchar(100)
   ,@MON_TIME nvarchar(25) 
)
AS
BEGIN

	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

	--SET @TABLE_NAME = 'TB_LGE_NET_PERFORMANCE'
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLE_NAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLE_NAME + ']'

	--SET @SQL = @SQL + 'WHERE TimeStamp > ''2014-12-09 16:50'''
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime'

	--SELECT @SQL

	SET @PARAM = N' @MonitorTime nvarchar(25) '

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @MON_TIME --'2014-12-09 16:50'

END



GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_CODE_SUB]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHL
-- 작성일 : 2014.12.09  
-- 수정일 : 2014.12.09  
-- 설   명 : Common SUB CODE 목록조회
-- 실   행 : EXEC [dbo].[USP_SELECT_CODE_SUB] 'S005'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_CODE_SUB] 
	@CLASS_CODE VARCHAR(4)
AS
BEGIN
	SET NOCOUNT ON;
	
	SELECT [CLASS_CODE]
		  ,[SUB_CODE]
		  ,[USE_YN]
		  ,[CODE_NAME]
		  ,[SORT_SEQ]
		  ,[VALUE1]
		  ,[VALUE2]
	  FROM dbo.TB_COMMON_CODE_SUB
	 WHERE CLASS_CODE = @CLASS_CODE
	   AND USE_YN = 'Y'
	 ORDER BY [SORT_SEQ]

END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_CONNECTIVITY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHR
-- 작성일 : 2014.12.10
-- 수정일 : 2014.12.10  
-- 설   명 : 회사별 서비스 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_CONNECTIVITY_LIST] 'LGE','CONNECTIVITY'

exec sp_executesql N'[dbo].[USP_SELECT_CONNECTIVITY_LIST] @COMPANYCODE, @ADSERVICE',N'@COMPANYCODE nvarchar(3),@ADSERVICE nvarchar(12)',@COMPANYCODE=N'LGE',@ADSERVICE=N'CONNECTIVITY'
[dbo].[USP_CREATE_DTO_CODE] 'TB_LGE_NET_CONNECTIVITY'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_CONNECTIVITY_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME =  [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_CONNECTIVITY';
 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' ,  REPLACE(B.IPAddress,''Null'','''')  AS IPAddress FROM [ADSysMon].[dbo].[' + @TABLENAME + '] A LEFT OUTER JOIN  ( SELECT DISTINCT ComputerName AS Computer, IPAddress FROM [dbo].[TB_SERVERS] ) B ON ( A.ComputerName = B.Computer ) '
 
	SET @SQL = @SQL + ' WHERE A.UTCMonitored > @MonitorTime '
 
	SET @PARAM = N' @MonitorTime nvarchar(25), @pADSERVICE nvarchar(10)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME , @pADSERVICE = @ADSERVICE 
 
 
END

 
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_COM]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
-- =============================================
-- [USP_SELECT_DASHBOARD_COM]
-- DASH BOARD Lv0 회사별 Service Error Count 
-- EXEC [dbo].[USP_SELECT_DASHBOARD_COM] 'ADadmin'
-- =============================================
CREATE PROCEDURE [dbo].[USP_SELECT_DASHBOARD_COM]
(
	@USERID nvarchar(10)
)
AS
BEGIN


	DECLARE @COMPANYCODE NVARCHAR(20)  
	DECLARE @ADSERVICE NVARCHAR(16)
	DECLARE @DATETIME DATETIME


	IF OBJECT_ID('tempdb..#TMP_TB_BYCOMPANY') IS NOT NULL
		DROP TABLE #TMP_TB_BYCOMPANY

	CREATE TABLE #TMP_TB_BYCOMPANY (COMPANY nvarchar(20), ADSERVICE nvarchar(10), MonitoredTime datetime, CHK_CNT int)

	DECLARE ADM_CURSOR_COM CURSOR FOR --SELECT VALUE2 FROM TB_MANAGE_COMPANY_USER U INNER JOIN TB_COMMON_CODE_SUB B 
									  --	                ON ( U.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' AND U.USERID = @USERID ) 
									  --         ORDER BY SORT_SEQ ASC

									  -- 해당 company 만 조회할 경우 위에 쿼리로 변경
									  SELECT VALUE2 FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] 
									   WHERE CLASS_CODE = '0001' --AND VALUE2 IN ( SELECT [VALUE2] FROM TB_MANAGE_COMPANY_USER U INNER JOIN TB_COMMON_CODE_SUB B ON ( U.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' AND U.USERID = @USERID ) )
									   ORDER BY SORT_SEQ ASC
 
	OPEN ADM_CURSOR_COM

	FETCH NEXT FROM ADM_CURSOR_COM INTO @COMPANYCODE

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		--SELECT @COMPANYCODE
			SET @ADSERVICE = 'ADDS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYCOMPANY
			SELECT Company, ADService, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement]  -- SELECT * FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService


			SET @ADSERVICE = 'ADCS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYCOMPANY
			SELECT Company, ADService, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService


			SET @ADSERVICE = 'DNS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYCOMPANY
			SELECT Company, ADService, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService

			SET @ADSERVICE = 'DHCP'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYCOMPANY
			SELECT Company, ADService, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService


		FETCH NEXT FROM ADM_CURSOR_COM INTO @COMPANYCODE
	END 

	CLOSE ADM_CURSOR_COM
	DEALLOCATE ADM_CURSOR_COM



	--SELECT COMPANY, ADSERVICE, CHK_CNT FROM #TMP_TB_BYCOMPANY

	--SELECT COM.VALUE2, SVC.SUB_CODE 
	--  FROM (SELECT VALUE2, SORT_SEQ FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] WHERE CLASS_CODE = '0001') COM
	--	 , (SELECT SUB_CODE, SORT_SEQ FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] WHERE CLASS_CODE = '0002') SVC
	-- ORDER BY COM.SORT_SEQ, SVC.SORT_SEQ 


	--SELECT  LST.VALUE2, LST.SUB_CODE, CHK.COMPANY, CHK.ADSERVICE, CHK.CHK_CNT
	--SELECT  LST.VALUE2 as COMPANY, LST.SUB_CODE as ADSERVICE, CHK.CHK_CNT


	SELECT ST.CODE_NAME as COMPANY, ST.SUB_CODE as COMPANY_SUBCODE
	    , IIF(ORD.ADDS        IS NULL, 0, ORD.ADDS)        AS ADDS
		, IIF(ORD.ADCS        IS NULL, 0, ORD.ADCS)        AS ADCS
		, IIF(ORD.DNS         IS NULL, 0, ORD.DNS)         AS DNS
		, IIF(ORD.DHCP        IS NULL, 0, ORD.DHCP)        AS DHCP
		, '' AS RADIUS
		, TM.MonitoredTime AS MonitoredTime 
	  FROM (

		SELECT PVT.COMPANY, PVT.ADDS, PVT.ADCS, PVT.DNS, PVT.DHCP
		  FROM (

			SELECT  LST.VALUE2 as COMPANY, LST.SUB_CODE as ADSERVICE, CHK.CHK_CNT
			  FROM (SELECT COM.VALUE2, SVC.SUB_CODE, COM.SORT_SEQ
					  FROM (SELECT VALUE2, SORT_SEQ FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] WHERE CLASS_CODE = '0001'
							 --AND VALUE2 IN ( SELECT [VALUE2] FROM TB_MANAGE_COMPANY_USER U INNER JOIN TB_COMMON_CODE_SUB B ON ( U.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' ) )
						   ) COM
						 , (SELECT SUB_CODE, SORT_SEQ FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] WHERE CLASS_CODE = '0002') SVC
				   ) AS LST
				   LEFT OUTER JOIN
				   (SELECT COMPANY, ADSERVICE, CHK_CNT, MonitoredTime FROM #TMP_TB_BYCOMPANY) AS CHK
				   ON LST.VALUE2 = CHK.COMPANY AND LST.SUB_CODE = CHK.ADSERVICE
			 ) AS MST
			 PIVOT (SUM(CHK_CNT) FOR ADSERVICE IN ([ADDS],[ADCS],[DNS],[DHCP])) AS PVT
		 ) ORD 
		 LEFT JOIN (SELECT SUB_CODE, CODE_NAME, VALUE2, SORT_SEQ FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] WHERE CLASS_CODE = '0001') ST ON ST.VALUE2 = ORD.COMPANY 
		 LEFT JOIN (SELECT COMPANY, MAX(MonitoredTime) as MonitoredTime FROM #TMP_TB_BYCOMPANY GROUP BY COMPANY) TM ON TM.COMPANY = ORD.COMPANY  -- 이 부분은 TaskLog 에서 가져와야함 추후 수정

	 -- 해당 company 만 조회할 경우 아래 조건을 포함한다.
	 --WHERE ORD.COMPANY IN (SELECT VALUE2 FROM TB_MANAGE_COMPANY_USER U INNER JOIN TB_COMMON_CODE_SUB B ON ( U.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' AND U.USERID = @USERID ) )

	 ORDER BY ST.SORT_SEQ

	 

END




GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_COM_DIV]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- [USP_SELECT_DASHBOARD_COM]
-- DASH BOARD Lv1 고객사별 Service Error Count 
 --EXEC [dbo].[USP_SELECT_DASHBOARD_COM_DIV] 'LGE.NET', 'ADDS'
 --EXEC [dbo].[USP_SELECT_DASHBOARD_COM_DIV] 'LGE.NET', 'ADCS'
 --EXEC [dbo].[USP_SELECT_DASHBOARD_COM_DIV] 'LGE.NET', 'DNS'
 --EXEC [dbo].[USP_SELECT_DASHBOARD_COM_DIV] 'LGE.NET', 'DHCP'
-- =============================================
CREATE PROCEDURE [dbo].[USP_SELECT_DASHBOARD_COM_DIV]
(
	@COMPANYCODE nvarchar(10),
	@ADSERVICE nvarchar(4)
)
AS
BEGIN

	DECLARE @COM_CODE nvarchar(10)
	DECLARE @DATETIME DATETIME


	IF OBJECT_ID('tempdb..#TMP_TB_BYSERVICE') IS NOT NULL
		DROP TABLE #TMP_TB_BYSERVICE

	CREATE TABLE #TMP_TB_BYSERVICE (COMPANY nvarchar(20), ADSERVICE nvarchar(10), Serviceitem nvarchar(50), MonitoredTime datetime, CHK_CNT int)

	DECLARE ADM_CURSOR_COM CURSOR FOR SELECT VALUE2 FROM TB_COMMON_CODE_SUB WHERE CLASS_CODE = '0001' AND SUB_CODE = @COMPANYCODE
 
	OPEN ADM_CURSOR_COM

	FETCH NEXT FROM ADM_CURSOR_COM INTO @COM_CODE

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COM_CODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COM_CODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem

		FETCH NEXT FROM ADM_CURSOR_COM INTO @COM_CODE
	END 

	CLOSE ADM_CURSOR_COM
	DEALLOCATE ADM_CURSOR_COM



	IF @ADSERVICE = 'ADDS'
	BEGIN
		SELECT PVT.[Event],PVT.[Service],PVT.[Performance Data] as PerformanceData,PVT.[Replication],PVT.[Sysvol Shares] as SysvolShares
		      ,PVT.[Topology And Intersite Messaging] as TopologyAndIntersiteMessaging,PVT.[Repository],PVT.[Advertisement],PVT.[W32TimeSync]
		  FROM (
				SELECT VALUE2 AS ADService,  IIF(TMP.CHK_CNT IS NULL, 0, TMP.CHK_CNT) AS ErrorCount, SUB.CODE_NAME AS ADServiceName
				  FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] AS SUB 
				  LEFT OUTER JOIN (SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE	GROUP BY ADSERVICE, Serviceitem)
					AS TMP ON SUB.SUB_CODE = TMP.Serviceitem
				 WHERE CLASS_CODE = '0003'
				   AND VALUE2 = @ADSERVICE
				) MST
		 PIVOT (SUM(ErrorCount) FOR ADServiceName IN ([Event],[Service],[Performance Data],[Replication],[Sysvol Shares],[Topology And Intersite Messaging],[Repository],[Advertisement],[W32TimeSync])) AS PVT
	END

	IF @ADSERVICE = 'ADCS'
	BEGIN
		SELECT PVT.[Event],PVT.[Service],PVT.[Performance Data] as PerformanceData,PVT.[Service Availability] as ServiceAvailability,PVT.[Enrollment Policy Templates] as EnrollmentPolicyTemplates
		  FROM (
				SELECT VALUE2 AS ADService,  IIF(TMP.CHK_CNT IS NULL, 0, TMP.CHK_CNT) AS ErrorCount, SUB.CODE_NAME AS ADServiceName
				  FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] AS SUB 
				  LEFT OUTER JOIN (SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE	GROUP BY ADSERVICE, Serviceitem)
					AS TMP ON SUB.SUB_CODE = TMP.Serviceitem
				 WHERE CLASS_CODE = '0003'
				   AND VALUE2 = @ADSERVICE
				) MST
		 PIVOT (SUM(ErrorCount) FOR ADServiceName IN ([Event],[Service],[Performance Data],[Service Availability],[Enrollment Policy Templates])) AS PVT
	END

	IF @ADSERVICE = 'DNS'
	BEGIN
		SELECT PVT.[Event],PVT.[Service],PVT.[Performance Data] as PerformanceData,PVT.[Service Availability] as ServiceAvailability
		  FROM (
				SELECT VALUE2 AS ADService,  IIF(TMP.CHK_CNT IS NULL, 0, TMP.CHK_CNT) AS ErrorCount, SUB.CODE_NAME AS ADServiceName
				  FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] AS SUB 
				  LEFT OUTER JOIN (SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE	GROUP BY ADSERVICE, Serviceitem)
					AS TMP ON SUB.SUB_CODE = TMP.Serviceitem
				 WHERE CLASS_CODE = '0003'
				   AND VALUE2 = @ADSERVICE
				) MST
		 PIVOT (SUM(ErrorCount) FOR ADServiceName IN ([Event],[Service],[Performance Data],[Service Availability])) AS PVT
	END


	IF @ADSERVICE = 'DHCP'
	BEGIN
		SELECT PVT.[Event],PVT.[Service],PVT.[Performance Data] as PerformanceData,PVT.[Service Availability] as ServiceAvailability
		  FROM (
				SELECT VALUE2 AS ADService,  IIF(TMP.CHK_CNT IS NULL, 0, TMP.CHK_CNT) AS ErrorCount, SUB.CODE_NAME AS ADServiceName
				  FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] AS SUB 
				  LEFT OUTER JOIN (SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE	GROUP BY ADSERVICE, Serviceitem)
					AS TMP ON SUB.SUB_CODE = TMP.Serviceitem
				 WHERE CLASS_CODE = '0003'
				   AND VALUE2 = @ADSERVICE
				) MST
		 PIVOT (SUM(ErrorCount) FOR ADServiceName IN ([Event],[Service],[Performance Data],[Service Availability])) AS PVT
	END










--SELECT * FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB]  WHERE CLASS_CODE = '0003'




	--SELECT VALUE2 AS ADService, SUB.CODE_NAME AS ADServiceName, IIF(TMP.CHK_CNT IS NULL, 0, TMP.CHK_CNT) AS ErrorCount, SUB.SUB_CODE, TMP.MonitoredTime, SUB.SORT_SEQ
	--  FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] AS SUB 
	--  LEFT OUTER JOIN (SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE	GROUP BY ADSERVICE, Serviceitem)
 --       AS TMP ON SUB.SUB_CODE = TMP.Serviceitem
	-- WHERE CLASS_CODE = '0003'
	--   AND VALUE2 = @ADSERVICE
 --	 ORDER BY SORT_SEQ



END

GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_CONNECTIVITY]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHR
-- 작성일 : 2014.12.10
-- 수정일 : 2014.12.10  
-- 설   명 : 회사별 서비스 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_DASHBOARD_CONNECTIVITY] 'LGE' 

exec sp_executesql N'[dbo].[USP_SELECT_CONNECTIVITY_LIST] @COMPANYCODE, @ADSERVICE',N'@COMPANYCODE nvarchar(3),@ADSERVICE nvarchar(12)',@COMPANYCODE=N'LGE',@ADSERVICE=N'CONNECTIVITY'
[dbo].[USP_CREATE_DTO_CODE] 'TB_LGE_NET_CONNECTIVITY'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_DASHBOARD_CONNECTIVITY] 
	@COMPANYCODE NVARCHAR(10)  
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME =  [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, 'CONNECT')
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_CONNECTIVITY';
 


  
	IF EXISTS 
	(
		SELECT   '*'
		FROM     sys.objects 
		WHERE    object_id = OBJECT_ID(@TABLENAME) 
				 AND 
				 type in (N'U')
	)
	BEGIN
	 
		DECLARE @SQL nvarchar(max)
		DECLARE @COLUMNS_NAME nvarchar(max)
		DECLARE @PARAM nvarchar(100)

 
		SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

		SET @SQL = 'SELECT ISNULL(CanPing, 9999) AS CanPing,ISNULL(CanPort135, 9999) AS CanPort135 FROM
					(
					 SELECT 
					SUM(CASE CanPing WHEN ''True'' THEN 0 ELSE 1 END) CanPing, 
					SUM(CASE CanPort135 WHEN ''True'' THEN 0 ELSE 1 END) CanPort135
					FROM [ADSysMon].[dbo].[' + @TABLENAME + ']  '
 
		SET @SQL = @SQL + ' WHERE  UTCMonitored > @MonitorTime  ) A'
 
		SET @PARAM = N' @MonitorTime DATETIME '

		--select @SQL, @DATETIME
		EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME  
  
	END
	ELSE
	BEGIN
		SELECT 0  AS CanPing, 0 AS CanPort135
	END


END

GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_SVC]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- [USP_SELECT_DASHBOARD_COM]
-- DASH BOARD Lv0 서비스별 Service Error Count 
-- EXEC [dbo].[USP_SELECT_DASHBOARD_SVC_DIV] 'ADadmin', 'DHCP'
-- EXEC [dbo].[USP_SELECT_DASHBOARD_SVC] 'ADadmin'
-- USP_SELECT_DASHBOARD_SVC 는 전체 ADService 모두 조회
-- USP_SELECT_DASHBOARD_SVC_DIV 는 ADService 를 파라미터로 받아 해당 ADService 만 조회한다.
-- =============================================
CREATE PROCEDURE [dbo].[USP_SELECT_DASHBOARD_SVC]
(
	@USERID nvarchar(10)
)
AS
BEGIN


	DECLARE @COMPANYCODE NVARCHAR(20)  
	DECLARE @ADSERVICE NVARCHAR(16)
	DECLARE @DATETIME DATETIME


	IF OBJECT_ID('tempdb..#TMP_TB_BYSERVICE') IS NOT NULL
		DROP TABLE #TMP_TB_BYSERVICE

	CREATE TABLE #TMP_TB_BYSERVICE (COMPANY nvarchar(20), ADSERVICE nvarchar(10), Serviceitem nvarchar(50), MonitoredTime datetime, CHK_CNT int)

	DECLARE ADM_CURSOR_COM CURSOR FOR --SELECT VALUE2 FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] WHERE CLASS_CODE = '0001' ORDER BY SORT_SEQ ASC
										SELECT VALUE2 FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] 
										 WHERE CLASS_CODE = '0001' -- AND VALUE2 IN ( SELECT [VALUE2] FROM TB_MANAGE_COMPANY_USER U INNER JOIN TB_COMMON_CODE_SUB B ON ( U.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' ) )
										 ORDER BY SORT_SEQ ASC
 
	OPEN ADM_CURSOR_COM

	FETCH NEXT FROM ADM_CURSOR_COM INTO @COMPANYCODE

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		--SELECT @COMPANYCODE
			SET @ADSERVICE = 'ADDS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem


			SET @ADSERVICE = 'ADCS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem


			SET @ADSERVICE = 'DNS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem

			SET @ADSERVICE = 'DHCP'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem


		FETCH NEXT FROM ADM_CURSOR_COM INTO @COMPANYCODE
	END 

	CLOSE ADM_CURSOR_COM
	DEALLOCATE ADM_CURSOR_COM

	--SELECT COMPANY, ADSERVICE, Serviceitem, MonitoredTime, CHK_CNT FROM #TMP_TB_BYSERVICE



	--SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE
	--GROUP BY ADSERVICE, Serviceitem


	SELECT LEFT(SUB.SUB_CODE,2) AS ADService, SUB.CODE_NAME AS ADServiceName, IIF(TMP.CHK_CNT IS NULL, 0, TMP.CHK_CNT) AS ErrorCount, SUB.SUB_CODE, TMP.MonitoredTime, SUB.SORT_SEQ
	  FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] AS SUB 
	  LEFT OUTER JOIN (SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE	GROUP BY ADSERVICE, Serviceitem)
        AS TMP ON SUB.SUB_CODE = TMP.Serviceitem
	 WHERE CLASS_CODE = '0003' 
 	 ORDER BY SORT_SEQ


-- EXEC [dbo].[USP_SELECT_DASHBOARD_SVC] 'ADadmin'	

	--SELECT COMPANY, ADSERVICE, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE
	--GROUP BY COMPANY, ADSERVICE

END


--SELECT * FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_DASHBOARD_SVC_DIV]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
-- =============================================
-- [USP_SELECT_DASHBOARD_COM]
-- DASH BOARD Lv0 서비스별 Service Error Count 
-- EXEC [dbo].[USP_SELECT_DASHBOARD_SVC_DIV] 'admin', 'ADDS'
-- EXEC [dbo].[USP_SELECT_DASHBOARD_SVC] 'ADadmin'
-- USP_SELECT_DASHBOARD_SVC 는 전체 ADService 모두 조회
-- USP_SELECT_DASHBOARD_SVC_DIV 는 ADService 를 파라미터로 받아 해당 ADService 만 조회한다.
-- =============================================
CREATE PROCEDURE [dbo].[USP_SELECT_DASHBOARD_SVC_DIV]
(
	@USERID nvarchar(10),
	@ADSERVICE nvarchar(4)
)
AS
BEGIN


	DECLARE @COMPANYCODE NVARCHAR(20)  
	--DECLARE @ADSERVICE NVARCHAR(16)
	DECLARE @DATETIME DATETIME, @LASTDATETIME DATETIME


	IF OBJECT_ID('tempdb..#TMP_TB_BYSERVICE') IS NOT NULL
		DROP TABLE #TMP_TB_BYSERVICE

	CREATE TABLE #TMP_TB_BYSERVICE (COMPANY nvarchar(20), ADSERVICE nvarchar(10), Serviceitem nvarchar(50), MonitoredTime datetime, CHK_CNT int)

	DECLARE ADM_CURSOR_COM CURSOR FOR SELECT VALUE2 FROM TB_MANAGE_COMPANY_USER U INNER JOIN TB_COMMON_CODE_SUB B 
										                ON ( U.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' AND U.USERID = @USERID ) ORDER BY SORT_SEQ ASC
 
	OPEN ADM_CURSOR_COM

	FETCH NEXT FROM ADM_CURSOR_COM INTO @COMPANYCODE

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		--SELECT @COMPANYCODE
		--	SET @ADSERVICE = 'ADDS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE]( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE
			   AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem

			IF ( @DATETIME IS NOT NULL)
			BEGIN
				SET @LASTDATETIME = @DATETIME
			END

		FETCH NEXT FROM ADM_CURSOR_COM INTO @COMPANYCODE
	END 

	CLOSE ADM_CURSOR_COM
	DEALLOCATE ADM_CURSOR_COM

	--SELECT COMPANY, ADSERVICE, Serviceitem, MonitoredTime, CHK_CNT FROM #TMP_TB_BYSERVICE



	--SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE
	--GROUP BY ADSERVICE, Serviceitem


	SELECT VALUE2 AS ADService, SUB.CODE_NAME AS ADServiceName, IIF(TMP.CHK_CNT IS NULL, 0, TMP.CHK_CNT) AS ErrorCount, SUB.SUB_CODE, ISNULL(TMP.MonitoredTime, @LASTDATETIME) AS MonitoredTime, SUB.SORT_SEQ
	  FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] AS SUB 
	  LEFT OUTER JOIN (SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE	GROUP BY ADSERVICE, Serviceitem)
        AS TMP ON SUB.SUB_CODE = TMP.Serviceitem
	 WHERE CLASS_CODE = '0003'
	   AND VALUE2 = @ADSERVICE
 	 ORDER BY SORT_SEQ


-- EXEC [dbo].[USP_SELECT_DASHBOARD_SVC] 'ADadmin'	

	--SELECT COMPANY, ADSERVICE, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT FROM #TMP_TB_BYSERVICE
	--GROUP BY COMPANY, ADSERVICE

END


--SELECT * FROM [ADSysMon].[dbo].[TB_ProblemManagement] 


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_ENROLLMENT_POLICY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.11
-- 수정일 : 2014.12.11  
-- 설   명 : AD CS Enrollment Policy Templates
-- 실   행 : EXEC [dbo].[USP_SELECT_ENROLLMENT_POLICY_LIST] 'LGE','ADCS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_ENROLLMENT_POLICY_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_' + @ADSERVICE + 'EnrollmentPolicy';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime'
 
	SET @PARAM = N' @MonitorTime nvarchar(25)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_EVENT_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHL
-- 작성일 : 2014.12.09  
-- 수정일 : 2014.12.09  
-- 설   명 : 회사 담당 목록 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_EVENT_LIST] 'LGE','ADDS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_EVENT_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_EVENT';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime AND ServiceFlag = @pADSERVICE'
 
	SET @PARAM = N' @MonitorTime nvarchar(25), @pADSERVICE nvarchar(10)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME , @pADSERVICE = @ADSERVICE 
 
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_MANAGE_COMPANY_USER]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHL
-- 작성일 : 2014.12.09  
-- 수정일 : 2014.12.09  
-- 설   명 : 회사 담당 목록 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_MANAGE_COMPANY_USER] 'test'
-------------------------------------------------------------------------------------  
-- 수   정   일 : 2014.12.22
-- 수   정   자 : KTW  
-- 수 정  내 용 : [USEYN]이 'Y' 이것만 가져오도록 수정.
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_MANAGE_COMPANY_USER] 
	@USERID NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;
	
	SELECT 
		USERID,
		COMPANYCODE,
		B.CODE_NAME AS COMPANYNAME,
	    B.VALUE1 AS	TABLENAME,
		B.VALUE2 AS DOMAINNAME
	  FROM dbo.TB_MANAGE_COMPANY_USER A
	  LEFT OUTER JOIN dbo.TB_COMMON_CODE_SUB B ON ( A.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' )
	 WHERE USERID = @USERID
	   AND A.USEYN = 'Y'
 
END



GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_MONITORING_TASK_LOG_DASHBOARD]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트
-- 작성일 : 2014.12.09  
-- 수정일 : 2014.12.09  
-- 설   명 : 고객사별 DASHBOARD TASKLOG LIST 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_MONITORING_TASK_LOG_DASHBOARD]  'LGE'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_MONITORING_TASK_LOG_DASHBOARD] 
	@COMPANY NVARCHAR(50)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @DOMAIN NVARCHAR(50)

	SET @DOMAIN = (SELECT [dbo].[UFN_GET_DOMAIN_NAME](@COMPANY))

	SELECT IIF(ST.ADService = 'CONNECT', 'ZCONNECT', ST.ADService) AS IDX,
		   ST.Company, IIF(ST.ADService = 'CONNECT', 'CONNECTIVITY', ST.ADService) AS TaskName, 
		   ST.TaskType AS START, 
		   CONVERT(nvarchar(16),ST.TaskDate,120) AS STARTDATE, 
		   IIF(ED.TaskType IS NULL, 'END', 'END') AS [END], 
		   CONVERT(nvarchar(16),IIF(ED.TaskDate IS NULL, '', ED.TaskDate),120) AS ENDDATE
			 FROM (SELECT MAX([TaskDate]) AS TaskDate, Company, ADService, TaskType 
					   FROM [ADSysMon].[dbo].[TB_MonitoringTaskLogs] WHERE TaskType = 'START'
					   AND Company = @DOMAIN
					  GROUP BY Company, ADService, TaskType
					) ST
			 LEFT JOIN 
				  (SELECT MAX([TaskDate]) AS TaskDate, Company, ADService, TaskType 
					   FROM [ADSysMon].[dbo].[TB_MonitoringTaskLogs] WHERE TaskType = 'END'
						AND Company = @DOMAIN
					  GROUP BY Company, ADService, TaskType
				  ) ED
			   ON (ST.Company = ED.Company AND ST.ADService = ED.ADService AND ST.TaskDate < ED.TaskDate)
	ORDER BY IDX
END



GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_MONITORING_TASK_LOG_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.12
-- 수정일 : 2014.12.12  
-- 설   명 : Monitoring Task Log List 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_MONITORING_TASK_LOG_LIST] 'admin'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_MONITORING_TASK_LOG_LIST] 
	@USERID NVARCHAR(10)
AS 
	BEGIN 
	SET nocount ON;

	SELECT   [TaskDate]
			,[TaskType]
			,[Company]
			,[ADService]
			,[Serviceitem]
			,[ComputerName]
			,[TaskScript]
			,[CreateDate]
	FROM   [ADSysMon].[dbo].[TB_MonitoringTaskLogs] A 
			LEFT OUTER JOIN TB_COMMON_CODE_SUB S 
						ON ( A.Serviceitem = S.SUB_CODE 
							AND S.CLASS_CODE = '0003' ) 
	WHERE  Company IN (SELECT [VALUE2] 
						FROM   TB_MANAGE_COMPANY_USER U 
							INNER JOIN TB_COMMON_CODE_SUB B 
									ON ( U.COMPANYCODE = B.SUB_CODE 
											AND B.CLASS_CODE = '0001' 
											AND U.USERID = @USERID))
			 
END
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_PERFORMANCE_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.10
-- 수정일 : 2014.12.10  
-- 설   명 : 회사별 퍼포먼스 데이터 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_PERFORMANCE_LIST] 'LGE','ADDS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_PERFORMANCE_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_PERFORMANCE';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime AND ServiceFlag = @pADSERVICE'
 
	SET @PARAM = N' @MonitorTime nvarchar(25), @pADSERVICE nvarchar(10)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME , @pADSERVICE = @ADSERVICE  
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_PROBLEM_MANAGEMENT_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.12
-- 수정일 : 2014.12.12  
-- 설   명 : ProblemManagement 테이블 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_PROBLEM_MANAGEMENT_LIST] 'admin'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_PROBLEM_MANAGEMENT_LIST] 
	@USERID NVARCHAR(10)
AS 
	BEGIN 
	SET nocount ON;

	SELECT   [IDX]
			,[MonitoredTime]
			,[Company]
			,[ADService]
			,S.CODE_NAME as Serviceitem
			,[ComputerName]
			,[ProblemScript]
			,[ManageStatus]
			,[Manager]
			,[ManageScript]
			,[ManageDate]
	FROM   dbo.TB_ProblemManagement A 
			LEFT OUTER JOIN TB_COMMON_CODE_SUB S 
						ON ( A.Serviceitem = S.SUB_CODE 
							AND S.CLASS_CODE = '0003' ) 
	WHERE  Company IN (SELECT [VALUE2] 
						FROM   TB_MANAGE_COMPANY_USER U 
							INNER JOIN TB_COMMON_CODE_SUB B 
									ON ( U.COMPANYCODE = B.SUB_CODE 
											AND B.CLASS_CODE = '0001' 
											AND U.USERID = @USERID))
ORDER BY IDX DESC
			 
END
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_REPLICATION_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.11
-- 수정일 : 2014.12.11  
-- 설   명 : AD DS Replication List
-- 실   행 : EXEC [dbo].[USP_SELECT_REPLICATION_LIST] 'LGE','ADDS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_REPLICATION_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_' + @ADSERVICE + 'Replication';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime'
 
	SET @PARAM = N' @MonitorTime nvarchar(25)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_REPOSITORY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.11
-- 수정일 : 2014.12.11  
-- 설   명 : AD DS Repository List
-- 실   행 : EXEC [dbo].[USP_SELECT_REPOSITORY_LIST] 'LGE','ADDS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_REPOSITORY_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_' + @ADSERVICE + 'Repository';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime'
 
	SET @PARAM = N' @MonitorTime nvarchar(25)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVER_CHART_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 
-- 작성일 : 2014.12.22
-- 수정일 : 2014.12.22  
-- 설   명 : 서버별 CPU, Memory, Disk 차트 데이터 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_SERVER_CHART_LIST] 'LGE'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_SERVER_CHART_LIST]  
	@COMPANYCODE NVARCHAR(10) 
AS
BEGIN
	SET NOCOUNT ON;
	  
	  
		DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
 
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_PERFORMANCE';

 
	DECLARE @SQL nvarchar(max)
 
 
 
	 SET @SQL = ' SELECT  
			DISTINCT  T1.ComputerName ,  
			T2.ProcessTotal, ProcessUTCDate,
			T3.MemoryMB, MemoryUTCDate,
			T4.DiskQueue, DiskUTCDate,
			S.IPAddress  
		FROM 
			[ADSysMon].[dbo].[' + @TABLENAME + '] T1
			LEFT OUTER JOIN (
				SELECT   A.ComputerName , UTCMonitored AS ProcessUTCDate, Value AS ProcessTotal
				FROM [ADSysMon].[dbo].['+ @TABLENAME +'] A
				where path like ''%\Processor(_Total)\% Processor Time%''  
				and UTCMonitored = ( SELECT MAX(UTCMonitored) 
						FROM [ADSysMon].[dbo].[' + @TABLENAME + '] B
						WHERE A.ComputerName = B.ComputerName
							AND path like ''%\Processor(_Total)\% Processor Time%''  
						GROUP BY ComputerName  )
				GROUP BY ComputerName , UTCMonitored, VALUE
				) T2 ON ( T1.ComputerName = T2.ComputerName )
			LEFT OUTER JOIN (
				SELECT   A.ComputerName , UTCMonitored AS MemoryUTCDate, Value AS MemoryMB
				FROM [ADSysMon].[dbo].[' + @TABLENAME + '] A
				where path like ''%\Memory\Available MBytes%''  
				and UTCMonitored = ( SELECT MAX(UTCMonitored) 
						FROM [ADSysMon].[dbo].[' + @TABLENAME + '] B
						WHERE A.ComputerName = B.ComputerName
							AND path like ''%\Memory\Available MBytes%''  
						GROUP BY ComputerName  )
				GROUP BY ComputerName , UTCMonitored, VALUE
				) T3 ON ( T1.ComputerName = T3.ComputerName )
			LEFT OUTER JOIN ( 
				SELECT   A.ComputerName , UTCMonitored  AS DiskUTCDate, Value AS DiskQueue
				FROM [ADSysMon].[dbo].[' + @TABLENAME + '] A
				where path like ''%\PhysicalDisk(_Total)\Avg. Disk Queue Length%''  
				and UTCMonitored = ( SELECT MAX(UTCMonitored) 
					FROM [ADSysMon].[dbo].[' + @TABLENAME + '] B
					WHERE A.ComputerName = B.ComputerName
						AND path like ''%\PhysicalDisk(_Total)\Avg. Disk Queue Length%'' 
					GROUP BY ComputerName  )
				GROUP BY ComputerName , UTCMonitored, VALUE
				) T4 ON ( T1.ComputerName = T4.ComputerName )
			 LEFT OUTER JOIN (
					SELECT DISTINCT [ComputerName]
					,[IPAddress] 
					FROM [ADSysMon].[dbo].[TB_SERVERS]  ) S  ON ( T1.ComputerName = S.ComputerName )
		ORDER BY T1.ComputerName '
	 
	 /* 
	SELECT  
		DISTINCT  T1.ComputerName ,  ProcessTotal, MemoryMB, DiskQueue  , IPAddress
	FROM 
		[ADSysMon].[dbo].[TB_LGE_NET_PERFORMANCE] T1
		LEFT OUTER JOIN (
			SELECT   A.ComputerName , UTCMonitored, Value AS ProcessTotal
			FROM [ADSysMon].[dbo].[TB_LGE_NET_PERFORMANCE] A
			where path like '%\Processor(_Total)\% Processor Time%'  
			and UTCMonitored = ( SELECT MAX(UTCMonitored) 
					FROM [ADSysMon].[dbo].[TB_LGE_NET_PERFORMANCE] B
					WHERE A.ComputerName = B.ComputerName
						AND path like '%\Processor(_Total)\% Processor Time%'  
					GROUP BY ComputerName  )
			GROUP BY ComputerName , UTCMonitored, VALUE
			) T2 ON ( T1.ComputerName = T2.ComputerName )
		LEFT OUTER JOIN (
			SELECT   A.ComputerName , UTCMonitored, Value AS MemoryMB
			FROM [ADSysMon].[dbo].[TB_LGE_NET_PERFORMANCE] A
			where path like '%\Memory\Available MBytes%'  
			and UTCMonitored = ( SELECT MAX(UTCMonitored) 
					FROM [ADSysMon].[dbo].[TB_LGE_NET_PERFORMANCE] B
					WHERE A.ComputerName = B.ComputerName
						AND path like '%\Memory\Available MBytes%'  
					GROUP BY ComputerName  )
			GROUP BY ComputerName , UTCMonitored, VALUE
			) T3 ON ( T1.ComputerName = T3.ComputerName )
		LEFT OUTER JOIN ( 
			SELECT   A.ComputerName , UTCMonitored, Value AS DiskQueue
			FROM [ADSysMon].[dbo].[TB_LGE_NET_PERFORMANCE] A
			where path like '%\PhysicalDisk(_Total)\Avg. Disk Queue Length%'  
			and UTCMonitored = ( SELECT MAX(UTCMonitored) 
				FROM [ADSysMon].[dbo].[TB_LGE_NET_PERFORMANCE] B
				WHERE A.ComputerName = B.ComputerName
					AND path like '%\PhysicalDisk(_Total)\Avg. Disk Queue Length%'  
				GROUP BY ComputerName  )
			GROUP BY ComputerName , UTCMonitored, VALUE
			) T4 ON ( T1.ComputerName = T4.ComputerName )
		 LEFT OUTER JOIN (
				SELECT DISTINCT [ComputerName]
				,[IPAddress] 
				FROM [ADSysMon].[dbo].[TB_SERVERS]  ) S  ON ( T1.ComputerName = S.ComputerName )
	ORDER BY T1.ComputerName
	*/
	 

	EXEC SP_EXECUTESQL @SQL 
 
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHL
-- 작성일 : 2014.12.11
-- 수정일 : 2014.12.11  
-- 설   명 :  
-- 실   행 : EXEC [dbo].[USP_SELECT_SERVER_LIST] 
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_SERVER_LIST]  
	@USERID	NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;
	
	SELECT DISTINCT [Domain]
		,[ServiceFlag]
		,[ComputerName]
		,[IPAddress] 
	FROM [ADSysMon].[dbo].[TB_SERVERS]
	WHERE Domain IN ( SELECT VALUE2 FROM TB_MANAGE_COMPANY_USER U INNER JOIN TB_COMMON_CODE_SUB B 
			ON ( U.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' AND U.USERID = @USERID )  )
			 
	ORDER BY Domain, ServiceFlag, ComputerName
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVICE_AVAILABILITY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.10
-- 수정일 : 2014.12.10  
-- 설   명 : 회사별 서비스 가용성 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_SERVICE_AVAILABILITY_LIST] 'LGE','DHCP'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_SERVICE_AVAILABILITY_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_' + @ADSERVICE + 'ServiceAvailability';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime'
 
	SET @PARAM = N' @MonitorTime nvarchar(25)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVICE_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.10
-- 수정일 : 2014.12.10  
-- 설   명 : 회사별 서비스 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_SERVICE_LIST] 'LGE','ADDS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_SERVICE_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_SERVICE';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime AND ServiceFlag = @pADSERVICE'
 
	SET @PARAM = N' @MonitorTime nvarchar(25), @pADSERVICE nvarchar(10)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME , @pADSERVICE = @ADSERVICE 
 
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SERVICE_STATUS]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- [USP_SELECT_DASHBOARD_COM]
-- DASH BOARD Lv0 서비스별 Service Error Count 
-- EXEC [dbo].[USP_SELECT_SERVICE_STATUS] 'admin'
-- =============================================
CREATE PROCEDURE [dbo].[USP_SELECT_SERVICE_STATUS]
(
	@USERID nvarchar(10)
)
AS
BEGIN
 

	DECLARE @COMPANYCODE NVARCHAR(20)  
	DECLARE @ADSERVICE NVARCHAR(16)
	DECLARE @DATETIME DATETIME
	 

	CREATE TABLE #TMP_TB_BYSERVICE_STATUS (
		COMPANY NVARCHAR(20), 
		ADSERVICE NVARCHAR(10), 
		Serviceitem NVARCHAR(50), 
		MonitoredTime DATETIME, 
		CHK_CNT INT
	)

	DECLARE ADM_CURSOR_COM CURSOR FOR  
			SELECT VALUE2 FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] 
				WHERE CLASS_CODE = '0001'  AND VALUE2 IN ( SELECT [VALUE2] FROM TB_MANAGE_COMPANY_USER U INNER JOIN TB_COMMON_CODE_SUB B ON ( U.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' AND U.USERID = @USERID ) )
				ORDER BY SORT_SEQ ASC
 
	OPEN ADM_CURSOR_COM

	FETCH NEXT FROM ADM_CURSOR_COM INTO @COMPANYCODE

	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		--SELECT @COMPANYCODE
			SET @ADSERVICE = 'ADDS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE_STATUS
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE AND MonitoredTime > @DATETIME AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem


			SET @ADSERVICE = 'ADCS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE_STATUS
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE AND MonitoredTime > @DATETIME  AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem


			SET @ADSERVICE = 'DNS'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE_STATUS
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE AND MonitoredTime > @DATETIME  AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem

			SET @ADSERVICE = 'DHCP'
			SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)

			INSERT INTO #TMP_TB_BYSERVICE_STATUS
			SELECT Company, ADService, Serviceitem, CONVERT(varchar(16),Max(MonitoredTime),120) as LastMonitored, COUNT(*) as CntByServiceItem 
			  FROM [ADSysMon].[dbo].[TB_ProblemManagement] 
			 WHERE Company = @COMPANYCODE AND ADService = @ADSERVICE AND MonitoredTime > @DATETIME  AND ManageStatus = 'NOTSTARTED'
			 GROUP BY Company, ADService, Serviceitem


		FETCH NEXT FROM ADM_CURSOR_COM INTO @COMPANYCODE
	END 

	CLOSE ADM_CURSOR_COM
	DEALLOCATE ADM_CURSOR_COM
 
	SELECT TMP.ADService, SUB.CODE_NAME AS ADServiceName, IIF(TMP.CHK_CNT IS NULL, 0, TMP.CHK_CNT) AS ErrorCount, CONVERT(CHAR(20),  TMP.MonitoredTime, 120)  AS MonitoredTime
	  FROM [ADSysMon].[dbo].[TB_COMMON_CODE_SUB] AS SUB 
		INNER JOIN (	SELECT ADSERVICE, Serviceitem, MAX(MonitoredTime) as MonitoredTime, SUM(CHK_CNT) as CHK_CNT 
						FROM #TMP_TB_BYSERVICE_STATUS	
						GROUP BY ADSERVICE, Serviceitem
				   ) AS TMP ON SUB.SUB_CODE = TMP.Serviceitem
	 WHERE CLASS_CODE = '0003' 
 	 ORDER BY SORT_SEQ

	DROP TABLE #TMP_TB_BYSERVICE_STATUS 

END
 
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_SYSVOL_SHARES_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.11
-- 수정일 : 2014.12.11  
-- 설   명 : AD DS Sysvol Shares List
-- 실   행 : EXEC [dbo].[USP_SELECT_SYSVOL_SHARES_LIST] 'LGE','ADDS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_SYSVOL_SHARES_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_' + @ADSERVICE + 'SysvolShares';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime'
 
	SET @PARAM = N' @MonitorTime nvarchar(25)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TEST_ON_DEMAND_DATA]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 /*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHR
-- 작성일 : 2014.12.12  
-- 수정일 : 2014.12.12  
-- 설  명 : Test On-Demand PS1 실행 후 완료 업데이트
-- 실  행 :  USP_UPDATE_TEST_ON_DEMAND_COMPLETED @IDX=2, @TOD_Result='Y', @TOD_ResultScript='test<br/>test completed'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  

CREATE PROCEDURE  [dbo].[USP_SELECT_TEST_ON_DEMAND_DATA] 
	@IDX	int	 
AS
BEGIN

	SET NOCOUNT ON;
	 
	 
	SELECT 
		IDX,
		DemandDate, 
		Company, 
		TOD_Code, 
		S.CODE_NAME AS TOD_NAME,
		TOD_Demander, 
		TOD_Result, 
		TOD_ResultScript, 
		CompleteDate
	FROM	
		dbo.TB_TestOnDemand A
		LEFT OUTER JOIN TB_COMMON_CODE_SUB S ON ( A.TOD_Code = S.SUB_CODE AND S.CLASS_CODE = '0004' )
	 WHERE  IDX = @IDX
	
END
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TEST_ON_DEMAND_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHL
-- 작성일 : 2014.12.11
-- 수정일 : 2014.12.11  
-- 설   명 : TestOnDemand 테이블 조회
-- 실   행 : EXEC [dbo].[USP_SELECT_TEST_ON_DEMAND_LIST] 'admin'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_TEST_ON_DEMAND_LIST] 
	@USERID NVARCHAR(10)  
AS
BEGIN
	SET NOCOUNT ON;
	
	SELECT 
		IDX,
		DemandDate, 
		Company, 
		TOD_Code, 
		S.CODE_NAME AS TOD_NAME,
		TOD_Demander, 
		TOD_Result, 
		TOD_ResultScript, 
		CompleteDate
	FROM	
		dbo.TB_TestOnDemand A
		LEFT OUTER JOIN TB_COMMON_CODE_SUB S ON ( A.TOD_Code = S.SUB_CODE AND S.CLASS_CODE = '0004' )
	WHERE Company IN ( SELECT 
						   [VALUE2] 
	                    FROM TB_MANAGE_COMPANY_USER U INNER JOIN TB_COMMON_CODE_SUB B ON ( U.COMPANYCODE = B.SUB_CODE AND B.CLASS_CODE = '0001' AND U.USERID = @USERID ) 
						)
	

END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TEST_ON_DEMAND_PROCESSING_ITEM]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 /*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHR
-- 작성일 : 2014.12.12  
-- 수정일 : 2014.12.12  
-- 설  명 :  
-- 실  행 :  EXEC [dbo].[USP_SELECT_TEST_ON_DEMAND_PROCESSING_ITEM]  
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  

CREATE PROCEDURE  [dbo].[USP_SELECT_TEST_ON_DEMAND_PROCESSING_ITEM] 
AS
BEGIN

	SET NOCOUNT ON;
	
	SELECT 
		IDX,
		DemandDate, 
		Company, 
		TOD_Code, 
		S.CODE_NAME AS TOD_NAME,
		TOD_Demander, 
		TOD_Result, 
		TOD_ResultScript, 
		CompleteDate
	FROM	
		dbo.TB_TestOnDemand A
		LEFT OUTER JOIN TB_COMMON_CODE_SUB S ON ( A.TOD_Code = S.SUB_CODE AND S.CLASS_CODE = '0004' )
	WHERE IDX = (SELECT MAX(IDX) FROM dbo.TB_TestOnDemand A )
  
END
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TEST_ON_DEMAND_RUN]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 /*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHR
-- 작성일 : 2014.12.12  
-- 수정일 : 2014.12.12  
-- 설  명 :  
-- 실  행 :  EXEC [dbo].[USP_SELECT_TEST_ON_DEMAND_RUN]  
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  

CREATE PROCEDURE  [dbo].[USP_SELECT_TEST_ON_DEMAND_RUN] 
AS
BEGIN

	SET NOCOUNT ON;
	
	IF ( EXISTS ( SELECT 'x' FROM dbo.TB_TestOnDemand WHERE TOD_Result = 'N' ) )
	BEGIN
		SELECT 'TRUE'
	END
	ELSE
	BEGIN
		SELECT 'FALSE'
	END

   
END
GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_TOPOLOGY_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.11
-- 수정일 : 2014.12.11  
-- 설   명 : AD DS Topology And Intersite Messaging List
-- 실   행 : EXEC [dbo].[USP_SELECT_TOPOLOGY_LIST] 'LGE','ADDS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_TOPOLOGY_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_' + @ADSERVICE + 'Topology';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime'
 
	SET @PARAM = N' @MonitorTime nvarchar(25)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_USER_INFO]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHL
-- 작성일 : 2014.12.09  
-- 수정일 : 2014.12.09  
-- 설   명 : 사용자 정보조회
-- 실   행 : EXEC [dbo].[USP_SELECT_USER_INFO] 'admin'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_USER_INFO] 
	@USERID NVARCHAR(10)
AS
BEGIN
	SET NOCOUNT ON;
	
	SELECT 
		USERID,
		USERNAME,
		[PASSWORD],
		MAILADDRESS,
		MOBILEPHONE,
		CREATE_DATE
	  FROM dbo.TB_USER
	 WHERE USERID = @USERID
	   AND USEYN = 'Y' 
END



GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_USER_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHL
-- 작성일 : 2014.12.09  
-- 수정일 : 2014.12.09  
-- 설   명 : 사용자 정보조회
-- 실   행 : EXEC [dbo].[USP_SELECT_USER_INFO] 'admin'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_USER_LIST]  
AS
BEGIN
	SET NOCOUNT ON;
	
	SELECT 
		USERID,
		USERNAME,
		[PASSWORD],
		MAILADDRESS,
		MOBILEPHONE,
		CREATE_DATE
	  FROM dbo.TB_USER
	 WHERE USEYN = 'Y' 
END



GO
/****** Object:  StoredProcedure [dbo].[USP_SELECT_W32TIMESYNC_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.11
-- 수정일 : 2014.12.11  
-- 설   명 : AD DS Advertisement List
-- 실   행 : EXEC [dbo].[USP_SELECT_W32TIMESYNC_LIST] 'LGE','ADDS'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_SELECT_W32TIMESYNC_LIST] 
	@COMPANYCODE NVARCHAR(10)  
	,@ADSERVICE NVARCHAR(16)
AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @TABLENAME nvarchar(50), @CTABLE nvarchar(50)
	
	DECLARE @DATETIME DATETIME
	SET @DATETIME = [dbo].[UFN_GET_MONITOR_DATE] ( @COMPANYCODE, @ADSERVICE)
	
	SELECT 
		@CTABLE = VALUE1
	FROM
	TB_COMMON_CODE_SUB S
	WHERE CLASS_CODE = '0001'
	AND SUB_CODE = @COMPANYCODE
	SET @TABLENAME = 'TB_' + @CTABLE + '_' + @ADSERVICE + 'W32TIMESYNC';

 
	DECLARE @SQL nvarchar(max)
	DECLARE @COLUMNS_NAME nvarchar(max)
	DECLARE @PARAM nvarchar(100)

 
	SET @COLUMNS_NAME = [dbo].[UFN_GET_TABLE_COLUMNS_STR](@TABLENAME)

	SET @SQL = 'SELECT ' + @COLUMNS_NAME + ' FROM [ADSysMon].[dbo].[' + @TABLENAME + ']'
 
	SET @SQL = @SQL + ' WHERE UTCMonitored > @MonitorTime'
 
	SET @PARAM = N' @MonitorTime nvarchar(25)'

	EXEC SP_EXECUTESQL @SQL, @PARAM, @MonitorTime = @DATETIME
 
END


GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_CHANGE_PASSWORD]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.18
-- 수정일 : 2014.12.18  
-- 설   명 : 사용자 비밀번호 변경
-- 실   행 : EXEC [dbo].[USP_UPDATE_CHANGE_PASSWORD] 'admin','1'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_UPDATE_CHANGE_PASSWORD]
	@USERID			NVARCHAR(10),
    @NEWPASSWORD	NVARCHAR(1000)
AS 
	BEGIN 
	SET nocount ON;	

	UPDATE [dbo].[TB_USER]
	   SET [PASSWORD] = @NEWPASSWORD
	 WHERE [USERID] = @USERID
END 



 


GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_MANAGE_COMPANY_USER]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 
/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.19  
-- 수정일 : 2014.12.19  
-- 설   명 : 회사 담당 목록 논리 삭제(수정)
-- 실   행 : EXEC [dbo].[USP_UPDATE_MANAGE_COMPANY_USER] 'admin', 'HIP^LGCNSC^LGE^LGD','system', 'N'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_UPDATE_MANAGE_COMPANY_USER] 
	@USERID			NVARCHAR(10),
	@COMPANYCODE	NVARCHAR(MAX),
	@CREATEID		NVARCHAR(10),
	@USEYN			CHAR(1)
AS
BEGIN
	SET NOCOUNT ON;	

	UPDATE [dbo].[TB_MANAGE_COMPANY_USER]
	   SET USEYN = @USEYN,
		   CREATE_ID = @CREATEID,
		   CREATE_DATE = GETUTCDATE()
	 WHERE USERID = @USERID
	   AND COMPANYCODE IN (SELECT * FROM [dbo].[UFN_GET_SPLIT_BigSize] (@COMPANYCODE,'^')) 
END
GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.12
-- 수정일 : 2014.12.16  
-- 설   명 : ProblemManagement 테이블 처리 사항 등록
-- 실   행 : EXEC [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST] '11887^11886^11885','ONGOING','system','abc','11887'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST] 
    @ARRIDX		NVARCHAR(MAX)
   ,@SCODE		NVARCHAR(20)
   ,@MANAGER	NVARCHAR(50)
   ,@SCRIPT		NVARCHAR(MAX)
   ,@MANAGEIDX	INT
AS 
	BEGIN 
	--SET nocount ON;
	
	UPDATE	 [dbo].[TB_ProblemManagement]
	   SET	 [ManageStatus] = @SCODE
			,[Manager] = @MANAGER
			,[ManageScript] = @SCRIPT
			,[ManageDate] = GETUTCDATE()
			,[ManageIDX] = @MANAGEIDX
	 WHERE   [IDX] IN (SELECT * FROM [dbo].[UFN_GET_SPLIT_BigSize] (@ARRIDX, '^'))
END 



 


GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST_TEST]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 KTW
-- 작성일 : 2014.12.12
-- 수정일 : 2014.12.16  
-- 설   명 : ProblemManagement 테이블 처리 사항 등록
-- 실   행 : EXEC [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST] '11887^11886^11885','ONGOING','system','abc','11887'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/
CREATE PROCEDURE [dbo].[USP_UPDATE_PROBLEM_MANAGEMENT_LIST_TEST] 
    @ARRIDX		NVARCHAR(MAX)
   ,@SCODE		NVARCHAR(20)
   ,@MANAGER	NVARCHAR(50)
   ,@SCRIPT		NVARCHAR(MAX)
   ,@MANAGEIDX	INT
AS 
	BEGIN 
	SET nocount ON;
	
	UPDATE	 [dbo].[TB_ProblemManagement]
	   SET	 [ManageStatus] = @SCODE
			,[Manager] = @MANAGER
			,[ManageScript] = @SCRIPT
			,[ManageDate] = GETUTCDATE()
			,[ManageIDX] = @MANAGEIDX
	 WHERE   [IDX] IN (SELECT * FROM [dbo].[UFN_GET_SPLIT_BigSize] (@ARRIDX, '^'))
END 



 


GO
/****** Object:  StoredProcedure [dbo].[USP_UPDATE_TEST_ON_DEMAND_COMPLETED]    Script Date: 2015-01-13 오후 6:58:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 /*------------------------------------------------------------------------------------  
-- 작성자 : 닷넷소프트 PHR
-- 작성일 : 2014.12.12  
-- 수정일 : 2014.12.12  
-- 설  명 : Test On-Demand PS1 실행 후 완료 업데이트
-- 실  행 :  USP_UPDATE_TEST_ON_DEMAND_COMPLETED @IDX=2, @TOD_Result='Y', @TOD_ResultScript='test<br/>test completed'
-------------------------------------------------------------------------------------  
-- 수   정   일 :   
-- 수   정   자 :   
-- 수 정  내 용 :   
------------------------------------------------------------------------------------*/  

CREATE PROCEDURE  [dbo].[USP_UPDATE_TEST_ON_DEMAND_COMPLETED] 
	@IDX	int							-- IDX 
	,@TOD_Result		nvarchar(1)		-- 처리 완료 ( 'Y')
	,@TOD_ResultScript	nvarchar(MAX)	-- 테스트 결과
AS
BEGIN

	SET NOCOUNT ON;
	
	 
	 UPDATE [dbo].[TB_TestOnDemand]
	    SET   
			TOD_Result = @TOD_Result, 
			TOD_ResultScript = @TOD_ResultScript, 
			CompleteDate = GETUTCDATE()
	 WHERE  IDX = @IDX
	
END
GO
