SELECT 
count(distinct(id)) as number_of_shards,
cast(sum(num_docs) as integer) as number_of_records
FROM sys.shards;

SELECT count(1) as number_of_nodes
FROM sys.nodes;

SELECT count(distinct(table_name)) as number_of_tables
FROM information_schema.tables
WHERE schema_name not in ('information_schema', 'sys');

SELECT
settings
FROM sys.cluster;

SELECT 
name,
hostname,
version['number'] as crate_version,
round(heap['max'] / 1024.0 / 1024.0) 
  as total_heap_mb,
round((mem['free'] + mem['used']) / 1024.0 / 1024.0)
  as total_memory_mb,
os_info['available_processors'] as cpus,
os['uptime'] /1000 as uptime_s
FROM sys.nodes
ORDER BY os['uptime'] DESC;
