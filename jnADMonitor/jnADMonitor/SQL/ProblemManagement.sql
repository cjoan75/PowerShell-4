/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP 1000 *
	FROM [ADSysMon].[dbo].[TB_ProblemManagement]
--	Where ComputerName like '%.%'
--	group by Serviceitem
	Order by MonitoredTime desc


--CAName :<br/>
--DNSName :<br/>
--CAType : (CertUtil:) (CertUtil:)<br/>
--PingAdmin :Connecting to DNPROD01.dotnetsoft.co.kr\dotnetsoft-DNPROD01-CA ...<br/>CertUtil: -pingadmin command FAILED: 0x800706ba (WIN32: 1722 RPC_S_SERVER_UNAVAILABLE)<br/>CertUtil: The RPC server is unavailable.<br/><br/>
--Ping :Connecting to DNPROD01.dotnetsoft.co.kr\dotnetsoft-DNPROD01-CA ...<br/>Server could not be reached: The RPC server is unavailable. 0x800706ba (WIN32: 1722 RPC_S_SERVER_UNAVAILABLE) -- (0ms)<br/><br/>CertUtil: -ping command FAILED: 0x800706ba (WIN32: 1722 RPC_S_SERVER_UNAVAILABLE)<br/>CertUtil: The RPC server is unavailable.<br/><br/>
--CrlPublishStatus :CertUtil: -CAInfo command FAILED: 0x800706ba (WIN32: 1722 RPC_S_SERVER_UNAVAILABLE)<br/>CertUtil: The RPC server is unavailable.<br/><br/>
--DeltaCrlPublishStatus :CertUtil: -CAInfo command FAILED: 0x800706ba (WIN32: 1722 RPC_S_SERVER_UNAVAILABLE)<br/>CertUtil: The RPC server is unavailable.<br/>


-->