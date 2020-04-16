select A.linea || B.linea
from
(
select 'CPUPCT=' || to_char(round((sum(AVG_CPU_UTILIZATION)/max(CPU_UTILIZATION_LIMIT))*100,0)) || ';' ||
'RUNQUEUE=' || to_char(ceil(sum(AVG_QUEUED_PARALLEL_STMTS))) || ';' ||
'CPUCOUNT=' as LINEA
from GV$RSRCMGRMETRIC) A,
(select value as linea from gv$parameter where name like 'cpu_count') B;

