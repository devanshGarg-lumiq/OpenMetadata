-- Unique constraint for user email address
ALTER TABLE user_entity
ADD UNIQUE (email);


-- Remove classificationName in BigQuery
UPDATE dbservice_entity
SET json = JSON_REMOVE(json, '$.connection.config.classificationName') where serviceType in ('BigQuery');

-- migrate ingestAllDatabases in postgres 
UPDATE dbservice_entity de2 
SET json = JSON_REPLACE(
    JSON_INSERT(json, 
      '$.connection.config.database', 
      (select JSON_EXTRACT(json, '$.name') 
        from database_entity de 
        where id = (select er.toId 
            from entity_relationship er 
            where er.fromId = de2.id 
              and er.toEntity = 'database' 
            LIMIT 1
          ))
    ), '$.connection.config.ingestAllDatabases', 
    true
  ) 
where de2.serviceType = 'Postgres' 
  and JSON_EXTRACT(json, '$.connection.config.database') is NULL;

-- new object store service and container entities
CREATE TABLE IF NOT EXISTS objectstore_service_entity (
    id VARCHAR(36) GENERATED ALWAYS AS (json ->> '$.id') STORED NOT NULL,
    name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL,
    serviceType VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.serviceType') NOT NULL,
    json JSON NOT NULL,
    updatedAt BIGINT UNSIGNED GENERATED ALWAYS AS (json ->> '$.updatedAt') NOT NULL,
    updatedBy VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.updatedBy') NOT NULL,
    deleted BOOLEAN GENERATED ALWAYS AS (json -> '$.deleted'),
    PRIMARY KEY (id),
    UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS objectstore_container_entity (
    id VARCHAR(36) GENERATED ALWAYS AS (json ->> '$.id') STORED NOT NULL,
    fullyQualifiedName VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.fullyQualifiedName') NOT NULL,
    json JSON NOT NULL,
    updatedAt BIGINT UNSIGNED GENERATED ALWAYS AS (json ->> '$.updatedAt') NOT NULL,
    updatedBy VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.updatedBy') NOT NULL,
    deleted BOOLEAN GENERATED ALWAYS AS (json -> '$.deleted'),
    PRIMARY KEY (id),
    UNIQUE (fullyQualifiedName)
);

CREATE TABLE IF NOT EXISTS test_connection_definition (
    id VARCHAR(36) GENERATED ALWAYS AS (json ->> '$.id') STORED NOT NULL,
    name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL,
    json JSON NOT NULL,
    updatedAt BIGINT UNSIGNED GENERATED ALWAYS AS (json ->> '$.updatedAt') NOT NULL,
    updatedBy VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.updatedBy') NOT NULL,
    deleted BOOLEAN GENERATED ALWAYS AS (json -> '$.deleted'),
    PRIMARY KEY (id),
    UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS automations_workflow (
    id VARCHAR(36) GENERATED ALWAYS AS (json ->> '$.id') STORED NOT NULL,
    name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL,
    workflowType VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.workflowType') STORED NOT NULL,
    status VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.status') STORED,
    json JSON NOT NULL,
    updatedAt BIGINT UNSIGNED GENERATED ALWAYS AS (json ->> '$.updatedAt') NOT NULL,
    updatedBy VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.updatedBy') NOT NULL,
    deleted BOOLEAN GENERATED ALWAYS AS (json -> '$.deleted'),
    PRIMARY KEY (id),
    UNIQUE (name)
);

-- Do not store OM server connection, we'll set it dynamically on the resource
UPDATE ingestion_pipeline_entity
SET json = JSON_REMOVE(json, '$.openMetadataServerConnection');

CREATE TABLE IF NOT EXISTS query_entity (
    id VARCHAR(36) GENERATED ALWAYS AS (json ->> '$.id') NOT NULL,
    name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL,
    json JSON NOT NULL,
    updatedAt BIGINT UNSIGNED GENERATED ALWAYS AS (json ->> '$.updatedAt') NOT NULL,
    updatedBy VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.updatedBy') NOT NULL,
    deleted BOOLEAN GENERATED ALWAYS AS (json -> '$.deleted'),
    UNIQUE(name),
    INDEX name_index (name)
);

CREATE TABLE IF NOT EXISTS temp_query_migration (
    tableId VARCHAR(36)NOT NULL,
    queryId VARCHAR(36) GENERATED ALWAYS AS (json ->> '$.id') NOT NULL,
    json JSON NOT NULL
);


INSERT INTO temp_query_migration(tableId,json)
SELECT id,JSON_OBJECT('id',UUID(),'vote',vote,'query',query,'users',users,'checksum',checksum,'duration',duration,'name','table','name',checksum,
'updatedAt',UNIX_TIMESTAMP(NOW()),'updatedBy','admin','deleted',false) as json from entity_extension d, json_table(d.json, '$[*]' columns (vote double path '$.vote', query varchar(200) path '$.query',users json path '$.users',checksum varchar(200) path '$.checksum',duration double path '$.duration',
queryDate varchar(200) path '$.queryDate')) AS j WHERE extension = "table.tableQueries";

INSERT INTO query_entity(json)
SELECT json FROM temp_query_migration;

INSERT INTO entity_relationship(fromId,toId,fromEntity,toEntity,relation)
SELECT tableId,queryId,"table","query",5 FROM temp_query_migration;

DELETE FROM entity_extension WHERE id IN
 (SELECT DISTINCT tableId FROM temp_query_migration) AND extension = "table.tableQueries";

DROP Table temp_query_migration;

-- remove the audience if it was wrongfully sent from the UI after editing the OM service
UPDATE metadata_service_entity
SET json = JSON_REMOVE(json, '$.connection.config.securityConfig.audience')
WHERE name = 'OpenMetadata' AND JSON_EXTRACT(json, '$.connection.config.authProvider') != 'google';

ALTER TABLE user_tokens MODIFY COLUMN expiryDate BIGINT UNSIGNED GENERATED ALWAYS AS (json ->> '$.expiryDate');

DELETE FROM alert_entity;
DROP TABLE alert_action_def;

ALTER TABLE alert_entity RENAME TO event_subscription_entity;

-- create data model table
CREATE TABLE IF NOT EXISTS dashboard_data_model_entity (
    id VARCHAR(36) GENERATED ALWAYS AS (json ->> '$.id') STORED NOT NULL,
    fqnHash VARCHAR(256)  NOT NULL,
    json JSON NOT NULL,
    updatedAt BIGINT UNSIGNED GENERATED ALWAYS AS (json ->> '$.updatedAt') NOT NULL,
    updatedBy VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.updatedBy') NOT NULL,
    deleted BOOLEAN GENERATED ALWAYS AS (json -> '$.deleted'),
    PRIMARY KEY (id),
    UNIQUE (fqnHash)
);

UPDATE dbservice_entity
SET json = JSON_INSERT(
        JSON_REMOVE(json, '$.connection.config.database'),
        '$.connection.config.databaseName', JSON_EXTRACT(json, '$.connection.config.database')
    )
where serviceType = 'Druid'
  and JSON_EXTRACT(json, '$.connection.config.database') is not null;

-- We were using the same jsonSchema for Pipeline Services and Ingestion Pipeline status
-- Also, we relied on the extension to store the run id
UPDATE entity_extension_time_series
SET jsonSchema = 'ingestionPipelineStatus', extension = 'ingestionPipeline.pipelineStatus'
WHERE jsonSchema = 'pipelineStatus' AND extension <> 'pipeline.PipelineStatus';


-- add fullyQualifiedName hash and remove existing columns

-- update the OM system tables

ALTER TABLE  field_relationship DROP KEY `PRIMARY`, ADD COLUMN fromFQNHash VARCHAR(256), ADD COLUMN toFQNHash VARCHAR(256),
DROP INDEX from_index, DROP INDEX to_index, ADD INDEX from_fqnhash_index(fromFQNHash, relation), ADD INDEX to_fqnhash_index(toFQNHash, relation),
ADD CONSTRAINT  `field_relationship_primary` PRIMARY KEY(fromFQNHash, toFQNHash, relation), MODIFY fromFQN VARCHAR(2096) NOT NULL,
MODIFY toFQN VARCHAR(2096) NOT NULL;

ALTER TABLE entity_extension_time_series DROP COLUMN entityFQN, ADD COLUMN entityFQNHash VARCHAR (256) NOT NULL;

ALTER TABLE type_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);

ALTER TABLE event_subscription_entity DROP KEY `name`,  ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);

ALTER TABLE test_definition DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE test_suite DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE test_case DROP COLUMN fullyQualifiedName,  ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL,
    ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash);

ALTER TABLE web_analytic_event DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash);
ALTER TABLE data_insight_chart DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash);
ALTER TABLE kpi_entity  DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);

ALTER TABLE classification  DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);;

ALTER TABLE glossary_term_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;

ALTER TABLE tag DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;

ALTER TABLE tag_usage DROP index `source`, DROP COLUMN targetFQN, ADD COLUMN tagFQNHash VARCHAR(256), ADD COLUMN targetFQNHash VARCHAR(256),
    ADD UNIQUE KEY `tag_usage_key` (source, tagFQNHash, targetFQNHash);

ALTER TABLE policy_entity DROP COLUMN fullyQualifiedName,  ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;

ALTER TABLE role_entity DROP KEY `name`,  ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE automations_workflow DROP KEY `name`,  ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE test_connection_definition DROP KEY `name`,  ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);


-- update services
ALTER TABLE dbservice_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE messaging_service_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE dashboard_service_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE pipeline_service_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE storage_service_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE metadata_service_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE mlmodel_service_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE objectstore_service_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);



-- all entity tables
ALTER TABLE database_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE database_schema_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE table_entity DROP COLUMN fullyQualifiedName,  ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE metric_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE report_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE dashboard_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE chart_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE ml_model_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE pipeline_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE topic_entity DROP COLUMN fullyQualifiedName,  ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE location_entity DROP COLUMN fullyQualifiedName,  ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE ingestion_pipeline_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE objectstore_container_entity DROP COLUMN fullyQualifiedName, ADD COLUMN fqnHash VARCHAR(256) NOT NULL, ADD UNIQUE (fqnHash),
ADD COLUMN name VARCHAR(256) GENERATED ALWAYS AS (json ->> '$.name') NOT NULL;
ALTER TABLE query_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE team_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE user_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE bot_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);
ALTER TABLE glossary_entity DROP KEY `name`, ADD COLUMN nameHash VARCHAR(256) NOT NULL, ADD UNIQUE (nameHash);







