SELECT TOP 1000 [Domain] ,[ServiceFlag] ,[ComputerName] ,[IPAddress] ,[UTCMonitored] 
FROM [dbo].[TB_SERVERS] 
WHERE [ServiceFlag] IN ('ADDS', 'ADCS', 'DNS', 'DHCP')

INSERT INTO [dbo].[TB_SERVERS]
    ([Domain]
    ,[ServiceFlag]
    ,[ComputerName]
    ,[IPAddress]
    ,[UTCMonitored])
VALUES
    ('dotnetsoft.co.kr'
    , 'DNS'
    , 'DNPROD00'
    , '192.168.10.10'
    , GETUTCDATE()
	)
GO

