select * from TB_SERVERS
   where SErviceFlag in ( 'ADDS' )
--87

select * from TB_SERVERS
   where SErviceFlag in ( 'DNS' )
--38

select ComputerName from TB_SERVERS
   where ComputerName not in ( select DISTINCT ComputerName FROM TB_SERVERS  WHERE ServiceFlag in ( 'DNS') )
    and ServiceFlag = 'ADDS'
   group by ComputerName
--62

select ComputerName from TB_SERVERS
   where SErviceFlag in ( 'ADDS', 'DNS' )
   group by ComputerName
   having count(*) >=2
--25

select ComputerName, IPAddress from TB_SERVERS
   where ComputerName not in ( select DISTINCT ComputerName FROM TB_SERVERS  WHERE ServiceFlag in ( 'ADDS') )
    and ServiceFlag = 'DNS'
   group by ComputerName
--13
